"""Original bitmap font for Before the Cut ("Counter Sans", 7 px capitals).

Glyphs are drawn by hand below as rows separated by '/'. Row 0 is the top of
a capital, row 6 sits on the baseline, rows 7-8 hold descenders.
"""
import os

import numpy as np
from PIL import Image

ROWS = 9
BASE = 7            # rows above the baseline
TOP_PAD = 1         # blank pixel above capitals inside the line box
LINE_H = 11

_G = {
    " ": "...",
    "A": ".##./#..#/#..#/####/#..#/#..#/#..#",
    "B": "###./#..#/#..#/###./#..#/#..#/###.",
    "C": ".##./#..#/#.../#.../#.../#..#/.##.",
    "D": "###./#..#/#..#/#..#/#..#/#..#/###.",
    "E": "####/#.../#.../###./#.../#.../####",
    "F": "####/#.../#.../###./#.../#.../#...",
    "G": ".##./#..#/#.../#.##/#..#/#..#/.###",
    "H": "#..#/#..#/#..#/####/#..#/#..#/#..#",
    "I": "###/.#./.#./.#./.#./.#./###",
    "J": "..##/...#/...#/...#/...#/#..#/.##.",
    "K": "#..#/#..#/#.#./##../#.#./#..#/#..#",
    "L": "#.../#.../#.../#.../#.../#.../####",
    "M": "#...#/##.##/#.#.#/#.#.#/#...#/#...#/#...#",
    "N": "#..#/##.#/##.#/#.##/#.##/#..#/#..#",
    "O": ".##./#..#/#..#/#..#/#..#/#..#/.##.",
    "P": "###./#..#/#..#/###./#.../#.../#...",
    "Q": ".##./#..#/#..#/#..#/#..#/#.#./.#.#",
    "R": "###./#..#/#..#/###./#.#./#..#/#..#",
    "S": ".###/#.../#.../.##./...#/...#/###.",
    "T": "#####/..#../..#../..#../..#../..#../..#..",
    "U": "#..#/#..#/#..#/#..#/#..#/#..#/.##.",
    "V": "#...#/#...#/#...#/#...#/.#.#./.#.#./..#..",
    "W": "#...#/#...#/#...#/#.#.#/#.#.#/##.##/#...#",
    "X": "#...#/#...#/.#.#./..#../.#.#./#...#/#...#",
    "Y": "#...#/#...#/.#.#./..#../..#../..#../..#..",
    "Z": "####/...#/..#./.#../#.../#.../####",
    "a": "..../..../.##./...#/.###/#..#/.###",
    "b": "#.../#.../###./#..#/#..#/#..#/###.",
    "c": ".../.../.##/#../#../#../.##",
    "d": "...#/...#/.###/#..#/#..#/#..#/.###",
    "e": "..../..../.##./#..#/####/#.../.###",
    "f": ".##/#../###/#../#../#../#..",
    "g": "..../..../.###/#..#/#..#/#..#/.###/...#/.##.",
    "h": "#.../#.../###./#..#/#..#/#..#/#..#",
    "i": "#/./#/#/#/#/#",
    "j": ".#/../.#/.#/.#/.#/.#/.#/#.",
    "k": "#.../#.../#..#/#.#./##../#.#./#..#",
    "l": "#./#./#./#./#./#./.#",
    "m": "...../...../####./#.#.#/#.#.#/#.#.#/#.#.#",
    "n": "..../..../###./#..#/#..#/#..#/#..#",
    "o": "..../..../.##./#..#/#..#/#..#/.##.",
    "p": "..../..../###./#..#/#..#/#..#/###./#.../#...",
    "q": "..../..../.###/#..#/#..#/#..#/.###/...#/...#",
    "r": ".../.../#.#/##./#../#../#..",
    "s": "..../..../.###/#.../.##./...#/###.",
    "t": ".#./.#./###/.#./.#./.#./..#",
    "u": "..../..../#..#/#..#/#..#/#..#/.###",
    "v": ".../.../#.#/#.#/#.#/#.#/.#.",
    "w": "...../...../#...#/#.#.#/#.#.#/#.#.#/.#.#.",
    "x": ".../.../#.#/#.#/.#./#.#/#.#",
    "y": "..../..../#..#/#..#/#..#/#..#/.###/...#/.##.",
    "z": "..../..../####/..#./.#../#.../####",
    "0": ".##./#..#/#.##/##.#/#..#/#..#/.##.",
    "1": ".#./##./.#./.#./.#./.#./###",
    "2": ".##./#..#/...#/..#./.#../#.../####",
    "3": "###./...#/...#/.##./...#/...#/###.",
    "4": "#..#/#..#/#..#/####/...#/...#/...#",
    "5": "####/#.../###./...#/...#/#..#/.##.",
    "6": ".##./#.../#.../###./#..#/#..#/.##.",
    "7": "####/...#/...#/..#./..#./.#../.#..",
    "8": ".##./#..#/#..#/.##./#..#/#..#/.##.",
    "9": ".##./#..#/#..#/.###/...#/...#/.##.",
    ".": "./././././././#",
    ",": "../../../../../.#/.#/#.",
    "!": "#/#/#/#/#/./#",
    "?": ".##./#..#/...#/..#./.#../..../.#..",
    ":": "./././#/././#",
    ";": "../../../.#/../../.#/#.",
    "'": "#/#",
    '"': "#.#/#.#",
    "-": ".../.../.../.../###",
    "_": "..../..../..../..../..../..../..../####",
    "+": ".../.../.../.#./###/.#.",
    "=": ".../.../.../###/.../###",
    "/": "..#/..#/.#./.#./.#./#../#..",
    "\\": "#../#../.#./.#./.#./..#/..#",
    "(": ".#/#./#./#./#./#./.#",
    ")": "#./.#/.#/.#/.#/.#/#.",
    "[": "##/#./#./#./#./#./##",
    "]": "##/.#/.#/.#/.#/.#/##",
    "<": ".../..#/.#./#../.#./..#",
    ">": ".../#../.#./..#/.#./#..",
    "*": ".../#.#/.#./#.#",
    "#": "...../.#.#./#####/.#.#./#####/.#.#.",
    "$": "..#../.####/#.#../.###./..#.#/####./..#..",
    "%": "##..#/##.#./...#./..#../.#.../.#.##/#..##",
    "&": ".#.../#.#../#.#../.#.../#.#.#/#..#./.##.#",
    "@": ".###./#...#/#.###/#.#.#/#.###/#..../.###.",
    "^": ".#./#.#",
    "~": "..../..../..../.#.#/#.#.",
    "`": "#./.#",
    "|": "#/#/#/#/#/#/#/#",
    "{": ".##/.#./.#./#../.#./.#./.##",
    "}": "##./.#./.#./..#/.#./.#./##.",
    "✓": "......./......./......#/.....#./#...#../.#.#.../..#....",   # check
    "✗": "...../...../#...#/.#.#./..#../.#.#./#...#",                 # cross
    "•": "../../../##/##",                                            # bullet
    "►": ".../.../#../##./###/##./#..",                               # play
    "◄": ".../.../..#/.##/###/.##/..#",
    "…": "...../...../...../...../...../...../#.#.#",                 # ellipsis
    "–": "..../..../..../..../####",                                  # dash
    "●": "...../.###./#####/#####/#####/.###.",                       # full pip
    "○": "...../.###./#...#/#...#/#...#/.###.",                       # empty pip
    "→": "...../...../...#./#####/...#.",                             # arrow
}

_G["."] = "/".join(["."] * 6 + ["#"])

# hand-drawn bold forms where the automatic smear would fill the counters
_BOLD = {
    "M": "##...##/###.###/#######/##.#.##/##...##/##...##/##...##",
    "W": "##...##/##...##/##...##/##.#.##/#######/###.###/##...##",
    "m": "......./......./######./##.#.##/##.#.##/##.#.##/##.#.##",
    "w": "......./......./##...##/##.#.##/##.#.##/#######/.##.##.",
}


def _rows(ch):
    rows = _G[ch].split("/")
    w = len(rows[0])
    for r in rows:
        if len(r) != w:
            raise ValueError("glyph %r has ragged rows: %r" % (ch, rows))
    if len(rows) > ROWS:
        raise ValueError("glyph %r too tall" % ch)
    rows = rows + ["." * w] * (ROWS - len(rows))
    return rows


def glyph(ch, bold=False):
    """Boolean array ROWS x width."""
    if ch not in _G:
        ch = "?"
    rows = _rows(ch)
    a = np.array([[c == "#" for c in r] for r in rows], dtype=bool)
    if bold and ch != " ":
        if ch in _BOLD:
            rows = _BOLD[ch].split("/")
            rows = rows + ["." * len(rows[0])] * (ROWS - len(rows))
            return np.array([[c == "#" for c in r] for r in rows], dtype=bool)
        # widen one-pixel counters first so the smear does not close them
        w = a.shape[1]
        cols = []
        for x in range(w):
            cols.append(a[:, x])
            if 0 < x < w - 1 and np.any(~a[:, x] & a[:, x - 1] & a[:, x + 1]):
                cols.append(a[:, x])
        a = np.stack(cols, axis=1)
        b = np.zeros((a.shape[0], a.shape[1] + 1), dtype=bool)
        b[:, :-1] |= a
        b[:, 1:] |= a
        a = b
    return a


def advance(ch, bold=False):
    if ch == " ":
        return 3
    return glyph(ch, bold).shape[1] + 1


def text_width(s, bold=False, scale=1):
    if not s:
        return 0
    return (sum(advance(c, bold) for c in s) - 1) * scale


def draw_text(canvas, x, y, s, color, bold=False, scale=1):
    """Draw text with its top-left at (x, y). Returns the end x."""
    from px import col
    c = col(color)
    for ch in s:
        g = glyph(ch, bold)
        if scale > 1:
            g = np.repeat(np.repeat(g, scale, axis=0), scale, axis=1)
        h, w = g.shape
        for yy in range(h):
            for xx in range(w):
                if g[yy, xx]:
                    px, py = x + xx, y + yy
                    if 0 <= px < canvas.w and 0 <= py < canvas.h:
                        canvas.a[py, px, :3] = c
                        canvas.a[py, px, 3] = 255
        x += advance(ch, bold) * scale
    return x


def export_font(dirpath, name, bold=False, scale=1, line_h=LINE_H, face="Counter Sans"):
    """Write a BMFont text .fnt and its white-on-transparent atlas."""
    os.makedirs(dirpath, exist_ok=True)
    chars = sorted(_G.keys(), key=ord)
    cell_w = (max(glyph(c, bold).shape[1] for c in chars) + 1) * scale
    cell_h = (ROWS + 1) * scale
    per_row = 16
    n_rows = (len(chars) + per_row - 1) // per_row
    aw = 1
    while aw < cell_w * per_row:
        aw *= 2
    ah = 1
    while ah < cell_h * n_rows:
        ah *= 2
    atlas = np.zeros((ah, aw, 4), dtype=np.uint8)
    atlas[:, :, :3] = 255
    lines = []
    for i, ch in enumerate(chars):
        g = glyph(ch, bold)
        if scale > 1:
            g = np.repeat(np.repeat(g, scale, axis=0), scale, axis=1)
        h, w = g.shape
        x0 = (i % per_row) * cell_w
        y0 = (i // per_row) * cell_h
        atlas[y0:y0 + h, x0:x0 + w, 3] = np.where(g, 255, 0)
        lines.append(
            "char id=%d x=%d y=%d width=%d height=%d xoffset=0 yoffset=%d xadvance=%d page=0 chnl=15"
            % (ord(ch), x0, y0, w, h, TOP_PAD * scale, advance(ch, bold) * scale))
    png = name + ".png"
    Image.fromarray(atlas, "RGBA").save(os.path.join(dirpath, png))
    size = (ROWS + TOP_PAD) * scale
    head = [
        'info face="%s" size=%d bold=%d italic=0 charset="" unicode=1 stretchH=100 smooth=0 aa=1 '
        "padding=0,0,0,0 spacing=0,0 outline=0" % (face, size, 1 if bold else 0),
        "common lineHeight=%d base=%d scaleW=%d scaleH=%d pages=1 packed=0 alphaChnl=0 redChnl=4 "
        "greenChnl=4 blueChnl=4" % (line_h * scale, (BASE + TOP_PAD) * scale, aw, ah),
        'page id=0 file="%s"' % png,
        "chars count=%d" % len(chars),
    ]
    with open(os.path.join(dirpath, name + ".fnt"), "w", encoding="utf-8", newline="\n") as f:
        f.write("\n".join(head + lines) + "\n")
    return len(chars)
