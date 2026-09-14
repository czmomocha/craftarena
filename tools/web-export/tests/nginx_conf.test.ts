import assert from "node:assert/strict";
import { readFileSync } from "node:fs";
import { dirname, join } from "node:path";
import { describe, it } from "node:test";
import { fileURLToPath } from "node:url";

import { DEFAULT_REMOTE_PATH } from "../src/constants.ts";

const REPO_ROOT = join(dirname(fileURLToPath(import.meta.url)), "../../..");
const CONF = join(REPO_ROOT, "infra/nginx/craftarena-web.conf");

describe("nginx test-period web conf", () => {
	it("serves Godot Web on plaintext port 80 at the deploy path", () => {
		const source = readFileSync(CONF, "utf8").replaceAll("\r\n", "\n");
		const active = source.replace(/#.*$/gm, "");
		assert.match(source, /listen 80/);
		assert.match(source, /application\/wasm/);
		assert.match(source, /Cache-Control "no-cache"/);
		assert.ok(source.includes(`root ${DEFAULT_REMOTE_PATH};`));
		assert.doesNotMatch(active, /listen\s+443/);
		assert.doesNotMatch(active, /ssl_certificate/);
		assert.doesNotMatch(active, /webrtc/i);
		assert.doesNotMatch(active, /\b(?:\d{1,3}\.){3}\d{1,3}\b/);
	});
});
