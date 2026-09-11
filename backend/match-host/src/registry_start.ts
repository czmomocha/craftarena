import { randomUUID } from "node:crypto";

import type { MatchContentRef } from "../../contracts/src/match_body.ts";
import {
	officialTraprushCoursePath,
	type OfficialTraprushCourseId,
} from "../../contracts/src/official_courses.ts";
import {
	contentRefOf,
	removeMatchEnvelopeFile,
	writeMatchEnvelopeFile,
	type ContentEnvelopeFetcher,
} from "./content_envelope.ts";
import type { LaunchedProcess, MatchLaunchSpec, ProcessLauncher } from "./launcher.ts";
import type { MatchListenProbe } from "./listen_probe.ts";
import { buildMatchUpstreamUrl, MatchSessionRegisterError, type MatchSessionRegistrar } from "./registrar.ts";
import { toStartFailure, waitUntilListening } from "./registry_launch.ts";
import type { PortAllocator } from "./ports.ts";

export type MatchStartPlan =
	| { readonly kind: "official"; readonly course: OfficialTraprushCourseId; readonly seats: number }
	| { readonly kind: "content"; readonly content: MatchContentRef; readonly seats: number };

export interface MatchLaunchContext {
	readonly launcher: ProcessLauncher;
	readonly registrar: MatchSessionRegistrar;
	readonly listenProbe: MatchListenProbe;
	readonly contentEnvelope?: ContentEnvelopeFetcher | undefined;
	readonly upstreamHost: string;
	readonly ports: PortAllocator;
	readonly now: () => number;
	readonly onStartFailed?: (event: {
		readonly matchId: string;
		readonly port: number;
		readonly message: string;
		readonly recentOutput: readonly string[];
	}) => void;
}

export interface StartedMatch {
	readonly matchId: string;
	readonly port: number;
	readonly pid: number | undefined;
	readonly upstreamUrl: string;
	readonly seats: number;
	readonly course: OfficialTraprushCourseId | null;
	readonly content?: MatchContentRef | undefined;
	readonly contentHash?: string | undefined;
	readonly process: LaunchedProcess;
	readonly envelopePath?: string | undefined;
}

export async function launchRegisteredMatch(
	ctx: MatchLaunchContext,
	plan: MatchStartPlan,
): Promise<StartedMatch> {
	const matchId = randomUUID();
	const port = ctx.ports.allocate();
	let process: LaunchedProcess | undefined;
	let envelopePath: string | undefined;
	let upstreamUrl: string;
	let content: MatchContentRef | undefined;
	let contentHash: string | undefined;
	try {
		const launch = await resolveLaunch(ctx, matchId, port, plan);
		envelopePath = launch.envelopePath;
		content = launch.content;
		contentHash = launch.contentHash;
		upstreamUrl = buildMatchUpstreamUrl(ctx.upstreamHost, port);
		process = ctx.launcher.launch(launch.spec);
		await waitUntilListening(ctx.listenProbe, process, port);
		await ctx.registrar.register({
			matchId,
			upstreamUrl,
			seats: plan.seats,
			...(launch.course === undefined ? {} : { course: launch.course }),
			...(launch.content === undefined
				? {}
				: { content: launch.content, content_hash: launch.contentHash }),
		});
	} catch (error) {
		const recentOutput = process?.recentOutput() ?? [];
		process?.kill();
		ctx.ports.release(port);
		removeMatchEnvelopeFile(envelopePath);
		const failure = toStartFailure(error, process !== undefined);
		ctx.onStartFailed?.({
			matchId,
			port,
			message: failure.message,
			recentOutput,
		});
		throw failure;
	}

	return {
		matchId,
		port,
		pid: process.pid,
		upstreamUrl,
		seats: plan.seats,
		course: plan.kind === "official" ? plan.course : null,
		content,
		contentHash,
		process,
		envelopePath,
	};
}

interface ResolvedLaunch {
	readonly spec: MatchLaunchSpec;
	readonly course?: string;
	readonly content?: MatchContentRef;
	readonly contentHash?: string;
	readonly envelopePath?: string;
}

async function resolveLaunch(
	ctx: MatchLaunchContext,
	matchId: string,
	port: number,
	plan: MatchStartPlan,
): Promise<ResolvedLaunch> {
	if (plan.kind === "official") {
		return {
			spec: {
				matchId,
				port,
				course: officialTraprushCoursePath(plan.course),
				players: plan.seats,
			},
			course: plan.course,
		};
	}
	if (ctx.contentEnvelope === undefined) {
		throw new MatchSessionRegisterError("content envelope fetcher is unavailable");
	}
	const envelope = await ctx.contentEnvelope.fetch(plan.content.id, plan.content.version);
	const path = writeMatchEnvelopeFile(matchId, envelope);
	return {
		spec: {
			matchId,
			port,
			players: plan.seats,
			contentEnvelopePath: path,
		},
		content: contentRefOf(envelope),
		contentHash: envelope.content_hash,
		envelopePath: path,
	};
}
