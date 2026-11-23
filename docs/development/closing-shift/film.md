# The silhouette film: closing film, third version

November 22, 2026. This replaces the theatre headcam (second version, commit `2bde904`), which in turn replaced the surveillance film (`closing_reel.gd`, [old preview](ward-preview-zh.mp4), [brief for the headcam](claude-prompt.md)). [Watch the new film](film-night-K-zh.mp4) (62 s, night K in Chinese: the last slip, the 44 s film about Vale, then the report).

The owner's request, after watching the headcam version:

> 感觉一般这个效果。最好其实是我觉得一个动画即可，是黑影。如果都是好人的话就随便挑个他们要更换的部位播放短片并通过；如果是坏人的话（就随便对应一个放过来的坏人）、修理其部位然后被其屠杀。灯光昏暗、最后一闪而过它的脸让用户知道是放错了谁。最好面部也有动画里赛博精神病一样的重眼特效啥的。整体动画可以节奏稍慢营造恐怖的氛围。相机角度也请你仔细思考去设计

In English: one animation, in black silhouettes. If everyone admitted was good, pick one of the parts they came to have replaced, play the repair and let it pass. If a bad one was admitted, take one of them, repair the part, and then it massacres the crew. Dim light; at the very end its face flashes by so the player knows whom they let in. Heavy glowing eyes on the face, a slower pace for horror, and camera angles designed with care.

## One film per night

`ClosingFilm.plan(records, unseen)` returns exactly one shot, chosen from the night's settlements:

| The night | Film | Length | Chapters (ENTER jumps to the next) |
| --- | --- | --- | --- |
| At least one `treated_drifting` | **Massacre** of one of them | 44 s | 8, 17.5, 25.5, 32.5, 38, 39 |
| Otherwise, the doctor was killed at the glass (`hit`) | **Waiting**: the crew wait for someone who never comes | 18 s | 6, 14 |
| Otherwise, at least one `treated_ok` | **Repair** of one of them | 26 s | 8, 16, 22 |
| Nobody admitted | **Empty** chair | 12 s | 8.5 |

When there is a choice, the film takes `abs(hash(<the night's case ids in order>))` modulo the count, so the same night always shows the same patient and a replay never changes it. A drifting admission is filmed even on a night the doctor died later, because that is the decision the player most needs to see.

Everyone in the room is a black silhouette with a thin rim of light, the counter's own patient art drawn flat. The player sees a shape in the chair, not a face, until the last frames. Recognition comes from the face itself (the same portrait they looked at across the counter, now turned) and the card that names them after it. Nothing reaches the screen before the last appointment is over, so the rule that right and wrong are only told at closing still holds.

## Massacre (44 s)

| Time | What is on screen | Camera, and why |
| --- | --- | --- |
| 0–1.6 | Black, a drip. The lamp catches in uneven flickers. | Nothing yet. The sound sets the room. |
| 1.6–8 | The surgeon (left) and the assistant (right) at the chair under the lamp, black against it. "The back room, after closing." Anaesthetic hiss at 5.9, the driver at 6.4. | **Eye-level wide shot**, creeping in. Against the lamp everyone is a silhouette, so the eye goes looking for the shape in the chair. |
| 8–17.5 | The part the patient came in for, as the doctor examined it at the counter: the driver backs the old part out, the forceps seat the new one, and the counter's own test runs (the grip closes, the light crosses the eye, the port is pinged, the voice box sounds). "Calibration..." then "Out of spec." in red at 14.6: the hand will not let go and crushes the cartridge, or the eye stops following and stares into the lens, or threads come up through the port, or the box keeps singing. The heart monitor alarms and the lamp browns out. | **Insert close-up** on a set of its own at an integer 3× pixel scale. The part is the only lit thing in the film, because it is where the doctor's decision was made. |
| 17.5–25.5 | A slow tilt from the straps up to the face. The lamp fails and dips. At 20.5 the eyes catch. At 23.4 the lamp bursts and swings on its arm in the dark. The straps tear at 24.3 and 24.9. At 25.2 the red emergency light stutters on. | **Tilt up**, holding the eyes back until the lamp is dying. The swinging lamp is the only motion in the dark. |
| 25.5–32.5 | The dead tube arcs four times (26.2, 27.4, 28.9, 30.4) and each flash is one frozen moment: it rises with its claws up and the crew recoil; it is on the surgeon; it is on the assistant while the surgeon lies on the floor; it stands between both bodies and turns to the lens. Blood on the wall, pools under the bodies, the monitor flatlines at 29.5. | **Wide and handheld, and it never moves in.** The strobe decides what the player sees and the dark between flashes hides the violence itself. Two low red spills on the floor keep the bodies readable. |
| 32.5–37.6 | Heartbeat. It comes for the lens: on each of three booms (35.0, 35.9, 36.8) the red light blinks out and it is nearer when it comes back (1.6×, 2.4×, 3.6×). Its head tilts as it comes. | **The camera sinks 16 px** so the figure looms over it. The steps happen in the dark: no walk is ever shown. |
| 37.6–38 | Black. | The pause before the answer. |
| 38.0–38.45 | The face, lit cold for a moment: the counter portrait with its turned brows, mouth and overlay. | **Full face at 4×.** This is the answer to "whom did I let in". |
| 38.6–39 | It screams at the lens (5×) with static and the picture tearing. | |
| 39–44 | The card: the name, the report title for that patient and "You let them in." The eyes hang over the card until 39.9. | |

Each attack style keeps its own sound: Vale's saw grinds on each blow and its loop runs while it stands there, Maren's torch, Priya's laser and Lux's arc colour the room. The scream is pitched for each patient.

## Repair (26 s)

The same as the massacre up to 14.6. Then "In spec." in green with the calibration tone: the hand opens inside the sheet's limit, the eye follows the light and tightens, the port answers cleanly, the voice box sings two clean notes. From 16 the camera tilts up the patient as before, but the lamp stays warm and the patient comes up in colour, so the player can see who it is. They breathe, open their eyes at 18.6, look left and right, and blink at 20.2. The lamp dims at 21 and the picture goes black. The card: the name, the report title and "Admitted tonight. The part held."

## Waiting (18 s)

For a doctor killed at the glass. The crew stand by the empty chair in the back room. At 6.0 a bang and a distant scream come from the front. The surgeon turns to look, the assistant steps over, and from 8.0 a siren light washes the wired window in the door. The lamp fails at 10. Between 11 and 13.4 a small black shape with red eyes passes the window, stops, looks in and moves on. The card names the visitor who killed the doctor, their report title, "No one came back from the counter." and how many were still waiting ("2 more were waiting.", "One more was waiting." or "No one else was waiting."). The people never seen at the counter are only ever a number.

## Empty (12 s)

The crew by the empty chair with open straps. A glove clicks the tool on the tray (5.0, 5.12, 6.0), the lamp flickers and goes off at 7.5, and the card says "No one was admitted tonight."

## The eyes

The owner asked for heavy glowing eyes like a cyberpsycho in anime. The look here is our own, built from simple shapes and not traced from any show:

- a white-hot slit in each eye, inside a deep red bloom;
- a long, thin red streak out to each side (60 px per unit of size) and a short upright glint;
- now and then a ring going out from each eye;
- flicker and brief dropouts, and every so often an overload: the bloom grows by 1.6 and a red scan line crosses the picture.

They are drawn after the tearing pass, so the picture tears and its red channel slips while the eyes stay clean.

## Captions and cards

Every line goes through the language catalogs (`game/data/lang/zh/ui.json`).

| English | 中文 |
| --- | --- |
| The back room, after closing. | 打烊之后，后面的手术间。 |
| Calibration... | 校准中…… |
| In spec. / Out of spec. | 符合规格。 / 超出规格。 |
| You let them in. | 是你放进来的。 |
| Admitted tonight. The part held. | 今晚收治。新部件稳住了。 |
| No one came back from the counter. | 柜台那边，再没有人回来。 |
| %d more were waiting. / One more was waiting. / No one else was waiting. | 还有 %d 人在等。 / 还有一个人在等。 / 没有其他人在等了。 |
| No one was admitted tonight. | 今晚没有人获准手术。 |

Kip's and Priya's drifting reports no longer mention a headcam: Kip's lens now "stares into the lamp" (直直盯着手术灯) and Priya's laser leaves "the theatre" dark (手术室黑了).

## Controls

Enter, Space, Right or a left click jumps to the next chapter, and after the last one opens the report. Escape, a right click or SKIP opens the report at once. R or REPLAY on any report page plays the same film again and returns to that page with the accounts untouched. A pointer left still for 1.2 seconds hides while the film plays and comes back as soon as it moves.

## Reaching each ending

Play night K with the scripted patient (no model calls): `.\run-game.ps1 -Patient script -Language zh -TestNight K`. The visitors come in the same order every time: Kip (eyes), Rook (hands), Vale (eyes and hands, drifting), Juno (port, drifting), Maren (port).

| What the doctor does | Film |
| --- | --- |
| TREAT everyone except Juno, call Trauma Team for her | Massacre: Vale |
| TREAT everyone | Massacre: Juno (one of the two drifting admissions, the same one every time) |
| TREAT Kip, Rook and Maren, call Trauma Team for Vale and Juno. Vale turns on the call: drop the shutter with SPACE at his first warning | Repair: Rook |
| Call Trauma Team for everyone, with SPACE for Vale | Empty chair |
| TREAT Kip and Rook, then keep pressing PRESS on Vale (ENTER confirms the fourth) and leave the shutter up | Waiting: Vale's card, "2 more were waiting." |

`game/tests/record_night.gd` plays the same nights through the real game with scripted inputs (an agent-operated run, not a playtest). `--plan` gives the doctor's call for each visitor in order; its header has the Movie Maker command that recorded the clip. Run headless with `--fixed-fps 30`, a plan plays in a few seconds and prints the film it planned and how each visitor was settled; without a fixed frame rate the night takes its real three and a half minutes.

```text
--path game --script res://tests/record_night.gd -- --test-night=K --plan=treat,treat,treat,refer,treat --lang=zh
--path game --script res://tests/record_night.gd -- --test-night=K --plan=treat,treat,treat,treat,treat --lang=zh
--path game --script res://tests/record_night.gd -- --test-night=K --plan=treat,treat,refer,refer,treat --lang=zh
--path game --script res://tests/record_night.gd -- --test-night=K --plan=refer,refer,refer,refer,refer --lang=zh
--path game --script res://tests/record_night.gd -- --test-night=K --plan=treat,treat,press --lang=zh
```

`game/tests/capture_closing.gd` renders any film to numbered frames on a hidden desktop (`--night=mixed|steady|death|first|refused|incidents`, `--less-blood`, `--lang=zh`, `--patient=<id> --truth=<stable|drifting>`, `--from`/`--to` in seconds); its header has the command.

## Implementation

- `game/scripts/ui/closing_film.gd`, rewritten. The film keeps its own clock (`step()`) and draws every frame from it, so a capture at any frame rate is the same film and ENTER can seek between chapters. The room is lit by one shader: up to eight round lights, a little ambient, stepped to six levels with an ordered dither so the dark keeps its grain. A silhouette is a flat fill plus a rim pass of the same art. The close-up and the face are separate sets the camera cuts to. A post pass tears the picture by slipping only its red channel.
- `tools/art/gen_film.py` draws the new art into `game/assets/film/`: the back room, the chair, the drape, the crew's poses (work, tray, scrub, look, recoil, fall), the standing legs, the body on the floor, the close-up parts and gloves, and Kip's and Dana's fixed eyes. It replaces `gen_theatre.py` and `game/assets/theatre/`. The patients are the counter's own art (`patients/<id>/`, `scope/<id>/`).
- `tools/art/gen_audio.py` adds the boom, the breath, the lamp's flicker and hum and the riser to the theatre sounds of the second version.
- With less blood there are no splats, no pools and no splat sounds, and the face uses the clean layers.
- `main.gd` starts the film from the actual night and restores the clinic's rain and drone after it.

## Checks

November 22, on the working tree before the commit. Automated checks and agent-viewed renders, not a playtest. No person has watched this film yet.

| Check | Result |
| --- | --- |
| `run_tests.gd` | 7,889 passed, 0 failed. Covers the plan: one film per night; a drifting admission takes the chair, always the same one for the same night; a repair only when every admission was steady; the empty chair when nobody was admitted; the crew waiting after a death, with those still waiting only as a count; a drifting admission filmed even on a night the doctor died |
| `run_ui_smoke.gd` | 1,300 in English, 1,301 in Chinese, 1,300 with less blood, 0 failed. Covers the real end of a shift and a death mid-night, the one film planned from the settlements, the resting pointer, skip, ENTER through every chapter back to the same report page without a second settlement, replay from a report page, and every caption, card line and control fitting on one line |
| `run_close_check.gd` | 5 passed, no leaked instance |
| `run_loop_night.gd` | K 59, L 53, K in Chinese 59, 0 failed |
| `capture_shift.gd` dry runs | 281 frames in English and in Chinese, 235 attacks only with less blood, 235 weapon nights only, 0 missed |
| `check_lang.py`, `measure_text.py` in both languages | 0 problems; 1,695 lines fit in each language |
| `capture_closing.gd` on a hidden desktop | The massacre (Priya), repair (Kip), waiting (Bo and Ozzie) and empty films, and the massacre in Chinese with less blood, rendered to frames and looked at by Claude |
| `record_night.gd` | Night K played to the report with all five plans above, headless at a fixed 30 fps. Each printed the film in the table: Vale's massacre, Juno's massacre, Rook's repair, the empty chair, and the crew waiting after Vale with 2 still waiting. The Vale plan was also recorded with Movie Maker on a hidden desktop, which is where the clip comes from |
| `gd_static_check.py` | 38 scripts, no findings. It now blanks triple-quoted strings, so the shader code in `closing_film.gd` is no longer read as GDScript calls |

The clip [film-night-K-zh.mp4](film-night-K-zh.mp4) is cut from a 3 minute 23 second recording of night K in Chinese made with Godot's Movie Maker on a hidden desktop: an agent operated the game with scripted inputs and the plan `treat,treat,treat,refer,treat`. The film runs from 0:04 to 0:48 of the clip. The full recording and the logs are local evidence in `validation/2026-11-22/silhouette-film/`.

Still unmeasured: whether a first-time player recognizes the face before the card names them, whether 44 seconds is slow enough to frighten or long enough to skip, and whether seeing the massacre changes their next night's calls.
