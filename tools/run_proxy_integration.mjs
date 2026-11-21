// Run the real Godot client against controlled local mock providers. No credentials are read.
// Usage: node tools/run_proxy_integration.mjs <Godot console executable> [evidence directory]
import fs from 'node:fs';
import http from 'node:http';
import path from 'node:path';
import { fileURLToPath } from 'node:url';
import { spawn } from 'node:child_process';
import { startServer, loadGameData } from '../agent_proxy/src/dev_server.mjs';
import { createMockProvider } from '../agent_proxy/src/providers.mjs';

const project = path.resolve(path.dirname(fileURLToPath(import.meta.url)), '..');
const godot = process.argv[2] || process.env.GODOT_BIN;
if (!godot) throw new Error('Pass the Godot executable as the first argument.');
const output = path.resolve(project, process.argv[3] || 'validation/latest');
fs.mkdirSync(output, { recursive: true });
const { cases } = loadGameData();
const servers = [];
const requests = [];
const prompts = [];
let stdout = '';
let stderr = '';
try {
  // 'normal' runs on the proxy's own default limits. 'slow' answers after the game's client
  // deadline (rules.json agent.timeout_ms = 4000) while its own upstream limit is longer still.
  // The stt_* servers are for push-to-talk: the same synthetic provider, whose "transcript" is a
  // fixed sentence that says it is a mock. No microphone and no speech service are involved.
  const scenarios = [
    ['normal', '', {}],
    ['timeout', 'timeout', { upstreamTimeoutMs: 2000, transcribeTimeoutMs: 600 }],
    ['invalid', 'invalid_shape', { upstreamTimeoutMs: 2000 }],
    ['slow', 'slow:6000', { upstreamTimeoutMs: 8000 }],
    ['stt_slow', 'slow:700', {}],
    ['stt_empty', 'stt_empty', {}],
    ['stt_fail', 'http_error', {}],
    ['stt_fancy', 'stt_fancy', {}],
  ];
  for (const [name, fail, limits] of scenarios) {
    const mock = createMockProvider({ fail });
    const provider = { ...mock, async generate(input, signal) {
      if (name === 'normal' && !input.intent) prompts.push({ case_id: input.req.case_id, visit_id: input.req.visit_id, event: input.req.event,
        run_id: input.req.run_id, session_id: input.req.session_id,
        actions: input.req.conversation_history.filter(t => t.role === 'action').map(t => t.text),
        language: input.req.language, matrix: input.req.run_id === 'btc-sign-matrix', fair: input.req.run_id.startsWith('btc-fair-'),
        matching_prompt: ['speech', 'temper'].every(row => {
          const signs = input.caseData.signs[row];
          return [...signs.normal, ...signs.broken].every(s => (input.currentTurn.earned_cues || '').includes(s.model) === (s.id === input.req.signs[row]));
        }) && input.system.includes(input.req.language === 'zh' ? 'Reply in Simplified Chinese' : 'Reply in English.'),
        history_turns: input.req.conversation_history.length,
        doctor_turns: input.req.conversation_history.filter(t => t.role === 'doctor').map(t => t.text),
        signs: input.req.signs, tonight: Boolean(input.currentTurn.earned_cues),
        characters: (input.system + '\n' + input.user).length });
      return mock.generate(input, signal);
    }};
    const server = await startServer({ provider, port: 0, limits, log: entry => requests.push({ scenario: name, ...entry }) });
    servers.push({ name, ...server });
  }
  // A GET-only fixture for SETTINGS, including valid-but-incompatible and unresponsive services.
  const healthFixture = http.createServer((req, res) => {
    const mode = req.url.split('/')[1];
    const roster = Object.values(cases).map(({ id, version }) => ({ id, version }));
    if (mode === 'missing') roster.pop();
    if (mode === 'duplicate') roster[0] = roster[1];
    if (mode === 'outdated') roster[0].version++;
    const answer = () => {
      res.writeHead(200, { 'content-type': 'application/json' });
      res.end(JSON.stringify({ ok: true, protocol: mode === 'protocol' ? '3' : '4', cases: roster,
        provider: 'mock', disabled: mode === 'disabled', speech_to_text: false }));
    };
    if (mode === 'late') setTimeout(answer, 2400);
    else if (mode === 'delayed') setTimeout(answer, 150);
    else answer();
  });
  await new Promise(resolve => healthFixture.listen(0, '127.0.0.1', resolve));
  servers.push({ name: 'health', url: 'http://127.0.0.1:' + healthFixture.address().port,
    close: () => new Promise(resolve => { healthFixture.close(resolve); healthFixture.closeAllConnections(); }) });
  const args = ['--headless', '--audio-driver', 'Dummy', '--path', path.join(project, 'game'), '--script', 'res://tests/run_proxy_integration.gd', '--', ...servers.map(s => `--${s.name}=${s.url}`)];
  const status = await new Promise((resolve, reject) => {
    const child = spawn(godot, args, { cwd: project, windowsHide: true, stdio: ['ignore', 'pipe', 'pipe'] });
    const watchdog = setTimeout(() => { child.kill(); reject(new Error('Integration run exceeded 200 seconds.')); }, 200000);
    child.stdout.on('data', data => { stdout += data; process.stdout.write(data); });
    child.stderr.on('data', data => { stderr += data; process.stderr.write(data); });
    child.on('error', reject);
    child.on('close', code => { clearTimeout(watchdog); resolve(code); });
  });
  fs.writeFileSync(path.join(output, 'godot-proxy-integration.log'), stdout + stderr);
  fs.writeFileSync(path.join(output, 'proxy-integration-requests.json'), JSON.stringify(requests, null, 2) + '\n');
  // What actually crossed the wire in the scene test: every typed line of a visit must be in
  // the requests that follow it, and a new patient must start from that patient's opening only.
  const wire = [];
  const typed = prompts.filter(p => !p.fair && p.run_id !== 'btc-visit-record' && p.event.type === 'say');
  const visitRecord = prompts.find(p => p.run_id === 'btc-visit-record' && p.event.type === 'say');
  wire.push(['dialogue carries one visit-scoped session id independently of the run', prompts.every(p => p.session_id === p.visit_id && p.run_id !== p.visit_id)]);
  wire.push(['a follow-up remembers both gauge openings, one completion and actual pressure in order',
    visitRecord?.actions.filter(a => a === 'open:grip' || a === 'done:grip' || a === 'press:1').join(',') === 'open:grip,open:grip,done:grip,press:1']);
  const byVisit = new Map();
  for (const p of typed) byVisit.set(p.visit_id, [...(byVisit.get(p.visit_id) || []), p]);
  const visits = [...byVisit.values()];
  wire.push(['three patients were spoken to in typed or spoken lines', visits.length === 3]);
  wire.push(['each request reveals only the earned sign sentences', prompts.length > 0 && prompts.every(p =>
    p.matching_prompt && p.tonight === (Object.keys(p.signs).length > 0))]);
  for (const turns of visits) {
    let carried = true;
    for (let i = 1; i < turns.length; i += 1) {
      if (!turns[i].doctor_turns.includes(turns[i - 1].event.text)) carried = false;
      if (turns[i].history_turns <= turns[i - 1].history_turns) carried = false;
    }
    wire.push([`visit ${turns[0].case_id}: each typed line reaches the next request (${turns.length} typed lines)`, carried]);
  }
  for (let k = 1; k < visits.length; k += 1) {
    const earlier = visits.slice(0, k).flat().map(p => p.event.text);
    const later = visits[k];
    wire.push([`patient ${k + 1} never receives an earlier patient's conversation`,
      later.every(p => !p.doctor_turns.some(t => earlier.includes(t)))]);
    wire.push([`patient ${k + 1} starts from its own opening lines only`, later[0].history_turns <= 4 && later[0].doctor_turns.length === 0]);
  }
  for (const [language, words] of [['en','Say it clearly.'], ['zh','说清楚。']]) {
    const fair = prompts.filter(p => p.fair && p.language === language);
    wire.push([language + ' small talk has no sign sentences', fair.some(p => p.event.type === 'say' && !p.tonight)]);
    wire.push([language + ' typed pressure reaches the model once with earned signs', fair.filter(p => p.event.type === 'press' &&
      p.event.text === words && p.signs.temper && p.signs.speech && p.matching_prompt).length === 1]);
  }
  const matrix = prompts.filter(p => p.matrix);
  for (const c of Object.values(cases)) {
    for (const lang of ['en', 'zh']) {
      for (const speech of ['normal', 'broken']) for (const temper of ['normal', 'broken']) {
        const matches = matrix.filter(p => p.case_id === c.id && p.language === lang &&
          p.signs.speech === c.signs.speech[speech][0].id && p.signs.temper === c.signs.temper[temper][0].id);
        wire.push([['signs', c.id, lang, speech, temper].join('/'), matches.length === 1 && matches[0].matching_prompt]);
      }
    }
  }
  // Push-to-talk on the wire. The scene prints how many clips it sent; every one of them, and
  // nothing else, must have reached a proxy. Dialogue requests must carry no audio.
  const clips = requests.filter(r => r.route === 'transcribe');
  const scene = /VOICE_SCENE session=(\S+) clips_sent=(\d+)/.exec(stdout);
  const sceneClips = scene ? clips.filter(r => r.run_id === scene[1]) : [];
  const late = sceneClips.filter(r => r.scenario === 'stt_slow');
  const numbersOnly = ['scenario', 't', 'request_id', 'route', 'provider', 'model', 'status', 'code', 'latency_ms', 'run_id', 'session_id', 'visit_id',
    'language', 'audio_seconds', 'audio_bytes', 'input_tokens', 'output_tokens', 'transcript_chars'];
  wire.push(['the scene reported the clips it sent', Boolean(scene) && Number(scene[2]) > 0]);
  wire.push([`every clip the scene sent reached a proxy, and a tap, silence or a dead microphone sent nothing (${sceneClips.length} clips)`,
    Boolean(scene) && sceneClips.length === Number(scene[2])]);
  wire.push(['the two clips the game stopped waiting for were still answered: the game ignored them, the service did not fail',
    late.length === 2 && late.every(r => r.status === 200)]);
  wire.push(['the longest clip crossed the wire whole', sceneClips.some(r => r.audio_seconds >= 9.99 && r.status === 200)]);
  wire.push(['the proxy logged speech as numbers and codes only', clips.length > 0 && clips.every(r => Object.keys(r).every(k => numbersOnly.includes(k)))]);
  wire.push(['a spoken line reaches the patient model as ordinary doctor text', typed.some(p => p.event.text.startsWith('This is a mock transcript.'))]);
  wire.push(['no audio rode along with a dialogue request', requests.filter(r => r.route !== 'transcribe').every(r => !('audio_bytes' in r))]);
  let wireFailed = 0;
  for (const [label, ok] of wire) {
    if (!ok) { wireFailed += 1; console.log('FAIL (wire): ' + label); }
  }
  console.log(`WIRE: ${wire.length - wireFailed} passed, ${wireFailed} failed`);
  fs.writeFileSync(path.join(output, 'wire-checks.json'), JSON.stringify(wire.map(([label, ok]) => ({ label, ok })), null, 2) + '\n');
  const sizes = prompts.map(p => p.characters);
  const summary = { label: 'Measured characters on current real Godot-to-mock requests. Tokens and live-model performance are unmeasured.', live_model_calls: 0, live_speech_calls: 0, mock_requests: prompts.length, mock_speech_requests: clips.length, min_characters: Math.min(...sizes), max_characters: Math.max(...sizes), mean_characters: sizes.reduce((a,b)=>a+b,0)/sizes.length,
    prompts: prompts.map(p => ({ case_id: p.case_id, visit_id: p.visit_id, language: p.language,
      event: p.event.type, signs: p.signs, history_turns: p.history_turns, doctor_turns: p.doctor_turns.length, characters: p.characters })) };
  fs.writeFileSync(path.join(output, 'prompt-measurements.json'), JSON.stringify(summary, null, 2) + '\n');
  console.log(JSON.stringify({ mock_requests: summary.mock_requests, mock_speech_requests: summary.mock_speech_requests, min_characters: summary.min_characters, max_characters: summary.max_characters, mean_characters: summary.mean_characters }));
  process.exitCode = status === 0 && wireFailed === 0 && /RESULT: \d+ passed, 0 failed/.test(stdout) ? 0 : 1;
} finally {
  await Promise.all(servers.map(server => server.close()));
}
