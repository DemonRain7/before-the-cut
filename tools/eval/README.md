# Patient comparison and evaluation

The automated runs use the same Node HTTP service, validation, provider, model, prompt, output limits and timeouts as the game. The blinded E2 judge is available only on the evaluation process's loopback port with an ephemeral run token. A fresh paid authorization needs its own ledger. This run's ledger is bound to the November 21 authorization and survives restarts. Each paid call is reserved before it leaves the proxy. The judge uses the same model and counts against the same ceiling. Exact prompts, player input and audio are never logged. The 20 synthetic E2 answers chosen per language for the student are local only.

From the repository root, run the mock with `node tools/eval/run.mjs mock`. For the approved November 21 run, from `agent_proxy` run `node --env-file-if-exists=.dev.vars ../tools/eval/run.mjs live`. Repeating a completed run reads its ledger. On an interrupted process a surviving writer lock contains the PID. Verify the writer has exited before removing that single lock. An interrupted reserved call keeps its slot. The report includes unavailable answers, both routes' latency and a deliberately timed-out request. Official pricing is USD 0.10 per million standard input tokens and USD 0.50 per million output tokens. [OpenAI model and pricing](https://developers.openai.com/api/docs/models/gpt-6-luna)

## E6 outside-player session

Recruit at least three people unfamiliar with the build. Each person plays night I and night J in **both** modes. Keep the language, seed, audio and controls fixed for that person. Odd-numbered participants play I scripted, J model, J scripted, I model. Even-numbered participants play I model, J scripted, J model, I scripted. Use anonymous participant numbers. This is a prepared comparison. No human results have been collected.

From the repository root in PowerShell, set `$night = 'I'` or `'J'` and `$language = 'en'` or `'zh'`. Run one command for the assigned condition. The live launcher starts the game's own local OpenAI proxy and names its provider-call cap before the operator enables that human session. Human-session calls need their own budget.

```powershell
.\run-game.ps1 -Patient script -Language $language -Seed 41307 -TestNight $night
.\run-game.ps1 -Patient live -Language $language -Seed 41307 -TestNight $night
```

Record one row per visit on paper or in a local copy. Mark a follow-up when the doctor speaks to the same subject after its paid ASK. Score correctness only after the closing report. Count a typed or transcribed submission once. End a visit at its recorded outcome. Keep the sheet free of quotes, names, clips and transcripts.

| Participant | Night | Mode | Visit | Submitted lines | Follow-ups after paid ASK | ASK pad uses | Right call (0/1) | Seconds |
| --- | --- | --- | --- | ---: | ---: | ---: | ---: | ---: |
| | | | | | | | | |

After each condition rate each statement from 1 (strongly disagree) to 5 (strongly agree). Use the same wording for everyone.

1. I felt I was examining a person with their own reason for visiting. / 我感觉自己在给一个有自己来意的人看诊。
2. What the patient said made me want to ask another question. / 病人的回答让我想接着问。
3. I could tell which evidence supported my final decision. / 我能说清哪些线索支持我的最终判断。

Compare the fraction of visits in which people talked, follow-ups per paid question, right-call rate, median visit duration and the three ratings, paired within participant and night. Keep dropouts and calls that timed out in the counts. The game's hypothesis predicts more conversations, more follow-ups and a stronger sense of examining a person alongside comparable correctness.
