"""Measure authored game text in the Counter Sans bitmap font.

Run from tools/art:  python measure_text.py
Prints every line that is wider than the space the interface gives it, needs more lines than
its box has, or uses a letter the font does not have.
"""
import glob
import json
import os
import re

from font_data import _G, text_width
from px import ROOT

DATA = os.path.join(ROOT, "game", "data")
UI = os.path.join(ROOT, "game", "scripts", "ui")
MAIN_GD = os.path.join(UI, "main.gd")
SCREENS_GD = os.path.join(UI, "screens.gd")
CLIPBOARD_GD = os.path.join(UI, "clipboard.gd")
INTRO_GD = os.path.join(UI, "intro.gd")
GUIDE_GD = os.path.join(UI, "guide.gd")
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
SLIP_LINES = 6          # lines of outcome text the slip has room for
REPORT_LINES = 3        # lines of title text the report has room for above the meter line and the tally
STRIP_WIDTH = 376       # the dialogue strip (dialogue_box.gd: TEXT_W)
STRIP_LINES = 2         # rows of speech on one page of it (dialogue_box.gd: PAGE_LINES)
SCREEN_H = 360
LINE = 10               # gfx.gd: LINE


def check(kind, where, text, bold=False, scale=1, limit=None):
    missing = sorted({ch for ch in text if ch not in _G})
    w = text_width(text, bold, scale)
    most = LIMITS.get(kind) if limit is None else limit
    flag = ""
    if missing:
        flag += " MISSING GLYPHS %r" % "".join(missing)
    if most is not None and w > most:
        flag += " TOO WIDE (limit %d)" % most
    return (kind, where, w, text, flag)


def wrap(text, width, bold=False):
    """The same greedy word wrap as Gfx.wrap_text in the game."""
    out = []
    for para in text.split("\n"):
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


def check_lines(kind, where, text, width, most):
    """A wrapped paragraph: reported by its line count, flagged when it needs more lines than there are."""
    missing = sorted({ch for ch in text if ch not in _G})
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
                          limit=text_w - text_width(counter) - 8))
        labels = c.get("labels", {})
        art = c.get("art", "")
        if art == "lease":
            # the paper is 212 px wide with 12 px margins; the lender's mark takes 30 px of the head
            rows.append(check("card_label", cid + ".head", labels.get("head", ""), bold=True, limit=212 - 24 - 30 - 4))
            rows.append(check("card_label", cid + ".sub", labels.get("sub", ""), limit=212 - 24 - 30 - 4))
            for i, item in enumerate(labels.get("items", [])):
                rows.append(check("card_label", cid + ".items%d" % i, item, limit=212 - 24 - 15))
            rows.append(check("card_label", cid + ".foot", labels.get("foot", ""), limit=212 - 24))
            rows.append(check("card_label", cid + ".stamp", labels.get("stamp", ""), bold=True, limit=74 - 8))
        elif art == "line":
            hours = int(numbers.get("hours", 5))
            per_hour = int(numbers.get("per_hour", 0))
            rows.append(check("card_label", cid + ".hour", labels.get("hour", ""), limit=38 - 8 - 2))
            head = "%s %d   %s %d" % (labels.get("hour", ""), hours, labels.get("line", ""), hours * per_hour)
            rows.append(check("card_label", cid + ".header", head, limit=360 - 44 - 18))
            step_w = 290 // max(1, hours)
            rows.append(check("card_label", cid + ".over", labels.get("over", ""), bold=True, limit=step_w * hours - 20))
            # the boxed word is centred on the last step and must stay inside the picture
            centre = 38 + step_w * (hours - 1)
            rows.append(check("card_label", cid + ".under", labels.get("under", ""), bold=True,
                              limit=2 * (360 - centre) - 12))
            rows.append(check("card_label", cid + ".step", str(hours * per_hour), limit=step_w - 4))
        elif art == "drift":
            both = labels.get("list", "") + labels.get("ask", "")
            rows.append(check("card_label", cid + ".list+ask", both, bold=True, limit=360 - 16 - 12))
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
                          limit=pw - pad * 2 - text_width(counter) - 6))
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


def main():
    rows = []
    sheet = json.load(open(os.path.join(DATA, "sheet.json"), encoding="utf-8"))
    for r in sheet["rows"]:
        rows.append(check("sheet", "sheet." + r["id"] + ".normal", r["normal"]))
        rows.append(check("sheet", "sheet." + r["id"] + ".ordinary", r["ordinary"]))
    for i, f in enumerate(sheet["footer"]):
        rows.append(check("footer", "sheet.footer%d" % i, f))
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
            rows.append(check("rowtext", cid + ".rows." + r, row["text"]))
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
    widest = max(text_width("%s credits" % money(v), True) for v in figures)
    calls = slip_calls()
    if not calls:
        rows.append(("slip_call", "main.gd:_draw_slip", 0, "", " NO CALL LABELS FOUND"))
    for label in calls:
        room = SLIP_WIDTH - widest - SLIP_GAP
        w = text_width(label, True)
        flag = ""
        if text_width(label) > room:
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
    numbers = {"per_hour": per_hour, "hours": hours, "total": per_hour * hours, "threshold": threshold,
               "repair_cost": repair_cost}
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
    tally = "Right calls: %d of %d   •   Hours under the line: %d   •   Times you were hurt: %d" % (hours, hours, hours, hours)
    rows.append(check("report_tally", "screens.gd:_draw_report tally", tally))
    # the title card
    for name, text in consts(SCREENS_GD, r"^HELP"):
        rows.append(check("screen", "screens.gd:" + name, text))
    src = source(SCREENS_GD)
    block = src[src.index("const TITLE_LINES"):]
    block = block[:block.index("]")]
    for i, text in enumerate(re.findall(r'"([^"]*)"', block)):
        rows.append(check("screen", "screens.gd:TITLE_LINES%d" % i, text))
    status = consts(MAIN_GD, r"^STATUS_")
    if not status:
        rows.append(("screen", "main.gd", 0, "", " NO STATUS LINES FOUND"))
    for name, text in status:
        rows.append(check("screen", "main.gd:" + name, text))
    # the dialogue strip: hints (one line), and what the meter and the radio say (one page)
    found = hints()
    if not found:
        rows.append(("hint", "main.gd", 0, "", " NO HINTS FOUND"))
    hint_values = {"GLASS_HINT": [repair_cost]}
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
    bad = [r for r in rows if r[4]]
    by_kind = {}
    for kind, where, w, text, flag in rows:
        by_kind.setdefault(kind, []).append(w)
    for kind, ws in sorted(by_kind.items()):
        unit = "lines" if kind in ("slip_text", "report_text", "strip_text", "card_text", "guide_item") else "px"
        print("%-12s n=%-3d max=%d %s" % (kind, len(ws), max(ws), unit))
    for kind, where, w, text, flag in bad:
        print("!! %s %s (%d)%s: %s" % (kind, where, w, flag, text))
    print("%d lines measured, %d problems" % (len(rows), len(bad)))


if __name__ == "__main__":
    main()
