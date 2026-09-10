/**
 * 账号认领 HTTP 契约（CD-13 / CD-14 / CD-32）。
 *
 * Guest ID + 恢复密钥；用户名 + 密码注册登录；认领把 Guest 云端草稿
 * 转到账号。发布 HTTP 与入场票据仍不绑账号。OpenAPI 仍未生成。
 */

export const ACCOUNT_USERNAME_MIN = 3;
export const ACCOUNT_USERNAME_MAX = 24;
export const ACCOUNT_PASSWORD_MIN = 8;
export const ACCOUNT_PASSWORD_MAX = 64;
export const ACCOUNT_ID_LEN = 36;
export const GUEST_ID_LEN = 36;
export const RECOVERY_KEY_MIN = 32;
export const RECOVERY_KEY_MAX = 64;
export const DRAFT_JSON_MAX = 1_048_576;

export const ACCOUNT_ERRORS = {
	unexpectedRequestBody: "unexpected_request_body",
	usernameInvalid: "username_invalid",
	passwordInvalid: "password_invalid",
	usernameTaken: "username_taken",
	credentialsInvalid: "credentials_invalid",
	guestIdInvalid: "guest_id_invalid",
	recoveryKeyInvalid: "recovery_key_invalid",
	guestNotFound: "guest_not_found",
	guestClaimed: "guest_claimed",
	sessionInvalid: "session_invalid",
	documentInvalid: "document_invalid",
	draftTooLarge: "draft_too_large",
	draftConflict: "draft_conflict",
	draftMissing: "draft_missing",
} as const;

export type AccountError = (typeof ACCOUNT_ERRORS)[keyof typeof ACCOUNT_ERRORS];

const USERNAME_RE = /^[A-Za-z0-9][A-Za-z0-9._-]{2,23}$/;
const GUEST_ID_RE = /^gst_[0-9a-f]{32}$/;
const ACCOUNT_ID_RE = /^acc_[0-9a-f]{32}$/;
const SECRET_RE = /^[A-Za-z0-9_-]+$/;

export function isAccountUsername(value: unknown): value is string {
	return typeof value === "string" && USERNAME_RE.test(value);
}

export function isAccountPassword(value: unknown): value is string {
	return (
		typeof value === "string" &&
		value.length >= ACCOUNT_PASSWORD_MIN &&
		value.length <= ACCOUNT_PASSWORD_MAX
	);
}

export function isGuestId(value: unknown): value is string {
	return typeof value === "string" && GUEST_ID_RE.test(value);
}

export function isAccountId(value: unknown): value is string {
	return typeof value === "string" && ACCOUNT_ID_RE.test(value);
}

export function isRecoveryKey(value: unknown): value is string {
	return (
		typeof value === "string" &&
		value.length >= RECOVERY_KEY_MIN &&
		value.length <= RECOVERY_KEY_MAX &&
		SECRET_RE.test(value)
	);
}

export function isSessionToken(value: unknown): value is string {
	return isRecoveryKey(value);
}

export interface GuestMintView {
	readonly guest_id: string;
	readonly recovery_key: string;
}

export interface AccountSessionView {
	readonly account_id: string;
	readonly username: string;
	readonly session: string;
}

export interface AccountMeView {
	readonly account_id: string;
	readonly username: string;
}

export interface DraftView {
	readonly owner_kind: "guest" | "account";
	readonly owner_id: string;
	readonly document: Record<string, unknown>;
	readonly updated_at: string;
}

export interface ClaimView {
	readonly claimed: true;
	readonly had_draft: boolean;
}

export interface AccountRegisterRequest {
	readonly username: string;
	readonly password: string;
	readonly guest_id?: string;
	readonly recovery_key?: string;
}

export interface AccountLoginRequest {
	readonly username: string;
	readonly password: string;
}

export interface AccountClaimRequest {
	readonly guest_id: string;
	readonly recovery_key: string;
}

export interface DraftPutRequest {
	readonly document: Record<string, unknown>;
}

export const accountRegisterBodySchema = {
	type: "object",
	additionalProperties: false,
	required: ["username", "password"],
	properties: {
		username: { type: "string", minLength: ACCOUNT_USERNAME_MIN, maxLength: ACCOUNT_USERNAME_MAX },
		password: { type: "string", minLength: ACCOUNT_PASSWORD_MIN, maxLength: ACCOUNT_PASSWORD_MAX },
		guest_id: { type: "string", minLength: GUEST_ID_LEN, maxLength: GUEST_ID_LEN },
		recovery_key: { type: "string", minLength: RECOVERY_KEY_MIN, maxLength: RECOVERY_KEY_MAX },
	},
} as const;

export const accountLoginBodySchema = {
	type: "object",
	additionalProperties: false,
	required: ["username", "password"],
	properties: {
		username: { type: "string", minLength: ACCOUNT_USERNAME_MIN, maxLength: ACCOUNT_USERNAME_MAX },
		password: { type: "string", minLength: ACCOUNT_PASSWORD_MIN, maxLength: ACCOUNT_PASSWORD_MAX },
	},
} as const;

export const accountClaimBodySchema = {
	type: "object",
	additionalProperties: false,
	required: ["guest_id", "recovery_key"],
	properties: {
		guest_id: { type: "string", minLength: GUEST_ID_LEN, maxLength: GUEST_ID_LEN },
		recovery_key: { type: "string", minLength: RECOVERY_KEY_MIN, maxLength: RECOVERY_KEY_MAX },
	},
} as const;

export const draftPutBodySchema = {
	type: "object",
	additionalProperties: false,
	required: ["document"],
	properties: {
		document: { type: "object" },
	},
} as const;
