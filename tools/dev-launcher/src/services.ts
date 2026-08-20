/**
 * DevLauncher 要拉起的服务清单，以及从子进程日志里认出"它已经开始监听哪个地址"的解析规则。
 *
 * 这里刻意不写端口：端口的所有者是各服务自己的 `config.ts`，DevLauncher 复制一份默认值
 * 就会在别人改端口或用 `*_PORT` 环境变量覆盖时探测到错误地址，白等 30 秒再报一个假故障。
 */

export interface ServiceSpec {
	readonly name: string;
	/** 相对仓库根目录的入口路径。 */
	readonly entry: string;
}

export const SERVICES: readonly ServiceSpec[] = [
	{
		name: "control-plane",
		entry: "backend/control-plane/src/main.ts",
	},
	{
		// 网关的 /readyz 会去探控制面，所以必须排在控制面后面，否则第一次探测必然是 503。
		name: "gateway",
		entry: "backend/realtime-gateway/src/main.ts",
	},
	{
		name: "match-host",
		entry: "backend/match-host/src/main.ts",
	},
];

/** Fastify 在 `listen()` 成功后固定打印这句话，三个服务都用默认 logger。 */
const LISTENING_PATTERN = /Server listening at (https?:\/\/\S+)/;

/**
 * 从一行子进程日志里取出监听地址，取不到返回 undefined。
 *
 * 服务用 pino 输出 JSON 行，所以先按 JSON 解析取 `msg`；解析不了就把整行当纯文本匹配，
 * 这样日志格式换成 pretty print 也不会让启动流程失灵。
 */
export function parseListeningUrl(line: string): string | undefined {
	const message = extractMessage(line);
	const matched = LISTENING_PATTERN.exec(message);
	if (matched === null) {
		return undefined;
	}

	const raw = matched[1];
	if (raw === undefined) {
		return undefined;
	}

	return normalizeHost(raw);
}

function extractMessage(line: string): string {
	if (!line.trimStart().startsWith("{")) {
		return line;
	}

	try {
		const parsed: unknown = JSON.parse(line);
		if (typeof parsed === "object" && parsed !== null && "msg" in parsed) {
			const msg = (parsed as { msg: unknown }).msg;
			if (typeof msg === "string") {
				return msg;
			}
		}
	} catch {
		// 不是合法 JSON 就退回纯文本匹配。
	}

	return line;
}

/**
 * 监听在通配地址时日志会打印 `0.0.0.0` / `[::]`，但这两个地址在部分平台上不能直接作为
 * 连接目标，必须换成回环地址才能探测。
 */
function normalizeHost(url: string): string {
	try {
		const parsed = new URL(url);
		if (parsed.hostname === "0.0.0.0") {
			parsed.hostname = "127.0.0.1";
		} else if (parsed.hostname === "[::]" || parsed.hostname === "::") {
			parsed.hostname = "[::1]";
		}
		return parsed.origin;
	} catch {
		return url;
	}
}
