// A bounded, resumable supervised test. Never records prompts, replies, audio or credentials.
import fs from "node:fs";
import path from "node:path";
import { DEFAULT_LIMITS, validateResponse } from "../agent_proxy/src/core.mjs";
import { ProviderError } from "../agent_proxy/src/providers.mjs";

export const TEST_CAPS = Object.freeze({ dialogue: 40, transcribe: 15 });

export function createTestGuard(directory) {
  fs.mkdirSync(directory, { recursive: true });
  const filename = path.join(directory, "call-budget.json");
  const read = () => JSON.parse(fs.readFileSync(filename, "utf8"));
  const write = (state) => fs.writeFileSync(filename, JSON.stringify(state, null, 2) + "\n");
  if (!fs.existsSync(filename)) write({ dialogue: 0, transcribe: 0, phase: "first", first_status: null });
  let active = null;
  let firstRequest = false;
  return {
    state: read,
    reserve(route) {
      const state = read();
      if (!Object.hasOwn(TEST_CAPS, route)) throw new Error("unknown_test_route");
      if (active || !["first", "active"].includes(state.phase)) throw new Error("test_paused");
      if (state.phase === "first" && route !== "dialogue") throw new Error("dialogue_first");
      if (state[route] >= TEST_CAPS[route]) throw new Error("test_call_cap");
      firstRequest = state.phase === "first";
      if (firstRequest) state.phase = "review";
      state[route] += 1; // Reserve before the request; a timeout still consumes the budget.
      write(state);
      active = Symbol("request");
      return active;
    },
    finish(status, reservation) {
      if (!active || active !== reservation) return;
      const state = read();
      if (firstRequest) {
        state.first_status = status;
        if (status !== 200) state.phase = "blocked";
        write(state);
      }
      active = null;
      firstRequest = false;
    },
    continueAfterReview() {
      const state = read();
      if (state.phase !== "review" || state.first_status !== 200) throw new Error("first_call_not_successful");
      state.phase = "active";
      write(state);
    },
    stop() {
      const state = read();
      state.phase = "stopped";
      write(state);
    },
  };
}

export function guardedProvider(base, guard) {
  const provider = { ...base };
  for (const [method, route] of [["generate", "dialogue"], ["transcribe", "transcribe"]]) {
    provider[method] = async (input, signal) => {
      if (input.intent) throw new ProviderError("test_route_not_authorized");
      let reservation;
      try { reservation = guard.reserve(route); } catch { throw new ProviderError("test_paused_or_capped"); }
      const abort = () => guard.finish(504, reservation);
      signal.addEventListener("abort", abort, { once: true });
      try {
        const result = await base[method](input, signal);
        let status = 200;
        if (method === "generate") {
          try {
            const answer = JSON.parse(String(result.text).trim());
            // Reuse the core's exact shape check before unlocking the first-call review.
            if (!validateResponse(answer, Math.max(input.maxLineChars, DEFAULT_LIMITS.maxReplyChars),
              input.req.event.type === "check", input.req.event.outcome).ok) status = 422;
          } catch { status = 422; }
        }
        guard.finish(status, reservation);
        return result;
      } catch (error) {
        guard.finish(signal.aborted ? 504 : 502, reservation);
        throw error;
      } finally {
        signal.removeEventListener("abort", abort);
      }
    };
  }
  return provider;
}

// Explicit fields only: never serialize an upstream response, an Error, or a request body.
const STRING_FIELDS = new Set(["t", "request_id", "route", "provider", "model", "code", "session_id", "visit_id", "case_id", "event"]);
const NUMBER_FIELDS = new Set(["status", "latency_ms", "input_tokens", "output_tokens", "audio_seconds", "audio_bytes", "transcript_chars"]);
export function safeLog(entry) {
  const out = {};
  for (const [key, value] of Object.entries(entry)) {
    if (NUMBER_FIELDS.has(key) && (value === null || Number.isFinite(value))) out[key] = value;
    if (STRING_FIELDS.has(key) && typeof value === "string" && /^[\w:.+/-]{1,100}$/.test(value)) out[key] = value;
  }
  return out;
}

export function latencySummary(values) {
  const ordered = values.filter(Number.isFinite).sort((a, b) => a - b);
  const n = ordered.length;
  if (!n) return { count: 0, median_ms: null, p90_ms: null, max_ms: null };
  return { count: n, median_ms: n % 2 ? ordered[(n - 1) / 2] : (ordered[n / 2 - 1] + ordered[n / 2]) / 2,
    p90_ms: ordered[Math.ceil(n * 0.9) - 1], max_ms: ordered[n - 1] };
}
