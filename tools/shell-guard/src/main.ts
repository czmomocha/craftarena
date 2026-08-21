import { execFileSync } from "node:child_process";
import { stdin, stdout } from "node:process";

import { decideShellCommand, type Decision } from "./decide.ts";

type HookInput = {
	readonly command?: unknown;
	readonly cwd?: unknown;
};

const input = await readStdinJson();
const command = typeof input.command === "string" ? input.command : "";
const cwd = typeof input.cwd === "string" && input.cwd !== "" ? input.cwd : process.cwd();
const decision = decideShellCommand(command, {
	currentBranch: readCurrentBranch(cwd),
});
stdout.write(`${JSON.stringify(toHookResponse(decision))}\n`);

async function readStdinJson(): Promise<HookInput> {
	const chunks: Buffer[] = [];
	for await (const chunk of stdin) {
		chunks.push(Buffer.isBuffer(chunk) ? chunk : Buffer.from(chunk));
	}
	const raw = Buffer.concat(chunks).toString("utf8").trim();
	if (raw === "") {
		return {};
	}
	try {
		return JSON.parse(raw) as HookInput;
	} catch {
		return {};
	}
}

function readCurrentBranch(cwd: string): string | undefined {
	try {
		const output = execFileSync("git", ["rev-parse", "--abbrev-ref", "HEAD"], {
			cwd,
			encoding: "utf8",
			timeout: 2000,
			stdio: ["ignore", "pipe", "ignore"],
		}).trim();
		if (output === "" || output === "HEAD") {
			return undefined;
		}
		return output;
	} catch {
		return undefined;
	}
}

function toHookResponse(decision: Decision): {
	readonly permission: Decision["permission"];
	readonly user_message: string;
	readonly agent_message: string;
} {
	if (decision.permission === "allow") {
		return { permission: "allow", user_message: "", agent_message: "" };
	}
	return {
		permission: "deny",
		user_message: decision.message,
		agent_message: decision.message,
	};
}
