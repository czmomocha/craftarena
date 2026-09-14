import { spawnSync } from "node:child_process";

import { runDeployWeb } from "./deploy_web.ts";

function detectRsync(): boolean {
	const probe = spawnSync("rsync", ["--version"], { encoding: "utf8" });
	return probe.error === undefined && probe.status === 0;
}

process.exit(
	runDeployWeb({
		argv: process.argv.slice(2),
		env: process.env,
		platform: process.platform,
		hasRsync: detectRsync(),
	}),
);
