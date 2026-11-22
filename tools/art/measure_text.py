"""Measure authored game text in the game's bitmap fonts.

Run from tools/art:  python measure_text.py              (English)
                     python measure_text.py --lang zh    (the same lines, as the player reads them in Chinese)
Prints every line that is wider than the space the interface gives it, needs more lines than
its box has, or uses a letter the font does not have.

In another language every line is first put into it the way the game does (scripts/core/lang.gd):
the catalog line for exactly that English, or, for words with numbers or names filled into them,
the catalog's template filled with the same values. It is then measured in Counter Sans with the
Chinese glyphs as its fallback (font_zh.py) and wrapped the way Gfx.wrap_raw wraps it. Lines no
catalog accounts for are measured in English and listed at the end; names and code names, which
stay English, are left out of that list.
"""
import glob
import json
import os
import re
import sys

import font_zh
from px import ROOT

DATA = os.path.join(ROOT, "game", "data")
UI = os.path.join(ROOT, "game", "scripts", "ui")
MAIN_GD = os.path.join(UI, "main.gd")
SCREENS_GD = os.path.join(UI, "screens.gd")
CLIPBOARD_GD = os.path.join(UI, "clipboard.gd")
INTRO_GD = os.path.join(UI, "intro.gd")
GUIDE_GD = os.path.join(UI, "guide.gd")
COACH_GD = os.path.join(UI, "coach.gd")
# "sheet" is the text column of a sheet row; "footer" is centred across the whole sheet.
# "slip_title" is what happened at the counter (rules.json "counter") in the big font across the
# result slip; wider than this and the slip falls back to the small font. "report_title" is a big
# title on the end-of-shift report, "report_line" one centred line of its text, "report_row" a
# label of its figures (the figure is right-aligned on the same row; the meter row has five lamps
# there), "report_tally" a line across the report. "visit_title" is how a visit ended, bold and
# centred on the visit's own page of the report.
# "hint" is the one dim line at the foot of the dialogue strip (dialogue_box.gd: TEXT_W); it does not wrap.
# "plate" is the bold line that takes the attack bar's place once the shutter is down
# (clinic_view.gd: SLOT, 207 px wide). "tally" is the bold count in the record's DECISION box
# (clipboard.gd: DECISION, 78 px wide). "screen" is one centred line across the whole screen
# (title card, opening cards). "lit_item" is one line of the lease picture's list.
LIMITS = {"note": 186, "look": 186, "sheet": 182, "footer": 220, "row": 176, "question": 180, "name": 120, "request": 140,
          "slip_title": 180, "report_title": 368, "visit_title": 368, "report_line": 352, "report_row": 286, "report_tally": 368, "hint": 376,
          "plate": 203, "tally": 74, "screen": 624}
SLIP_WIDTH = 180        # the text column of the result slip (main.gd: _draw_slip)
SLIP_GAP = 8            # least space between the call and the money on its last line (main.gd: SLIP_GAP)
REPORT_X0 = 136         # the report's text column (screens.gd: the panel's x + 16 ...
REPORT_X1 = 504         # ... to its right edge - 16)
REPORT_WIDTH = REPORT_X1 - REPORT_X0
REPORT_NAME_ROOM = 94   # a row of the totals: the name, from x0 + 16 to the title at x0 + 110
REPORT_VISIT_ROOM = 258 # a row of the totals: the title at x0 + 110, up to the figure column (x1)
SLIP_LINES = 5          # lines of outcome text the slip has room for (main.gd: _draw_slip)
REPORT_LINES = 3        # lines of title text the report has room for above the meter line and the tally
STRIP_WIDTH = 376       # the dialogue strip (dialogue_box.gd: TEXT_W)
STRIP_LINES = 2         # rows of speech on one page of it (dialogue_box.gd: PAGE_LINES)
SCREEN_H = 360
LINE = 10               # gfx.gd: LINE

LANG = "en"             # --lang <code>: every line is measured in that language (game/data/lang/<code>)
_CAT = {}               # English -> that language, from every catalog of it
_FILLED = []            # (pattern, slots, translation) for catalog lines with {slots} or %-codes
_KEEP = set()           # Latin words the catalogs keep as they are (names, code names, keys)
UNMATCHED = {}          # English no catalog line accounts for -> times measured
RAW = set()             # drawn as they are in every language: a contact's alias (Gfx.text_raw), here and on the opening card
_SLOT = re.compile(r"\{(\w+)\}|%[-+0-9.]*[dsf]")


def use_language(code):
    """Loads the catalogs of a language the way scripts/core/lang.gd does: they all merge."""
    global LANG
    LANG = code
    if code == "en":
        return
    root = os.path.join(DATA, "lang", code)
    if not os.path.isdir(root):
        raise SystemExit("no catalogs in game/data/lang/%s" % code)
    for path in sorted(glob.glob(os.path.join(root, "**", "*.json"), recursive=True)):
        cat = json.load(open(path, encoding="utf-8"))
        _CAT.update({k: v for k, v in cat.get("strings", {}).items() if v})
        _KEEP.update(w.lower() for w in cat.get("keep", []))
    contacts = json.load(open(os.path.join(DATA, "contacts.json"), encoding="utf-8"))
    RAW.update(str(a) for a in contacts.get("aliases", []))
    for card in json.load(open(os.path.join(DATA, "intro.json"), encoding="utf-8")).get("cards", []):
        RAW.update(str(e.get("alias", "")) for e in card.get("labels", {}).get("entries", []))
    for en, said in _CAT.items():
        slots = [m.group(0) for m in _SLOT.finditer(en)]
        if not slots:
            continue
        pattern = ""
        pos = 0
        for m in _SLOT.finditer(en):
            pattern += re.escape(en[pos:m.start()]) + (r"([-+]?\d+(?:\.\d+)?)" if m.group(0)[-1] in "df" else "(.+?)")
            pos = m.end()
        pattern += re.escape(en[pos:])
        _FILLED.append((re.compile(pattern + r"\Z", re.S), slots, said, len(_SLOT.sub("", en))))
    _FILLED.sort(key=lambda f: -f[3])        # the most particular template first


def has_cjk(s):
    """scripts/core/lang.gd: has_cjk."""
    return any(0x2E80 <= ord(c) <= 0x9FFF or 0xF900 <= ord(c) <= 0xFAFF or 0xFF00 <= ord(c) <= 0xFFEF for c in s)


def tr(text):
    """text as the player reads it: in English, itself; in another language, the catalog's line
    for it, or the catalog's template with the same values put back in (Lang.fill, Lang.tf: a
    value that is words is translated too). A line with Chinese in it is already translated."""
    if LANG == "en" or not text or has_cjk(text) or text in RAW:
        return text
    hit = _CAT.get(text)
    if hit is not None:
        return hit
    for pattern, slots, said, _ in _FILLED:
        m = pattern.match(text)
        if m is None:
            continue
        values = {}
        codes = []
        for slot, v in zip(slots, m.groups()):
            v = _CAT.get(v, v)
            if slot.startswith("{"):
                values.setdefault(slot, v)
            else:
                codes.append(v)
        out = said
        for slot, v in values.items():
            out = out.replace(slot, v)
        it = iter(codes)
        return _SLOT.sub(lambda c: c.group(0) if c.group(0).startswith("{") else next(it, c.group(0)), out)
    # what the game puts around a translated piece: a bullet, quotes
    for a, b in (("• ", ""), ('"', '"')):
        if len(text) > len(a) + len(b) and text.startswith(a) and text.endswith(b):
            inner = tr(text[len(a):len(text) - len(b)])
            if has_cjk(inner):
                return a + inner + b
    UNMATCHED[text] = UNMATCHED.get(text, 0) + 1
    return text


def text_width(s, bold=False, scale=1):
    """The width of exactly s (Counter Sans, Chinese from font_zh: the same as the game)."""
    return font_zh.text_width(s, bold, scale)


def tw(s, bold=False, scale=1):
    """The width of s as the player reads it (tr)."""
    return text_width(tr(s), bold, scale)


def missing_glyphs(text):
    return sorted({ch for ch in text if not font_zh.has(ch)})


def check(kind, where, text, bold=False, scale=1, limit=None):
    text = tr(text)
    missing = missing_glyphs(text)
    w = text_width(text, bold, scale)
    most = LIMITS.get(kind) if limit is None else limit
    flag = ""
    if missing:
        flag += " MISSING GLYPHS %r" % "".join(missing)
    if most is not None and w > most:
        flag += " TOO WIDE (limit %d)" % most
    return (kind, where, w, text, flag)


def wrap(text, width, bold=False):
    """The same greedy wrap as Gfx.wrap_raw in the game: at spaces, and in a paragraph with
    Chinese in it also between Chinese characters (wrap_cjk)."""
    out = []
    for para in text.split("\n"):
        if has_cjk(para):
            out += wrap_cjk(para, width, bold)
            continue
        line = ""
        for word in para.split(" "):
            if word == "":
                continue
            trial = word if line == "" else line + " " + word
            if line != "" and text_width(trial, bold) > width:
                out.append(line)
                line = word
            else:
                line = trial
        out.append(line)
    return out


NO_START = "，。、；：？！…—）》」』】〕〉”’·%,.;:!?)]}"     # gfx.gd: _NO_START
NO_END = "（《「『【〔〈“‘([{"                                 # gfx.gd: _NO_END


def wrap_cjk(para, width, bold=False):
    """gfx.gd _wrap_cjk: units are single Chinese characters and runs of anything else; a closing
    mark joins the unit before it and an opening mark the unit after it."""
    units = []
    space = False
    i = 0
    while i < len(para):
        if para[i] == " ":
            space = True
            i += 1
            continue
        j = i + 1
        if not has_cjk(para[i]):
            while j < len(para) and para[j] != " " and not has_cjk(para[j]):
                j += 1
        units.append([para[i:j], space])
        space = False
        i = j
    joined = []
    glue = False
    for piece, sp in units:
        if joined and (glue or piece[:1] in NO_START):
            joined[-1][0] += (" " if sp else "") + piece
        else:
            joined.append([piece, sp])
        glue = piece[-1:] in NO_END
    out = []
    line = ""
    for piece, sp in joined:
        trial = piece if line == "" else line + (" " if sp else "") + piece
        if line != "" and text_width(trial, bold) > width:
            out.append(line)
            line = piece
        else:
            line = trial
    out.append(line)
    return out


def check_lines(kind, where, text, width, most):
    """A wrapped paragraph: reported by its line count, flagged when it needs more lines than there are."""
    text = tr(text)
    missing = missing_glyphs(text)
    lines = wrap(text, width)
    n = len(lines)
    flag = ""
    if missing:
        flag += " MISSING GLYPHS %r" % "".join(missing)
    if n > most:
        flag += " TOO MANY LINES (%d, room for %d at %d px)" % (n, most, width)
    if any(text_width(line) > width for line in lines):
        flag += " A WORD IS WIDER THAN THE COLUMN (%d px)" % width
    return (kind, where, n, text, flag)




def wrap_after(text, first_w, width):
    """gfx.gd wrap_after: a first line first_w wide, the lines after it width."""
    first = wrap(text, first_w)
    if len(first) <= 1:
        return first
    head = first[0]
    left = len(head.replace(" ", ""))
    k = 0
    while k < len(text) and left > 0:
        if text[k] != " ":
            left -= 1
        k += 1
    return [head] + wrap(text[k:].strip(), width)


def check_finding(where, text, ok):
    """A case's row text on the visit's page of the report (screens.gd _draw_finding and
    _finding_text): it starts after the label (NORMAL or BROKEN LINE) on the label's line, which
    ends where "you did not check" begins (measured as if it always were there), and has one more
    line under it from the label's left edge; the game cuts anything longer with "...". The
    game's own widths count the gap after the last letter, one pixel more than text_width."""
    text = tr(text)
    missing = missing_glyphs(text)
    gap = number(SCREENS_GD, "FINDING_GAP")
    x = REPORT_X0 + number(SCREENS_GD, "FINDING_X")
    after = x + text_width(tr("NORMAL" if ok else "BROKEN LINE"), True) + 1 + gap
    right = REPORT_X1 - (text_width(tr("you did not check")) + 1) - gap
    lines = wrap_after(text, right - after, REPORT_X1 - x)
    flag = ""
    if missing:
        flag += " MISSING GLYPHS %r" % "".join(missing)
    if len(lines) > 2:
        flag += " TOO MANY LINES (%d, room for 2: the rest is cut)" % len(lines)
    return ("finding", where, len(lines), text, flag)


def money(v):
    return "+%d" % v if v > 0 else str(v)


def fill(text, numbers):
    """Gfx.fill: {name} placeholders."""
    for k, v in numbers.items():
        text = text.replace("{%s}" % k, str(v))
    return text


def source(path):
    return open(path, encoding="utf-8").read()


def consts(path, pattern):
    """String constants of a script whose names match the pattern, as (name, text)."""
    return [(n, t) for n, t in re.findall(r'^const ([A-Z_]+) := "([^"]*)"', source(path), re.M) if re.search(pattern, n)]


def number(path, name):
    """A numeric constant of a script."""
    m = re.search(r'^const %s := ([0-9.]+)' % name, source(path), re.M)
    if m is None:
        raise SystemExit("%s: no constant %s" % (os.path.basename(path), name))
    return float(m.group(1))


def rects(path, name):
    """A table of Rect2 constants (const NAME := {"key": Rect2(x, y, w, h), ...})."""
    src = source(path)
    body = src[src.index("const %s := {" % name):]
    body = body[:body.index("}")]
    return {k: tuple(float(v) for v in (x, y, w, h))
            for k, x, y, w, h in re.findall(r'"(\w+)":\s*Rect2\(([0-9.]+),\s*([0-9.]+),\s*([0-9.]+),\s*([0-9.]+)\)', body)}


def table(path, name):
    """A table of string constants (const NAME := {"key": "text", ...}), as (NAME.key, text)."""
    src = source(path)
    body = src[src.index("const %s := {" % name):]
    body = body[:body.index("}")]
    return [("%s.%s" % (name, k), v) for k, v in re.findall(r'"(\w+)":\s*"([^"]*)"', body)]


def figures(path, name):
    """A table of numeric constants (const NAME := {"key": 1.0, ...})."""
    src = source(path)
    body = src[src.index("const %s := {" % name):]
    body = body[:body.index("}")]
    return {k: float(v) for k, v in re.findall(r'"(\w+)":\s*([0-9.]+)', body)}


def overlap(a, b):
    """Whether two (x, y, w, h) rectangles share any pixel."""
    return a[0] < b[0] + b[2] and b[0] < a[0] + a[2] and a[1] < b[1] + b[3] and b[1] < a[1] + a[3]


def inside(a, b):
    """Whether rectangle a lies inside rectangle b."""
    return a[0] >= b[0] and a[1] >= b[1] and a[0] + a[2] <= b[0] + b[2] and a[1] + a[3] <= b[1] + b[3]


def verdicts():
    """The verdicts a visit's page of the report can print (screens.gd _verdict_of), read from
    the game source so they cannot drift."""
    src = source(SCREENS_GD)
    body = src[src.index("func _verdict_of"):]
    return sorted(set(re.findall(r'return "((?:RIGHT|WRONG|NO) CALL)"', body)))


def visit_money(rules, fees, pay, calm_most):
    """Every figure a visit can show on the report (its counter, closing and in-all money, and
    the totals row): the fee with or without a drop and the calm-patches, the fee with Trauma
    Team's bounty on top (rules version 9: the crew pays the fee on account), each scoring rule
    the same way, and at closing the fee taken back with a bill: the call-out for a steady
    patient, or the work on one who drifted."""
    scoring = {k: int(v) for k, v in rules["scoring"].items() if not isinstance(v, str)}      # not its note
    bounty = scoring.get("refer_drifting", 0)
    out = set()
    for v in set(fees) | {fee + bounty for fee in fees} | set(scoring.values()) | {0}:
        out |= {v, v + pay, v - calm_most, v + pay - calm_most}
    for fee in fees:
        for k in ("treat_drifting", "false_call"):
            out.add(scoring.get(k, 0) - fee)
    return sorted(out)


HINT_TABLES = ("MIC_HINTS", "OBJECT_HINT", "TAB_HINT", "SCOPE_HINT", "LEAD_HINT")


def hints():
    """The fixed hints main.gd can show: every *_HINT constant and the tables of them (the
    microphone's, the wall objects', the papers' tabs, the tool close-ups')."""
    out = consts(MAIN_GD, r"HINT")
    for name in HINT_TABLES:
        out += table(MAIN_GD, name)
    return out


def worst_numbers(text, values):
    """A %d line with the widest figures it can carry: each %d takes the next value."""
    out = text
    for v in values:
        out = out.replace("%d", str(v), 1)
    return out


def intro_rows(intro, numbers):
    """The opening cards (intro.gd): the typed text, the title, and the words inside each picture."""
    rows = []
    text_w = int(number(INTRO_GD, "TEXT_W"))
    text_lines = int(number(INTRO_GD, "TEXT_LINES"))
    cards = intro.get("cards", [])
    counter = "%d/%d" % (len(cards), len(cards))
    for c in cards:
        cid = "intro." + str(c.get("id", "?"))
        rows.append(check_lines("card_text", cid + ".text", fill(c.get("text", ""), numbers), text_w, text_lines))
        rows.append(check("card_title", cid + ".title", c.get("title", ""), bold=True,
                          limit=text_w - tw(counter) - 8))
        labels = c.get("labels", {})
        art = c.get("art", "")
        if art == "fired":
            panel_w = number(INTRO_GD, "PANEL_W")
            tab_w = number(INTRO_GD, "TAB_W")
            # the company's name sits on the door's 40 px plate, and in bold on the binder's 58 px one
            rows.append(check("card_label", cid + ".company@door", labels.get("company", ""), limit=40 - 4))
            rows.append(check("card_label", cid + ".company@binder", labels.get("company", ""), bold=True, limit=58 - 6))
            rows.append(check("card_label", cid + ".binder", labels.get("binder", ""), limit=58 - 6))
            # the floor's caption box starts 3 px in and has 4 px of padding each side
            rows.append(check("card_label", cid + ".floor", labels.get("floor", ""), limit=panel_w - 3 - 8 - 3))
            rows.append(check("card_label", cid + ".denied", labels.get("denied", ""), limit=40 - 4))   # the reader's screen
            for i, tab in enumerate(labels.get("tabs", [])[:4]):
                rows.append(check("card_label", cid + ".tabs%d" % i, tab, limit=tab_w - 3 - 2))
        elif art == "debt":
            file_w = number(INTRO_GD, "FILE_W")
            rest = number(INTRO_GD, "FILE_REST")
            lease_x = number(INTRO_GD, "LEASE_X")
            lease_w = number(INTRO_GD, "LEASE_W")
            # once the lease is over Kessler's file only its left side shows, from FILE_REST to LEASE_X,
            # and the file's words start 8 px in; the head shares its band with a 16 px mark
            seen = lease_x - rest - 8 - 4
            rows.append(check("card_label", cid + ".file_head", labels.get("file_head", ""), bold=True,
                              limit=min(file_w - 8 - 16 - 4, seen)))
            rows.append(check("card_label", cid + ".file_sub", labels.get("file_sub", ""), limit=seen))
            for i, item in enumerate(labels.get("file_items", [])):
                rows.append(check("card_label", cid + ".file_items%d" % i, item, limit=seen))
            # the SOLD stamp is the word plus 16 px, 10 px in from the file's edge
            rows.append(check("card_label", cid + ".sold", labels.get("sold", ""), bold=True,
                              limit=lease_x - rest - 10 - 16 - 2))
            # the lease has 12 px margins; the lender's mark takes 30 px of the head and the sub
            rows.append(check("card_label", cid + ".head", labels.get("head", ""), bold=True, limit=lease_w - 24 - 30 - 4))
            rows.append(check("card_label", cid + ".sub", labels.get("sub", ""), limit=lease_w - 24 - 30 - 4))
            rows.append(check("card_label", cid + ".from", labels.get("from", ""), limit=lease_w - 24))
            for i, item in enumerate(labels.get("items", [])):
                rows.append(check("card_label", cid + ".items%d" % i, item, limit=lease_w - 24 - 15))
            rows.append(check("card_label", cid + ".foot", labels.get("foot", ""), limit=lease_w - 24))
            rows.append(check("card_label", cid + ".stamp", labels.get("stamp", ""), bold=True, limit=74 - 8))
        elif art == "lanterns":
            # the list is 196 px wide with 12 px margins; SAY is a button at least 30 px wide at the
            # right of each alias, and the PICKED UP stamp takes its place on the first entry
            col = 196 - 24
            say = labels.get("say", "")
            say_w = max(30, tw(say, True) + 10)
            rows.append(check("card_label", cid + ".head", labels.get("head", ""), bold=True, limit=col))
            rows.append(check("card_label", cid + ".say", say, bold=True, limit=30 - 4))
            for i, e in enumerate(labels.get("entries", [])[:2]):
                alias = e.get("alias", "")
                rows.append(check("card_label", cid + ".alias%d" % i, alias, bold=True, limit=col - say_w - 6))
                for k, clue in enumerate(e.get("clues", [])):
                    rows.append(check("card_label", cid + ".clue%d.%d" % (i, k), "• " + clue, limit=col))
                rows.append(check("card_label", cid + ".code%d" % i, '"%s"' % e.get("code", ""), limit=col))
                if i == 0:
                    rows.append(check("card_label", cid + ".picked", labels.get("picked", ""), bold=True,
                                      limit=col - tw(alias, True) - 6 - 6))
            # the figure rises over the package, between the list and the courier
            rows.append(check("card_label", cid + ".drop", fill(labels.get("drop", ""), numbers), bold=True, limit=56))
            # two tags on the counter's edge: PATIENT (then CONTACT) under the courier at TAG_X, and
            # PACKAGE under the package. A tag is the word plus 6 px; the two keep 2 px apart.
            tag_x = number(INTRO_GD, "TAG_X")
            pkg_x = number(INTRO_GD, "PACKAGE_X") + 16
            for key in ("patient", "contact"):
                rows.append(check("card_label", cid + "." + key, labels.get(key, ""), limit=2 * (360 - tag_x - 2) - 6))
            both = tr(labels.get("contact", "")) + tr(labels.get("package", ""))
            rows.append(check("card_label", cid + ".contact+package", both, limit=2 * (tag_x - pkg_x) - 12 - 4))
        elif art == "line":
            hours = int(numbers.get("hours", 5))
            per_hour = int(numbers.get("per_hour", 0))
            rows.append(check("card_label", cid + ".hour", labels.get("hour", ""), limit=38 - 8 - 2))
            head = "%s %d   %s %d" % (tr(labels.get("hour", "")), hours, tr(labels.get("line", "")), hours * per_hour)
            rows.append(check("card_label", cid + ".header", head, limit=360 - 44 - 18))
            step_w = 290 // max(1, hours)
            rows.append(check("card_label", cid + ".over", labels.get("over", ""), bold=True, limit=step_w * hours - 20))
            # the boxed word is centred on the last step and must stay inside the picture
            centre = 38 + step_w * (hours - 1)
            rows.append(check("card_label", cid + ".under", labels.get("under", ""), bold=True,
                              limit=2 * (360 - centre) - 12))
            rows.append(check("card_label", cid + ".step", str(hours * per_hour), limit=step_w - 4))
        elif art == "drift":
            side = number(INTRO_GD, "CRATE_SIDE")
            # stencilled on the crate's front (x 14 to CRATE_SIDE - 16), between its 6 px corner posts
            rows.append(check("card_label", cid + ".surplus", labels.get("surplus", ""), bold=True,
                              limit=side - 14 - 16 - 2 * 6 - 4))
            # over the clinic glass, which is the rest of the picture less 8 px each side
            rows.append(check("card_label", cid + ".ask", labels.get("ask", ""), bold=True,
                              limit=360 - side - 16 - 8))
        elif art == "counter":
            for key in ("treat", "team", "shutter"):
                rows.append(check("card_label", cid + "." + key, labels.get(key, ""), bold=True, limit=100 - 6))
                rows.append(check("card_label", cid + "." + key + "_sub", labels.get(key + "_sub", ""), limit=100 - 6))
    for name, text in consts(INTRO_GD, r"^FOOT$"):
        rows.append(check("screen", "intro.gd:" + name, text))
    return rows


def guide_rows(intro, numbers):
    """The counter guide (guide.gd): each item wrapped to its panel, and the whole list on the screen."""
    rows = []
    panels = rects(GUIDE_GD, "PANEL")
    areas = rects(GUIDE_GD, "AREAS")
    lit = rects(GUIDE_GD, "LIT")
    stands = figures(GUIDE_GD, "STANDS")
    pad = number(GUIDE_GD, "PAD")
    badge = number(GUIDE_GD, "BADGE")
    gap = number(GUIDE_GD, "ITEM_GAP")
    pages = intro.get("guide", [])
    counter = "%d/%d" % (len(pages), len(pages))
    foot = consts(GUIDE_GD, r"^FOOT$")
    for p in pages:
        pid = str(p.get("id", "?"))
        where = "guide." + pid
        if pid not in panels:
            rows.append(("guide_box", where, 0, "", " NO PANEL FOR THIS PAGE IN guide.gd"))
            continue
        px, py, pw, _ph = panels[pid]
        item_w = int(pw - pad * 2 - badge - 5)
        rows.append(check("guide_title", where + ".title", p.get("title", ""), bold=True,
                          limit=pw - pad * 2 - tw(counter) - 6))
        height = pad + 12 + 7
        for it in p.get("items", []):
            key = str(it.get("key", "?"))
            text = fill(it.get("text", ""), numbers)
            row = check_lines("guide_item", where + "." + key, text, item_w, 6)
            if key not in areas:
                row = row[:4] + (row[4] + " NO AREA FOR THIS KEY IN guide.gd",)
            elif pid in lit and not inside(areas[key], lit[pid]):
                row = row[:4] + (row[4] + " ITS FRAME IS OUTSIDE THE PART THE PAGE LIGHTS",)
            rows.append(row)
            height += len(wrap(text, item_w)) * LINE + gap
        closing = fill(p.get("closing", ""), numbers)
        if closing:
            rows.append(check_lines("guide_item", where + ".closing", closing, int(pw - pad * 2), 3))
            height += 3 + len(wrap(closing, int(pw - pad * 2))) * LINE + gap
        height += 4 + LINE + pad
        # a list hangs from its panel's top, or stands on a line of the screen (guide.gd: STANDS)
        if pid in stands:
            top = stands[pid] - height
            room = stands[pid] - 8
        else:
            top = py
            room = SCREEN_H - py - 8
        flag = " TOO TALL (room for %d px)" % room if height > room else ""
        if pid not in lit:
            flag += " NO LIT PART FOR THIS PAGE IN guide.gd"
        for it in p.get("items", []):
            key = str(it.get("key", "?"))
            if key in areas and overlap((px, top, pw, height), areas[key]):
                flag += " THE LIST COVERS WHAT IT EXPLAINS (%s)" % key
        rows.append(("guide_box", where + ".height", int(height), "%d items" % len(p.get("items", [])), flag))
        for name, text in foot:
            rows.append(check("guide_foot", where + ":" + name, text, limit=pw - pad * 2))
    if not foot:
        rows.append(("guide_foot", "guide.gd", 0, "", " NO FOOT LINE FOUND"))
    return rows


TRAINING_LINES = 4      # lines a training tip may take (the box grows with them; four keeps it off the face)
TRAINING_UNTIL = {"next", "list_open", "sheet_open", "card_open", "visit_start", "code_said", "mark", "verdict",
                  "continue", "complaint", "first_test", "second_test", "listed_answer", "courier_arrives", "courier_list", "courier_card", "courier_code", "talk", "look", "check:penlight", "check:grip", "check:port"}
TRAINING_AREAS = {"lead","list", "sheet", "card", "marks", "guide", "cam", "code", "tools", "talk", "decide", "slip",
                  "patience", "meter", "shutter"}


def eyes_row(left, right, parts):
    """The eyes row of an assembled sheet (case_db.gd: _eyes_row): (tag, normal, fine)."""
    l, r = parts["eyes"][left], parts["eyes"][right]
    if left == right:
        return l["tag"], l["both"], l["fine"]
    mixed = parts["eyes_mixed"]
    normal = mixed["normal"].replace("{l}", l["one"]).replace("{r}", r["one"])
    fine = mixed["fine"].replace("{l}", l["fine_one"]).replace("{r}", r["fine_one"])
    if r["kind"] == "natural":
        tag = mixed["tag_l"].replace("{tag}", l["tag"])
    elif l["kind"] == "natural":
        tag = mixed["tag_r"].replace("{tag}", r["tag"])
    else:
        tag = mixed["tag_two"]
    return tag, normal, fine


def sheet_rows(sheet, parts):
    """Every line a reference sheet can be assembled with (case_db.gd: sheet_for): each pair of eye
    models, each model of the other slots, and the title for each patient. On the paper
    (clipboard.gd: _draw_sheet_paper) the tag sits under the label, in the label column, and the
    fine line follows SHEET_FINE on the second line of the text column."""
    rows = []
    fine_lead = tw(tr(dict(consts(CLIPBOARD_GD, r"^SHEET_FINE$")).get("SHEET_FINE", "fine:")) + " ")
    room = LIMITS["sheet"]
    label_room = int(number(CLIPBOARD_GD, "SHEET_TEXT_X")) - 408 - 3
    base = {r["id"]: r for r in sheet["rows"]}
    for r in sheet["rows"]:
        rows.append(check("sheet_label", "sheet." + r["id"] + ".label", r["label"], bold=True, limit=label_room))
    for left in parts["eyes"]:
        for right in parts["eyes"]:
            tag, normal, fine = eyes_row(left, right, parts)
            where = "parts.eyes.%s+%s" % (left, right)
            rows.append(check("sheet", where + ".normal", normal))
            rows.append(check("sheet", where + ".fine", fine, limit=room - fine_lead))
            rows.append(check("sheet_tag", where + ".tag", tag, limit=label_room))
    for row_id, group in (("hands", "hands"), ("port", "ports"), ("speech", "voices")):
        for mid, m in parts[group].items():
            where = "parts.%s.%s" % (group, mid)
            normal = m.get("normal", base[row_id].get("normal", ""))
            if group == "hands":
                normal = normal.replace("{limit}", "%.1f" % (m["limit_ms"] / 1000.0))
            rows.append(check("sheet", where + ".normal", normal))
            rows.append(check("sheet", where + ".fine", m["fine"], limit=room - fine_lead))
            rows.append(check("sheet_tag", where + ".tag", m["tag"], limit=label_room))
    temper = base.get("temper", {})
    rows.append(check("sheet", "sheet.temper.normal", temper.get("normal", "")))
    rows.append(check("sheet", "sheet.temper.ordinary", temper.get("ordinary", ""), limit=room - fine_lead))
    rows.append(check("footer", "sheet.title_none", sheet.get("title_none", ""), bold=True))
    for path in sorted(glob.glob(os.path.join(DATA, "cases", "*.json"))):
        c = json.load(open(path, encoding="utf-8"))
        rows.append(check("footer", c["id"] + ".sheet_title", sheet["title"].replace("{name}", c["name"].upper()), bold=True))
    for i, f in enumerate(sheet["footer"]):
        rows.append(check("footer", "sheet.footer%d" % i, f))
    return rows


def training_rows(intro, numbers):
    """The first-night training (coach.gd): each tip wrapped to the box, and the box's own words."""
    rows = []
    width = number(COACH_GD, "WIDTH")
    pad = number(COACH_GD, "PAD")
    text_w = number(COACH_GD, "TEXT_W")
    if text_w != width - pad * 2:
        rows.append(("training", "coach.gd:TEXT_W", int(text_w), "", " NOT WIDTH - 2 * PAD (%d)" % (width - pad * 2)))
    steps = intro.get("training", [])
    if not steps:
        rows.append(("training", "intro.training", 0, "", " NO TRAINING STEPS FOUND"))
    phases = set(re.findall(r'"(\w+)"', source(COACH_GD)[source(COACH_GD).index("const PHASES"):].split("\n")[0]))
    counter = "%d/%d" % (len(steps), len(steps))
    named = dict(consts(COACH_GD, r"^(TITLE|NEXT|DONE|SKIP)$"))
    title_w = tw(named.get("TITLE", ""), True) + 6 + tw(counter)
    rows.append(("training_label", "coach.gd:TITLE+counter", title_w, named.get("TITLE", ""),
                 " TOO WIDE (room %d px)" % text_w if title_w > text_w else ""))
    # SKIP ALL on the left and NEXT (or DONE) on the right of the bottom row, with room between
    for last in ("NEXT", "DONE"):
        both = tw(named.get("SKIP", ""), True) + 10 + 12 + tw(named.get(last, ""), True) + 8
        rows.append(("training_label", "coach.gd:SKIP+" + last, both, named.get(last, ""),
                     " THE BUTTONS MEET (room %d px)" % text_w if both > text_w else ""))
    seen = set()
    for i, st in enumerate(steps):
        sid = str(st.get("id", "?"))
        where = "intro.training.%d.%s" % (i + 1, sid)
        row = check_lines("training", where, fill(st.get("text", ""), numbers), int(text_w), TRAINING_LINES)
        flag = row[4]
        if sid in seen:
            flag += " DUPLICATE ID"
        seen.add(sid)
        if "{" in fill(st.get("text", ""), numbers):
            flag += " AN UNFILLED {NUMBER}"
        own = [x.strip() for x in str(st.get("phase", "")).split(",") if x.strip()]
        if not own or any(x not in phases for x in own):
            flag += " UNKNOWN PHASE (%s)" % st.get("phase", "")
        if str(st.get("until", "")) not in TRAINING_UNTIL:
            flag += " UNKNOWN EVENT (%s)" % st.get("until", "")
        area = str(st.get("area", ""))
        if area not in TRAINING_AREAS and not area.startswith("pad:"):
            flag += " UNKNOWN AREA (%s)" % area
        rows.append(row[:4] + (flag,))
    return rows

MARK = "►"              # the marker beside the lit item of the menu and the SETTINGS page (bold, drawn raw)


def title_rows():
    """The title card (screens.gd _draw_title, _draw_menu): each menu item centred in its box,
    clear of the marker that blinks at the box's left; the SUDDEN ATTACKS box, which is as wide
    as its longer line and must stay 8 px inside the screen; the attack picture's plate; and the
    keys at the foot of HOW TO PLAY and SETTINGS. The game's own widths count the gap after the
    last letter, one pixel more than text_width."""
    rows = []
    menu_w = number(SCREENS_GD, "MENU_W")
    mark = text_width(MARK, True) + 1
    # the name is centred: its left edge must stay right of the marker (box x + 6) with 2 px to spare
    room = int(menu_w - 2 * (6 + mark + 2))
    names = table(SCREENS_GD, "MENU_NAMES")
    if not names:
        rows.append(("screen", "screens.gd:MENU_NAMES", 0, "", " NO MENU FOUND"))
    for where, text in names:
        rows.append(check("menu", "screens.gd:" + where, text, bold=True, limit=room))
    # the warning box: max(title, text) + 20 wide, centred, 8 px from either edge of the screen at least
    box_room = LIMITS["screen"] - 20
    found = dict(consts(SCREENS_GD, r"^WARNING(_TITLE)?$"))
    if len(found) < 2:
        rows.append(("screen", "screens.gd:WARNING", 0, "", " NO WARNING FOUND"))
    if "WARNING_TITLE" in found:
        rows.append(check("screen", "screens.gd:WARNING_TITLE", found["WARNING_TITLE"], bold=True, limit=box_room))
    if "WARNING" in found:
        row = check("screen", "screens.gd:WARNING", found["WARNING"], limit=box_room)
        if "SPACE" not in row[3]:
            row = row[:4] + (row[4] + " DOES NOT NAME SPACE",)
        rows.append(row)
    for name, text in consts(SCREENS_GD, r"^(HOWTO_KEYS|HOWTO_LAST_KEYS|SETTINGS_KEYS)$"):
        rows.append(check("screen", "screens.gd:" + name, text))
    # the attack picture's plate takes the place of a bar as wide as the sill's (screens.gd _draw_demo)
    for name, text in consts(SCREENS_GD, r"^DEMO_STOPPED$"):
        rows.append(check("plate", "screens.gd:" + name, text, bold=True))
    return rows


SETTINGS_PANEL = (110, 22, 420, 290)    # screens.gd _draw_settings: p


def settings_rows():
    """The SETTINGS page (screens.gd _draw_settings, setting_rects): each row's name right-aligned
    at SET_LABEL_RIGHT and clear of the marker; its choices laid out from SET_OPTIONS_X, each as
    wide as its name plus the padding, all inside the lit band; MUTED [M] after the last volume
    step; each row's hint wrapped under the rows, above the panel's foot; the page's big title."""
    rows = []
    px, py, pw, ph = SETTINGS_PANEL
    band_right = px + 8 + (pw - 16)
    label_right = number(SCREENS_GD, "SET_LABEL_RIGHT")
    options_x = number(SCREENS_GD, "SET_OPTIONS_X")
    gap = number(SCREENS_GD, "SET_GAP")
    pad = number(SCREENS_GD, "LANG_PAD")
    set_y = number(SCREENS_GD, "SET_Y")
    step = number(SCREENS_GD, "SET_STEP")
    mark_right = px + 14 + text_width(MARK, True) + 1
    for name, text in consts(SCREENS_GD, r"^SETTINGS_TITLE$"):
        rows.append(check("screen", "screens.gd:" + name, text, bold=True, scale=2, limit=pw - 20))
    for name, text in consts(SCREENS_GD, r"^BACK$"):
        rows.append(check("screen", "screens.gd:" + name, text, bold=True, limit=pw - 40))
    labels = dict((k.split(".", 1)[1], v) for k, v in table(SCREENS_GD, "SETTING_NAMES"))
    option_names = dict((k.split(".", 1)[1], v) for k, v in table(SCREENS_GD, "OPTION_NAMES"))
    hints_of = dict((k.split(".", 1)[1], v) for k, v in table(SCREENS_GD, "SETTING_HINTS"))
    languages = dict(re.findall(r'"(\w+)":\s*"([^"]*)"', re.search(r"^const NAMES := \{([^}]*)\}",
                     source(os.path.join(ROOT, "game", "scripts", "core", "lang.gd")), re.M).group(1)))
    src = source(SCREENS_GD)
    order = re.findall(r'"(\w+)"', re.search(r"^const SETTING_ROWS := \[([^\]]*)\]", src, re.M).group(1))
    body = src[src.index("const SETTING_OPTIONS := {"):]
    body = body[:body.index("}")]
    options = {k: re.findall(r'"?(\w+)"?', v) for k, v in re.findall(r'"(\w+)":\s*\[([^\]]*)\]', body)}
    if not order or not options:
        rows.append(("setting", "screens.gd:SETTING_ROWS", 0, "", " NO SETTINGS FOUND"))
    muted = dict(consts(SCREENS_GD, r"^MUTED_NOTE$")).get("MUTED_NOTE", "")
    for i, row in enumerate(order):
        y = set_y + step * i
        hint = hints_of.get(row, "")
        # the hint under the rows: centred, wrapped to the panel less 20 px a side, above its foot
        top = set_y + step * len(order) + 14
        most = int((py + ph - 4 - top) // 11)
        r = check_lines("setting_hint", "screens.gd:SETTING_HINTS." + row, hint, pw - 40, most)
        if not hint:
            r = r[:4] + (r[4] + " NO HINT FOR THIS ROW",)
        rows.append(r)
        if row == "patient_ai":
            for key, text in table(SCREENS_GD, "PATIENT_HINTS"):
                rows.append(check_lines("setting_hint", key, text, pw - 40, most))
        if row == "back":
            continue
        label = labels.get(row, "")
        room = int(label_right - mark_right - 4)
        rows.append(check("setting", "screens.gd:SETTING_NAMES." + row, label, bold=True, limit=room)
                    if label else ("setting", "screens.gd:SETTING_NAMES." + row, 0, "", " NO NAME FOR THIS ROW"))
        x = options_x
        shown = []
        for v in options.get(row, []):
            name = languages.get(v, v) if row == "language" else tr(option_names.get(v, v))
            missing = missing_glyphs(name)
            if missing:
                rows.append(("setting", "screens.gd:OPTION_NAMES." + v, 0, name, " MISSING GLYPHS %r" % "".join(missing)))
            x += -(-(text_width(name, True) + 1 + pad * 2 + 4) // 1) + gap
            shown.append(name)
        end = x - gap
        if row == "volume" and muted:
            end += 8 + tw(muted, True) + 1
            shown.append(tr(muted))
        flag = " PAST THE BAND (it ends at %d)" % band_right if end > band_right else ""
        rows.append(("setting", "screens.gd:_draw_settings " + row, int(end), " | ".join(shown), flag))
    return rows


def howto_rows(intro, numbers):
    """HOW TO PLAY (screens.gd _draw_howto, howto_points, howto_bottom): each page's big title
    inside the panel, its header line (HOW TO PLAY on the left, the page count on the right),
    its points with their numbers in, wrapped to HOWTO_TEXT_W, and the last of them above the
    panel's foot. A point about the price of glass goes when glass has no price, as in the game."""
    rows = []
    pages = intro.get("howto", [])
    if not pages:
        rows.append(("howto", "intro.howto", 0, "", " NO HOW TO PLAY PAGES FOUND"))
        return rows
    panel = re.search(r"^const HOWTO_PANEL := Rect2\(([0-9.]+), ([0-9.]+), ([0-9.]+), ([0-9.]+)\)", source(SCREENS_GD), re.M)
    px, py, pw, ph = (float(v) for v in panel.groups())
    text_w = int(number(SCREENS_GD, "HOWTO_TEXT_W"))
    art_y = number(SCREENS_GD, "HOWTO_ART_Y")
    art_h = number(SCREENS_GD, "HOWTO_ART_H")
    line_h = number(SCREENS_GD, "HOWTO_LINE")
    gap = number(SCREENS_GD, "HOWTO_GAP")
    src = source(SCREENS_GD)
    arts = re.findall(r'"(\w+)"', re.search(r"^const HOWTO_ARTS := \[([^\]]*)\]", src, re.M).group(1))
    page_of = dict(consts(SCREENS_GD, r"^HOWTO_PAGE$")).get("HOWTO_PAGE", "%d / %d")
    menu = dict((k.split(".", 1)[1], v) for k, v in table(SCREENS_GD, "MENU_NAMES"))
    head = tw(menu.get("howto", ""), True) + 1 + 12 + tw(worst_numbers(page_of, [len(pages), len(pages)]), True) + 1
    rows.append(("howto_title", "screens.gd:_draw_howto head", int(head), tr(menu.get("howto", "")),
                 " THE HEAD LINE MEETS ITS PAGE COUNT (room %d px)" % (pw - 20) if head > pw - 20 else ""))
    seen = set()
    for i, p in enumerate(pages):
        pid = str(p.get("id", "?"))
        where = "intro.howto.%d.%s" % (i + 1, pid)
        row = check("howto_title", where + ".title", p.get("title", ""), bold=True, scale=2, limit=pw - 20)
        if pid in seen:
            row = row[:4] + (row[4] + " DUPLICATE ID",)
        seen.add(pid)
        art = str(p.get("art", ""))
        if art and art not in arts:
            row = row[:4] + (row[4] + " NO PICTURE CALLED %s IN screens.gd" % art,)
        rows.append(row)
        y = art_y + (art_h + 8 if art else 2)
        points = 0
        for k, line in enumerate(p.get("lines", [])):
            if "{repair_cost}" in line and int(numbers.get("repair_cost", 0)) <= 0:
                continue
            text = fill(line, numbers)
            r = check_lines("howto", "%s.%d" % (where, k + 1), text, text_w, 6)
            if "{" in text:
                r = r[:4] + (r[4] + " AN UNFILLED {NUMBER}",)
            rows.append(r)
            y += line_h * r[2] + gap
            points += 1
        y -= gap
        bottom = py + ph - 6
        flag = " TOO TALL (the panel ends at %d)" % bottom if y > bottom else ""
        if points < 3:
            flag += " FEWER THAN THREE POINTS"
        rows.append(("howto_box", where + ".bottom", int(y), "%d points" % points, flag))
    return rows


def main():
    args = sys.argv[1:]
    if hasattr(sys.stdout, "reconfigure"):
        sys.stdout.reconfigure(encoding="utf-8")
    for i, a in enumerate(args):
        if a.startswith("--lang="):
            use_language(a[len("--lang="):])
        elif a == "--lang" and i + 1 < len(args):
            use_language(args[i + 1])
    rows = []
    sheet = json.load(open(os.path.join(DATA, "sheet.json"), encoding="utf-8"))
    parts = json.load(open(os.path.join(DATA, "parts.json"), encoding="utf-8"))
    rows.extend(sheet_rows(sheet, parts))
    rules = json.load(open(os.path.join(DATA, "rules.json"), encoding="utf-8"))
    contacts = rules.get("contacts", {})
    reassure = rules.get("reassure", {})
    calm_most = int(reassure.get("cost", 0)) * int(reassure.get("uses", 0))
    cases = [json.load(open(p, encoding="utf-8")) for p in sorted(glob.glob(os.path.join(DATA, "cases", "*.json")))]
    fees = set(int(c.get("fee", 0)) for c in cases)
    figures = visit_money(rules, fees, int(contacts.get("pay", 0)), calm_most)
    widest_money = max((money(v) for v in figures), key=tw)
    tally_gap = dict(consts(SCREENS_GD, r"^TALLY_GAP$")).get("TALLY_GAP", "   •   ")
    your_call = dict(consts(SCREENS_GD, r"^YOUR_CALL$")).get("YOUR_CALL", "")
    calls = [tr(your_call.replace("%s", tr(t), 1)) for _, t in table(SCREENS_GD, "CALL_NAMES")]
    if not your_call or not calls:
        rows.append(("visit_call", "screens.gd:_draw_visit_page", 0, "", " NO CALL WORDS FOUND"))
    widest_call = max(calls, key=lambda t: text_width(t, True)) if calls else ""
    visit_lines = int(number(SCREENS_GD, "VISIT_TEXT_LINES"))
    for c in cases:
        cid = c["id"]
        rows.append(check("name", cid + ".name", c["name"], bold=True))
        rows.append(check("request", cid + ".request", c["request"]))
        for field, sentence in c["intake"].items():
            if field in ("part", "terms"):
                continue
            if field in ("firm", "flat"):
                rows.append(check_lines("intake", cid + "." + field, sentence, STRIP_WIDTH, 2))
            else:
                rows.append(check_lines("intake", cid + "." + field, sentence, 214, 3 if field in ("clear", "gap") else 2))
        for z, t in c["complaints"].items():
            rows.append(check_lines("complaint", cid + ".complaints." + z, t, 360, 2))
        # every sign of every row (case data version 3): the night picks one sign a row, so any of
        # them can be the one on the screen: its card note, its look, its line after the grip,
        # its answers, its reaction to a press and its flare, and its row on the report
        for row, kinds in c.get("signs", {}).items():
            for kind in ("normal", "broken"):
                for s in kinds.get(kind, []):
                    where = "%s.signs.%s.%s" % (cid, row, s.get("id", "?"))
                    if s.get("note"):
                        rows.append(check("note", where + ".note", s["note"].replace("{t}", "0.0")))
                    if s.get("look"):
                        rows.append(check("look", where + ".look", s["look"]))
                    if s.get("after"):
                        rows.append(check("line", where + ".after", s["after"]))
                    for tid, said in s.get("answers", {}).items():
                        rows.append(check("note", where + ".answers." + tid + ".note", said.get("note", "")))
                        rows.append(check("line", where + ".answers." + tid + ".a", said.get("a", "")))
                    for k in ("press", "flare"):
                        p = s.get(k, {})
                        if p.get("note"):
                            rows.append(check("note", where + "." + k + ".note", p["note"]))
                        if p.get("line"):
                            rows.append(check("line", where + "." + k + ".line", p["line"]))
                    rows.append(check_finding(where + ".text", s.get("text", ""), kind == "normal"))
        for k, cl in c.get("claims", {}).items():
            rows.append(check("note", cid + ".claims." + k, cl["note"]))
        for tp in c["topics"]:
            rows.append(check("question", cid + ".topics." + tp["id"] + ".q", tp["q"]))
        # the line after the last press: the walk-out for somebody steady, the turn for somebody drifting
        for k, s in c.get("press_end", {}).items():
            rows.append(check("line", cid + ".press_end." + k, s))
        # the visit's page of the report: who it was, what the player did beside what was true,
        # and how it ended; and its row among the totals
        role = tr("%s, %d" % (c["role"], int(c["age"]))) + tally_gap + tr("For: %s" % c["request"])
        rows.append(check("report_tally", cid + ":_draw_visit_page role", role))
        was = max((tr("%s was %s." % (c["name"], t)) for t in ("STEADY", "DRIFTING")), key=lambda t: text_width(t, True))
        w = text_width(widest_call, True) + 1 + SLIP_GAP + text_width(was, True) + 1
        rows.append(("visit_call", cid + ":_draw_visit_page call", w, widest_call + " | " + was,
                     " TOO WIDE (limit %d)" % REPORT_WIDTH if w > REPORT_WIDTH else ""))
        rows.append(check("report_name", cid + ".name (totals row)", c["name"], bold=True, limit=REPORT_NAME_ROOM - 4))
        # how a visit ends, for either truth: the night decides which of the two it is
        for truth, ends in c["outcomes"].items():
            for k, o in ends.items():
                where = "%s.outcomes.%s.%s" % (cid, truth, k)
                rows.append(check("outcome", where, o["text"]))
                rows.append(check_lines("visit_text", where + ".lines", o["text"], REPORT_WIDTH - 16, visit_lines))
                rows.append(check("visit_title", where + ".title", o["title"], bold=True))
                rows.append(check("totals_row", where + ".title (totals row)", o["title"],
                                  limit=REPORT_VISIT_ROOM - tw(widest_money) - SLIP_GAP))
        rows.append(check("line", cid + ".teaser", c["teaser"]))
        for k, v in c["lines"].items():
            for s in (v if isinstance(v, list) else [v]):
                rows.append(check("line", cid + ".lines." + k, s))
        for k, s in c.get("exit", {}).items():
            rows.append(check("line", cid + ".exit." + k, s))
    # the slip: its number and the patient's name, what happened at the counter (rules.json
    # "counter", filled with the widest name), and under the rule what the counter took in
    names = [c["name"] for c in cases]
    longest_name = max(names, key=tw) if names else ""
    visitors = int(rules.get("night", {}).get("visitors", len(rules.get("shift_order", []))))
    head = tr("INTAKE SLIP %d/%d" % (visitors, visitors))
    w = text_width(head) + 1 + SLIP_GAP + tw(longest_name) + 1
    rows.append(("slip_call", "main.gd:_draw_slip head", w, head + " | " + longest_name,
                 " TOO WIDE (limit %d)" % SLIP_WIDTH if w > SLIP_WIDTH else ""))
    counter = rules.get("counter", {})
    if not counter:
        rows.append(("slip_title", "rules.counter", 0, "", " NO COUNTER WORDS FOUND"))
    for k, e in counter.items():
        title = tr(e.get("title", ""))
        if text_width(title, True, 2) > SLIP_WIDTH:
            rows.append(check("slip_title", "rules.counter." + k + ".title (small)", title, bold=True))
        else:
            rows.append(check("slip_title", "rules.counter." + k + ".title", title, bold=True, scale=2))
        said = fill(tr(e.get("text", "")), {"name": longest_name})
        rows.append(check_lines("slip_text", "rules.counter." + k + ".lines", said, SLIP_WIDTH, SLIP_LINES))
    # the figure beside AT THE COUNTER is all the counter took in (main.gd: _draw_slip): a fee or
    # none, with or without a courier's package, less the calm-patches
    drop_pay = int(contacts.get("pay", 0))
    counter_figures = sorted({f + d - c for f in fees | {0} for d in (0, drop_pay) for c in (0, calm_most)})
    widest = max(text_width(tr("%s credits" % money(v)), True) + 1 for v in counter_figures)
    room = SLIP_WIDTH - widest - SLIP_GAP
    for label in [t for n, t in consts(MAIN_GD, r"^SLIP_COUNTER$")] or [""]:
        w = tw(label, True) + 1
        flag = " NO COUNTER LABEL FOUND" if label == "" else ""
        if label and tw(label) + 1 > room:
            flag = " TOUCHES THE MONEY (room %d px)" % room
        elif label and w > room:
            flag = " NOT BOLD (bold needs %d px, room %d px)" % (w, room)
        rows.append(("slip_call", "main.gd:SLIP_COUNTER", w, label, flag))
    for name, text in consts(MAIN_GD, r"^SLIP_LATER$"):
        rows.append(check("slip_call", "main.gd:" + name, text, limit=SLIP_WIDTH))
    # the numbers the words are filled with (main.gd: _ready)
    # one visitor is one hour (rules.json night.visitors since rules version 9)
    hours = visitors
    per_hour = int(rules.get("line", {}).get("per_hour", 0))
    threshold = int(rules["visit"]["threshold"])
    glass = int(rules.get("attack", {}).get("glass", 0))
    repair_cost = int(rules.get("attack", {}).get("repair_cost", 0))
    # the most glass a night can buy: a whole pane before every patient
    repair_most = repair_cost * glass * hours
    costs = rules.get("costs", {})
    numbers = {"lamps": int(rules["visit"]["lamps"]), "idle": int(rules["patience"]["leave_ms"]/1000), "per_hour": per_hour, "hours": hours, "total": per_hour * hours, "threshold": threshold,
               "repair_cost": repair_cost, "pay": int(contacts.get("pay", 0)), "code_cost": int(contacts.get("wrong_cost", 0)),
               "per_night": int(contacts.get("per_night", 0)), "calm_cost": int(reassure.get("cost", 0)),
               "catch_bonus": int(rules["scoring"]["press_catch_bonus"]), "calm_gain": int(reassure.get("gain", 0)), "ask_cost": int(costs.get("ask", 0)),
               "press_cost": int(costs.get("press", 0)), "check_cost": int(costs.get("check", 0)), "glass": glass,
               "false_alarm": abs(int(rules.get("scoring", {}).get("false_alarm", 0)))}
    contact_data = json.load(open(os.path.join(DATA, "contacts.json"), encoding="utf-8"))
    packages = [str(e.get("package", "")) for e in contact_data.get("pool", [])]
    longest_package = max(packages, key=lambda t: tw(t)) if packages else ""
    aliases = [str(a) for a in contact_data.get("aliases", [])]
    # the widest readings: every hour at the dearest fee with Trauma Team's bounty on top, and
    # every drop of the night; or every hour at the worst a visit can cost
    best = (max(fees | {0}) + max(0, int(rules["scoring"].get("refer_drifting", 0)))) * hours \
        + int(contacts.get("pay", 0)) * int(contacts.get("per_night", 0))
    worst = min(int(v) for v in rules["scoring"].values() if not isinstance(v, str)) * hours
    line_total = per_hour * hours
    # the end-of-shift report
    for t in rules.get("titles", []):
        rows.append(check("report_title", "rules.titles." + t["title"], t["title"], bold=True, scale=2))
        rows.append(check_lines("report_text", "rules.titles." + t["title"] + ".lines", t["text"], LIMITS["report_line"], REPORT_LINES))
        if "last_visitor_text" in t:
            rows.append(check_lines("report_text", "rules.titles.last_visitor", t["last_visitor_text"], LIMITS["report_line"], REPORT_LINES))
    line_text = rules.get("line_text", {})
    if not line_text:
        rows.append(("report_line", "rules.line_text", 0, "", " NO METER LINES FOUND"))
    for k, s in line_text.items():
        rows.append(check("report_line", "rules.line_text." + k, s))
    for name, text in consts(SCREENS_GD, r"_ROW$"):
        values = [repair_most] if name == "TILL_GLASS_ROW" else [hours, per_hour]
        rows.append(check("report_row", "screens.gd:" + name, worst_numbers(text, values), bold=name in ("OVER_ROW", "UNDER_ROW")))
    for name, text in consts(SCREENS_GD, r"^UNSEEN$"):
        rows.append(check("totals_row", "screens.gd:" + name, text, limit=REPORT_VISIT_ROOM - tw(widest_money) - SLIP_GAP))
    tally_words = dict(consts(SCREENS_GD, r"^TALLY_"))
    tally = tally_words.get("TALLY_GAP", "   •   ").join(
        tr(worst_numbers(tally_words.get(k, k), [hours, hours])) for k in ("TALLY_CALLS", "TALLY_UNDER"))
    rows.append(check("report_tally", "screens.gd:_draw_totals tally", tally))
    for name, text in consts(SCREENS_GD, r"^DROPS_TALLY$"):
        per_night = int(contacts.get("per_night", 0))
        rows.append(check("report_tally", "screens.gd:" + name,
                          worst_numbers(text, [per_night, per_night, per_night * int(contacts.get("pay", 0))])))
    # a visit's page: its place in the report, the verdict, its money and what was not the call's
    # own, and the words that turn the page
    page_of = dict(consts(SCREENS_GD, r"^PAGE_OF$")).get("PAGE_OF", "")
    head = tr("END OF SHIFT")
    w = text_width(head, True) + 1 + SLIP_GAP + tw(worst_numbers(page_of, [hours, hours])) + 1
    rows.append(("report_tally", "screens.gd:_draw_visit_page head", w, head + " | " + tr(worst_numbers(page_of, [hours, hours])),
                 " TOO WIDE (limit %d)" % REPORT_WIDTH if w > REPORT_WIDTH else ""))
    found = verdicts()
    if not found:
        rows.append(("report_title", "screens.gd:_verdict_of", 0, "", " NO VERDICTS FOUND"))
    for text in found:
        rows.append(check("report_title", "screens.gd:_verdict_of", text, scale=2))
    small = dict(consts(SCREENS_GD, r"^VISIT_"))
    if len([k for k in small if k in ("VISIT_DROP", "VISIT_NO_DROP", "VISIT_MONEY")]) < 3:
        rows.append(("report_tally", "screens.gd:_draw_visit_page", 0, "", " NO VISIT LINE WORDS FOUND"))
    else:
        extra = tr(max(worst_numbers(small["VISIT_DROP"], [int(contacts.get("pay", 0))]), small["VISIT_NO_DROP"], key=tw))
        rows.append(check("report_tally", "screens.gd:_visit_extra", extra))
        rows.append(check("report_tally", "screens.gd:VISIT_MONEY", small["VISIT_MONEY"].replace("%s", widest_money)))
    # the words that turn a page, and on the totals start the next night or the same one again
    prompts = consts(SCREENS_GD, r"^(NEXT_VISIT|TO_TOTALS|NEXT_NIGHT|TRY_AGAIN)$")
    if len(prompts) < 4:
        rows.append(("report_tally", "screens.gd", 0, "", " NO PAGE PROMPTS FOUND"))
    for name, text in prompts:
        rows.append(check("report_tally", "screens.gd:" + name, text, bold=True))
    keys = consts(SCREENS_GD, r"^(PAGE_KEYS|TOTALS_KEYS)$")
    if len(keys) < 2:
        rows.append(("report_tally", "screens.gd", 0, "", " NO PAGE KEYS FOUND"))
    for name, text in keys:
        rows.append(check("report_tally", "screens.gd:" + name, text))
    # the title card
    for name, text in consts(SCREENS_GD, r"^HELP"):
        rows.append(check("screen", "screens.gd:" + name, text))
    rows += title_rows()
    rows += settings_rows()
    for name, text in consts(SCREENS_GD, r"^SUBTITLE$"):
        rows.append(check("screen", "screens.gd:" + name, text))
    status = consts(MAIN_GD, r"^STATUS_")
    if not status:
        rows.append(("screen", "main.gd", 0, "", " NO STATUS LINES FOUND"))
    for name, text in status:
        rows.append(check("screen", "main.gd:" + name, text))
    # the dialogue strip: hints (one line), and what the meter and the radio say (one page)
    found = hints()
    if not found:
        rows.append(("hint", "main.gd", 0, "", " NO HINTS FOUND"))
    calm_uses = int(reassure.get("uses", 0))
    hint_values = {"GLASS_HINT": [repair_cost],




                   "SAY_CODE_HINT": [numbers["code_cost"]], "CODE_BLANK_HINT": [numbers["code_cost"]],
                   "PRESS_HINT": [numbers["press_cost"]]}
    for name, h in found:
        rows.append(check("hint", "main.gd:" + name, worst_numbers(h, hint_values.get(name, [len(sheet["rows"])] * 2))))
    said = consts(MAIN_GD, r"_LINE$")
    for name, text in said:
        if name.startswith("STOP_"):
            continue
        if name == "METER_OVER_LINE":
            text = worst_numbers(text, [hours, hours, best, line_total])
        elif name == "METER_UNDER_LINE":
            text = worst_numbers(text, [hours, hours, worst, line_total, line_total - worst])
        elif name == "SHIFT_LINE":
            text = worst_numbers(text, [hours, per_hour])
        elif name == "SHIFT_LIST_LINE":
            text = worst_numbers(text, [hours, numbers["per_night"], per_hour])
        elif name == "DROP_LINE":
            text = worst_numbers(text.replace("%s", longest_package, 1), [numbers["pay"]])
        elif name == "GLASS_LINE":
            text = worst_numbers(text, [repair_cost, glass, glass])
        rows.append(check_lines("strip_text", "main.gd:" + name, text, STRIP_WIDTH, STRIP_LINES))
    # the attack bar's last word
    plates = [(n, t) for n, t in said if n.startswith("STOP_")]
    if not plates:
        rows.append(("plate", "main.gd", 0, "", " NO STOP PLATES FOUND"))
    for name, text in plates:
        for blows in (range(1, glass + 1) if "%d" in text else [0]):
            rows.append(check("plate", "main.gd:" + name, worst_numbers(text, [blows]), bold=True))
    # the player's own count in the DECISION box
    for name, text in consts(CLIPBOARD_GD, r"^TALLY$"):
        rows.append(check("tally", "clipboard.gd:" + name, worst_numbers(text, [len(sheet["rows"]), threshold]), bold=True))
    # the opening cards and the counter guide
    intro = json.load(open(os.path.join(DATA, "intro.json"), encoding="utf-8"))
    rows += intro_rows(intro, numbers)
    rows += guide_rows(intro, numbers)
    rows += training_rows(intro, numbers)
    rows += howto_rows(intro, numbers)
    # the slip's breakdown line under the call (main.gd: _slip_breakdown): the longest it can be
    named = dict(consts(MAIN_GD, r"^SLIP_(FEE|DROP)$"))
    if len(named) < 2:
        rows.append(("slip_call", "main.gd:SLIP_*", 0, "", " NO BREAKDOWN WORDS FOUND"))
    else:
        worst = "  •  ".join([tr(worst_numbers(named["SLIP_FEE"], [max(fees | {0})])),
                             tr(worst_numbers(named["SLIP_DROP"], [numbers["pay"]]))])
        rows.append(("slip_call", "main.gd:_slip_breakdown", tw(worst), worst,
                     " WIDER THAN THE SLIP (%d px)" % SLIP_WIDTH if tw(worst) > SLIP_WIDTH else ""))
    # tonight's contact list (clipboard.gd: _draw_list_paper), one column: each alias with what
    # stands on its right (the SAY button, "blank look" or the PICKED UP stamp), each clue with its
    # bullet, and each code line in its quotes
    list_room = int(number(CLIPBOARD_GD, "LIST_RIGHT") - number(CLIPBOARD_GD, "LIST_X"))
    say_w = int(re.search(r"^const SAY_SIZE := Vector2\((\d+)", source(CLIPBOARD_GD), re.M).group(1))
    right_w = max(say_w, tw("PICKED UP", True) + 6, tw("blank look"))
    if not aliases or not contact_data.get("codes"):
        rows.append(("list", "contacts.json", 0, "", " NO ALIASES OR CODES FOUND"))
    for a in aliases:
        rows.append(check("list", "contacts.aliases." + a, a, bold=True, limit=list_room - right_w - 6))
    for cid, clue in contact_data.get("clues", {}).items():
        rows.append(check("list", "contacts.clues." + cid, "• " + str(clue.get("text", "")), limit=list_room))
    for i, code in enumerate(contact_data.get("codes", [])):
        rows.append(check("list", "contacts.codes.%d" % i, '"%s"' % str(code.get("say", "")), limit=list_room))
    bad = [r for r in rows if r[4]]
    by_kind = {}
    for kind, where, w, text, flag in rows:
        by_kind.setdefault(kind, []).append(w)
    for kind, ws in sorted(by_kind.items()):
        unit = "lines" if kind in ("slip_text", "report_text", "visit_text", "strip_text", "card_text", "guide_item",
                                   "training", "finding", "howto", "setting_hint") else "px"
        print("%-12s n=%-3d max=%d %s" % (kind, len(ws), max(ws), unit))
    for kind, where, w, text, flag in bad:
        print("!! %s %s (%d)%s: %s" % (kind, where, w, flag, text))
    if LANG != "en":
        word = re.compile(r"[A-Za-z][A-Za-z'-]+")
        left = sorted(t for t in UNMATCHED if any(m.group(0).lower().rstrip("-'") not in _KEEP for m in word.finditer(t)))
        for t in left:
            print("?? measured in English (no %s line accounts for it): %s" % (LANG, t))
        print("in %s: %d lines measured in English" % (LANG, len(left)))
    print("%d lines measured, %d problems" % (len(rows), len(bad)))
    return 1 if bad else 0


if __name__ == "__main__":
    sys.exit(main())
