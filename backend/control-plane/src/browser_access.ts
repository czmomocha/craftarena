import type { FastifyInstance, FastifyReply, FastifyRequest } from "fastify";

const ALLOW_METHODS = "GET,HEAD,POST,DELETE,OPTIONS";
const ALLOW_HEADERS = "content-type";

/**
 * Test-period browser clients (Web export on another origin/port) must be
 * able to call this process. No new dependency: Fastify CORS plugin would
 * be constitution article 18. `*` is the accepted test-stage risk, not a
 * production TLS/auth boundary.
 */
export function registerBrowserAccess(app: FastifyInstance): void {
	app.addHook("onRequest", async (request: FastifyRequest, reply: FastifyReply) => {
		reply.header("Access-Control-Allow-Origin", "*");
		reply.header("Access-Control-Allow-Methods", ALLOW_METHODS);
		reply.header("Access-Control-Allow-Headers", ALLOW_HEADERS);
		if (request.method === "OPTIONS") {
			return reply.code(204).send();
		}
		return undefined;
	});
}
