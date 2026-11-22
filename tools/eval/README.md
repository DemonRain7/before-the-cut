# Patient comparison and evaluation

The automated runs use the same Node HTTP service, validation, provider, model, prompt, output limits and timeouts as the game. The blinded E2 judge is available only on the evaluation process's loopback port with an ephemeral run token. A fresh paid authorization needs its own ledger. This run's ledger is bound to the November 21 authorization and survives restarts. Each paid call is reserved before it leaves the proxy. The judge uses the same model and counts against the same ceiling. Exact prompts, player input and audio are never logged. The 20 synthetic E2 answers chosen per language for the student are local only.

From the repository root, run the mock with `node tools/eval/run.mjs mock`. For the approved November 21 run, from `agent_proxy` run `node --env-file-if-exists=.dev.vars ../tools/eval/run.mjs live`. Repeating a completed run reads its ledger. On an interrupted process a surviving writer lock contains the PID. Verify the writer has exited before removing that single lock. An interrupted reserved call keeps its slot. The report includes unavailable answers, both routes' latency and a deliberately timed-out request. Official pricing is USD 0.10 per million standard input tokens and USD 0.50 per million output tokens. [OpenAI model and pricing](https://developers.openai.com/api/docs/models/gpt-6-luna)

## Protocol 5 slim evaluation

The five probes use the game's HTTP routes and fixed bilingual material across ten patients. The local ledger has separate quotas of 120 listed questions, 80 complaint questions, 80 social controls, 80 voiced complaints and 40 health conversations. It reserves the full prompt and maximum output before each OpenAI call, including failures. The five groups share USD 5 and 400 attempts. The local evidence contains categorical scores and token usage. No words, recordings or paid judge are saved. L4 checks body-part words and diagnostic claims in both languages. L5 screens for physical symptom claims near a tested body part and for temper symptoms. These are automated language screens. The measured figures and actual production decision are in [the redesign results](../../docs/development/play-loop-redesign/PROGRESS.md).

## E6 outside-player session

Recruit at least three people unfamiliar with the build. Each person plays night K and night L in **both** modes. Keep the language, seed, audio and controls fixed for that person. Odd-numbered participants play K scripted, L model, L scripted, K model. Even-numbered participants play K model, L scripted, L model, K scripted. Use anonymous participant numbers. This is a prepared comparison. No human results have been collected.

From the repository root in PowerShell, set `$night = 'K'` or `'L'` and `$language = 'en'` or `'zh'`. Run one command for the assigned condition. The live launcher starts the game's own local OpenAI proxy and names its provider-call cap before the operator enables that human session. Human-session calls need their own budget.

```powershell
.\run-game.ps1 -Patient script -Language $language -Seed 41307 -TestNight $night
.\run-game.ps1 -Patient live -Language $language -Seed 41307 -TestNight $night
```

Record one row per appointment. Join the anonymous session and visit IDs to its visit_end event. Copy complaints_told, tests_in_order and complaints_followed as row IDs. A followed complaint means the next new test targeted that row. Reopening an instrument adds no test. A correctly targeted choice still counts when its result is normal. The numerator is the number followed and the denominator is the number of distinct complaints heard. A visit with none has no opportunity. Count submitted text or dictation once and score the call at closing.

| Participant | Night | Mode | Visit | Complaints heard (IDs) | Test order (IDs) | Followed (IDs) | Submitted lines | Correct | Seconds |
| --- | --- | --- | --- | --- | --- | --- | ---: | ---: | ---: |
| | | | | | | | | | |

After each condition rate each statement from 1 (strongly disagree) to 5 (strongly agree). Use the same wording for everyone.

1. I felt I was examining a person with their own reason for visiting. / 我感觉自己在给一个有自己来意的人看诊。
2. What the patient said made me want to ask another question. / 病人的回答让我想接着问。
3. I could tell which evidence supported my final decision. / 我能说清哪些线索支持我的最终判断。

Compare complaint-follow rate, fraction of visits with free input, right-call rate, median visit duration and the three ratings, paired within participant and fixed night. Keep dropouts and calls that timed out in the counts. The game's hypothesis predicts more conversations, more follow-ups and a stronger sense of examining a person alongside comparable correctness.
