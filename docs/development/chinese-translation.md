# The Chinese translation

Written November 18, 2026, by Claude (Opus 5.5), with the translation itself. On that day the
student asked for a language option on the title screen, Chinese first, with everything that
should be translated translated, and added: "if one side is changed, the other must be changed
too". **The translation is an assistant proposal. No person has read it in the data or in play,
and nobody has played the game in Chinese.** What is below says what was chosen and how the two
languages are kept in step; none of it has been reviewed.

## What the student decided

- A language option on the title card, Chinese first; a change to one language is a change to
  the other, in the same commit (November 18; `AGENTS.md`, Languages).
- People's names and the contacts' code names stay English (Kip, Adrian Vale, SPARROW);
  companies, gangs, organizations and everything else are translated.
- The Chinese title: "think of a more reasonable and interesting one". The assistant chose
  先别下刀 ("don't cut yet": the doctor's job is to stop a cut that should not happen), set over
  a small BEFORE THE CUT on the sign and used for the window's title.
- Yes to downloading Fusion Pixel Font for the Chinese glyphs.

What else stays English is the assistant's choice: the binder's model names (KITE, IRIS, TALON,
LOADER, DEFT, REFLEX, SEAM, VX-9), key names (ENTER, ESC, TAB, SPACE and the letters in
brackets), AI and REC. The descriptive model words are translated: NATURAL 原生, STREET 街货,
WORK 工用, MIL-SPEC 军规, MIXED 混装.

## Glossary

Use each term the same way everywhere. To change one, change it here and in every catalog line
that uses it, in the same commit.

| English | Chinese | Note |
| --- | --- | --- |
| implant; chrome (slang) | 义体 | an eye implant is 义眼: "Implants in both eyes." 双眼都是义眼。 Chrome is slang in English (Juno's lines); Chinese has 义体 for both |
| steady / drifting | 稳定 / 失控 | the card THE DRIFT is 失控 too |
| dark threads | 黑色纹路 | the drift sign of dark lines spreading out from a port. Never 黑丝, which reads as black stockings |
| Trauma Team | 创伤小组 | on the imprint, 创伤 over 小组 |
| the Lanterns | 灯笼帮 | |
| Kessler; Kessler Security | 凯斯勒; 凯斯勒安保 | |
| Harrow Credit | 哈罗信贷 | |
| doctor | 医生 | |
| the line (the lender's) | 红线 | |
| BEFORE THE CUT; THE CUT | 先别下刀; 下刀 | THE CUT is the title of a night that ended under the line |
| FIRED; THE DEBT | 被开除; 债务 | opening card titles |
| shutter | 卷闸 | the plate's SHUT is 落闸; the TALON eye's shutter is a camera's, 快门 (快门闭合) |
| GLASS | 玻璃 | |
| CALM, calm-patch | 镇静贴 | |
| ASK; PRESS; SAY | 问; 施压; 说 | |
| TREAT; VOID | 治疗; 作废 | the imprints on the intake card |
| hall camera; buzz them in | 走廊监控; 放人进来 | |
| CLOSED; EXIT | 停诊; 出口 | the shutter's stencil, the light over the hall door |
| PATIENCE; LEAVING | 耐心; 要走了 | |
| penlight (LIGHT) | 笔灯 | |
| grip bar; GRIP | 握力棒; 握力 | |
| port check; PORT | 接口检查; 接口 | |
| tightens; no pupil; follows | 收缩; 无瞳孔; 跟随 | the penlight readouts |
| LIMIT 1.5s | 上限 1.5秒 | |
| reference sheet; NORMAL REFERENCE SHEET | 参照表; 标准参照表 | the sheet's painted header NORMAL is 参照表 |
| spec binder | 规格手册 | |
| intake card; INTAKE RECORD; INTAKE SLIP | 接诊卡; 接诊记录; 接诊单 | |
| counter guide | 柜台指南 | |
| EYES; HANDS; PORT; SPEECH; TEMPER | 眼睛; 双手; 接口; 言语; 脾气 | the rows of the sheet and the card |
| NORMAL; BROKEN LINE | 正常; 异常 | a finding's verdict |
| PATIENT SAID; you did not check | 病人说; 你没有检查 | |
| CROSSED; house rule | 打叉; 店规 | |
| contact; TONIGHT'S CONTACTS; CONTACT LIST | 接头人; 今晚的接头人; 接头人名单 | |
| alias; clue; code | 代号; 线索; 暗号 | |
| package; drop | 货; 交货 | |
| till; meter | 钱箱; 计费表 | |
| fee | 诊费 | |
| credits | 信用点 | 点 alone where room is short (`%dcr` is %d点) |
| NEXT; SKIP ALL | 下一条; 全部跳过 | the training |
| AT THE COUNTER; At the counter | 柜台实收 | the slip, and the report's first money row: what came in during the visit |
| At closing | 收工结算 | the report's second money row: bounties, bills and the reports on the work |
| TREATED; HANDED OVER; SHUTTER HELD; SHUTTER DOWN; WALKED OUT; OUT OF PATIENCE | 已治疗; 已移交; 卷闸守住了; 卷闸落下; 转身走了; 耐心耗尽 | the slip's title (`rules.json` `counter`): what was done, never whether it was right |
| FALSE CALL; TAKEN IN | 错误呼叫; 移交收治 | a Trauma Team call on the report page |
| LIGHTS OUT | 熄灯 | the title of a night that ended with the doctor killed |
| never came in | 没等到接诊 | on that report, the visitors still in the hall |

## The patients' voices

The briefs the model reads stay English, and the proxy tells the model to answer in Chinese
(below). The offline patient's lines are translated in each case catalog, in the patient's own
voice:

- **Kip Marlow**, 22, a courier in a hurry: short, casual, apologetic (行啊。好吧。不过快点。).
- **Rook Dunmore**, 41, a dock loader: blunt and clipped (行。赶紧的。).
- **Adrian Vale**, 38, Kessler security: formal and cold, the only patient who says 您
  (如您所愿。既然您坚持。).
- **Juno Reyes**, 27, a street singer: warm and cheeky; her voice box skips, written as a
  repeated syllable with a hyphen, as in the English (付-付过钱的, 总-总算, 杂-杂音).
- **Maren Holt**, 54, a night-shift welder: gentle and apologetic; she says 你, and her "dear"
  is 孩子 (谢谢你，孩子。).

## How it works

- **Catalogs.** `game/data/lang/zh/` has one catalog for each data file with words the player
  sees (`cases/*.json`, `contacts.json`, `intro.json`, `parts.json`, `rules.json`,
  `sheet.json`), `ui.json` for the words in the scripts, and `topics.json`: 722 lines in all on
  November 18. A catalog has a `note`, a `keep` list (Latin words a translation keeps as they
  are: the patient's name, the model names, the key names) and `strings`, which map the exact
  English to its Chinese. Case catalogs and `topics.json` also have `topics` (below).
- **Translating where it is drawn.** `game/scripts/core/lang.gd` loads the catalogs for the
  player's language. `Lang.t(s)` gives the line for exactly this English, or the English itself
  when there is none; `Lang.tf(fmt, values)` translates a `%`-format line and then fills it, so
  a translation keeps the English line's `%`-codes in the same order; `Lang.fill(s, values)`
  puts values into `{slots}` and translates a value that is words. The drawing calls in
  `gfx.gd` translate what they draw; their `*_raw` twins draw text as it is (code names, text
  already translated). The rules, the data and the event log stay English.
- **The choice.** English | 中文 in the title card's top-right corner, saved in
  `user://settings.cfg` and changed only on the title card. `-- --lang=zh` on the command line
  wins over the saved choice; tests and captures pin a language with `Lang.pin()`, and a pinned
  run never saves.
- **Pictures.** Words painted into pictures live in `tools/art/words.py`; each generator writes
  `<name>.png` and `<name>_zh.png` together, and `gfx.gd` `tex()` shows the twin in Chinese. The
  twins: the booth (HALL CAM), the hall (EXIT), the shutter (CLOSED), the four things on the
  pinboards (the sheet, the intake card, the counter guide, the contact list), the three
  imprints (TREAT, VOID, TRAUMA TEAM) and the logo.
- **Glyphs.** Fusion Pixel Font by TakWolf, which draws on Ark Pixel Font, BoutiqueBitmap9x9 and
  Galmuri, under the SIL Open Font License 1.1: release 2026.11.10, 10 px proportional,
  zh_hans. `tools/art/extract_zh_font.py` cut every ideograph it draws (10,687; it lacks 818 of
  GB 2312's rarer ones) and the CJK punctuation into `tools/art/fonts/`, beside the licences;
  `font_zh.py` reads that cut and `gen_font.py` builds `game/assets/fonts/zh.fnt`, with
  `zh_LICENSE.txt` beside it. It is the fallback of every Counter Sans font, so Latin letters
  and digits stay Counter Sans. A hanzi is 9 x 9 in Counter Sans's 11-row line box. Chinese has
  no bold here; the big font draws the same glyphs twice the size.
- **Line breaks.** A paragraph with Chinese in it breaks between any two hanzi (`_wrap_cjk`),
  never before a closing mark or after an opening one. It may still break inside a word
  (常 | 见).
- **The intake card.** Lines nine pixels apart touch in Chinese. Where a row has one or two
  notes they are set ten apart (`Gfx.tall_lines()`); three still go nine apart, a row higher.
  The card holds only the doctor's own notes; the findings are told at closing.
- **The report.** Each visit's page sets the findings beside the doctor's marks. A finding puts
  正常 or 异常 at the start of its text and 你没有检查 on the right (`screens.gd`
  `_finding_text()`).
- **Pace.** A Chinese line says as much in about half the characters, so typewriters type it at
  half the English rate per character and a page of it is held twice as long per character
  (`Lang.PER_CHAR`).
- **Typing.** While the typing line is open in Chinese the game turns the system's input method
  on, places its candidate list at the caret and shows the text being composed
  (`main.gd` `_sync_ime()`, `dialogue_box.gd` `input_compose()`); otherwise it is off, so the
  letter keys stay the game's keys. Nobody has tried this with a real input method.
- **The patient model.** The request names the language (`patient_agent.gd`). The proxy refuses
  a language it does not have before any call, tells the model "Reply in Simplified Chinese"
  with names and code names in Latin letters (`core.mjs` `LANGUAGES`), asks for 55 characters a
  line and 110 a reply (`rules.json` `agent.languages` and `core.mjs`
  `DEFAULT_LIMITS.languages`, which must agree), and passes the language on to transcription
  (`providers.mjs`). None of this has met a live model or Chinese speech.
- **The offline patient** listens for topic words. Chinese has no spaces, so a Chinese word
  counts wherever it appears in the typed line: `topics.json` has the words for every patient,
  each case catalog's `topics` those for that patient only (`scripted_brain.gd`).

## Keeping the two in step

Run these before a commit that touches any words (`AGENTS.md`, Languages):

- `python tools/check_lang.py` fails on a shown line with no translation, a translation whose
  English has changed (stale), one English line with two translations, a line and its
  translation with different `{slots}` or `%`-codes, a translation that is empty or the English
  again, a topic no case has, and a picture without its twin. `--todo zh` lists what still needs
  words, file by file. It cannot see words the scripts put together at run time; the scene test
  catches those.
- `python measure_text.py --lang zh` in `tools/art` measures every line as it reads in Chinese
  (and `python measure_text.py` in English).
- The scene test with ` -- --lang=zh` plays the nine shifts in Chinese and fails on any English
  that reached the screen untranslated (`run_ui_smoke.gd` `untranslated_words()`).

On November 18 all three passed: 0 problems, 616 lines that fit in each language, 954 scene
checks. That shows that every line has a translation and fits, not that the translation is good.

## Adding a language

1. Add its code to `Lang.CODES`, its own name to `Lang.NAMES` and its pace to `Lang.PER_CHAR`
   (`game/scripts/core/lang.gd`). The title card's switch lays out every code by itself
   (`screens.gd` `language_rects()`).
2. Write its catalogs in `game/data/lang/<code>/`, the same files as `zh/`;
   `python tools/check_lang.py --todo <code>` lists what is missing.
3. Add it to `LANGS` and give every key its words in `tools/art/words.py`, then run the
   generators for the twins (`<name>_<code>.png`).
4. If Counter Sans and the Chinese glyphs cannot draw it, add a fallback font as `font_zh.py`
   and `gen_font.py` do.
5. In the proxy, add it to `LANGUAGES` in `core.mjs` and `SPOKEN` in `providers.mjs`; if its
   characters say more or less than English, give it limits in `rules.json`
   `agent.languages` and `core.mjs` `DEFAULT_LIMITS.languages` together.
6. Give the offline patient its topic words (`topics.json` and each case catalog's `topics`).
7. Run the three checks above in the new language, and the rule tests.
