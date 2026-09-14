import { runExportWeb } from "./export_web.ts";

process.exit(
	runExportWeb({
		argv: process.argv.slice(2),
		env: process.env,
		platform: process.platform,
	}),
);
