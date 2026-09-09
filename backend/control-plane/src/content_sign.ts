import { createHmac, timingSafeEqual } from "node:crypto";

import {
	CONTENT_HEX_LEN,
	CONTENT_ID_MAX,
	CONTENT_PUBLISH_SCHEMA_VERSION,
	CONTENT_VERSION_MAX,
	CONTENT_VERSION_MIN,
} from "../../contracts/src/content_publish.ts";

/** 文档化的测试 / 长期测试钥。不是生产秘密。 */
export const CONTENT_SIGN_DEV_KEY = "craftarena-content-sign-dev-key";

const CONTENT_ID_RE = /^[A-Za-z0-9._-]+$/;
const CONTENT_HEX_RE = /^[0-9a-f]+$/;

export function isContentId(contentId: string): boolean {
	return contentId.length >= 1 && contentId.length <= CONTENT_ID_MAX && CONTENT_ID_RE.test(contentId);
}

export function isContentVersion(version: number): boolean {
	return Number.isInteger(version) && version >= CONTENT_VERSION_MIN && version <= CONTENT_VERSION_MAX;
}

export function isContentHex(text: string): boolean {
	return text.length === CONTENT_HEX_LEN && CONTENT_HEX_RE.test(text);
}

export function signContentMessage(
	key: string,
	contentId: string,
	version: number,
	contentHash: string,
): string {
	return createHmac("sha256", key).update(`${contentId}\n${version}\n${contentHash}`).digest("hex");
}

export function signaturesEqual(left: string, right: string): boolean {
	if (left.length !== right.length) {
		return false;
	}
	try {
		return timingSafeEqual(Buffer.from(left, "hex"), Buffer.from(right, "hex"));
	} catch {
		return false;
	}
}

export function verifyContentEnvelope(
	input: {
		readonly schema_version: number;
		readonly content_id: string;
		readonly version: number;
		readonly content_hash: string;
		readonly signature: string;
	},
	key: string,
): "ok" | "envelope_keys" | "id_invalid" | "version_invalid" | "signature_mismatch" {
	if (input.schema_version !== CONTENT_PUBLISH_SCHEMA_VERSION) {
		return "envelope_keys";
	}
	if (!isContentId(input.content_id)) {
		return "id_invalid";
	}
	if (!isContentVersion(input.version)) {
		return "version_invalid";
	}
	if (!isContentHex(input.content_hash) || !isContentHex(input.signature)) {
		return "envelope_keys";
	}
	const expected = signContentMessage(key, input.content_id, input.version, input.content_hash);
	if (!signaturesEqual(expected, input.signature)) {
		return "signature_mismatch";
	}
	return "ok";
}
