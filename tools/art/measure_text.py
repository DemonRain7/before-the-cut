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
# "slip_title" is an outcome title in the big font across the result slip; wider than this and
# the slip falls back to the small font. "report_title" is the big title on the end-of-shift
# report, "report_line" one centred line of its text, "report_row" a label of its figures (the
# figure is right-aligned on the same row; the meter row has five lamps there), "report_tally"
# the last line across the report.
# "hint" is the one dim line at the foot of the dialogue strip (dialogue_box.gd: TEXT_W); it does not wrap.
# "plate" is the bold line that takes the attack bar's place once the shutter is down
# (clinic_view.gd: SLOT, 207 px wide). "tally" is the bold count in the record's DECISION box
# (clipboard.gd: DECISION, 78 px wide). "screen" is one centred line across the whole screen
# (title card, opening cards). "lit_item" is one line of the lease picture's list.
LIMITS = {"note": 186, "look": 186, "sheet": 182, "footer": 220, "row": 176, "question": 180, "name": 120, "request": 140,
          "slip_title": 180, "report_title": 368, "report_line": 352, "report_row": 286, "report_tally": 368, "hint": 376,
          "plate": 203, "tally": 74, "screen": 624}
SLIP_WIDTH = 180        # the text column of the result slip (main.gd: _draw_slip)
SLIP_GAP = 8            # least space between the call and the money on its last line (main.gd: SLIP_GAP)
REPORT_VISIT_ROOM = 258 # a visit's second line on the report, from the call (x0 + 110) to the figure column (x1)
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
    RAW.update(str(e.get("alias", "")) for e in contacts.get("pool", []))
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


REC_TEXT_X = 448        # clipboard.gd: the record card's text column
REC_TEXT_W = 186
REC_NOTE_RIGHT = 632    # clipboard.gd: where "you did not check" ends, at the right of the label's line
LABEL_GAP = 6           # clipboard.gd: LABEL_GAP
TALL_LINES = ("zh",)    # gfx.gd tall_lines: the languages whose lines fill their box


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
    """A case's row text on the record card after the call (clipboard.gd _draw_findings), which
    has room for two lines: under the label, or, in a language whose lines fill their box, one
    after the label and one under it (_finding_after), with "you did not check" at the right end
    of the label's line (measured as if it always were). The game's own widths count the gap
    after the last letter, one pixel more than text_width."""
    text = tr(text)
    missing = missing_glyphs(text)
    if LANG in TALL_LINES:
        x = REC_TEXT_X + text_width(tr("NORMAL" if ok else "BROKEN LINE"), True) + 1 + LABEL_GAP
        right = REC_NOTE_RIGHT - (text_width(tr("you did not check")) + 1) - LABEL_GAP
        lines = wrap_after(text, right - x, REC_TEXT_W)
    else:
        lines = wrap(text, REC_TEXT_W)
    flag = ""
    if missing:
        flag += " MISSING GLYPHS %r" % "".join(missing)
    if len(lines) > 2:
        flag += " TOO MANY LINES (%d, room for 2)" % len(lines)
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


def slip_calls():
    """The call labels the result slip can print, read from the game source so they cannot drift."""
    src = source(MAIN_GD)
    body = src[src.index("func _draw_slip"):]
    return sorted(set(re.findall(r'"((?:RIGHT|WRONG|NO) CALL[^"]*)"', body)))


HINT_TABLES = ("MIC_HINTS", "OBJECT_HINT", "TAB_HINT", "SCOPE_HINT")


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
                  "continue", "talk", "look", "check:penlight", "check:grip", "check:port"}
TRAINING_AREAS = {"list", "sheet", "card", "marks", "guide", "cam", "code", "tools", "talk", "decide", "slip",
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
    fees = set()
    for path in sorted(glob.glob(os.path.join(DATA, "cases", "*.json"))):
        c = json.load(open(path, encoding="utf-8"))
        cid = c["id"]
        rows.append(check("name", cid + ".name", c["name"], bold=True))
        rows.append(check("request", cid + ".request", c["request"]))
        for z, t in c["looks"].items():
            rows.append(check("look", cid + ".looks." + z, t))
        for t, chk in c["checks"].items():
            rows.append(check("note", cid + ".checks." + t, chk["note"].replace("{t}", "0.0")))
        for k, cl in c.get("claims", {}).items():
            rows.append(check("note", cid + ".claims." + k, cl["note"]))
        for tp in c["topics"]:
            rows.append(check("question", cid + ".topics." + tp["id"] + ".q", tp["q"]))
            rows.append(check("note", cid + ".topics." + tp["id"] + ".note", tp["note"]))
            rows.append(check("line", cid + ".topics." + tp["id"] + ".a", tp["a"]))
        for i, p in enumerate(c["press"]):
            if "note" in p:
                rows.append(check("note", cid + ".press%d.note" % i, p["note"]))
            rows.append(check("line", cid + ".press%d.line" % i, p["line"]))
        for r, row in c["rows"].items():
            rows.append(check_finding(cid + ".rows." + r, row["text"], bool(row.get("ok", True))))
        for k, o in c["outcomes"].items():
            rows.append(check("outcome", cid + ".outcomes." + k, o["text"]))
            rows.append(check_lines("slip_text", cid + ".outcomes." + k + ".lines", o["text"], SLIP_WIDTH, SLIP_LINES))
            rows.append(check("slip_title", cid + ".outcomes." + k + ".title", o["title"], bold=True, scale=2))
        rows.append(check("line", cid + ".teaser", c["teaser"]))
        for k, v in c["lines"].items():
            for s in (v if isinstance(v, list) else [v]):
                rows.append(check("line", cid + ".lines." + k, s))
        for k, s in c.get("exit", {}).items():
            rows.append(check("line", cid + ".exit." + k, s))
        fees.add(int(c.get("fee", 0)))
    # the slip's last line: the call on the left, the money on the right, both bold when there is room
    rules = json.load(open(os.path.join(DATA, "rules.json"), encoding="utf-8"))
    figures = sorted(fees | set(int(v) for v in rules["scoring"].values()) | {0})
    widest = max(tw("%s credits" % money(v), True) for v in figures)
    calls = slip_calls()
    if not calls:
        rows.append(("slip_call", "main.gd:_draw_slip", 0, "", " NO CALL LABELS FOUND"))
    for label in calls:
        room = SLIP_WIDTH - widest - SLIP_GAP
        w = tw(label, True)
        flag = ""
        if tw(label) > room:
            flag = " TOUCHES THE MONEY (room %d px)" % room
        elif w > room:
            flag = " NOT BOLD (bold needs %d px, room %d px)" % (w, room)
        rows.append(("slip_call", "main.gd:_draw_slip", w, label, flag))
    # the numbers the words are filled with (main.gd: _ready)
    hours = len(rules.get("shift_order", []))
    per_hour = int(rules.get("line", {}).get("per_hour", 0))
    threshold = int(sheet.get("threshold", 0))
    glass = int(rules.get("attack", {}).get("glass", 0))
    repair_cost = int(rules.get("attack", {}).get("repair_cost", 0))
    # the most glass a night can buy: a whole pane before every patient
    repair_most = repair_cost * glass * hours
    contacts = rules.get("contacts", {})
    reassure = rules.get("reassure", {})
    costs = rules.get("costs", {})
    numbers = {"per_hour": per_hour, "hours": hours, "total": per_hour * hours, "threshold": threshold,
               "repair_cost": repair_cost, "pay": int(contacts.get("pay", 0)), "code_cost": int(contacts.get("wrong_cost", 0)),
               "per_night": int(contacts.get("per_night", 0)), "calm_cost": int(reassure.get("cost", 0)),
               "calm_gain": int(reassure.get("gain", 0)), "ask_cost": int(costs.get("ask", 0)),
               "press_cost": int(costs.get("press", 0))}
    contact_data = json.load(open(os.path.join(DATA, "contacts.json"), encoding="utf-8"))
    packages = [str(e.get("package", "")) for e in contact_data.get("pool", [])]
    longest_package = max(packages, key=lambda t: tw(t)) if packages else ""
    aliases = [str(e.get("alias", "")) for e in contact_data.get("pool", [])]
    longest_alias = max(aliases, key=lambda t: tw(t, True)) if aliases else ""
    best = sum(sorted(fees | {int(rules["scoring"].get("refer_drifting", 0))}, reverse=True)[:1]) * hours
    worst = min(int(v) for v in rules["scoring"].values()) * hours
    line_total = per_hour * hours
    # the end-of-shift report
    for t in rules.get("titles", []):
        rows.append(check("report_title", "rules.titles." + t["title"], t["title"], bold=True, scale=2))
        rows.append(check_lines("report_text", "rules.titles." + t["title"] + ".lines", t["text"], LIMITS["report_line"], REPORT_LINES))
    line_text = rules.get("line_text", {})
    if not line_text:
        rows.append(("report_line", "rules.line_text", 0, "", " NO METER LINES FOUND"))
    for k, s in line_text.items():
        rows.append(check("report_line", "rules.line_text." + k, s))
    for name, text in consts(SCREENS_GD, r"_ROW$"):
        values = [repair_most] if name == "TILL_GLASS_ROW" else [hours, per_hour]
        rows.append(check("report_row", "screens.gd:" + name, worst_numbers(text, values), bold=name in ("OVER_ROW", "UNDER_ROW")))
    tally_words = dict(consts(SCREENS_GD, r"^TALLY_"))
    tally = tally_words.get("TALLY_GAP", "   •   ").join(
        tr(worst_numbers(tally_words.get(k, k), [hours, hours])) for k in ("TALLY_CALLS", "TALLY_UNDER", "TALLY_HURT"))
    rows.append(check("report_tally", "screens.gd:_draw_report tally", tally))
    for name, text in consts(SCREENS_GD, r"^DROPS_TALLY$"):
        per_night = int(contacts.get("per_night", 0))
        rows.append(check("report_tally", "screens.gd:" + name,
                          worst_numbers(text, [per_night, per_night, per_night * int(contacts.get("pay", 0))])))
    # a visit's second line: what the doctor did at x0 + 110, and what was not the call's own at x1
    src = source(SCREENS_GD)
    body = src[src.index("func _call_text"):]
    said_calls = re.findall(r'return "([^"]+)"', body)
    small = dict(consts(SCREENS_GD, r"^VISIT_"))
    if not said_calls or len(small) < 3:
        rows.append(("report_row", "screens.gd:_draw_report", 0, "", " NO VISIT LINE WORDS FOUND"))
    else:
        calm_most = int(reassure.get("cost", 0)) * int(reassure.get("uses", 0))
        extra = "   ".join([tr(max(worst_numbers(small["VISIT_DROP"], [int(contacts.get("pay", 0))]), small["VISIT_NO_DROP"],
                                   key=tw)), tr(worst_numbers(small["VISIT_CALM"], [calm_most]))])
        call = max(said_calls, key=tw)
        room = REPORT_VISIT_ROOM - tw(call) - SLIP_GAP
        rows.append(("report_row", "screens.gd:_visit_extra", tw(extra), extra,
                     " RUNS INTO '%s' (room %d px)" % (call, room) if tw(extra) > room else ""))
    # the title card
    for name, text in consts(SCREENS_GD, r"^HELP"):
        rows.append(check("screen", "screens.gd:" + name, text))
    src = source(SCREENS_GD)
    block = src[src.index("const TITLE_LINES"):]
    block = block[:block.index("]")]
    for i, text in enumerate(re.findall(r'"([^"]*)"', block)):
        rows.append(check("screen", "screens.gd:TITLE_LINES%d" % i, text))
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
                   "CALM_HINT": [numbers["calm_cost"], numbers["calm_gain"], calm_uses],
                   "CALM_HOLD_HINT": [numbers["calm_cost"], numbers["calm_gain"], calm_uses],
                   "CALM_FREE_HINT": [numbers["calm_gain"], calm_uses],
                   "CALM_FREE_HOLD_HINT": [numbers["calm_gain"], calm_uses],
                   "SAY_CODE_HINT": [numbers["code_cost"]], "CODE_BLANK_HINT": [numbers["code_cost"]]}
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
    # the slip's breakdown line under the call (main.gd: _slip_breakdown): the longest it can be
    named = dict(consts(MAIN_GD, r"^SLIP_(DROP|NO_DROP|CALM)$"))
    if len(named) < 3:
        rows.append(("slip_call", "main.gd:SLIP_*", 0, "", " NO BREAKDOWN WORDS FOUND"))
    else:
        worst = "  •  ".join([tr(max(worst_numbers(named["SLIP_DROP"], [numbers["pay"]]),
                                     named["SLIP_NO_DROP"].replace("%s", longest_alias), key=tw)),
                             tr(worst_numbers(named["SLIP_CALM"], [numbers["calm_cost"] * calm_uses]))])
        rows.append(("slip_call", "main.gd:_slip_breakdown", tw(worst), worst,
                     " WIDER THAN THE SLIP (%d px)" % SLIP_WIDTH if tw(worst) > SLIP_WIDTH else ""))
    bad = [r for r in rows if r[4]]
    by_kind = {}
    for kind, where, w, text, flag in rows:
        by_kind.setdefault(kind, []).append(w)
    for kind, ws in sorted(by_kind.items()):
        unit = "lines" if kind in ("slip_text", "report_text", "strip_text", "card_text", "guide_item", "training",
                                   "finding") else "px"
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
