import { loadConfig, readTlsCredentials } from "./config.ts";
import { HttpControlPlaneProbe, buildGateway } from "./server.ts";
import { ControlPlaneTicketVerifier, DevTicketVerifier } from "./ticket.ts";

const config = loadConfig();
const https =
	config.tls === undefined ? undefined : readTlsCredentials(config.tls);

const ticketVerifier =
	config.devUpstreamUrl === undefined
		? new ControlPlaneTicketVerifier(config.controlPlaneUrl)
		: new DevTicketVerifier(config.devUpstreamUrl);

const gateway = buildGateway({
	ticketVerifier,
	controlPlaneProbe: new HttpControlPlaneProbe(config.controlPlaneUrl),
	version: config.version,
	logger: { level: config.logLevel },
	https,
});

let shuttingDown = false;
for (const signal of ["SIGINT", "SIGTERM"] as const) {
	process.on(signal, () => {
		if (shuttingDown) {
			return;
		}
		shuttingDown = true;
		gateway.app.log.info({ signal }, "shutting down gateway");

		void gateway
			.close()
			.then(() => process.exit(0))
			.catch((error: unknown) => {
				gateway.app.log.error({ error }, "failed to shut down cleanly");
				process.exit(1);
			});
	});
}

try {
	await gateway.app.listen({ host: config.host, port: config.port });
	if (https === undefined) {
		gateway.app.log.warn(
			{ controlPlaneUrl: config.controlPlaneUrl },
			"gateway listening over plaintext ws; set GATEWAY_TLS_CERT and GATEWAY_TLS_KEY for in-process wss (constitution rule 22)",
		);
	} else {
		gateway.app.log.info(
			{ controlPlaneUrl: config.controlPlaneUrl },
			"gateway listening over wss; match-process upstream remains plaintext ws on the loopback",
		);
	}
} catch (error) {
	gateway.app.log.error({ error }, "gateway failed to start");
	process.exit(1);
}
