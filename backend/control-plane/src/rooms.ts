import { randomInt } from "node:crypto";

/**
 * 房间码是开发期占位，不是产品锁定的字表或长度。
 * 去掉 I/O/0/1，避免口头念码时混淆。
 */
export const ROOM_CODE_ALPHABET = "ABCDEFGHJKLMNPQRSTUVWXYZ23456789";
export const ROOM_CODE_LENGTH = 6;
export const ROOM_CODE_PATTERN = /^[A-HJ-NP-Z2-9]{6}$/;

export function generateRoomCode(): string {
	let code = "";
	for (let index = 0; index < ROOM_CODE_LENGTH; index += 1) {
		code += ROOM_CODE_ALPHABET[randomInt(ROOM_CODE_ALPHABET.length)];
	}
	return code;
}

export function normalizeRoomCode(raw: string): string | undefined {
	const normalized = raw.trim().toUpperCase();
	if (!ROOM_CODE_PATTERN.test(normalized)) {
		return undefined;
	}
	return normalized;
}
