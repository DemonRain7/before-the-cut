"""Desk objects, stamps, cursors, the result slip and the title sign.

Everything is written to game/assets/ui. Labels and numbers are drawn by the game.
"""
import os

import numpy as np

from font_data import draw_text, text_width
from gen_clinic import paper, text_mask
from people import CLOTH, grow, smooth, stroke
from px import OUT, Canvas, bayer, contact_sheet

IW, IH = 36, 38
OUTLINE = "ink0"


def shadow(c, mask, dx=1, dy=2, color="ink0", a=150):
    s = np.zeros_like(mask)
    s[dy:, dx:] = mask[:-dy, :-dx] if dx else mask[:-dy, :]
    c.fill(s & ~mask, color, a)


# ------------------------------------------------------------------ tools
def tool_light(lit=False):
    c = Canvas(IW, IH)
    body = smooth(c.seg([(8, 31), (24, 13)], 6), 1)
    head = smooth(c.seg([(23, 14), (28, 8)], 8), 1)
    shadow(c, body | head)
    c.shade(body, ["0b1014", "1b2228", "2e3a42", "4a5a63", "70838a"], light=(-0.7, -0.7), round_px=3)
    c.shade(head, CLOTH["chrome"], light=(-0.7, -0.7), round_px=3)
    c.outline(OUTLINE, body | head)
    stroke(c, [(11, 25), (17, 18)], "a3b5b6")
    c.fill(c.ell(13, 27, 1.2, 1.2), "c8483c")
    lens = c.ell(29, 7, 3.2, 3.2)
    c.fill(grow(lens, 1), OUTLINE)
    c.fill(lens, "f2c979" if lit else "c98a22")
    c.px(28, 6, "fbe9b5")
    if lit:
        for a in np.linspace(-2.2, 0.6, 5):
            x0, y0 = 29 + np.cos(a) * 5.5, 7 + np.sin(a) * 5.5
            c.px(int(round(x0)), int(round(y0)), "f2c979")
    return c


def tool_grip():
    c = Canvas(IW, IH)
    plate = c.rrect(2, 20, 33, 33, 3)
    shadow(c, plate)
    c.shade(plate, ["0b1014", "1b2228", "2e3a42", "4a5a63"], light=(-0.8, -0.4), round_px=3)
    c.outline(OUTLINE, plate)
    for x in (5, 30):
        c.px(x, 30, "70838a")
    posts = c.rrect(5, 9, 10, 24, 2) | c.rrect(25, 9, 30, 24, 2)
    c.shade(posts, CLOTH["chrome"], light=(-0.8, -0.3), round_px=2)
    c.outline(OUTLINE, posts)
    bar = c.rrect(7, 11, 28, 17, 3)
    c.shade(bar, ["0b1014", "1b2228", "2e3a42", "4a5a63"], light=(0, -1.0), round_px=3, contrast=1.3)
    yy, xx = c.grid()
    c.fill(bar & (xx % 3 == 0), "0b1014")
    c.fill(c.rect(9, 12, 26, 12), "70838a")
    c.outline(OUTLINE, bar)
    # readout window
    c.fill(c.rect(13, 25, 22, 29), "07090c")
    c.fill(c.rect(14, 26, 17, 28), "3fd67a")
    c.px(20, 27, "3fd67a")
    return c


def tool_port():
    c = Canvas(IW, IH)
    handle = smooth(c.seg([(19, 19), (9, 32)], 7), 1)
    head = c.ell(22, 13, 10, 10)
    cable = c.seg([(8, 33), (4, 36), (14, 37), (30, 34)], 2)
    shadow(c, handle | head)
    c.fill(cable, "0b1014")
    c.shade(handle, ["0b1014", "1b2228", "2e3a42", "4a5a63"], light=(-0.7, -0.6), round_px=3)
    c.outline(OUTLINE, handle)
    for t in (0.35, 0.55, 0.75):
        x, y = 19 + (9 - 19) * t, 19 + (32 - 19) * t
        stroke(c, [(x - 2, y - 2), (x + 2, y + 1)], "0b1014")
    c.fill(grow(head, 1), OUTLINE)
    c.shade(head, CLOTH["chrome"], light=(-0.7, -0.6), round_px=4)
    lens = c.ell(22, 13, 6.5, 6.5)
    c.fill(grow(lens, 1), "0b1014")
    c.fill(lens, "0a2e34")
    c.fill(c.ell(22, 13, 4.2, 4.2) & ~c.ell(22, 13, 2.6, 2.6), "2a8f96")
    c.px(22, 13, "5ee6e0")
    stroke(c, [(18, 10), (20, 8)], "c8fff6")
    return c


# ------------------------------------------------------------------ talk
def bubble_mask(c, x0, y0, x1, y1, tail_x):
    b = c.rrect(x0, y0, x1, y1, 5)
    tail = c.poly([(tail_x, y1 - 1), (tail_x + 7, y1 - 1), (tail_x - 2, y1 + 7)])
    return b | tail


def talk_ask():
    c = Canvas(IW, IH)
    m = bubble_mask(c, 3, 4, 32, 26, 9)
    shadow(c, m)
    c.fill(m, "efe6cf")
    yy, xx = c.grid()
    c.fill(m & (yy > 22) & (yy < 27), "d8ccb0")
    c.outline(OUTLINE, m)
    draw_text(c, 18 - text_width("?", True, 2) // 2, 8, "?", "1b2228", bold=True, scale=2)
    return c


def talk_calm():
    c = Canvas(IW, IH)
    m = bubble_mask(c, 3, 4, 32, 26, 20)
    shadow(c, m)
    c.fill(m, "bfe6dc")
    yy, xx = c.grid()
    c.fill(m & (yy > 22) & (yy < 27), "8fc4bb")
    c.outline(OUTLINE, m)
    for dy, col in ((0, "14484f"), (6, "2a8f96")):
        pts = [(8 + i, 12 + dy + np.sin(i * 0.75) * 2.2) for i in range(0, 21)]
        stroke(c, pts, col, 2)
    return c


def talk_press():
    c = Canvas(IW, IH)
    pts = []
    n = 11
    for i in range(n * 2):
        a = np.pi * i / n - 0.3
        r = 16.5 if i % 2 == 0 else 10.5
        pts.append((18 + np.cos(a) * r * 1.02, 17 + np.sin(a) * r * 0.92))
    m = c.poly(pts)
    shadow(c, m)
    c.fill(m, "c8483c")
    c.fill(c.poly([(18 + (x - 18) * 0.72, 17 + (y - 17) * 0.72) for x, y in pts]), "e8704a")
    c.outline(OUTLINE, m)
    draw_text(c, 18 - text_width("!", True, 2) // 2 + 1, 9, "!", "fbe9b5", bold=True, scale=2)
    return c


# ------------------------------------------------------------------ decide
def stamp(color_ramp):
    c = Canvas(IW, IH)
    knob = c.ell(18, 8, 8, 6.5)
    neck = c.rect(15, 12, 21, 23)
    base = c.rrect(5, 22, 30, 31, 2)
    pad = c.rect(6, 31, 29, 34)
    allm = knob | neck | base | pad
    shadow(c, allm)
    c.shade(knob | neck, ["2a1a1a", "4a2a22", "7a4630", "a86a3c", "d49a5a"], light=(-0.7, -0.6), round_px=4)
    c.shade(base, ["0b1014", "1b2228", "2e3a42", "4a5a63"], light=(-0.7, -0.6), round_px=3)
    c.fill(pad, color_ramp[1])
    c.fill(c.rect(6, 31, 29, 31), color_ramp[2])
    c.fill(c.rect(6, 34, 29, 34), color_ramp[0])
    c.fill(c.rect(9, 25, 26, 28), color_ramp[1])
    c.fill(c.rect(9, 25, 26, 25), color_ramp[2])
    c.outline(OUTLINE, allm)
    c.px(14, 5, "f0c890")
    c.px(15, 4, "f0c890")
    return c


def lever(down):
    c = Canvas(IW, IH)
    yy, xx = c.grid()
    plate = c.rrect(4, 3, 31, 35, 3)
    shadow(c, plate)
    c.fill(plate, "1b2228")
    stripes = plate & (((xx + yy) // 4) % 2 == 0)
    c.fill(stripes, "c98a22")
    inner = c.rrect(8, 7, 27, 31, 2)
    c.shade(inner, ["0b1014", "1b2228", "2e3a42", "4a5a63"], light=(-0.7, -0.6), round_px=3)
    c.outline(OUTLINE, plate)
    c.fill(c.rrect(15, 10, 20, 28, 2), "07090c")
    ky = 25 if down else 12
    arm = c.rect(16, min(ky, 19), 19, max(ky, 19))
    c.fill(arm, "a3b5b6")
    c.fill(c.rect(16, min(ky, 19), 16, max(ky, 19)), "dbe6e0")
    knob = c.ell(17.5, ky, 5.5, 5.5)
    c.fill(grow(knob, 1), OUTLINE)
    c.shade(knob, ["5a1414", "8a1c1c", "c8483c", "e8704a", "f8b090"], light=(-0.7, -0.6), round_px=3)
    c.px(15, ky - 2, "fbe9b5")
    return c


def pad(w, h=58, hot=False):
    c = Canvas(w, h)
    m = c.rrect(0, 0, w - 1, h - 1, 3)
    c.fill(m, "0b1014", 150 if not hot else 190)
    if hot:
        c.inline(m, "5ee6e0")
    else:
        c.fill(c.rect(3, h - 1, w - 4, h - 1), "2e3a42", 200)
        c.fill(c.rect(3, 0, w - 4, 0), "07090c", 200)
    return c


def ink(text, color, w=76, h=24, seed=1):
    c = Canvas(w, h)
    yy, xx = c.grid()
    frame = c.rrect(0, 0, w - 1, h - 1, 3) & ~c.rrect(2, 2, w - 3, h - 3, 2)
    tm = text_mask(w, h, (w - text_width(text, True, 2)) // 2, (h - 14) // 2 - 1, text, bold=True, scale=2)
    m = frame | tm
    rng = np.random.default_rng(seed)
    noise = rng.random((h, w))
    worn = (noise < 0.10) | ((bayer(h, w) > 0.82) & (noise < 0.5))
    c.fill(m & ~worn, color)
    c.fill(m & worn & (noise > 0.06), color, 110)
    return c


# ------------------------------------------------------------------ small parts
def pip(on):
    c = Canvas(7, 7)
    m = c.ell(3, 3, 3.2, 3.2)
    if on:
        c.fill(m, "c98a22")
        c.fill(c.ell(3, 3, 2.2, 2.2), "f2c979")
        c.px(2, 2, "fbe9b5")
        c.outline("ink0", m)
    else:
        c.fill(m, "1b2228")
        c.fill(c.ell(3, 3, 2.0, 2.0), "0b1014")
    return c


def mark(kind):
    c = Canvas(11, 11)
    box = c.rect(1, 1, 9, 9)
    c.fill(box & ~c.rect(2, 2, 8, 8), "8a7a5a")
    if kind == "tick":
        stroke(c, [(2, 5), (4, 8), (10, 0)], "2e3a42", 2)
    elif kind == "cross":
        stroke(c, [(1, 1), (9, 9)], "8a1c1c", 2)
        stroke(c, [(9, 1), (1, 9)], "8a1c1c", 2)
    return c


def truth_mark(ok):
    c = Canvas(11, 11)
    if ok:
        stroke(c, [(1, 5), (4, 8), (10, 1)], "2f8f4a", 2)
    else:
        stroke(c, [(1, 1), (9, 9)], "c8281c", 2)
        stroke(c, [(9, 1), (1, 9)], "c8281c", 2)
    return c


def cursor(kind):
    c = Canvas(16, 16)
    if kind == "point":
        m = c.poly([(1, 1), (1, 12), (4, 9), (7, 14), (9, 13), (6, 8), (10, 8)])
        c.fill(m, "efe6cf")
        c.outline("07090c", m)
    elif kind == "look":
        ring = c.ell(6, 6, 5.2, 5.2)
        c.fill(grow(ring, 1), "07090c")
        c.fill(ring, "efe6cf")
        c.fill(c.ell(6, 6, 3.2, 3.2), "0a2e34")
        c.px(5, 5, "5ee6e0")
        h = c.seg([(10, 10), (14, 14)], 3)
        c.fill(grow(h, 1) & ~grow(ring, 1), "07090c")
        c.fill(h & ~grow(ring, 1), "c98a22")
    elif kind == "hand":
        palm = c.rrect(3, 6, 12, 14, 2)
        fingers = c.rect(3, 3, 4, 7) | c.rect(6, 1, 7, 7) | c.rect(9, 2, 10, 7) | c.rect(12, 4, 13, 9)
        m = palm | fingers
        c.fill(m, "efe6cf")
        c.outline("07090c", m)
        c.px(5, 9, "b3a587")
        c.px(8, 9, "b3a587")
    elif kind == "talk":
        m = c.rrect(1, 1, 13, 10, 3) | c.poly([(3, 9), (8, 9), (2, 14)])
        c.fill(m, "efe6cf")
        c.outline("07090c", m)
        for x in (4, 7, 10):
            c.px(x, 5, "1b2228")
            c.px(x, 6, "1b2228")
    return c


def slip(w=200, h=150):
    p = paper(w, h, base="paper4", shade="paper3", edge="paper2", seed=7)
    yy, xx = p.grid()
    # torn top edge and printer feed holes down both sides
    tear = (yy < 3) & (((xx + 2) // 3) % 2 == 0) & (yy < 2 + ((xx // 3) % 2))
    p.erase(tear | ((yy == 0) & ((xx // 2) % 2 == 0)))
    for y in range(8, h - 4, 8):
        for x in (3, w - 5):
            p.fill(p.rect(x, y, x + 1, y + 1), "b3a587")
    p.fill(p.rect(8, 14, w - 9, 14), "b3a587")
    return p


def neon(text, scale, tube, core, glow, pad_px=10):
    w = text_width(text, True, scale) + pad_px * 2
    h = 9 * scale + pad_px * 2
    c = Canvas(w, h)
    tm = text_mask(w, h, pad_px, pad_px, text, bold=True, scale=scale)
    halo = grow(tm, 5)
    yy, xx = c.grid()
    for n, a in ((6, 0.25), (4, 0.45), (2, 0.75)):
        g = grow(tm, n) & ~tm
        c.fill(g & (bayer(h, w) < a), glow)
    c.fill(grow(tm, 1) & ~tm, glow)
    c.fill(tm, tube)
    inner = tm & ~c.edge(tm, 0, -1) & ~c.edge(tm, 0, 1) & ~c.edge(tm, -1, 0) & ~c.edge(tm, 1, 0)
    c.fill(inner if scale >= 3 else tm & (bayer(h, w) < 0.5), core)
    del halo
    return c


def logo():
    a = neon("BEFORE THE", 3, "5ee6e0", "e8fffb", "14686f")
    b = neon("CUT", 6, "ff4f8a", "ffe0ea", "7a1c44")
    w = max(a.w, b.w) + 8
    c = Canvas(w, a.h + b.h - 12)
    c.blit(a, (w - a.w) // 2, 0)
    c.blit(b, (w - b.w) // 2, a.h - 12)
    # a scalpel line through the sign
    y = a.h + b.h // 2 - 12
    for x0, x1 in ((2, (w - b.w) // 2 - 2), ((w + b.w) // 2 + 2, w - 3)):
        if x1 > x0:
            c.fill(c.rect(x0, y, x1, y), "ff4f8a")
            c.fill(c.rect(x0, y - 1, x1, y - 1) & (bayer(c.h, c.w) < 0.5), "7a1c44")
            c.fill(c.rect(x0, y + 1, x1, y + 1) & (bayer(c.h, c.w) < 0.5), "7a1c44")
    return c


def crack():
    """Glass crack shown over the window when a patient gets through."""
    c = Canvas(220, 186)
    rng = np.random.default_rng(11)
    cx, cy = 112, 86
    for i in range(13):
        a = 2 * np.pi * i / 13 + rng.uniform(-0.2, 0.2)
        pts = [(cx, cy)]
        r = 0.0
        while r < 150:
            r += rng.uniform(14, 30)
            a += rng.uniform(-0.25, 0.25)
            pts.append((cx + np.cos(a) * r, cy + np.sin(a) * r * 0.85))
        stroke(c, pts, "dbe6e0")
        stroke(c, [(x + 1, y + 1) for x, y in pts[:3]], "ffffff")
    for r in (18, 38, 64):
        ring = [(cx + np.cos(t) * r * rng.uniform(0.85, 1.1), cy + np.sin(t) * r * 0.85 * rng.uniform(0.85, 1.1))
                for t in np.linspace(0, 2 * np.pi, 15)]
        stroke(c, ring, "a3b5b6")
    c.fill(c.ell(cx, cy, 5, 4), "ffffff")
    return c


def main():
    d = "ui"
    items = []

    def put(name, canvas):
        canvas.save("%s/%s.png" % (d, name))
        items.append((name, canvas))

    put("tool_light", tool_light())
    put("tool_light_on", tool_light(True))
    put("tool_grip", tool_grip())
    put("tool_port", tool_port())
    put("talk_ask", talk_ask())
    put("talk_calm", talk_calm())
    put("talk_press", talk_press())
    put("stamp_treat", stamp(["1c5a30", "2f8f4a", "5fc878"]))      # the call box is in gen_team.py
    put("lever_up", lever(False))
    put("lever_down", lever(True))
    put("pad40", pad(40))
    put("pad40_hot", pad(40, hot=True))
    put("pad36", pad(36))
    put("pad36_hot", pad(36, hot=True))
    put("ink_treat", ink("TREAT", "2f8f4a", seed=2))
    # grey, so that it cannot be mistaken for the red TRAUMA TEAM imprint (ink_refer, gen_team.py)
    put("ink_void", ink("VOID", "5a4e52", seed=4))
    put("pip_on", pip(True))
    put("pip_off", pip(False))
    put("mark_blank", mark("blank"))
    put("mark_tick", mark("tick"))
    put("mark_cross", mark("cross"))
    put("truth_ok", truth_mark(True))
    put("truth_bad", truth_mark(False))
    for k in ("point", "look", "hand", "talk"):
        put("cursor_" + k, cursor(k))
    contact_sheet(items, os.path.join(OUT, "ui_items.png"), scale=4, per_row=8, bg="teal1")
    s = slip()
    s.save(d + "/slip.png")
    lg = logo()
    lg.save(d + "/logo.png")
    cr = crack()
    cr.save(d + "/crack.png")
    contact_sheet([("slip", s), ("logo", lg), ("crack", cr)], os.path.join(OUT, "ui_big.png"), scale=2, per_row=3, bg="ink0")
    print("ui art written")


if __name__ == "__main__":
    main()
