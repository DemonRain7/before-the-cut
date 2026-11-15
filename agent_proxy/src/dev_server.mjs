// Local server for the patient-dialogue proxy (and its push-to-talk route). Node 22 or newer, no dependencies.
//   node src/dev_server.mjs
// Settings come from environment variables (see ../README.md and ../.dev.vars.example).

import fs from "node:fs";
import http from "node:http";
import path from "node:path";
import { fileURLToPath } from "node:url";

import { createHandler, DEFAULT_LIMITS } from "./core.mjs";
import { providerFromSettings } from "./providers.mjs";

const HERE = path.dirname(fileURLToPath(import.meta.url));

/** Reads rules.json and every case file from the game's data folder. The proxy needs its own copy of the cases. */
export function loadGameData(dataDir = path.resolve(HERE, "..", "..", "game", "data")) {
	const rules = JSON.parse(fs.readFileSync(path.join(dataDir, "rules.json"), "utf8"));
	const cases = {};
	const caseDir = path.join(dataDir, "cases");
	for (const file of fs.readdirSync(caseDir).sort()) {
		if (!file.endsWith(".json")) continue;
		const c = JSON.parse(fs.readFileSync(path.join(caseDir, file), "utf8"));
		cases[c.id] = c;
	}
	return { rules, cases };
}

function readBody(req, cap) {
	return new Promise((resolve) => {
		const chunks = [];
		let size = 0;
		req.on("data", (chunk) => {
			size += chunk.length;
			if (size <= cap) chunks.push(chunk);
		});
		req.on("end", () => resolve({ text: size <= cap ? Buffer.concat(chunks).toString("utf8") : "", tooLarge: size > cap }));
		req.on("error", () => resolve({ text: "", tooLarge: false }));
	});
}

/** Starts the server. Returns {server, url, close()}. Port 0 picks a free port (used by the tests). */
export function startServer({ provider, limits = {}, host = "127.0.0.1", port = 8787, dataDir, log = (entry) => console.log(JSON.stringify(entry)) } = {}) {
	const { rules, cases } = loadGameData(dataDir);
	const lim = { ...DEFAULT_LIMITS, ...limits };
	const handle = createHandler({ cases, rules, provider, limits: lim, log: (entry) => log({ t: new Date().toISOString(), ...entry }) });
	const server = http.createServer(async (req, res) => {
		let out;
		try {
			// a push-to-talk clip is far larger than a line of dialogue: each route has its own cap
			const cap = String(req.url || "").split("?")[0].replace(/\/+$/, "") === "/v1/transcribe" ? lim.maxAudioBodyBytes : lim.maxBodyBytes;
			const body = req.method === "POST" ? await readBody(req, cap) : { text: "", tooLarge: false };
			out = await handle({ method: req.method, path: req.url, bodyText: body.text, bodyTooLarge: body.tooLarge });
		} catch {
			out = { status: 500, body: { error: { code: "internal", message: "internal" } } };
		}
		res.writeHead(out.status, { "content-type": "application/json; charset=utf-8", "cache-control": "no-store" });
		res.end(JSON.stringify(out.body));
	});
	return new Promise((resolve) => {
		server.listen(port, host, () => {
			const address = server.address();
			const close = () => new Promise((done) => {
				server.close(done);
				server.closeAllConnections();
			});
			resolve({ server, url: `http://${host}:${address.port}`, close });
		});
	});
}

const startedDirectly = process.argv[1] && path.resolve(process.argv[1]) === fileURLToPath(import.meta.url);
if (startedDirectly) {
	const env = process.env;
	const limits = {};
	if (env.BTC_UPSTREAM_TIMEOUT_MS) limits.upstreamTimeoutMs = Number(env.BTC_UPSTREAM_TIMEOUT_MS);
	if (env.BTC_TRANSCRIBE_TIMEOUT_MS) limits.transcribeTimeoutMs = Number(env.BTC_TRANSCRIBE_TIMEOUT_MS);
	let provider;
	try {
		provider = providerFromSettings(env);
	} catch (err) {
		console.error(String(err.message));
		process.exit(1);
	}
	const running = await startServer({ provider, limits, host: env.BTC_HOST || "127.0.0.1", port: Number(env.BTC_PORT || 8787) });
	console.error(`patient-dialogue proxy on ${running.url}  provider=${provider.name}  model=${provider.model}`);
	console.error("Point the game at it:  godot --path game -- --agent-url=" + running.url + " --model");
}
