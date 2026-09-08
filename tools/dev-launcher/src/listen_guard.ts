import { BASE_PORTS } from "./worktree_ports.ts";

const HEALTHZ_TIMEOUT_MS = 800;

/**
 * `npm run dev` inherits whatever is already bound on the control-plane port.
 * A Python `http.server` 404 page looks like "the game is down" instead of
 * "this is not our process". Probe `/healthz` before spawn so that conflict
 * is a launcher error, not a browser mystery.
 */
export function occupiedControlPlaneMessage(port: number, status: number, body: string): string {
	const preview = body.replace(/\s+/g, " ").trim().slice(0, 160);
	const pythonPage = /HTTPStatus\.NOT_FOUND|Error response/i.test(body);
	const pythonHint = pythonPage
		? " That page is Python http.server, not the control plane."
		: "";
	return (
		`http://127.0.0.1:${port} is already in use. GET /healthz returned HTTP ${status}: ${preview}.` +
		`${pythonHint} Stop that process, then npm run dev.`
	);
}

export function controlPlaneListenPort(env: NodeJS.ProcessEnv = process.env): number {
	const raw = env["CONTROL_PLANE_PORT"];
	if (raw === undefined || raw.trim() === "") {
		return BASE_PORTS.controlPlane;
	}
	const parsed = Number.parseInt(raw, 10);
	if (!Number.isInteger(parsed) || parsed < 0 || parsed > 65535) {
		return BASE_PORTS.controlPlane;
	}
	return parsed;
}

export async function probeOccupiedControlPlane(
	port: number,
	fetchImpl: typeof fetch = fetch,
): Promise<string | undefined> {
	try {
		const response = await fetchImpl(`http://127.0.0.1:${port}/healthz`, {
			signal: AbortSignal.timeout(HEALTHZ_TIMEOUT_MS),
		});
		const body = await response.text();
		return occupiedControlPlaneMessage(port, response.status, body);
	} catch {
		return undefined;
	}
}
