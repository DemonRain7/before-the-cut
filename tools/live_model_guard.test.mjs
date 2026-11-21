import test from "node:test";
import assert from "node:assert/strict";
import fs from "node:fs";
import os from "node:os";
import path from "node:path";
import { createTestGuard, guardedProvider, safeLog, latencySummary } from "./live_model_guard.mjs";

test("the historical supervised guard cannot spend on intent", async (t) => {
  const { guard } = fixture(t);
  const base = { generate: () => assert.fail("unexpected upstream call") };
  await assert.rejects(guardedProvider(base, guard).generate({ intent: true }, new AbortController().signal), /test_route_not_authorized/);
  assert.equal(guard.state().dialogue, 0);
});

function fixture(t) {
  const directory = fs.mkdtempSync(path.join(os.tmpdir(), "btc-guard-test-"));
  t.after(() => fs.rmSync(directory, { recursive: true, force: true }));
  return { directory, guard: createTestGuard(directory) };
}

test("the first dialogue pauses all paid routes until successful review", (t) => {
  const { guard } = fixture(t);
  assert.throws(() => guard.reserve("transcribe"), /dialogue_first/);
  const first = guard.reserve("dialogue");
  assert.throws(() => guard.reserve("dialogue"), /test_paused/);
  assert.throws(() => guard.continueAfterReview(), /not_successful/);
  guard.finish(200, first);
  assert.throws(() => guard.reserve("transcribe"), /test_paused/);
  guard.continueAfterReview();
  const speech = guard.reserve("transcribe");
  guard.finish(200, speech);
  assert.equal(guard.state().transcribe, 1);
});

test("a failed first call remains blocked after process restart", (t) => {
  const { directory, guard } = fixture(t);
  const first = guard.reserve("dialogue");
  guard.finish(502, first);
  const restarted = createTestGuard(directory);
  assert.throws(() => restarted.continueAfterReview(), /not_successful/);
  assert.throws(() => restarted.reserve("dialogue"), /test_paused/);
  assert.equal(restarted.state().dialogue, 1);
});

test("40 dialogue and 15 clip attempts are separate persistent hard limits", (t) => {
  const { directory, guard } = fixture(t);
  const first = guard.reserve("dialogue"); guard.finish(200, first); guard.continueAfterReview();
  for (let i = 1; i < 40; i++) { const call = guard.reserve("dialogue"); guard.finish(504, call); }
  const restarted = createTestGuard(directory);
  assert.throws(() => restarted.reserve("dialogue"), /test_call_cap/);
  for (let i = 0; i < 15; i++) { const call = restarted.reserve("transcribe"); restarted.finish(200, call); }
  assert.throws(() => restarted.reserve("transcribe"), /test_call_cap/);
  restarted.stop();
  assert.equal(restarted.state().phase, "stopped");
});

test("invalid first JSON cannot unlock a live session", async (t) => {
  const { guard } = fixture(t);
  const provider = guardedProvider({ generate: async () => ({ text: "invalid" }) }, guard);
  await provider.generate({ maxLineChars: 110, req: { event: { type: "ask" } } }, new AbortController().signal);
  assert.equal(guard.state().first_status, 422);
  assert.throws(() => guard.continueAfterReview(), /not_successful/);
});

test("rejected concurrent requests cannot finish or unlock the first request", async (t) => {
  const { guard } = fixture(t);
  let resolve;
  let paidCalls = 0;
  const provider = guardedProvider({ generate: () => { paidCalls++; return new Promise((done) => { resolve = done; }); } }, guard);
  const input = { maxLineChars: 110, req: { event: { type: "ask" } } };
  const first = provider.generate(input, new AbortController().signal);
  await assert.rejects(provider.generate(input, new AbortController().signal), /test_paused_or_capped/);
  assert.equal(guard.state().first_status, null);
  assert.equal(paidCalls, 1);
  resolve({ text: JSON.stringify({ reply: "I need my optic repaired.", reaction: "Looks worried." }) });
  await first;
  assert.equal(guard.state().first_status, 200);
  guard.continueAfterReview();
});

test("metadata logger drops text, audio, credentials, unexpected fields and unsafe identifiers", () => {
  assert.deepEqual(safeLog({ case_id: "kip", event: "say:free", status: 200, latency_ms: 45,
    reply: "private words", text: "private words", audio: "bytes", authorization: "secret",
    code: "unsafe text", input_tokens: 120, output_tokens: null }),
  { case_id: "kip", event: "say:free", status: 200, latency_ms: 45, input_tokens: 120, output_tokens: null });
  assert.deepEqual(latencySummary([20, 10, 30, 40]), { count: 4, median_ms: 25, p90_ms: 40, max_ms: 40 });
});
