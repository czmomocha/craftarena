import assert from "node:assert/strict";
import { createServer, type IncomingMessage, type ServerResponse } from "node:http";
import https from "node:https";
import { after, before, describe, test } from "node:test";
import { fileURLToPath } from "node:url";

import { WebSocket, WebSocketServer } from "ws";

import type {
	IssueMatchTicketResponse,
	ReadinessCheck,
	ReadinessPayload,
	RegisterMatchSessionResponse,
} from "../../contracts/src/index.ts";
import { ControlPlaneDatabase } from "../../control-plane/src/db/database.ts";
import { buildServer } from "../../control-plane/src/server.ts";
import { loadConfig, readTlsCredentials } from "../src/config.ts";
import {
	WEBSOCKET_PATH,
	buildGateway,
	type ControlPlaneProbe,
	type Gateway,
} from "../src/server.ts";
import {
	ControlPlaneTicketVerifier,
	DevTicketVerifier,
	appendSlotQuery,
	type TicketVerdict,
	type TicketVerifier,
} from "../src/ticket.ts";

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

describe("appendSlotQuery", () => {
	test("adds slot without dropping the upstream host", () => {
		assert.equal(
			new URL(appendSlotQuery("ws://127.0.0.1:18211", 2)).searchParams.get("slot"),
			"2",
		);
		assert.equal(new URL(appendSlotQuery("ws://127.0.0.1:18211", 2)).port, "18211");
	});
});

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

const TLS_FIXTURE_FILES = {
	certPath: fileURLToPath(new URL("./fixtures/tls-cert.pem", import.meta.url)),
	keyPath: fileURLToPath(new URL("./fixtures/tls-key.pem", import.meta.url)),
};

describe("gateway config", () => {
	test("treats a blank GATEWAY_DEV_UPSTREAM as unset so the control-plane path is used", () => {
		assert.equal(loadConfig({}).devUpstreamUrl, undefined);
		assert.equal(loadConfig({ GATEWAY_DEV_UPSTREAM: "  " }).devUpstreamUrl, undefined);
		assert.equal(loadConfig({ GATEWAY_DEV_UPSTREAM: "ws://127.0.0.1:9" }).devUpstreamUrl, "ws://127.0.0.1:9");
	});

	test("leaves tls unset when both PEM paths are absent", () => {
		assert.equal(loadConfig({}).tls, undefined);
		assert.equal(loadConfig({ GATEWAY_TLS_CERT: "  ", GATEWAY_TLS_KEY: "" }).tls, undefined);
	});

	test("requires GATEWAY_TLS_CERT and GATEWAY_TLS_KEY together", () => {
		assert.deepEqual(loadConfig({
			GATEWAY_TLS_CERT: TLS_FIXTURE_FILES.certPath,
			GATEWAY_TLS_KEY: TLS_FIXTURE_FILES.keyPath,
		}).tls, TLS_FIXTURE_FILES);
		assert.throws(
			() => loadConfig({ GATEWAY_TLS_CERT: TLS_FIXTURE_FILES.certPath }),
			/GATEWAY_TLS_CERT and GATEWAY_TLS_KEY must be set together/,
		);
		assert.throws(
			() => loadConfig({ GATEWAY_TLS_KEY: TLS_FIXTURE_FILES.keyPath }),
			/GATEWAY_TLS_CERT and GATEWAY_TLS_KEY must be set together/,
		);
	});

	test("reads the fixture PEM pair", () => {
		const credentials = readTlsCredentials(TLS_FIXTURE_FILES);
		assert.match(credentials.cert, /BEGIN CERTIFICATE/);
		assert.match(credentials.key, /BEGIN (?:RSA )?PRIVATE KEY/);
	});
});

describe("control plane ticket verifier", () => {
	test("maps a 401 from the control plane to a rejected verdict", async () => {
		const stub = await listenJson((_req, res) => {
			res.writeHead(401, { "content-type": "application/json" });
			res.end(JSON.stringify({ ok: false, reason: "unknown_ticket" }));
		});
		try {
			const verifier = new ControlPlaneTicketVerifier(stub.url);
			const verdict = await verifier.verify("missing");
			assert.equal(verdict.ok, false);
			assert.equal(verdict.reason, "unknown_ticket");
		} finally {
			await stub.close();
		}
	});

	test("maps a successful verify to the returned upstream", async () => {
		const stub = await listenJson((_req, res) => {
			res.writeHead(200, { "content-type": "application/json" });
			res.end(JSON.stringify({ ok: true, upstreamUrl: "ws://10.0.0.8:9100", seat: 3 }));
		});
		try {
			const verifier = new ControlPlaneTicketVerifier(stub.url);
			const verdict = await verifier.verify("issued-ticket");
			assert.equal(verdict.ok, true);
			assert.equal(verdict.upstreamUrl, "ws://10.0.0.8:9100");
			assert.equal(verdict.seat, 3);
		} finally {
			await stub.close();
		}
	});

	test("rejects a successful verify that omits seat", async () => {
		const stub = await listenJson((_req, res) => {
			res.writeHead(200, { "content-type": "application/json" });
			res.end(JSON.stringify({ ok: true, upstreamUrl: "ws://10.0.0.8:9100" }));
		});
		try {
			const verifier = new ControlPlaneTicketVerifier(stub.url);
			const verdict = await verifier.verify("issued-ticket");
			assert.equal(verdict.ok, false);
		} finally {
			await stub.close();
		}
	});

	test("throws when the control plane is not a ticket authority response", async () => {
		const stub = await listenJson((_req, res) => {
			res.writeHead(503, { "content-type": "application/json" });
			res.end(JSON.stringify({ status: "not_ready" }));
		});
		try {
			const verifier = new ControlPlaneTicketVerifier(stub.url);
			await assert.rejects(verifier.verify("issued-ticket"), /HTTP 503/);
		} finally {
			await stub.close();
		}
	});
});

describe("gateway uses control plane tickets", () => {
	test("proxies after a real issued ticket and rejects the same ticket the second time", async () => {
		const database = new ControlPlaneDatabase(":memory:");
		database.migrate();
		const controlPlane = buildServer({ database, version: "1.2.3-test", logger: false });
		await controlPlane.listen({ host: "127.0.0.1", port: 0 });

		const upstreamInbox: Buffer[] = [];
		let requestedUrl = "";
		const upstream = new WebSocketServer({ host: "127.0.0.1", port: 0 });
		upstream.on("connection", (socket, request) => {
			requestedUrl = request.url ?? "";
			socket.send(Buffer.from([1, 2, 3]), { binary: true });
			socket.on("message", (data: Buffer) => {
				upstreamInbox.push(Buffer.from(data));
			});
		});
		await new Promise<void>((resolvePromise) => upstream.on("listening", resolvePromise));

		const gateway = buildGateway({
			ticketVerifier: new ControlPlaneTicketVerifier(httpBase(controlPlane)),
			controlPlaneProbe: new StubProbe(),
			version: "1.2.3-test",
			logger: false,
		});
		await gateway.app.listen({ host: "127.0.0.1", port: 0 });

		try {
			const created = await controlPlane.inject({
				method: "POST",
				url: "/match-sessions",
				payload: { upstreamUrl: `ws://127.0.0.1:${socketPort(upstream.address())}` },
			});
			assert.equal(created.statusCode, 201);
			const matchId = created.json<RegisterMatchSessionResponse>().matchId;
			const issued = await controlPlane.inject({
				method: "POST",
				url: `/match-sessions/${matchId}/tickets`,
			});
			assert.equal(issued.statusCode, 201);
			const ticket = issued.json<IssueMatchTicketResponse>().ticket;

			const socket = new WebSocket(
				`ws://127.0.0.1:${addressPort(gateway)}${WEBSOCKET_PATH}?ticket=${encodeURIComponent(ticket)}`,
			);
			try {
				const greeting = await nextRawMessage(socket);
				assert.deepEqual([...greeting.data], [1, 2, 3]);
				assert.match(requestedUrl, /(?:\?|&)slot=0(?:&|$)/);
				socket.send(Buffer.from([9, 8, 7]), { binary: true });
				await waitFor(() => upstreamInbox.length >= 1);
				assert.deepEqual([...upstreamInbox[0]!], [9, 8, 7]);
			} finally {
				socket.close();
			}

			const reused = new WebSocket(
				`ws://127.0.0.1:${addressPort(gateway)}${WEBSOCKET_PATH}?ticket=${encodeURIComponent(ticket)}`,
			);
			const error = await nextError(reused);
			assert.match(error.message, /401/);
		} finally {
			await gateway.close();
			await new Promise<void>((resolvePromise) => upstream.close(() => resolvePromise()));
			await controlPlane.close();
			database.close();
		}
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

describe("gateway in-process TLS", () => {
	let upstream: WebSocketServer;
	let upstreamUrl: string;
	let gateway: Gateway;
	let port: number;
	const upstreamInbox: Buffer[] = [];

	before(async () => {
		upstream = new WebSocketServer({ host: "127.0.0.1", port: 0 });
		upstream.on("connection", (socket) => {
			socket.send(Buffer.from([1, 2, 3]), { binary: true });
			socket.on("message", (data: Buffer) => {
				upstreamInbox.push(Buffer.from(data));
			});
		});
		await new Promise<void>((resolvePromise) => upstream.on("listening", resolvePromise));
		upstreamUrl = `ws://127.0.0.1:${socketPort(upstream.address())}`;

		gateway = buildGateway({
			ticketVerifier: new DevTicketVerifier(upstreamUrl),
			controlPlaneProbe: new StubProbe(),
			version: "1.2.3-test",
			logger: false,
			https: readTlsCredentials(TLS_FIXTURE_FILES),
		});
		await gateway.app.listen({ host: "127.0.0.1", port: 0 });
		port = addressPort(gateway);
	});

	after(async () => {
		await gateway.close();
		await new Promise<void>((resolvePromise) => upstream.close(() => resolvePromise()));
	});

	test("proxies binary frames over wss while the match-process upstream stays plaintext ws", async () => {
		assert.equal(new URL(upstreamUrl).protocol, "ws:");
		const socket = new WebSocket(
			`wss://127.0.0.1:${port}${WEBSOCKET_PATH}?ticket=dev`,
			{ rejectUnauthorized: false },
		);
		try {
			const greeting = await nextRawMessage(socket);
			assert.equal(greeting.isBinary, true);
			assert.deepEqual([...greeting.data], [1, 2, 3]);
			socket.send(Buffer.from([9, 8, 7]), { binary: true });
			await waitFor(() => upstreamInbox.length >= 1);
			assert.deepEqual([...upstreamInbox[0]!], [9, 8, 7]);
		} finally {
			socket.close();
		}
	});

	test("serves /healthz on the same TLS port", async () => {
		const response = await httpsGet("127.0.0.1", port, "/healthz");
		assert.equal(response.statusCode, 200);
		assert.equal(JSON.parse(response.body).status, "ok");
	});

	test("rejects a wss client that requires a trusted certificate", async () => {
		const socket = new WebSocket(`wss://127.0.0.1:${port}${WEBSOCKET_PATH}?ticket=dev`);
		const error = await nextError(socket);
		assert.match(error.message, /certificate|UNABLE_TO_VERIFY|self.signed/i);
	});
});

function httpBase(app: { server: { address(): string | { port: number } | null } }): string {
	return `http://127.0.0.1:${socketPort(app.server.address())}`;
}

function socketPort(address: string | { port: number } | null): number {
	if (address === null || typeof address === "string") {
		throw new Error("expected a TCP listen address");
	}
	return address.port;
}

async function listenJson(
	handler: (request: IncomingMessage, response: ServerResponse) => void,
): Promise<{ url: string; close: () => Promise<void> }> {
	const server = createServer(handler);
	await new Promise<void>((resolvePromise, rejectPromise) => {
		server.once("error", rejectPromise);
		server.listen(0, "127.0.0.1", () => resolvePromise());
	});
	return {
		url: `http://127.0.0.1:${socketPort(server.address())}`,
		close: () =>
			new Promise<void>((resolvePromise, rejectPromise) => {
				server.close((error) => {
					if (error) {
						rejectPromise(error);
						return;
					}
					resolvePromise();
				});
			}),
	};
}

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

function httpsGet(
	hostname: string,
	port: number,
	path: string,
): Promise<{ statusCode: number; body: string }> {
	return new Promise((resolvePromise, rejectPromise) => {
		https
			.get({ hostname, port, path, rejectUnauthorized: false }, (response) => {
				const chunks: Buffer[] = [];
				response.on("data", (chunk: Buffer) => {
					chunks.push(chunk);
				});
				response.on("end", () => {
					resolvePromise({
						statusCode: response.statusCode ?? 0,
						body: Buffer.concat(chunks).toString("utf8"),
					});
				});
			})
			.on("error", rejectPromise);
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
