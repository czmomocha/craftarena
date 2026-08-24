import { loadConfig } from "./config.ts";
import { HttpControlPlaneProbe, buildGateway } from "./server.ts";
import { DevTicketVerifier } from "./ticket.ts";

const config = loadConfig();

const gateway = buildGateway({
	ticketVerifier: new DevTicketVerifier(config.devUpstreamUrl),
	controlPlaneProbe: new HttpControlPlaneProbe(config.controlPlaneUrl),
	version: config.version,
	logger: { level: config.logLevel },
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
	gateway.app.log.warn(
		{ controlPlaneUrl: config.controlPlaneUrl },
		"gateway listening over plaintext ws; TLS must be terminated by the deployment layer (constitution rule 22)",
	);
} catch (error) {
	gateway.app.log.error({ error }, "gateway failed to start");
	process.exit(1);
}
