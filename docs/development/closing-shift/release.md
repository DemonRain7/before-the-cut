# Escalating pressure and the closing cameras

November 22, 2026. Godot rules 15, patient protocol 5. [Watch the 17-second Chinese cut](ward-preview-zh.mp4) · [Hand the film to Claude](claude-prompt.md) · [Next solo and co-op prototypes](next-game.md)

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

Each settled visitor supplies the actual identity and outcome for one shot, in encounter order. The signed chart and theatre arm start an admission. A repaired implant works on camera. Nine outside incidents show the patient's own location and hardware. Priya's incident happens as her scanner powers up in the ward. The two attendants fall, their monitors stop, and any subsequent admissions use an overflow theatre with a relief crew. The case report carries the same ending.

Trauma Team collections, catches, shutter lockouts and departures use the corridor or counter. With zero admissions the film shows an unused chair. A doctor killed at the glass ends the footage on that patient's camera. People never seen at the counter stay out of the cast. The footage builds only from settlements. Appointment dialogue has already been released.

The film runs automatically for 4.8 seconds per admission and 2.9 seconds per corridor or empty-chair shot. Enter or left click goes to the next shot. Escape, right click or the visible skip control opens the report. R or the replay button on any report page starts the same shift's footage again and returns to that page. The blood setting selects the portrait layers. Captions and monitor changes carry the incident with the sound muted.

The sample stages four actual engine settlements to show the branches in one cut. Rook receives a successful repair, Priya's dangerous admission closes the ward, Lux receives treatment from relief staff, and Vale is caught at the counter. The preview is a recording of the Godot renderer with the in-game sound cues. Some secondary incidents use silhouettes, shared street scenery and a caption. Recognizability at a glance is the next film playtest.

## Verification

Pressure sampling used 30,000 appointments across five positions in 6,000 seeded shifts. These are observed conditional frequencies.

| Push reached | Visits | Ended | Actual end rate | Showed a tell | Actual tell rate |
| --- | ---: | ---: | ---: | ---: | ---: |
| 1 | 30,000 | 1,512 | 5.04% | 7,426 | 24.75% |
| 2 | 28,488 | 5,693 | 19.98% | 12,679 | 44.51% |
| 3 | 22,795 | 11,416 | 50.08% | 14,637 | 64.21% |
| 4 | 11,379 | 11,379 | 100% | 9,611 | 84.46% |

A separate 25,000-night, 125,000-visit engine simulation followed the complaint-led routine and checked the intake file. Among 100,000 later visitors it made the correct call in 89.869% and ended 2.167% of appointments through pressure. The simulation assumes a successful shutter catch when it chooses to defend. The analytical desk-only comparisons in `analyze_loop.py` describe evidence selection under their original simplifying assumptions. Difficulty and appeal still need observation with outside players.

The current build passed 7,921 engine assertions, 1,307 English UI assertions, 1,308 Chinese UI assertions and 1,307 English reduced-blood UI assertions, fixed nights K and L, 399 local transport integration assertions, 102 wire checks, 66 proxy unit cases and 10 evaluation guard cases. The UI suite includes a first-push walkout, early attack and successful catch, a surviving empty-lamp tell, the fourth-push confirmation and cancellation, ordinary and fatal shifts, film order, camera controls and replay without a second settlement. Both language catalogs and text-fit runs passed. A separate renderer pass captured all ten characters under both admission outcomes. The Chinese preview contains 209 rendered frames at 12 fps with a synchronized AAC track.

The actual desktop game connected over loopback to the game's OpenAI service for GPT-6 Luna. Two appointments, one English and one Chinese, each generated the first pressure reply, classified a free follow-up after the third push and generated that follow-up. All six provider requests returned HTTP 200. Each fourth push completed locally with the expected walkout. The four displayed model replies ranged from 25 to 107 characters. Visible body actions and character wording were also exercised offline and through proxy timeout. Of 7,858 input tokens, 4,026 were cached across three requests. This six-request sample measures this scenario only. The public live Worker stays disabled.

## Reproducing the cut

From the checkout, run the Godot executable with the following arguments. Use an absolute path to an empty capture directory. The script produces sequential PNGs and `cues.json` with the sound name and frame of each cue. The game plays the sound at 0.9 pitch and -9 dB.

```text
--audio-driver Dummy --resolution 640x360 --fixed-fps 60 --path game --script res://tests/capture_closing.gd -- --out=<absolute-directory> --lang=zh --less-blood
```

For an ordinary playable shift, run `.\run-game.ps1 -Language zh -TestNight K`. The camera film begins after the last receipt or a lethal counter attack. The same game loop works with `-Patient script`.
