import assert from "node:assert/strict";
import { after, before, describe, test } from "node:test";

import { WebSocket, WebSocketServer } from "ws";

import type { ReadinessCheck, ReadinessPayload } from "../../contracts/src/index.ts";
import {
	WEBSOCKET_PATH,
	buildGateway,
	type ControlPlaneProbe,
	type Gateway,
} from "../src/server.ts";
import { DevTicketVerifier, type TicketVerdict, type TicketVerifier } from "../src/ticket.ts";

class StubProbe implements ControlPlaneProbe {
	ok = true;

	async check(): Promise<ReadinessCheck> {
		return this.ok
			? { name: "control_plane_reachable", ok: true }
			: { name: "control_plane_reachable", ok: false, detail: "stubbed failure" };
	}
}

class RejectingVerifier implements TicketVerifier {
	async verify(): Promise<TicketVerdict> {
		return { ok: false, reason: "stubbed rejection" };
	}
}

describe("dev ticket verifier", () => {
	test("rejects missing and blank tickets", async () => {
		const verifier = new DevTicketVerifier("ws://127.0.0.1:1");
		assert.equal((await verifier.verify(null)).ok, false);
		assert.equal((await verifier.verify("   ")).ok, false);
	});

	test("accepts any non-empty ticket and resolves the configured dev upstream", async () => {
		const verifier = new DevTicketVerifier("ws://127.0.0.1:18211");
		const verdict = await verifier.verify("anything");
		assert.equal(verdict.ok, true);
		assert.equal(verdict.upstreamUrl, "ws://127.0.0.1:18211");
	});

	test("accepts without an upstream when none is configured", async () => {
		const verifier = new DevTicketVerifier();
		const verdict = await verifier.verify("anything");
		assert.equal(verdict.ok, true);
		assert.equal(verdict.upstreamUrl, undefined);
	});
});

describe("gateway readiness", () => {
	const probe = new StubProbe();
	let gateway: Gateway;

	before(async () => {
		gateway = buildGateway({
			ticketVerifier: new DevTicketVerifier(),
			controlPlaneProbe: probe,
			version: "1.2.3-test",
			logger: false,
		});
		await gateway.app.ready();
	});

	after(async () => {
		await gateway.close();
	});

	test("is ready while the control plane is reachable", async () => {
		probe.ok = true;
		const response = await gateway.app.inject({ method: "GET", url: "/readyz" });

		assert.equal(response.statusCode, 200);
		assert.equal(response.json<ReadinessPayload>().status, "ready");
	});

	test("returns 503 when the control plane is unreachable", async () => {
		probe.ok = false;
		const response = await gateway.app.inject({ method: "GET", url: "/readyz" });

		assert.equal(response.statusCode, 503);
		assert.equal(response.json<ReadinessPayload>().status, "not_ready");
	});
});

describe("gateway websocket handshake", () => {
	let gateway: Gateway;
	let baseUrl: string;

	before(async () => {
		gateway = buildGateway({
			ticketVerifier: new DevTicketVerifier(),
			controlPlaneProbe: new StubProbe(),
			version: "1.2.3-test",
			logger: false,
		});
		// 端口 0 让内核挑一个空闲端口，避免并行测试互相抢占。
		await gateway.app.listen({ host: "127.0.0.1", port: 0 });
		baseUrl = `ws://127.0.0.1:${addressPort(gateway)}`;
	});

	after(async () => {
		await gateway.close();
	});

	test("rejects a connection without a ticket", async () => {
		const socket = new WebSocket(`${baseUrl}${WEBSOCKET_PATH}`);
		const error = await nextError(socket);
		assert.match(error.message, /401/);
	});

	test("rejects an unknown path", async () => {
		const socket = new WebSocket(`${baseUrl}/nope?ticket=dev`);
		const error = await nextError(socket);
		assert.match(error.message, /404/);
	});

	test("rejects a connection the verifier turns down", async () => {
		const strict = buildGateway({
			ticketVerifier: new RejectingVerifier(),
			controlPlaneProbe: new StubProbe(),
			version: "1.2.3-test",
			logger: false,
		});
		await strict.app.listen({ host: "127.0.0.1", port: 0 });

		try {
			const socket = new WebSocket(`ws://127.0.0.1:${addressPort(strict)}${WEBSOCKET_PATH}?ticket=x`);
			const error = await nextError(socket);
			assert.match(error.message, /401/);
		} finally {
			await strict.close();
		}
	});

	test("rejects with 502 when the verdict carries no upstream", async () => {
		const socket = new WebSocket(`${baseUrl}${WEBSOCKET_PATH}?ticket=dev`);
		const error = await nextError(socket);
		assert.match(error.message, /502/);
	});
});

describe("gateway websocket proxy", () => {
	let upstream: WebSocketServer;
	let upstreamUrl: string;
	let gateway: Gateway;
	let baseUrl: string;
	let upstreamConnections: number;
	const upstreamInbox: Array<{ data: Buffer; isBinary: boolean }> = [];

	before(async () => {
		upstreamConnections = 0;
		upstream = new WebSocketServer({ host: "127.0.0.1", port: 0 });
		upstream.on("connection", (socket) => {
			upstreamConnections += 1;
			// 入场即推一帧二进制，模拟对局进程的快照广播。
			socket.send(Buffer.from([1, 2, 3]), { binary: true });
			socket.on("message", (data: Buffer, isBinary: boolean) => {
				upstreamInbox.push({ data: Buffer.from(data), isBinary });
				// 原样回显，验证下游→上游→下游的完整回路。
				socket.send(data, { binary: isBinary });
			});
		});
		await new Promise<void>((resolvePromise) => upstream.on("listening", resolvePromise));
		const address = upstream.address();
		if (address === null || typeof address === "string") {
			throw new Error("expected the fake upstream to be listening on a TCP port");
		}
		upstreamUrl = `ws://127.0.0.1:${address.port}`;

		gateway = buildGateway({
			ticketVerifier: new DevTicketVerifier(upstreamUrl),
			controlPlaneProbe: new StubProbe(),
			version: "1.2.3-test",
			logger: false,
		});
		await gateway.app.listen({ host: "127.0.0.1", port: 0 });
		baseUrl = `ws://127.0.0.1:${addressPort(gateway)}`;
	});

	after(async () => {
		await gateway.close();
		await new Promise<void>((resolvePromise) => upstream.close(() => resolvePromise()));
	});

	test("forwards binary frames both ways unchanged", async () => {
		const socket = new WebSocket(`${baseUrl}${WEBSOCKET_PATH}?ticket=dev`);
		try {
			const greeting = await nextRawMessage(socket);
			assert.equal(greeting.isBinary, true);
			assert.deepEqual([...greeting.data], [1, 2, 3]);
			assert.equal(gateway.connectionCount(), 1);

			const command = Buffer.from([9, 8, 7, 6]);
			socket.send(command, { binary: true });
			const echo = await nextRawMessage(socket);
			assert.equal(echo.isBinary, true);
			assert.deepEqual([...echo.data], [9, 8, 7, 6]);

			await waitFor(() => upstreamInbox.length >= 1);
			assert.deepEqual([...upstreamInbox[0]!.data], [9, 8, 7, 6]);
			assert.equal(upstreamInbox[0]!.isBinary, true);
		} finally {
			socket.close();
		}
	});

	test("preserves text frames as text", async () => {
		const socket = new WebSocket(`${baseUrl}${WEBSOCKET_PATH}?ticket=dev`);
		try {
			await nextRawMessage(socket);
			socket.send("hello-upstream");
			const echo = await nextRawMessage(socket);
			assert.equal(echo.isBinary, false);
			assert.equal(echo.data.toString(), "hello-upstream");
		} finally {
			socket.close();
		}
	});

	test("closing the client closes the upstream connection", async () => {
		const socket = new WebSocket(`${baseUrl}${WEBSOCKET_PATH}?ticket=dev`);
		await nextRawMessage(socket);
		assert.equal(gateway.connectionCount(), 1);
		socket.close();
		await waitFor(() => gateway.connectionCount() === 0);
	});

	test("rejects with 502 when the upstream is unreachable", async () => {
		const dead = buildGateway({
			ticketVerifier: new DevTicketVerifier("ws://127.0.0.1:1"),
			controlPlaneProbe: new StubProbe(),
			version: "1.2.3-test",
			logger: false,
		});
		await dead.app.listen({ host: "127.0.0.1", port: 0 });

		try {
			const socket = new WebSocket(`ws://127.0.0.1:${addressPort(dead)}${WEBSOCKET_PATH}?ticket=dev`);
			const error = await nextError(socket);
			assert.match(error.message, /502/);
		} finally {
			await dead.close();
		}
	});

	test("never touches the upstream when the ticket is missing", async () => {
		const before = upstreamConnections;
		const socket = new WebSocket(`${baseUrl}${WEBSOCKET_PATH}`);
		const error = await nextError(socket);
		assert.match(error.message, /401/);
		assert.equal(upstreamConnections, before);
	});
});

function addressPort(gateway: Gateway): number {
	const address = gateway.app.server.address();
	if (address === null || typeof address === "string") {
		throw new Error("expected the gateway to be listening on a TCP port");
	}
	return address.port;
}

interface RawFrame {
	data: Buffer;
	isBinary: boolean;
}

function nextRawMessage(socket: WebSocket): Promise<RawFrame> {
	return new Promise((resolvePromise, rejectPromise) => {
		socket.once("message", (data: Buffer, isBinary: boolean) => {
			resolvePromise({ data: Buffer.from(data), isBinary });
		});
		socket.once("error", rejectPromise);
	});
}

function nextError(socket: WebSocket): Promise<Error> {
	return new Promise((resolvePromise, rejectPromise) => {
		socket.once("error", resolvePromise);
		socket.once("open", () => {
			socket.close();
			rejectPromise(new Error("expected the upgrade to be rejected, but it succeeded"));
		});
	});
}

async function waitFor(condition: () => boolean, timeoutMs = 2000): Promise<void> {
	const deadline = Date.now() + timeoutMs;
	while (!condition()) {
		if (Date.now() > deadline) {
			throw new Error("timed out waiting for condition");
		}
		await new Promise((resolvePromise) => setTimeout(resolvePromise, 10));
	}
}
