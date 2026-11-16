// Run from the repository root. Node, not this script, loads the ignored credential file:
// node --env-file=agent_proxy/.dev.vars tools/live_model_session.mjs start validation/YYYY-MM-DD/codex-live-test
// After inspecting the first reply: node tools/live_model_session.mjs continue <same-directory>
// End paid access: node tools/live_model_session.mjs stop <same-directory>
import fs from "node:fs";
import path from "node:path";
import { startServer } from "../agent_proxy/src/dev_server.mjs";
import { createOpenAIProvider } from "../agent_proxy/src/providers.mjs";
import { createTestGuard, guardedProvider, safeLog, latencySummary } from "./live_model_guard.mjs";

const [command, suppliedDirectory] = process.argv.slice(2);
if (!suppliedDirectory || !["start", "continue", "stop", "report"].includes(command)) {
  console.error("Usage: live_model_session.mjs start|continue|stop|report <evidence-directory>");
  process.exit(1);
}
const directory = path.resolve(suppliedDirectory);
const guard = createTestGuard(directory);
const append = (file, entry) => fs.appendFileSync(path.join(directory, file), JSON.stringify(entry) + "\n");
const readLines = (file) => fs.existsSync(path.join(directory, file))
  ? fs.readFileSync(path.join(directory, file), "utf8").trim().split("\n").filter(Boolean).map(JSON.parse) : [];

if (command === "continue") {
  guard.continueAfterReview();
  console.log(JSON.stringify(guard.state()));
} else if (command === "stop") {
  guard.stop();
  console.log(JSON.stringify(guard.state()));
} else if (command === "report") {
  const entries = readLines("proxy.log").filter((row) => row.latency_ms !== undefined);
  const upstream = readLines("upstream-usage.jsonl");
  // This is the rate snapshot for the authorized November 15 run, not a live billing API.
  const report = { budget: guard.state(), pricing_date: "2026-11-15", routes: {} };
  for (const route of ["dialogue", "transcribe"]) {
    const rows = entries.filter((row) => (row.route === "transcribe" ? "transcribe" : "dialogue") === route);
    const usages = upstream.filter((row) => row.route === route);
    const sum = (key) => usages.reduce((n, row) => n + (row[key] || 0), 0);
    const input = usages.map((row) => row.input_tokens).filter(Number.isFinite);
    const output = usages.map((row) => row.output_tokens).filter(Number.isFinite);
    const tokenStats = (tokens) => ({ mean: tokens.length ? tokens.reduce((a, b) => a + b, 0) / tokens.length : null,
      max: tokens.length ? Math.max(...tokens) : null });
    report.routes[route] = { ...latencySummary(rows.map((row) => row.latency_ms)),
      successes: rows.filter((row) => row.status === 200).length,
      errors: rows.filter((row) => row.status !== 200).length,
      timeouts: rows.filter((row) => row.code === "upstream_timeout").length,
      invalid_output: rows.filter((row) => row.code === "invalid_model_output").length,
      input_tokens: sum("input_tokens"), output_tokens: sum("output_tokens"),
      cached_input_tokens: sum("cached_input_tokens"), audio_input_tokens: sum("audio_input_tokens"),
      text_input_tokens: sum("text_input_tokens"),
      input_per_response: tokenStats(input), output_per_response: tokenStats(output),
      responses_without_usage: usages.filter((row) => row.input_tokens === null).length,
      attempts_without_response_metadata: guard.state()[route] - usages.length,
      audio_seconds: rows.reduce((n, row) => n + (row.audio_seconds || 0), 0),
      // Published token-price estimate. The billing dashboard is authoritative.
      known_tokens_list_usd: route === "dialogue"
        ? ((sum("input_tokens") - sum("cached_input_tokens")) * 0.1 + sum("cached_input_tokens") * 0.01 + sum("output_tokens") * 0.5) / 1e6
        : (sum("input_tokens") * 1.25 + sum("output_tokens") * 5) / 1e6,
      audio_duration_estimate_usd: route === "transcribe" ? rows.reduce((n, row) => n + (row.audio_seconds || 0), 0) / 60 * 0.003 : null };
  }
  fs.writeFileSync(path.join(directory, "metrics.json"), JSON.stringify(report, null, 2) + "\n");
  console.log(JSON.stringify(report, null, 2));
} else {
  if (process.env.BTC_PROVIDER !== "openai" || process.env.BTC_MODEL !== "gpt-6-luna" ||
      process.env.BTC_STT_MODEL !== "gpt-4o-mini-transcribe" || process.env.BTC_REASONING_EFFORT !== "none") {
    console.error("Configuration does not match the authorized provider and models.");
    process.exit(1);
  }
  if (!process.env.OPENAI_API_KEY) {
    console.error("Credential is not configured. No provider call was made.");
    process.exit(1);
  }
  const measuredFetch = async (url, init) => {
    const response = await fetch(url, init);
    // Extract numeric usage in memory; never retain the response text or error message.
    const copy = response.clone();
    void copy.json().then((data) => {
      const u = data.usage || {};
      const number = (value) => Number.isFinite(value) ? value : null;
      append("upstream-usage.jsonl", {
        route: url.endsWith("/responses") ? "dialogue" : "transcribe", status: response.status,
        input_tokens: number(u.input_tokens), output_tokens: number(u.output_tokens),
        cached_input_tokens: number(u.input_tokens_details?.cached_tokens),
        audio_input_tokens: number(u.input_token_details?.audio_tokens),
        text_input_tokens: number(u.input_token_details?.text_tokens),
        reasoning_tokens: number(u.output_tokens_details?.reasoning_tokens),
        incomplete: data.status === "incomplete",
      });
    }).catch(() => {});
    return response;
  };
  const base = createOpenAIProvider({ model: "gpt-6-luna", sttModel: "gpt-4o-mini-transcribe",
    reasoningEffort: "none", apiKey: process.env.OPENAI_API_KEY, fetchImpl: measuredFetch });
  const provider = guardedProvider(base, guard);
  const running = await startServer({ provider, log: (entry) => {
    append("proxy.log", safeLog(entry));
    console.log(JSON.stringify(safeLog(entry)));
  } });
  console.log(JSON.stringify({ listening: running.url, provider: base.name, model: base.model, ...guard.state() }));
  for (const signal of ["SIGINT", "SIGTERM"]) process.once(signal, async () => { await running.close(); process.exit(0); });
}
