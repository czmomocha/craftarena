import { spawn, type ChildProcessByStdio } from "node:child_process";
import { existsSync } from "node:fs";
import { dirname, join, resolve } from "node:path";
import { fileURLToPath } from "node:url";
import type { Readable } from "node:stream";

import { probeReadyEndpoint, waitUntilReady } from "./readiness.ts";
import { SERVICES, parseListeningUrl, type ServiceSpec } from "./services.ts";

/**
 * DevLauncher：一条命令把控制面、网关和 MatchHost 一起拉起来，等三个都就绪再放行。
 *
 * 它只做本地开发编排，**不是**部署工具：不守护、不重启、不限制资源。
 * 测试环境的编排见 CD-44。
 */

const REPO_ROOT = resolve(dirname(fileURLToPath(import.meta.url)), "../../..");

const envFile = join(REPO_ROOT, ".env");
if (existsSync(envFile)) {
	process.loadEnvFile(envFile);
}

const LISTEN_TIMEOUT_MS = 30_000;
const READY_TIMEOUT_MS = 30_000;
const READY_POLL_INTERVAL_MS = 250;

/** SIGTERM 之后留给子进程收尾的时间，超时就 SIGKILL，避免 Ctrl+C 之后卡住不返回。 */
const SHUTDOWN_GRACE_MS = 5_000;

/** stdio 固定为 ignore/pipe/pipe，所以 stdin 一定是 null、两条输出流一定存在。 */
type ServiceProcess = ChildProcessByStdio<null, Readable, Readable>;

interface RunningService {
	readonly spec: ServiceSpec;
	readonly child: ServiceProcess;
	/** 子进程日志里报出的监听地址，只有在它出现之后探测 /readyz 才有意义。 */
	readonly listening: Promise<string>;
	exited: boolean;
}

const running: RunningService[] = [];
let stopping = false;

function log(message: string): void {
	process.stdout.write(`[dev-launcher] ${message}\n`);
}

function start(spec: ServiceSpec): RunningService {
	const child = spawn(process.execPath, [spec.entry], {
		cwd: REPO_ROOT,
		stdio: ["ignore", "pipe", "pipe"],
	});

	let resolveListening: (url: string) => void = () => {};
	let rejectListening: (error: Error) => void = () => {};
	const listening = new Promise<string>((res, rej) => {
		resolveListening = res;
		rejectListening = rej;
	});

	const service: RunningService = { spec, child, listening, exited: false };

	// 按行切分而不是直接对 chunk 做匹配：监听日志有可能正好被拆在两个 chunk 之间，
	// 那样启动流程会一直等不到地址，最后报一个与真实原因无关的超时。
	const consume = (stream: NodeJS.ReadableStream): void => {
		let buffered = "";
		stream.on("data", (chunk: Buffer) => {
			buffered += chunk.toString();
			const lines = buffered.split(/\r?\n/);
			buffered = lines.pop() ?? "";
			for (const line of lines) {
				if (line.trim() === "") {
					continue;
				}
				process.stdout.write(`[${spec.name}] ${line}\n`);
				const url = parseListeningUrl(line);
				if (url !== undefined) {
					resolveListening(url);
				}
			}
		});
	};

	consume(child.stdout);
	consume(child.stderr);

	child.once("exit", (code, signal) => {
		service.exited = true;
		rejectListening(new Error(`${spec.name} exited before it started listening (code=${code} signal=${signal})`));

		if (stopping) {
			return;
		}
		// 启动完成后有进程掉线时整体退出：留着另外两个继续跑只会让人对着一个
		// 半死的环境调试，比直接失败更浪费时间。
		log(`${spec.name} exited unexpectedly (code=${code} signal=${signal}); stopping everything`);
		void shutdown(1);
	});

	running.push(service);
	return service;
}

async function bringUp(spec: ServiceSpec): Promise<void> {
	const service = start(spec);

	const baseUrl = await Promise.race([
		service.listening,
		new Promise<never>((_, reject) => {
			setTimeout(() => {
				reject(new Error(`${spec.name} never reported a listening address within ${LISTEN_TIMEOUT_MS}ms`));
			}, LISTEN_TIMEOUT_MS).unref();
		}),
	]);

	try {
		await waitUntilReady(() => probeReadyEndpoint(baseUrl), {
			timeoutMs: READY_TIMEOUT_MS,
			intervalMs: READY_POLL_INTERVAL_MS,
		});
	} catch (error) {
		throw new Error(`${spec.name} ${error instanceof Error ? error.message : String(error)}`);
	}

	log(`${spec.name} ready at ${baseUrl}`);
}

async function shutdown(exitCode: number): Promise<void> {
	if (stopping) {
		return;
	}
	stopping = true;

	const pending = running.filter((service) => !service.exited);
	await Promise.all(
		pending.map(
			(service) =>
				new Promise<void>((done) => {
					const killTimer = setTimeout(() => {
						service.child.kill("SIGKILL");
					}, SHUTDOWN_GRACE_MS);
					killTimer.unref();

					service.child.once("exit", () => {
						clearTimeout(killTimer);
						done();
					});
					service.child.kill("SIGTERM");
				}),
		),
	);

	process.exit(exitCode);
}

for (const signal of ["SIGINT", "SIGTERM"] as const) {
	process.on(signal, () => {
		log(`received ${signal}, stopping services`);
		void shutdown(0);
	});
}

try {
	for (const spec of SERVICES) {
		await bringUp(spec);
	}
	log("all services ready; press Ctrl+C to stop");
} catch (error) {
	log(`startup failed: ${error instanceof Error ? error.message : String(error)}`);
	await shutdown(1);
}
