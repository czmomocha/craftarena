import { spawn } from "node:child_process";
import { copyFileSync, existsSync, mkdirSync, readdirSync, readFileSync, writeFileSync } from "node:fs";
import { join, resolve } from "node:path";
import { fileURLToPath } from "node:url";

import { mergeDotEnv } from "./dotenv_file.ts";
import { portsForSlot, worktreeSlot, type WorktreePorts } from "./worktree_ports.ts";

export type CommandResult = {
	readonly code: number;
};

export type SetupWorktreeIo = {
	readonly cwd: string;
	readonly rootWorktreePath: string | undefined;
	readonly env: NodeJS.ProcessEnv;
	readonly platform: NodeJS.Platform;
	runCommand: (command: string, args: readonly string[], cwd: string) => Promise<CommandResult>;
};

export type SetupWorktreeResult = {
	readonly slot: number;
	readonly ports: WorktreePorts;
	readonly wroteEnv: boolean;
};

export async function setupWorktree(io: SetupWorktreeIo): Promise<SetupWorktreeResult> {
	const cwd = resolve(io.cwd);
	const root = io.rootWorktreePath === undefined || io.rootWorktreePath.trim() === "" ? undefined : resolve(io.rootWorktreePath);
	const slot = worktreeSlot(cwd, root, io.env);
	const ports = portsForSlot(slot);

	const install = await io.runCommand(npmCommand(io.platform), ["install"], cwd);
	if (install.code !== 0) {
		throw new Error(`npm install failed with exit ${install.code}`);
	}

	copyOptionalLocalFiles(root, cwd);
	const wroteEnv = writePortEnv(cwd, slot, ports);
	await importGodotProject(io, cwd);
	return { slot, ports, wroteEnv };
}

function npmCommand(platform: NodeJS.Platform): string {
	return platform === "win32" ? "npm.cmd" : "npm";
}

function copyOptionalLocalFiles(root: string | undefined, cwd: string): void {
	if (root === undefined || root === cwd) {
		return;
	}
	copyIfFile(join(root, ".env"), join(cwd, ".env"));
	const dataDir = join(root, "data");
	if (!existsSync(dataDir)) {
		return;
	}
	mkdirSync(join(cwd, "data"), { recursive: true });
	for (const name of readdirSync(dataDir)) {
		if (name.endsWith(".sqlite") || name.endsWith(".sqlite3")) {
			copyIfFile(join(dataDir, name), join(cwd, "data", name));
		}
	}
}

function copyIfFile(from: string, to: string): void {
	if (existsSync(from)) {
		copyFileSync(from, to);
	}
}

function writePortEnv(cwd: string, slot: number, ports: WorktreePorts): boolean {
	if (slot === 0) {
		return false;
	}
	const envPath = join(cwd, ".env");
	const existing = existsSync(envPath) ? readFileSync(envPath, "utf8") : "";
	const next = mergeDotEnv(existing, {
		CONTROL_PLANE_PORT: String(ports.CONTROL_PLANE_PORT),
		GATEWAY_PORT: String(ports.GATEWAY_PORT),
		MATCH_HOST_PORT: String(ports.MATCH_HOST_PORT),
		MATCH_HOST_PORT_RANGE_MIN: String(ports.MATCH_HOST_PORT_RANGE_MIN),
		MATCH_HOST_PORT_RANGE_MAX: String(ports.MATCH_HOST_PORT_RANGE_MAX),
		CONTROL_PLANE_URL: ports.CONTROL_PLANE_URL,
	});
	writeFileSync(envPath, next);
	return true;
}

async function importGodotProject(io: SetupWorktreeIo, cwd: string): Promise<void> {
	const executable = resolveGodot(io.env, io.platform);
	if (executable === undefined) {
		throw new Error("GODOT4 is not set; worktree setup cannot import game/.godot");
	}
	const result = await io.runCommand(executable, ["--headless", "--path", "game", "--import"], cwd);
	if (result.code !== 0) {
		throw new Error(`Godot --import failed with exit ${result.code}`);
	}
}

function resolveGodot(env: NodeJS.ProcessEnv, platform: NodeJS.Platform): string | undefined {
	if (platform === "win32") {
		const consoleBuild = env["GODOT4_CONSOLE"];
		if (consoleBuild !== undefined && consoleBuild.trim() !== "") {
			return consoleBuild;
		}
	}
	const godot = env["GODOT4"];
	if (godot === undefined || godot.trim() === "") {
		return undefined;
	}
	return godot;
}

export function runCommand(command: string, args: readonly string[], cwd: string): Promise<CommandResult> {
	return new Promise((resolveCommand, reject) => {
		const child = spawn(command, [...args], { cwd, stdio: "inherit", shell: false });
		child.on("error", reject);
		child.on("close", (code) => {
			resolveCommand({ code: code ?? 1 });
		});
	});
}

const invokedPath = process.argv[1];
if (invokedPath !== undefined && resolve(invokedPath) === fileURLToPath(import.meta.url)) {
	const result = await setupWorktree({
		cwd: process.cwd(),
		rootWorktreePath: process.env["ROOT_WORKTREE_PATH"],
		env: process.env,
		platform: process.platform,
		runCommand,
	});
	process.stdout.write(
		`worktree setup complete slot=${result.slot} wroteEnv=${result.wroteEnv} controlPlane=${result.ports.CONTROL_PLANE_PORT}\n`,
	);
}
