import { createReadStream, existsSync, statSync } from "node:fs";
import { extname, resolve, sep } from "node:path";

import type { FastifyInstance, FastifyReply, FastifyRequest } from "fastify";

const MIME_BY_EXT: Record<string, string> = {
	".css": "text/css; charset=utf-8",
	".html": "text/html; charset=utf-8",
	".ico": "image/x-icon",
	".js": "application/javascript; charset=utf-8",
	".json": "application/json",
	".pck": "application/octet-stream",
	".png": "image/png",
	".svg": "image/svg+xml",
	".wasm": "application/wasm",
};

const UNSET_PAYLOAD = {
	error: "web_root_unset",
	hint: "Set CRAFTARENA_WEB_ROOT to the Godot Web export directory (export/web) and restart.",
};

/**
 * Serves a Godot Web export at `/play/` so testers get one `http://host:port/play/`
 * link on the same control-plane process. Unset `webRoot` keeps API-only behaviour
 * but answers `/play/` with 503 instead of Fastify's generic 404. Path traversal
 * is rejected rather than resolved outside the root.
 */
export function registerWebPlay(app: FastifyInstance, webRoot?: string): void {
	if (webRoot === undefined || webRoot.trim() === "") {
		const missing = async (_request: FastifyRequest, reply: FastifyReply) =>
			reply.code(503).send(UNSET_PAYLOAD);
		app.get("/play", async (_request, reply) => reply.redirect("/play/"));
		app.get("/play/", missing);
		app.get("/play/*", missing);
		return;
	}
	const root = resolve(webRoot);

	app.get("/play", async (_request, reply) => reply.redirect("/play/"));
	app.get("/play/", async (_request, reply) => sendPlayFile(reply, root, "index.html"));
	app.get("/play/*", async (request, reply) => {
		const suffix = String((request.params as { "*": string })["*"] ?? "");
		return sendPlayFile(reply, root, suffix);
	});
}

function sendPlayFile(reply: FastifyReply, root: string, relative: string): FastifyReply {
	let decoded = relative;
	try {
		decoded = decodeURIComponent(relative);
	} catch {
		return reply.code(400).send({ error: "bad_path" });
	}
	const trimmed = decoded.replace(/^[/\\]+/, "");
	if (trimmed.includes("\0") || trimmed.split(/[/\\]/).includes("..")) {
		return reply.code(400).send({ error: "bad_path" });
	}
	const target = resolve(root, trimmed === "" ? "index.html" : trimmed);
	const prefix = root.endsWith(sep) ? root : `${root}${sep}`;
	if (target !== root && !target.startsWith(prefix)) {
		return reply.code(400).send({ error: "bad_path" });
	}
	if (!existsSync(target) || !statSync(target).isFile()) {
		return reply.code(404).send({ error: "not_found" });
	}
	const mime = MIME_BY_EXT[extname(target).toLowerCase()] ?? "application/octet-stream";
	reply.type(mime);
	return reply.send(createReadStream(target));
}
