# Escalating pressure and the closing film

November 22, 2026. Godot rules 15, patient protocol 5. [Watch the closing film](film-night-K-zh.mp4) · [How the film works](film.md) · [Brief for the second version](claude-prompt.md) · [Next solo and co-op prototypes](next-game.md)

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

The night closes on one short film in the back room, built only from the night's settlements. Everyone in it is a silhouette against the theatre lamp. If the doctor admitted a drifting patient, the film is about one of them: the surgeon swaps the part in close-up, the counter's own test fails, the lamp bursts, and in the flashes of a dead tube the patient opens the crew's throats: the blood pumps out over the wall, the floor and the lens. Then it comes for the lens and slams a bloody palm on it, cracking the glass, its face shows for a few frames, and a card names it. If everyone admitted was steady, one of them is repaired, the part holds and they open their eyes under the lamp. A doctor killed at the glass ends on the crew waiting in the back for someone who never comes; the people still waiting are only a count. A night with nobody admitted ends on the empty chair. [Shots, camera and timings](film.md)

The massacre runs 44 seconds, the repair 26, the waiting 18 and the empty chair 12. Enter, Space, Right or a left click jumps to the next chapter. Escape, a right click or SKIP opens the report. R or REPLAY on any report page plays the same film again and returns to that page without settling anything twice. Less blood removes all of the blood and the wet sounds; the kills, the cut-off screams, the palm on the lens and its crack stay. Captions and the end card carry the story with the sound muted. Each `drifting.treat` report title names what happened in the theatre, and since November 23 the massacre card ends on that patient's own thanks breaking into a laugh (`quote`). Two earlier films were rejected and replaced: outdoor incidents on surveillance cameras (its [17-second preview](ward-preview-zh.mp4) stays as a record) and the surgeon's headcam, which showed every admission in turn.

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

The silhouette film passed 7,889 engine assertions, 1,300 English, 1,301 Chinese and 1,300 reduced-blood UI assertions, fixed nights K and L and the shift capture's dry runs. The bloodier massacre of November 23 passed the same suite with the same counts and no engine error, after a fix to how the pools are filled. Claude looked at its renders and at the nine sounds' waveforms and spectrograms; no person has watched or heard it yet. [Film checks](film.md#checks)

The actual desktop game connected over loopback to the game's OpenAI service for GPT-6 Luna. Two appointments, one English and one Chinese, each generated the first pressure reply, classified a free follow-up after the third push and generated that follow-up. All six provider requests returned HTTP 200. Each fourth push completed locally with the expected walkout. The four displayed model replies ranged from 25 to 107 characters. Visible body actions and character wording were also exercised offline and through proxy timeout. Of 7,858 input tokens, 4,026 were cached across three requests. This six-request sample measures this scenario only. The public live Worker stays disabled.

## Reproducing the film

`capture_closing.gd` renders a staged night's film straight from engine settlements, one PNG per frame, and writes `cues.json` with each sound cue and the frame it starts on. `--night` picks `mixed` or `incidents` (a massacre), `steady` (a repair), `refused` (the empty chair), `death` or `first` (the crew waiting). `--patient=<id> --truth=stable|drifting` films one patient's repair or massacre, and `--from`/`--to` keep a stretch, in seconds. Use an absolute path to an empty directory and the real renderer (`tools/run_hidden.py` on Windows); `--dry` lists the plan and cues headless.

```text
--audio-driver Dummy --resolution 640x360 --fixed-fps 60 --path game --script res://tests/capture_closing.gd -- --out=<absolute-directory> --night=mixed --lang=zh --fps=12
```

To see it at the real end of a night, play `.\run-game.ps1 -Patient script -Language zh -TestNight K` to the last slip. [Reaching each ending](film.md#reaching-each-ending) lists five ways through night K and the `record_night.gd` plans that play them by script.
