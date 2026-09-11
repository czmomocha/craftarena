import { runBotRun } from "./run.ts";

process.exit(runBotRun({
	argv: process.argv.slice(2),
	env: process.env,
	platform: process.platform,
}));
