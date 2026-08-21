import { scanRepo } from "./scan.ts";
import { REPO_ROOT } from "./paths.ts";

const findings = scanRepo(REPO_ROOT);
if (findings.length === 0) {
	console.log("redline-scanner: no findings");
	process.exit(0);
}

for (const finding of findings) {
	console.error(
		`${finding.path}:${finding.line}: [${finding.ruleId} / art.${finding.article}] ${finding.message}`,
	);
	if (finding.excerpt.length > 0) {
		console.error(`  ${finding.excerpt}`);
	}
}
process.exit(1);
