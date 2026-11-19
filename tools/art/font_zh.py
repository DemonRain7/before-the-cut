"""The game's Chinese glyphs, from Fusion Pixel Font (fonts/, SIL Open Font License 1.1).

Counter Sans (font_data.py) draws every character it has; this font draws the rest: hanzi, CJK
punctuation, full-width forms. In the game each Counter Sans font takes zh.fnt as its fallback
(gfx.gd), so Chinese text keeps Counter Sans for its Latin letters, digits and ASCII
punctuation and uses these glyphs for everything else. The bold and the big fonts fall back to
the same glyphs: Chinese has no bold here, and the big font draws them at twice the size.

The line box is Counter Sans's, 11 rows with the baseline 8 rows down, so the fallback never
moves a line of English. A hanzi (9 x 9, one row below the baseline) fills rows 0-8 of it, which
leaves one clear row between lines at the game's 10-pixel line pitch.

Fusion Pixel Font is by TakWolf (https://github.com/TakWolf/fusion-pixel-font) and draws on Ark
Pixel Font, BoutiqueBitmap9x9 and Galmuri. extract_zh_font.py says how fonts/ was cut from it.
"""
import os

import numpy as np
from PIL import Image

from font_data import _G, BASE, TOP_PAD, LINE_H, advance as latin_advance, glyph as latin_glyph
from font_data import draw_text as latin_draw_text

HERE = os.path.dirname(os.path.abspath(__file__))
BDF = os.path.join(HERE, "fonts", "fusion-pixel-10px-zh_hans.bdf")
LICENCE_DIR = os.path.join(HERE, "fonts")
ASCENT = BASE + TOP_PAD      # 8: Counter Sans's baseline, from the top of its line box
SIZE = 10                    # gfx.gd FS: the font size the game asks for

_glyphs = None


def load():
    """code point -> (advance, x offset, rows from the line top to the bitmap's top, h x w bools)."""
    global _glyphs
    if _glyphs is not None:
        return _glyphs
    _glyphs = {}
    code = dw = None
    w = h = xo = yo = 0
    with open(BDF, encoding="utf-8") as f:
        lines = iter(f)
        for line in lines:
            if line.startswith("ENCODING"):
                code = int(line.split()[1])
            elif line.startswith("DWIDTH"):
                dw = int(line.split()[1])
            elif line.startswith("BBX"):
                w, h, xo, yo = map(int, line.split()[1:])
            elif line.startswith("BITMAP"):
                a = np.zeros((h, w), dtype=bool)
                for r in range(h):
                    hexrow = next(lines).strip()
                    bits = bin(int(hexrow, 16))[2:].zfill(len(hexrow) * 4)
                    a[r, :] = [b == "1" for b in bits[:w]]
                _glyphs[code] = (dw, xo, ASCENT - (yo + h), a)
    return _glyphs


def has(ch):
    """Whether the game can draw ch: Counter Sans has it, or this font does."""
    return ch in _G or ord(ch) in load()


def is_wide(ch):
    """Drawn by this font rather than by Counter Sans."""
    return ch not in _G and ord(ch) in load()


def advance(ch, bold=False):
    if ch in _G or ord(ch) not in load():
        return latin_advance(ch, bold)
    return load()[ord(ch)][0]


def text_width(s, bold=False, scale=1):
    """The same measure as font_data.text_width (no gap after the last letter), for mixed text."""
    if not s:
        return 0
    return (sum(advance(c, bold) for c in s) - 1) * scale


def draw_text(canvas, x, y, s, color, bold=False, scale=1):
    """Mixed Chinese and Latin text with its line box's top-left at (x, y). Returns the end x.
    Latin is Counter Sans, drawn as font_data.draw_text draws it (one row below the box top)."""
    from px import col
    c = col(color)
    for ch in s:
        if is_wide(ch):
            dw, xo, top, g = load()[ord(ch)]
            gx, gy = x + xo * scale, y + top * scale
            step = dw
        else:
            g = latin_glyph(ch, bold)
            gx, gy = x, y + TOP_PAD * scale
            step = latin_advance(ch, bold)
        if scale > 1:
            g = np.repeat(np.repeat(g, scale, axis=0), scale, axis=1)
        for yy, xx in zip(*np.nonzero(g)):
            px, py = gx + xx, gy + yy
            if 0 <= px < canvas.w and 0 <= py < canvas.h:
                canvas.a[py, px, :3] = c
                canvas.a[py, px, 3] = 255
        x += step * scale
    return x


def draw_label(canvas, x, y, s, color, bold=False, scale=1):
    """A picture's words in any language (tools/art/words.py), placed the way font_data.draw_text
    places English: (x, y) is the top-left of the capitals. Text with Chinese in it starts one row
    (scale rows) higher, so a hanzi's nine rows share the middle of a capital's seven and a twin's
    words sit where the English ones do. English is drawn by font_data, pixel for pixel as
    before. Returns the end x."""
    if any(is_wide(ch) for ch in s):
        return draw_text(canvas, x, y - scale, s, color, bold=bold, scale=scale)
    return latin_draw_text(canvas, x, y, s, color, bold=bold, scale=scale)


def export_zh_font(dirpath, name="zh"):
    """Write zh.fnt (BMFont text) and its white-on-transparent atlas: every glyph of the cut
    that Counter Sans does not have. Returns the number of glyphs."""
    glyphs = load()
    codes = sorted(c for c in glyphs if chr(c) not in _G and c != 0xFFFE)
    cell_w = max(glyphs[c][3].shape[1] for c in codes) + 1
    cell_h = max(glyphs[c][3].shape[0] for c in codes) + 1
    aw = 2048
    per_row = aw // cell_w
    n_rows = (len(codes) + per_row - 1) // per_row
    ah = 1
    while ah < cell_h * n_rows:
        ah *= 2
    atlas = np.zeros((ah, aw, 4), dtype=np.uint8)
    atlas[:, :, :3] = 255
    lines = []
    for i, code in enumerate(codes):
        dw, xo, top, g = glyphs[code]
        h, w = g.shape
        x0 = (i % per_row) * cell_w
        y0 = (i // per_row) * cell_h
        atlas[y0:y0 + h, x0:x0 + w, 3] = np.where(g, 255, 0)
        lines.append("char id=%d x=%d y=%d width=%d height=%d xoffset=%d yoffset=%d xadvance=%d page=0 chnl=15"
                     % (code, x0, y0, w, h, xo, top, dw))
    os.makedirs(dirpath, exist_ok=True)
    png = name + ".png"
    Image.fromarray(atlas, "RGBA").save(os.path.join(dirpath, png), optimize=True)
    head = [
        'info face="Fusion Pixel 10px zh_hans" size=%d bold=0 italic=0 charset="" unicode=1 stretchH=100 '
        "smooth=0 aa=1 padding=0,0,0,0 spacing=0,0 outline=0" % SIZE,
        "common lineHeight=%d base=%d scaleW=%d scaleH=%d pages=1 packed=0 alphaChnl=0 redChnl=4 "
        "greenChnl=4 blueChnl=4" % (LINE_H, ASCENT, aw, ah),
        'page id=0 file="%s"' % png,
        "chars count=%d" % len(codes),
    ]
    with open(os.path.join(dirpath, name + ".fnt"), "w", encoding="utf-8", newline="\n") as f:
        f.write("\n".join(head + lines) + "\n")
    # the licence travels with the font (SIL OFL 1.1, condition 2)
    with open(os.path.join(dirpath, name + "_LICENSE.txt"), "w", encoding="utf-8", newline="\n") as out:
        out.write("The Chinese glyphs in %s.fnt and %s.png are cut, unchanged, from Fusion Pixel Font\n"
                  "(https://github.com/TakWolf/fusion-pixel-font), release 2026.11.10, 10 px proportional,\n"
                  "zh_hans. Fusion Pixel Font draws on Ark Pixel Font, BoutiqueBitmap9x9 and Galmuri.\n"
                  "Their licences follow.\n\n" % (name, name))
        for part in ["OFL.txt", os.path.join("LICENSES", "ark-pixel", "OFL.txt"),
                     os.path.join("LICENSES", "boutique-bitmap-9x9", "OFL.txt"),
                     os.path.join("LICENSES", "galmuri", "LICENSE.txt")]:
            with open(os.path.join(LICENCE_DIR, part), encoding="utf-8") as f:
                out.write("=" * 72 + "\n" + f.read().strip() + "\n\n")
    return len(codes)
