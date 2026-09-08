import assert from "node:assert/strict";
import { describe, it } from "node:test";

import {
	controlPlaneListenPort,
	occupiedControlPlaneMessage,
	probeOccupiedControlPlane,
} from "../src/listen_guard.ts";
import { BASE_PORTS } from "../src/worktree_ports.ts";

describe("control-plane listen guard", () => {
	it("defaults to the same port the control plane uses", () => {
		assert.equal(controlPlaneListenPort({}), BASE_PORTS.controlPlane);
		assert.equal(controlPlaneListenPort({ CONTROL_PLANE_PORT: "18080" }), 18080);
		assert.equal(controlPlaneListenPort({ CONTROL_PLANE_PORT: "nope" }), BASE_PORTS.controlPlane);
	});

	it("names a Python http.server 404 as the wrong process", () => {
		const pythonBody =
			"Error response\nError code: 404\n\nMessage: File not found.\n\nError code explanation: HTTPStatus.NOT_FOUND - Nothing matches the given URI.\n";
		const message = occupiedControlPlaneMessage(8080, 404, pythonBody);
		assert.match(message, /127\.0\.0\.1:8080 is already in use/);
		assert.match(message, /Python http\.server/);
		assert.match(message, /not the control plane/);
	});

	it("still reports a foreign HTTP listener that is not Python", () => {
		const message = occupiedControlPlaneMessage(8080, 200, '{"ok":true}');
		assert.match(message, /HTTP 200/);
		assert.doesNotMatch(message, /Python http\.server/);
	});

	it("treats a refused connection as a free port", async () => {
		const fetchImpl = async (): Promise<Response> => {
			throw new TypeError("fetch failed");
		};
		assert.equal(await probeOccupiedControlPlane(8080, fetchImpl as typeof fetch), undefined);
	});

	it("returns the occupied message when /healthz answers", async () => {
		const fetchImpl = async (): Promise<Response> =>
			new Response("Error response\nError code: 404\nHTTPStatus.NOT_FOUND", { status: 404 });
		const message = await probeOccupiedControlPlane(8080, fetchImpl as typeof fetch);
		assert.ok(message !== undefined);
		assert.match(message ?? "", /Python http\.server/);
	});
});
