import { existsSync, readdirSync, statSync } from "node:fs";
import { extname, join } from "node:path";

const REQUIRED_FILE = "index.html";
const REQUIRED_EXTENSIONS = [".js", ".wasm", ".pck"] as const;

export type VerifyFailure = {
	readonly ok: false;
	readonly error: string;
};

export type VerifySuccess = {
	readonly ok: true;
	readonly files: readonly string[];
};

export type VerifyResult = VerifyFailure | VerifySuccess;

/**
 * The CD-61 second knife names `.wasm` + `.js` + `.html`. Godot 4 Web also
 * writes a `.pck`; without it the canvas boots and then has no game.
 */
export function verifyWebExportDir(dir: string): VerifyResult {
	if (!existsSync(dir) || !statSync(dir).isDirectory()) {
		return { ok: false, error: `web export directory is missing: ${dir}` };
	}
	const names = readdirSync(dir);
	const files = names.filter((name) => {
		const full = join(dir, name);
		return statSync(full).isFile() && statSync(full).size > 0;
	});
	if (!files.includes(REQUIRED_FILE)) {
		return { ok: false, error: `${dir} has no non-empty ${REQUIRED_FILE}` };
	}
	for (const extension of REQUIRED_EXTENSIONS) {
		if (!files.some((name) => extname(name).toLowerCase() === extension)) {
			return {
				ok: false,
				error: `${dir} has no non-empty *${extension} (Godot Web export is incomplete)`,
			};
		}
	}
	return { ok: true, files: files.slice().sort() };
}
