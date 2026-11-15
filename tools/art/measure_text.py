"""Measure authored game text in the Counter Sans bitmap font.

Run from tools/art:  python measure_text.py
Prints every line that is wider than the space the interface gives it.
"""
import glob
import json
import os
import re

from font_data import _G, text_width
from px import ROOT

DATA = os.path.join(ROOT, "game", "data")
MAIN_GD = os.path.join(ROOT, "game", "scripts", "ui", "main.gd")
# "sheet" is the text column of a sheet row; "footer" is centred across the whole sheet.
# "slip_title" is an outcome title in the big font across the result slip; wider than this and
# the slip falls back to the small font. "report_title" is the big title on the end-of-shift
# report, "report_line" one centred line of its text.
# "hint" is the one dim line at the foot of the dialogue strip (dialogue_box.gd: TEXT_W); it does not wrap.
LIMITS = {"note": 186, "look": 186, "sheet": 182, "footer": 220, "row": 176, "question": 180, "name": 120, "request": 140,
          "slip_title": 180, "report_title": 368, "report_line": 352, "hint": 376}
SLIP_WIDTH = 180        # the text column of the result slip (main.gd: _draw_slip)
SLIP_GAP = 8            # least space between the call and the money on its last line (main.gd: SLIP_GAP)
SLIP_LINES = 6          # lines of outcome text the slip has room for
REPORT_LINES = 3        # lines of title text the report has room for above the rent line and the tally


def check(kind, where, text, bold=False, scale=1):
    missing = sorted({ch for ch in text if ch not in _G})
    w = text_width(text, bold, scale)
    flag = ""
    if missing:
        flag += " MISSING GLYPHS %r" % "".join(missing)
    if kind in LIMITS and w > LIMITS[kind]:
        flag += " TOO WIDE (limit %d)" % LIMITS[kind]
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
    n = len(wrap(text, width))
    flag = ""
    if missing:
        flag += " MISSING GLYPHS %r" % "".join(missing)
    if n > most:
        flag += " TOO MANY LINES (%d, room for %d at %d px)" % (n, most, width)
    return (kind, where, n, text, flag)


def money(v):
    return "+%d" % v if v > 0 else str(v)


def slip_calls():
    """The call labels the result slip can print, read from the game source so they cannot drift."""
    src = open(MAIN_GD, encoding="utf-8").read()
    body = src[src.index("func _draw_slip"):]
    return sorted(set(re.findall(r'"((?:RIGHT|WRONG|NO) CALL[^"]*)"', body)))


def hints():
    """The fixed hints main.gd can show: every *_HINT constant and the MIC_HINTS table.
    Hints built with % at run time are not covered."""
    src = open(MAIN_GD, encoding="utf-8").read()
    out = re.findall(r'^const ([A-Z_]*HINT[A-Z_]*) := "([^"]*)"', src, re.M)
    table = src[src.index("const MIC_HINTS"):]
    table = table[:table.index("}")]
    out += [("MIC_HINTS." + k, v) for k, v in re.findall(r'"(\w+)":\s*"([^"]*)"', table)]
    return out


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
    # the end-of-shift report
    for t in rules.get("titles", []):
        rows.append(check("report_title", "rules.titles." + t["title"], t["title"], bold=True, scale=2))
        rows.append(check_lines("report_text", "rules.titles." + t["title"] + ".lines", t["text"], LIMITS["report_line"], REPORT_LINES))
    for k, s in rules.get("rent_text", {}).items():
        rows.append(check("report_line", "rules.rent_text." + k, s))
    found = hints()
    if not found:
        rows.append(("hint", "main.gd", 0, "", " NO HINTS FOUND"))
    for name, h in found:
        rows.append(check("hint", "main.gd:" + name, h))
    bad = [r for r in rows if r[4]]
    by_kind = {}
    for kind, where, w, text, flag in rows:
        by_kind.setdefault(kind, []).append(w)
    for kind, ws in sorted(by_kind.items()):
        unit = "lines" if kind in ("slip_text", "report_text") else "px"
        print("%-12s n=%-3d max=%d %s" % (kind, len(ws), max(ws), unit))
    for kind, where, w, text, flag in bad:
        print("!! %s %s (%d)%s: %s" % (kind, where, w, flag, text))
    print("%d lines measured, %d problems" % (len(rows), len(bad)))


if __name__ == "__main__":
    main()
