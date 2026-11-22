# Escalating pressure and the closing film

November 22, 2026. Godot rules 15, patient protocol 5. [Watch the closing film](film-night-K-zh.mp4) · [How the film works](film.md) · [Owner's brief](claude-prompt.md) · [Next solo and co-op prototypes](next-game.md)

## What a push can do

Both columns are conditional on the appointment reaching that push. Godot draws the two outcomes independently from an appointment seed and its committed push count. The same real tell can precede an exit or appear while the person stays. A character's diagnosis determines what happens once the patience threshold fires.

| Committed push | Additional visible tell | Visit ends now | Cost and warning |
| --- | ---: | ---: | --- |
| First | 25% | 5% | One examination lamp if available. A surviving funded test also opens the formal TEMPER close-up. |
| Second | 45% | 20% | Free. A survivor can still talk, examine or decide. |
| Third | 65% | 50% | Free. A survivor gives their own final warning. |
| Fourth | 85% | 100% | BREAK asks for confirmation. Stepping back keeps the current visit. |

Every tell acts out that patient's selected TEMPER sign. Rook can strike the counter and shout in unison or hold his face still while his fist tightens. A broken TEMPER circuit can briefly distort the face, including on a steady visitor with wear. The visual cue goes on one TEMPER row. Repetition supplies no second broken row. Free text, reviewed dictation and rehearsing a confirmation leave both draws alone. A new appointment gets its own seed and visit history.

A steady visitor whose patience breaks leaves unpaid. A drifting visitor lunges and starts the existing shutter sequence. A clean or damaged-glass catch earns the existing fee and 50-credit pressure bonus. The funded first action spends its lamp even on an immediate end. A tell can surface with both lamps spent. The separate 30-second idle departure still applies at zero lamps.

The game commits the state and presents the body cue when the doctor acts. The first surviving funded challenge can use model dialogue. The later push, boundary and exit wording come from character assets. The model sees the character and earned signs. A slow request, optional dialogue, or replay of the final confirmation cannot redraw a result. The local proxy advertises the pressure-history limit. A client speaking to an older protocol 5 service preserves the actual pressure count, observable words and reactions and filters unsupported action ordinals from the wire copy.

## The film

The night closes on the operating surgeon's headcam, built only from the night's settlements, in appointment order. Each admitted patient sits in the theatre chair as they stood at the counter, says the line they left the counter with and goes under. The camera pushes into the close-up the doctor examined at the counter and the part is swapped. The calibration then shows the truth. A steady patient's reading settles and they use the new part. A drifting patient's does not: they wake on the table, put the crew down and leave the headcam on the floor, and later admissions get a relief crew. Visitors who were sent away get a short counter recap. A night with nobody admitted ends on the empty chair. A doctor killed at the glass ends the film on that patient, then the hall camera shows anyone still waiting as a silhouette. People never seen at the counter are never named. [Shots, timings and report titles](film.md)

A repair runs about nine seconds, a wake-up about eleven and a counter recap 3.4. Enter, Space, Right or a left click goes to the next shot. Escape, a right click or SKIP opens the report. R or REPLAY on any report page plays the same night again and returns to that page without settling anything twice. Less blood swaps blood for scorch and a white flash. Captions and stamps carry each incident with the sound muted, and each `drifting.treat` report title names the incident the film shows. The first film, with its outdoor incidents and surveillance cameras, was rejected and replaced; its [17-second preview](ward-preview-zh.mp4) stays as a record.

## Verification

Pressure sampling used 30,000 appointments across five positions in 6,000 seeded shifts. These are observed conditional frequencies.

| Push reached | Visits | Ended | Actual end rate | Showed a tell | Actual tell rate |
| --- | ---: | ---: | ---: | ---: | ---: |
| 1 | 30,000 | 1,512 | 5.04% | 7,426 | 24.75% |
| 2 | 28,488 | 5,693 | 19.98% | 12,679 | 44.51% |
| 3 | 22,795 | 11,416 | 50.08% | 14,637 | 64.21% |
| 4 | 11,379 | 11,379 | 100% | 9,611 | 84.46% |

A separate 25,000-night, 125,000-visit engine simulation followed the complaint-led routine and checked the intake file. Among 100,000 later visitors it made the correct call in 89.869% and ended 2.167% of appointments through pressure. The simulation assumes a successful shutter catch when it chooses to defend. The analytical desk-only comparisons in `analyze_loop.py` describe evidence selection under their original simplifying assumptions. Difficulty and appeal still need observation with outside players.

Commit `c36f883` passed 7,921 engine assertions, 1,307 English UI assertions, 1,308 Chinese UI assertions and 1,307 English reduced-blood UI assertions, fixed nights K and L, 399 local transport integration assertions, 102 wire checks, 66 proxy unit cases and 10 evaluation guard cases. The UI suite includes a first-push walkout, early attack and successful catch, a surviving empty-lamp tell, the fourth-push confirmation and cancellation, ordinary and fatal shifts, film order, camera controls and replay without a second settlement. Both language catalogs and text-fit runs passed. A separate renderer pass captured all ten characters under both admission outcomes. Its Chinese preview of the first film contains 209 rendered frames at 12 fps with a synchronized AAC track.

The film remake passed 7,957 engine assertions, 1,329 English, 1,330 Chinese and 1,329 reduced-blood UI assertions, fixed nights K and L and the shift capture's dry runs. [Film checks](film.md#checks)

The actual desktop game connected over loopback to the game's OpenAI service for GPT-6 Luna. Two appointments, one English and one Chinese, each generated the first pressure reply, classified a free follow-up after the third push and generated that follow-up. All six provider requests returned HTTP 200. Each fourth push completed locally with the expected walkout. The four displayed model replies ranged from 25 to 107 characters. Visible body actions and character wording were also exercised offline and through proxy timeout. Of 7,858 input tokens, 4,026 were cached across three requests. This six-request sample measures this scenario only. The public live Worker stays disabled.

## Reproducing the film

`capture_closing.gd` renders a staged night's film straight from engine settlements, one PNG per frame, and writes `cues.json` with each sound cue and the frame it starts on. `--night` picks `mixed`, `incidents`, `refused`, `death` or `first`, and `--shot=N` renders one shot. Use an absolute path to an empty directory and the real renderer (`tools/run_hidden.py` on Windows); `--dry` lists the shots and cues headless.

```text
--audio-driver Dummy --resolution 640x360 --fixed-fps 60 --path game --script res://tests/capture_closing.gd -- --out=<absolute-directory> --night=incidents --lang=zh --fps=12
```

To see it at the real end of a night, play `.\run-game.ps1 -Patient script -Language zh -TestNight K` to the last slip. [Reaching another ending](film.md#reaching-another-ending) lists four ways through night K and the `record_night.gd` plans that play them by script.
