# The theatre headcam: closing film, second version

November 22, 2026. This replaces the surveillance film the owner rejected (`closing_reel.gd`, [old preview](ward-preview-zh.mp4)). [Owner's brief](claude-prompt.md) · [Watch the new film](film-night-K-zh.mp4) (56 s, night K in Chinese: the last slip, the film and the report)

## The idea in one line

The film is the operating surgeon's headcam. Every admitted patient sits in the theatre chair **exactly where and how large they stood at the counter**, says the line they left the counter with, and the camera pushes into **the same close-up the player examined** (the hand, the eye, the socket). Repaired and drifting patients look identical until the new part is calibrated. Then the film forks.

Why this answers "I let that person in, and this is what happened":

- Recognition comes from the face the player spent a whole appointment looking at, the same pose and scale, the same idle habits and the same voice blips. The caption names them a moment later.
- The consequence happens to the part the player was meant to test. A hand that locked during GRIP locks on the surgeon's driver. An optic that stayed wide under LIGHT stays wide under the theatre lamp. A port that showed threads grows them. Whatever the player skipped, the film shows them what that test would have caught.
- The crew is visible before anything happens. When a drifting patient wakes, the people in the room are the ones who get hurt, and the camera falls with the surgeon.

## Shot list

`ClosingFilm.plan(records, unseen)` builds the shots from settlements, in appointment order.

| Record | Shot | Length |
| --- | --- | --- |
| `treated_ok` | Theatre, the repair holds | 8.6–9.2 s |
| `treated_drifting` | Theatre, the patient wakes | 10.6–11.2 s |
| `referred_*`, `caught`, `locked_out`, `false_alarm`, `walkout`, `gave_up` | Counter recap | 3.4 s |
| `hit` | The doctor's death at the glass, then the hall camera | 5.2 s, then 4.4 s (3.0 s with nobody waiting) |
| no admissions and no death | Empty theatre | 5.0 s |

A theatre shot's length follows its calibration: a hand runs as long as that patient's grip limit on the sheet. Each theatre shot after a drifting one runs with the **relief crew**: orange gloves, a RELIEF CREW tag and the damage from earlier incidents still on the wall. People never seen at the counter are never named or drawn as themselves. After a death they appear only as plain silhouettes on the hall camera, then leave.

### Theatre (shared first half)

| Time | What happens |
| --- | --- |
| 0.0 | Dark theatre. The lamp flickers on over the patient, already seated and strapped. |
| 0.6–1.8 | They say their counter exit line ("About time.") with the mouth and voice blips. |
| 1.9 | Anaesthetic hiss. Their eyes close at 2.1. The heart rate on the headcam drops from 84 to 64. |
| 2.4–3.0 | The camera pushes in on the part, and the drape closes around that close-up. |
| 3.0–4.7 | The surgeon's gloves come in. The driver backs the old part out with sparks, forceps seat the new one, click. |
| 4.75 | Calibration: the theatre lamp sweeps the eye, the grip test closes the hand, a pulse runs down the cable, or the voice box sings a test note. |

### The repair holds

The reading goes green (IN SPEC): the hand releases inside the sheet's limit, the pupil tightens and follows, the signal comes back clean. The camera pulls back. The patient wakes and uses the part (a fist that opens, a blink and a look around, a note sung clean, a test cable that stays cool). A green stamp shows the report title, and they leave by the side door.

### The patient wakes

The calibration reading goes red (OUT OF SPEC) and keeps going. The hand stays shut on the driver past the limit, the glove trembles, then crunch. Or the pupil stays wide under the lamp and the iris rolls round to look into the lens. Or threads come up out of the socket, or the voice box keeps singing by itself. Heart rate 150, alarm. The camera tilts up to the face, and the eyes are already open. They tear the straps, their attack pose comes up, they lunge at the lens, impact, SIGNAL LOST.

Then the headcam lies on the floor, low and tilted, and rolls a little further before it settles: the empty chair with torn straps in the middle, the crew down along the floor, the back door swinging, the lamp still swaying. Blades and blows leave blood on the wall. The torch, the arc and the laser leave a ragged scorch, and so does every incident with less blood. A red stamp shows the report title over the chair.

### Counter recaps

The counter as the player saw it, the patient at the glass, and the one thing that ended the appointment: Trauma Team's lights take them (with a turn flicker if they were drifting), the shutter comes down (with dents if they turned), or they turn and leave. The stamp carries the report's own title for that visit. It is green for a drifting visitor taken by Trauma Team, caught by the shutter or locked out, red for a death and amber otherwise (a steady visitor sent away, anyone who walked out).

### Death and the hall

The counter in the attack pose, the third crack, the glass goes, the face fills the view, red, and the view tips over onto the floor while the heartbeat slows to nothing. Then the hall camera: the visitors nobody saw stand in line as plain silhouettes, the clinic sign goes dark and they leave one by one. "3 more were waiting." or "No one else was waiting."

### Empty theatre

The lamp comes on over an empty chair with open straps, the sealed parts are still on the tray, the monitor reads NO PATIENT, a glove taps the tray, the lamp goes off. "No one was admitted tonight."

## The written report agrees with the film

Every `drifting.treat` outcome now describes the theatre incident the film shows, in both languages. The slip at the counter only ever shows the shared counter title, so the new titles do not leak a diagnosis during play.

| Patient | Title | 中文 |
| --- | --- | --- |
| Rook | AWAKE ON THE TABLE | 手术台上醒了 |
| Kip | THE LENS STARED | 镜片直勾勾地盯着 |
| Juno | SHE SANG ON THE TABLE | 她在手术台上唱起来了 |
| Vale | THE RIG WOKE FIRST | 义体先醒了 |
| Maren | THE TORCH LIT | 焊枪点着了 |
| Bo | THE PISTON FIRED | PISTON 出拳了 |
| Dana | IT CAME UP RED | 亮起了红光 |
| Lux | SOMETHING CAME UP | 有东西上来了 |
| Ozzie | THE CHOP CLOSED | CHOP 合上了 |
| Priya | SCAN ONLINE | SCAN 上线 |

## Controls

Enter, Space, Right or a left click goes to the next shot. Escape, a right click or SKIP opens the report. R or REPLAY on any report page plays the same night again and returns to that page with the accounts untouched. A pointer left still for 1.2 seconds hides while the film plays, so it never sits on a patient's face, and comes back as soon as it moves.

## Reaching another ending

Play night K with the scripted patient (no model calls): `.\run-game.ps1 -Patient script -Language zh -TestNight K`. The visitors come in the same order every time: Kip (eyes), Rook (hands), Vale (eyes and hands, drifting), Juno (port, drifting), Maren (port).

| What the doctor does | What the film shows |
| --- | --- |
| TREAT everyone except Juno, call Trauma Team for her | Kip and Rook repaired; Vale's hand locks on the driver and he wakes (THE RIG WOKE FIRST); Juno taken at the counter; Maren repaired by the relief crew |
| TREAT Kip, Rook and Maren, call Trauma Team for Vale and Juno | Three repairs that hold and two counter recaps, all green. Vale turns on the call every time: drop the shutter with SPACE at his first warning |
| Call Trauma Team for everyone, and SPACE for Vale | Five counter recaps, then the empty chair |
| TREAT Kip and Rook, then keep pressing PRESS on Vale (ENTER confirms the fourth) and leave the shutter up | Kip's and Rook's repairs, the death at the glass, then the hall camera with the two who were still waiting |

The same nights play by script, at normal speed, with `game/tests/record_night.gd` (an agent-operated run with scripted inputs, not a playtest). `--plan` gives the doctor's call for each visitor in order: `treat`, `refer` (the shutter drops at the first warning) or `press` (push until the visit ends, never drop the shutter). Its header has the Movie Maker command that recorded the clip above.

```text
--path game --script res://tests/record_night.gd -- --test-night=K --plan=treat,treat,treat,refer,treat --lang=zh
--path game --script res://tests/record_night.gd -- --test-night=K --plan=refer,refer,refer,refer,refer --lang=zh
--path game --script res://tests/record_night.gd -- --test-night=K --plan=treat,treat,press --lang=zh
```

## Implementation

- `game/scripts/ui/closing_film.gd` replaces `closing_reel.gd`. It owns its own clock and steps the patient rig itself, so captures are deterministic. One `PatientRig` per theatre or counter shot, the existing close-up art from `scope/<id>/`, and its own `GoreLayer`. `patient_rig.gd` gained `release_hands`, so a repaired hand opens on camera.
- New art comes from `tools/art/gen_theatre.py` into `game/assets/theatre/` (the room, the lamp, the chair and straps, gloves and tools, the crew, the floor decals with the ragged scorch). New sounds (hiss, driver, seat, two calibration tones, ECG, flatline, static, strap, the voice note) are in `gen_audio.py`.
- Reduced blood removes splats and pools. The impact becomes a white flash and a cracked lens, the floor decal is the scorch, and the rig uses its clean layers.
- Captions and stamps carry the whole story with the sound off. Every word goes through the language catalogs; `lang/zh/ui.json` lost the old film's 44 lines and gained 30.
- `main.gd` starts the film from the actual night: the composed cases, the settlements in order and how many were still waiting.

## Checks

November 22, on the working tree before the commit. These are automated checks and renders, not a playtest. No person has played this film yet.

| Check | Result |
| --- | --- |
| `run_tests.gd` | 7,957 passed, 0 failed. Covers the shot plan: order, relief crew after a drifting admission, no theatre for refusals, the empty theatre only when nobody was admitted, the hall after a death, unseen visitors as a count only |
| `run_ui_smoke.gd` | 1,329 in English, 1,330 in Chinese, 1,329 with less blood, 0 failed. Covers the real end of a shift, a death mid-night, the film's plan and captions, the resting pointer, skip, replay from a report page with the accounts unchanged, and a following shift |
| `run_close_check.gd` | 5 passed, no leaked instance |
| `run_loop_night.gd` | K 59, L 53, K in Chinese 59, 0 failed |
| `capture_shift.gd` dry runs | 281 in English and in Chinese, 235 attacks only with less blood, 235 weapon nights only, 0 missed |
| `check_lang.py`, `measure_text.py` in both languages | 0 problems |
| `capture_closing.gd` on a hidden desktop | Chinese mixed, incidents, death and refused nights and the incidents with less blood, rendered to frames and looked at by Claude |
| `record_night.gd` | Night K played to the report with each of the three plans above |

`capture_shift.gd` needed two fixes that the rules 15 pressure draws made necessary, not the film: each staged push now gets a pressure seed whose draws end the visit on the push the scene expects (`pin_pressure`), and the death nights wait for the film before the report (`play_driver.gd` `wait_through_film`).

The clip [film-night-K-zh.mp4](film-night-K-zh.mp4) is cut from a 3 minute 19 second recording of night K in Chinese made with Godot's Movie Maker on a hidden desktop: an agent operated the game with scripted inputs and the plan `treat,treat,treat,refer,treat`. The full recording, the contact sheets and the logs are local evidence in `validation/2026-11-22/closing-film/`.

Still unmeasured: whether a first-time player recognizes the patient in the chair before the caption names them, and whether watching a wake-up changes their next night's calls.
