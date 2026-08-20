/**
 * 三个后端进程共用的健康与就绪契约。
 *
 * 刻意只覆盖运维面：玩法命令、快照与错误码属于 CD-42 的范围，等实现到那一步再定，
 * 不在这里提前发明一套可能和它冲突的体系。
 */

export const SERVICE_IDS = {
	controlPlane: "control-plane",
	realtimeGateway: "realtime-gateway",
	matchHost: "match-host",
} as const;

export type ServiceId = (typeof SERVICE_IDS)[keyof typeof SERVICE_IDS];

/** 单项就绪检查的结果。`ok` 为 false 时整个服务视为未就绪。 */
export interface ReadinessCheck {
	readonly name: string;
	readonly ok: boolean;
	/** 失败原因或补充信息。成功时通常省略。 */
	readonly detail?: string | undefined;
}

/** `GET /healthz` 的响应。只回答"进程还活着吗"，不做任何依赖探测。 */
export interface HealthPayload {
	readonly service: ServiceId;
	readonly status: "ok";
	readonly version: string;
	readonly uptimeSeconds: number;
}

/**
 * `GET /readyz` 的响应。会真的去碰依赖（数据库、下游服务），
 * 因此未就绪时必须返回 HTTP 503，让编排层不要往这个实例送流量。
 */
export interface ReadinessPayload {
	readonly service: ServiceId;
	readonly status: "ready" | "not_ready";
	readonly version: string;
	readonly uptimeSeconds: number;
	readonly checks: readonly ReadinessCheck[];
}

export function isReady(checks: readonly ReadinessCheck[]): boolean {
	return checks.every((check) => check.ok);
}
