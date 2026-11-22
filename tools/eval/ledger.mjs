import fs from "node:fs";
import path from "node:path";
import { openAIInput, ProviderError } from "../../agent_proxy/src/providers.mjs";

export const LIMITS = Object.freeze({ E1: 400, E2: 408, E3: 120, E4: 174 });
const budgets = {
  full: { counts: LIMITS, maxNano: 50_000_000_000, inputNano: 138, outputNano: 550 },
  slim: { counts: { L1:120, L2:80, L3:80, L4:80, L5:40 }, maxNano:5_000_000_000, inputNano:600, outputNano:1600 }
};
const MODEL = "gpt-6-luna";

export function openLedger(dir, live, kind = "full") {
  const budget = budgets[kind];
  if (!budget) throw Error("Unknown evaluation budget");
  fs.mkdirSync(dir, { recursive: true });
  // A single writer owns this authorization. The reservation survives a crash or an aborted HTTP call.
  const lock = path.join(dir, "writer.lock");
  const fd = fs.openSync(lock, "wx");
  fs.writeFileSync(fd, String(process.pid));
  fs.closeSync(fd);
  const file = path.join(dir, "ledger.jsonl");
  const events = fs.existsSync(file) ? fs.readFileSync(file, "utf8").trim().split("\n").filter(Boolean).map(t => JSON.parse(t)) : [];
  const output = fs.openSync(file, "a");
  const attempts = new Set();
  const counts = Object.fromEntries(Object.keys(budget.counts).map(group=>[group,0]));
  let bound = 0;
  function apply(row) {
    if (row.stage === "reserve") {
      attempts.add(row.id);
      counts[row.group]++;
      bound += row.nano;
    }
  }
  events.forEach(apply);
  function append(row) {
    fs.writeSync(output, JSON.stringify(row) + "\n");
    fs.fsyncSync(output);
    events.push(row);
    apply(row);
  }
  function reserve(id, input) {
    const group = id.split("-")[0];
    if (!Object.hasOwn(budget.counts, group) || attempts.has(id) || counts[group] >= budget.counts[group]) throw new ProviderError("eval_call_cap");
    // Max UTF-8 bytes for the exact prompt, schema, framing and output. Upper standard/regional rates per token, in nanodollars.
    const bytes = Buffer.byteLength(JSON.stringify([openAIInput(input, true), input.schema])) + 1024;
    const nano = live ? bytes * budget.inputNano + input.maxOutputTokens * budget.outputNano : 0;
    if (bound + nano > budget.maxNano) throw new ProviderError("eval_cost_cap");
    append({ stage: "reserve", id, group, nano });
  }
  return {
    events, attempts, counts, get bound() { return bound; }, append, reserve,
    wrap(base) {
      if (live && (base.name !== "openai" || base.model !== MODEL)) throw Error("Unapproved provider or model");
      return { ...base, async generate(input, signal) {
        reserve(input.req.visit_id, input);
        return base.generate(input, signal);
      }, transcribe: undefined };
    },
    close() { fs.closeSync(output); fs.unlinkSync(lock); }
  };
}
