import Fastify, { type FastifyInstance } from "fastify";

import {
	SERVICE_IDS,
	isReady,
	type HealthPayload,
	type ReadinessCheck,
	type ReadinessPayload,
} from "../../contracts/src/index.ts";
import type { ControlPlaneDatabase } from "./db/database.ts";

export interface BuildServerOptions {
	readonly database: ControlPlaneDatabase;
	readonly version: string;
	/** 传 false 可以让测试输出保持干净。 */
	readonly logger: boolean | { readonly level: string };
	/** 允许测试注入固定时钟。 */
	readonly now?: () => Date;
}

/**
 * 构建 Fastify 实例但不监听端口，这样测试可以用 `inject()` 走完整的路由与序列化，
 * 不必抢占真实端口，也不会在 CI 上因端口冲突随机失败。
 */
export function buildServer(options: BuildServerOptions): FastifyInstance {
	const now = options.now ?? (() => new Date());
	const startedAt = now();
	const app = Fastify({ logger: options.logger });

	const uptimeSeconds = (): number =>
		Math.max(0, Math.floor((now().getTime() - startedAt.getTime()) / 1000));

	app.get("/healthz", async (): Promise<HealthPayload> => {
		return {
			service: SERVICE_IDS.controlPlane,
			status: "ok",
			version: options.version,
			uptimeSeconds: uptimeSeconds(),
		};
	});

	app.get("/readyz", async (_request, reply): Promise<ReadinessPayload> => {
		const checks: ReadinessCheck[] = [databaseCheck(options.database, now())];
		const ready = isReady(checks);

		// 未就绪必须是 503。返回 200 会让上游以为这个实例可以接流量。
		reply.code(ready ? 200 : 503);

		return {
			service: SERVICE_IDS.controlPlane,
			status: ready ? "ready" : "not_ready",
			version: options.version,
			uptimeSeconds: uptimeSeconds(),
			checks,
		};
	});

	return app;
}

function databaseCheck(database: ControlPlaneDatabase, now: Date): ReadinessCheck {
	try {
		const ok = database.probeReadWrite(now);
		return ok
			? { name: "sqlite_read_write", ok: true }
			: { name: "sqlite_read_write", ok: false, detail: "write succeeded but read back mismatched" };
	} catch (error) {
		return {
			name: "sqlite_read_write",
			ok: false,
			detail: error instanceof Error ? error.message : String(error),
		};
	}
}
