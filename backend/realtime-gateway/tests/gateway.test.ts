import assert from "node:assert/strict";
import { after, before, describe, test } from "node:test";

import { WebSocket } from "ws";

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
		const verifier = new DevTicketVerifier();
		assert.equal((await verifier.verify(null)).ok, false);
		assert.equal((await verifier.verify("   ")).ok, false);
		assert.equal((await verifier.verify("anything")).ok, true);
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

	test("accepts a connection carrying a ticket and greets it", async () => {
		const socket = new WebSocket(`${baseUrl}${WEBSOCKET_PATH}?ticket=dev`);
		try {
			const greeting = await nextMessage(socket);
			assert.equal(greeting["type"], "gateway_hello");
			assert.equal(greeting["service"], "realtime-gateway");
			assert.equal(gateway.connectionCount(), 1);

			// M0 没有玩法协议，任何入站消息都必须得到明确的"未实现"，
			// 而不是被 echo 回去让调用方误以为通道可用。
			socket.send(JSON.stringify({ type: "anything" }));
			const reply = await nextMessage(socket);
			assert.equal(reply["type"], "gateway_not_implemented");
		} finally {
			socket.close();
		}
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
});

function addressPort(gateway: Gateway): number {
	const address = gateway.app.server.address();
	if (address === null || typeof address === "string") {
		throw new Error("expected the gateway to be listening on a TCP port");
	}
	return address.port;
}

function nextMessage(socket: WebSocket): Promise<Record<string, unknown>> {
	return new Promise((resolvePromise, rejectPromise) => {
		socket.once("message", (data) => {
			try {
				resolvePromise(JSON.parse(data.toString()) as Record<string, unknown>);
			} catch (error) {
				rejectPromise(error);
			}
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
