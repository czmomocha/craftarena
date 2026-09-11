import { randomUUID } from "node:crypto";

import type { FastifyInstance } from "fastify";

import type { ContentVersionView, MatchContentRef } from "../../contracts/src/index.ts";
import { MatchHostCapacityError, type MatchLauncher, type MatchLaunchRequest } from "../src/match_host.ts";

/** 测试里把控制面登记当成 MatchHost：官方课走 `course`，UGC 先 GET 信封再钉 hash。 */
export class FakeMatchLauncher implements MatchLauncher {
	readonly launched: string[] = [];
	readonly launchedCourses: string[] = [];
	readonly launchedSeats: number[] = [];
	readonly launchedContent: Array<MatchContentRef | undefined> = [];
	seats = 2;
	remainingCapacity = 100;
	failWith: Error | undefined;
	#app: FastifyInstance | undefined;
	#nextPort: number;

	constructor(nextPort = 19000) {
		this.#nextPort = nextPort;
	}

	bind(app: FastifyInstance): void {
		this.#app = app;
	}

	async launch(request: MatchLaunchRequest = {}): Promise<{ matchId: string }> {
		if (this.failWith !== undefined) {
			throw this.failWith;
		}
		if (this.remainingCapacity <= 0) {
			throw new MatchHostCapacityError("match host is at capacity");
		}
		if (this.#app === undefined) {
			throw new Error("fake launcher is not bound");
		}

		const seats = request.seats ?? this.seats;
		const matchId = randomUUID();
		const payload: Record<string, unknown> = {
			matchId,
			upstreamUrl: `ws://127.0.0.1:${this.#nextPort}`,
			seats,
		};
		if (request.content !== undefined) {
			const version = await this.#app.inject({
				method: "GET",
				url: `/content/${request.content.id}/versions/${request.content.version}`,
			});
			if (version.statusCode !== 200) {
				throw new Error(`fake content envelope failed: ${version.statusCode}`);
			}
			const view = version.json<ContentVersionView>();
			payload.content = request.content;
			payload.content_hash = view.content_hash;
		} else {
			payload.course = request.course ?? "course_01";
		}
		const registered = await this.#app.inject({
			method: "POST",
			url: "/match-sessions",
			payload,
		});
		this.#nextPort += 1;
		if (registered.statusCode !== 201) {
			throw new Error(`fake register failed: ${registered.statusCode}`);
		}
		this.remainingCapacity -= 1;
		this.launched.push(matchId);
		this.launchedCourses.push(typeof payload.course === "string" ? payload.course : "");
		this.launchedSeats.push(seats);
		this.launchedContent.push(request.content);
		return { matchId };
	}
}
