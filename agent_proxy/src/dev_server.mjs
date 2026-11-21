// Local server for the patient-dialogue proxy (and its push-to-talk route). Node 22 or newer, no dependencies.
//   node src/dev_server.mjs
// Settings come from environment variables (see ../README.md and ../.dev.vars.example).

import fs from "node:fs";
import http from "node:http";
import path from "node:path";
import { fileURLToPath } from "node:url";

import { createHandler, serviceSettings } from "./core.mjs";
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
			else if (size - chunk.length <= cap) resolve({ bodyText: "", bodyTooLarge: true });
		});
		req.on("end", () => resolve({ bodyText: size <= cap ? Buffer.concat(chunks).toString("utf8") : "", bodyTooLarge: size > cap }));
		req.on("error", () => resolve({ bodyText: "", bodyTooLarge: false }));
	});
}

/** Starts the server. Returns {server, url, close()}. Port 0 picks a free port (used by the tests). */
export function startServer({ provider, limits = {}, disabled = false, transcribeEnabled = true, host = "127.0.0.1", port = 8787, dataDir, log = (entry) => console.log(JSON.stringify(entry)) } = {}) {
	const { rules, cases } = loadGameData(dataDir);
	const handle = createHandler({ cases, rules, provider, limits, disabled, transcribeEnabled, log: (entry) => log({ t: new Date().toISOString(), ...entry }) });
	const server = http.createServer(async (req, res) => {
		let out;
		try {
			out = await handle({ method: req.method, path: req.url, readBody: (cap) => readBody(req, cap) });
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
	const options = serviceSettings(env);
	let provider;
	try {
		provider = options.disabled ? { name: env.BTC_PROVIDER || "mock", model: env.BTC_MODEL || "" } : providerFromSettings(env);
	} catch (err) {
		console.error(String(err.message));
		process.exit(1);
	}
	const running = await startServer({ provider, ...options, host: env.BTC_HOST || "127.0.0.1", port: Number(env.BTC_PORT || 8787) });
	// The launcher asks Node to bind port zero, then learns the actual port of this child.
	if (env.BTC_READY_FILE) fs.writeFileSync(env.BTC_READY_FILE, String(new URL(running.url).port), "ascii");
	console.error(`patient-dialogue proxy on ${running.url}  provider=${provider.name}  model=${provider.model}`);
	console.error("Point the game at it:  godot --path game -- --agent-url=" + running.url + " --model");
}
