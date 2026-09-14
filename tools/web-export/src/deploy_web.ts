import { spawnSync } from "node:child_process";
import { join } from "node:path";

import {
	DEFAULT_REMOTE_PATH,
	DEPLOY_HOST_ENV,
	DEPLOY_PATH_ENV,
	DEPLOY_SSH_PORT_ENV,
	DEPLOY_USER_ENV,
	EXPORT_RELATIVE_DIR,
} from "./constants.ts";
import { REPO_ROOT } from "./paths.ts";
import { verifyWebExportDir } from "./verify.ts";

export type SpawnResult = {
	readonly status: number | null;
	readonly stdout: string;
	readonly stderr: string;
	readonly error: Error | undefined;
};

export type SpawnFn = (executable: string, args: readonly string[], cwd: string) => SpawnResult;

export type DeployCommand = {
	readonly executable: string;
	readonly args: readonly string[];
};

export type DeployPlanFailure = {
	readonly ok: false;
	readonly error: string;
};

export type DeployPlanSuccess = {
	readonly ok: true;
	readonly command: DeployCommand;
	readonly display: string;
	readonly remote: string;
};

export type DeployPlan = DeployPlanFailure | DeployPlanSuccess;

export type DeployIo = {
	readonly argv: readonly string[];
	readonly env: NodeJS.ProcessEnv;
	readonly platform: NodeJS.Platform;
	readonly cwd?: string;
	readonly hasRsync?: boolean;
	readonly spawn?: SpawnFn;
	readonly log?: (line: string) => void;
	readonly logError?: (line: string) => void;
};

const FORBIDDEN_PATH = new Set(["/", "/etc", "/root", "/var", "/usr", "/home"]);

export function wantsDryRun(argv: readonly string[]): boolean {
	return argv.includes("--dry-run");
}

function readNonBlank(raw: string | undefined): string | undefined {
	if (raw === undefined || raw.trim() === "") {
		return undefined;
	}
	return raw.trim();
}

function rejectHost(host: string): string {
	if (host.includes("://")) {
		return "host must be a bare name or IP, not a URL";
	}
	for (const forbidden of [" ", "\t", "/", "?", "#", "@"]) {
		if (host.includes(forbidden)) {
			return "host must be a bare name or IP";
		}
	}
	return "";
}

function rejectPath(path: string): string {
	if (path.includes("\0") || path.includes("..")) {
		return "remote path must not contain .. or NUL";
	}
	if (FORBIDDEN_PATH.has(path) || path === "") {
		return `refusing to deploy onto ${path === "" ? "an empty path" : path}`;
	}
	if (!path.startsWith("/")) {
		return "remote path must be absolute";
	}
	return "";
}

function parseSshPort(raw: string | undefined): { ok: true; port: number } | { ok: false; error: string } {
	if (raw === undefined || raw.trim() === "") {
		return { ok: true, port: 22 };
	}
	if (!/^\d+$/.test(raw.trim())) {
		return { ok: false, error: "SSH port must be an integer" };
	}
	const port = Number.parseInt(raw.trim(), 10);
	if (port < 1 || port > 65535) {
		return { ok: false, error: "SSH port must be within [1, 65535]" };
	}
	return { ok: true, port };
}

/**
 * Prefer rsync when the caller says it exists (typical Linux/macOS VPS copy).
 * Windows OpenSSH usually has `scp` and not `rsync`.
 */
export function buildDeployPlan(io: {
	readonly env: NodeJS.ProcessEnv;
	readonly platform: NodeJS.Platform;
	readonly cwd?: string;
	readonly hasRsync?: boolean;
}): DeployPlan {
	const host = readNonBlank(io.env[DEPLOY_HOST_ENV]);
	const user = readNonBlank(io.env[DEPLOY_USER_ENV]);
	if (host === undefined || user === undefined) {
		return {
			ok: false,
			error:
				`set ${DEPLOY_HOST_ENV} and ${DEPLOY_USER_ENV} (optional ${DEPLOY_PATH_ENV}, ` +
				`${DEPLOY_SSH_PORT_ENV}). Manuals use placeholders; do not commit real IPs.`,
		};
	}
	const hostReason = rejectHost(host);
	if (hostReason !== "") {
		return { ok: false, error: hostReason };
	}
	const remotePath = readNonBlank(io.env[DEPLOY_PATH_ENV]) ?? DEFAULT_REMOTE_PATH;
	const pathReason = rejectPath(remotePath);
	if (pathReason !== "") {
		return { ok: false, error: pathReason };
	}
	const parsedPort = parseSshPort(io.env[DEPLOY_SSH_PORT_ENV]);
	if (!parsedPort.ok) {
		return { ok: false, error: parsedPort.error };
	}

	const cwd = io.cwd ?? REPO_ROOT;
	const localDir = join(cwd, EXPORT_RELATIVE_DIR);
	const target = `${user}@${host}:${remotePath}`;
	const useRsync = io.hasRsync === true;
	if (useRsync) {
		const args = ["-avz"];
		if (parsedPort.port !== 22) {
			args.push("-e", `ssh -p ${String(parsedPort.port)}`);
		}
		args.push(`${localDir}/`, `${target}/`);
		return {
			ok: true,
			command: { executable: "rsync", args },
			display: ["rsync", ...args].join(" "),
			remote: target,
		};
	}

	const args: string[] = ["-r"];
	if (parsedPort.port !== 22) {
		args.push("-P", String(parsedPort.port));
	}
	args.push(`${localDir}/.`, target);
	return {
		ok: true,
		command: { executable: "scp", args },
		display: ["scp", ...args].join(" "),
		remote: target,
	};
}

export function defaultSpawn(executable: string, args: readonly string[], cwd: string): SpawnResult {
	const result = spawnSync(executable, [...args], {
		cwd,
		encoding: "utf8",
		maxBuffer: 16 * 1024 * 1024,
	});
	return {
		status: result.status,
		stdout: result.stdout ?? "",
		stderr: result.stderr ?? "",
		error: result.error,
	};
}

/**
 * Copy `export/web/` to the VPS directory Nginx serves. Never guesses a host.
 * `--dry-run` prints the command. Live copy is a constitution article 18
 * human gate; tests only build the plan.
 */
export function runDeployWeb(io: DeployIo): number {
	const log = io.log ?? console.log;
	const logError = io.logError ?? console.error;
	const cwd = io.cwd ?? REPO_ROOT;
	const dryRun = wantsDryRun(io.argv);

	if (!dryRun) {
		const verified = verifyWebExportDir(join(cwd, EXPORT_RELATIVE_DIR));
		if (!verified.ok) {
			logError(`web-deploy: ${verified.error}; run npm run export:web first`);
			return 1;
		}
	}

	const plan = buildDeployPlan({
		env: io.env,
		platform: io.platform,
		cwd,
		...(io.hasRsync === undefined ? {} : { hasRsync: io.hasRsync }),
	});
	if (!plan.ok) {
		logError(`web-deploy: ${plan.error}`);
		return 1;
	}

	log(`web-deploy: ${plan.display}`);
	if (dryRun) {
		log("web-deploy: dry-run, not copying");
		return 0;
	}

	const spawn = io.spawn ?? defaultSpawn;
	const spawned = spawn(plan.command.executable, plan.command.args, cwd);
	if (spawned.stdout !== "") {
		log(spawned.stdout.endsWith("\n") ? spawned.stdout.slice(0, -1) : spawned.stdout);
	}
	if (spawned.stderr !== "") {
		logError(spawned.stderr.endsWith("\n") ? spawned.stderr.slice(0, -1) : spawned.stderr);
	}
	if (spawned.error !== undefined) {
		logError(`web-deploy: failed to start ${plan.command.executable}: ${spawned.error.message}`);
		return 1;
	}
	if (spawned.status !== 0) {
		logError(`web-deploy: ${plan.command.executable} exited ${String(spawned.status)}`);
		return spawned.status ?? 1;
	}
	log(
		JSON.stringify({
			event: "web_deploy",
			ok: true,
			remote: plan.remote,
		}),
	);
	return 0;
}
