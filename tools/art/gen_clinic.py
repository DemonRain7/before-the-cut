"""Clinic environment art: the hall behind the service window, the staff-side wall with its
window frame, monitor, pinboard and lamp, the shutter, the desk and the paper backings.

Scene layout (640 x 360 screen):
  scene      0,0   400 x 224     window opening (HOLE) 170,14  220 x 186
  dialogue   0,224 400 x 60
  desk       0,284 400 x 76
  clipboard  400,0 240 x 360     reference sheet on top, patient record below
"""
import os

import numpy as np

from font_data import draw_text, text_width
from px import ASSETS, OUT, Canvas, bayer, col, contact_sheet

HOLE = (170, 14, 220, 186)
SCREEN = (18, 22, 132, 94)       # monitor glass inside the wall image


def text_mask(w, h, x, y, s, bold=False, scale=1):
    t = Canvas(w, h)
    draw_text(t, x, y, s, "white", bold=bold, scale=scale)
    return t.alpha()


# ------------------------------------------------------------------ hall
def hall():
    W, H = HOLE[2], HOLE[3]
    c = Canvas(W, H, "teal2")
    A = c.all()
    yy, xx = c.grid()
    # back wall: darkest at the top right, lifted toward the lamp at the lower left
    c.grad(A, ["ink1", "teal1", "teal2", "teal3"], W + 30, -30, 10, H - 20, dither=1.0)
    c.glow(A, "teal4", 20, 150, 150, amt=0.85, power=1.3)
    c.glow(A, "teal5", 6, 160, 80, amt=0.55, power=1.4)
    # panel seams
    for x in (48, 104):
        c.fill(c.rect(x, 0, x, 109), "teal1")
    # wainscot
    lower = c.rect(0, 112, W - 1, H - 1)
    c.grad(lower, ["ink1", "teal1", "teal2", "teal3"], W, 100, -10, H + 20, dither=1.0)
    c.glow(lower, "teal4", 10, 170, 110, amt=0.6, power=1.2)
    c.fill(c.rect(0, 109, W - 1, 109), "teal5")
    c.fill(c.rect(0, 110, W - 1, 110), "teal4")
    c.fill(c.rect(0, 111, W - 1, 111), "ink1")
    c.dither(c.rect(70, 109, W - 1, 110), "teal3", np.clip((xx - 70) / 120.0, 0, 1))
    for x in range(14, W, 30):
        c.fill(c.rect(x, 113, x, H - 1), "ink1")

    # street door, right
    dx0, dx1, dy0 = 158, 213, 30
    c.fill(c.rect(dx0, dy0, dx1, H - 1), "ink1")
    leaf = c.rect(dx0 + 3, dy0 + 3, dx1 - 3, H - 1)
    c.grad(leaf, ["teal1", "teal2", "teal3"], dx1, dy0, dx0, H, dither=0.8)
    c.fill(c.rect(dx0 + 3, dy0 + 3, dx0 + 3, H - 1), "teal4")
    # pane with the wet street behind it
    px0, py0, px1, py1 = dx0 + 9, dy0 + 12, dx1 - 9, dy0 + 66
    c.fill(c.rect(px0 - 2, py0 - 2, px1 + 2, py1 + 2), "ink1")
    pane = c.rect(px0, py0, px1, py1)
    c.grad(pane, ["ink0", "vio0", "vio1"], px0, py0, px0, py1, dither=0.9)
    # neon sign seen from behind: three strokes and a bar
    for sx, sy, ex, ey, colr in ((px0 + 6, py0 + 6, px0 + 6, py0 + 26, "mag2"),
                                 (px0 + 12, py0 + 6, px0 + 20, py0 + 6, "mag2"),
                                 (px0 + 16, py0 + 6, px0 + 16, py0 + 26, "mag2"),
                                 (px0 + 12, py0 + 16, px0 + 20, py0 + 16, "mag3"),
                                 (px0 + 26, py0 + 10, px0 + 26, py0 + 26, "cyan2"),
                                 (px0 + 26, py0 + 10, px0 + 32, py0 + 10, "cyan2")):
        c.line([(sx, sy), (ex, ey)], colr, 1)
    halo = pane & ~c.seg([(px0 + 6, py0 + 6), (px0 + 6, py0 + 26)], 1)
    c.glow(halo & (c.a[:, :, 0] < 120), "mag0", px0 + 12, py0 + 16, 22, amt=0.8)
    c.glow(halo & (c.a[:, :, 0] < 90), "mag1", px0 + 12, py0 + 16, 12, amt=0.6)
    c.fill(c.rect(px0, py0 + 34, px1, py0 + 35), "ink1")        # mullion
    c.glow(c.rect(px0, py0 + 36, px1, py1), "vio2", px0 + 14, py1, 26, amt=0.7, ry=16)
    c.glow(c.rect(px0, py0 + 40, px1, py1), "mag1", px0 + 14, py1 + 2, 14, amt=0.7, ry=10)
    # push plate and kick plate
    c.fill(c.rect(dx1 - 12, dy0 + 84, dx1 - 7, dy0 + 106), "steel2")
    c.fill(c.rect(dx1 - 12, dy0 + 84, dx1 - 12, dy0 + 106), "steel4")
    c.fill(c.rect(dx0 + 4, H - 20, dx1 - 4, H - 1), "steel0")
    c.fill(c.rect(dx0 + 4, H - 20, dx1 - 4, H - 20), "steel2")
    # neon spill on the wall and floor line beside the door
    wall = A & ~c.rect(dx0, dy0, dx1, H - 1)
    c.glow(wall, "mag0", dx0 - 2, dy0 + 40, 46, amt=0.75, power=1.2)
    c.glow(wall, "mag1", dx0 - 1, dy0 + 40, 14, amt=0.5, power=1.0, ry=40)
    # exit light above the door
    c.fill(c.rect(dx0 + 12, dy0 - 15, dx0 + 43, dy0 - 5), "ink1")
    c.fill(c.rect(dx0 + 13, dy0 - 14, dx0 + 42, dy0 - 6), "grn1")
    draw_text(c, dx0 + 17, dy0 - 15, "EXIT", "grn4")
    c.glow(wall & (c.a[:, :, 1] < 100), "grn1", dx0 + 27, dy0 - 10, 26, amt=0.5, ry=14)

    # screening poster, left
    c.fill(c.rect(9, 37, 43, 87), "ink1")
    post = c.rect(8, 36, 42, 86)
    c.fill(post, "paper2")
    c.dither(post, "paper1", np.clip((yy - 36) / 80.0, 0, 0.6))
    c.fill(c.rect(8, 36, 42, 43), "teal4")
    c.fill(c.ell(25, 56, 11, 6), "paper4")
    c.outline("inkt", c.ell(25, 56, 11, 6))
    c.fill(c.ell(25, 56, 4, 4), "teal4")
    c.fill(c.ell(25, 56, 1.6, 1.6), "inkt")
    for i, wd in enumerate((26, 22, 26, 14)):
        c.fill(c.rect(12, 67 + i * 4, 12 + wd, 67 + i * 4), "inks")
    c.fill(c.rect(24, 34, 26, 36), "steel4")
    # a small manila notice
    c.fill(c.rect(51, 59, 67, 79), "ink1")
    c.fill(c.rect(50, 58, 66, 78), "manila1")
    for i in range(4):
        c.fill(c.rect(53, 62 + i * 4, 63 - (i % 2) * 3, 62 + i * 4), "manila0")

    # wall clock
    c.fill(c.ell(66, 19, 9.4, 9.4), "ink1")
    c.fill(c.ell(66, 19, 8.2, 8.2), "steel3")
    c.fill(c.ell(66, 19, 6.6, 6.6), "paper2")
    c.line([(66, 19), (66, 14)], "inkt")
    c.line([(66, 19), (62, 21)], "inkt")
    c.px(66, 19, "red1")

    # potted fern in the corner, catching the lamp
    for i, (tx, ty) in enumerate(((2, 122), (12, 114), (22, 118), (30, 128), (36, 140), (-4, 134), (17, 126))):
        base = (14, 162)
        mx, my = (base[0] + tx) / 2.0 + (4 if i % 2 else -4), (base[1] + ty) / 2.0 - 6
        leafm = c.seg([base, (mx, my), (tx, ty)], 4)
        c.fill(leafm, "grn1")
        c.fill(c.seg([base, (mx - 1, my), (tx, ty)], 1), "grn2")
        c.glow(leafm, "grn3", tx, ty, 16, amt=0.7)
    pot = c.poly([(4, 160), (25, 160), (22, 185), (7, 185)])
    c.shade(pot, "warm", light=(-0.7, 0.3), contrast=0.9, round_px=5, bias=-0.12)
    c.fill(c.rect(3, 159, 26, 161), "warm3")
    c.fill(c.rect(3, 159, 14, 159), "warm5")
    c.outline("ink1", pot | c.rect(3, 159, 26, 161))
    return c


def hall_door_open():
    """The same door standing open: street light, rain and neon pour in."""
    W, H = HOLE[2], HOLE[3]
    c = Canvas(W, H)
    dx0, dx1, dy0 = 158, 213, 30
    yy, xx = c.grid()
    gap = c.rect(dx0 + 3, dy0 + 3, dx1 - 3, H - 1)
    c.grad(gap, ["vio0", "vio1", "vio2"], dx0, dy0, dx0, H, dither=1.0)
    c.glow(gap, "mag1", dx0 + 24, dy0 + 40, 60, amt=0.8, ry=90)
    c.glow(gap, "mag2", dx0 + 30, dy0 + 34, 16, amt=0.9, ry=30)
    c.glow(gap, "mag3", dx0 + 30, dy0 + 30, 6, amt=0.9, ry=18)
    c.glow(gap, "cyan1", dx0 + 44, dy0 + 70, 14, amt=0.6, ry=40)
    # wet pavement glints
    for i in range(7):
        y = H - 6 - i * 5
        c.fill(c.rect(dx0 + 8 + (i * 7) % 20, y, dx0 + 20 + (i * 11) % 24, y), "mag2" if i % 2 else "vio2")
    # rain
    rng = np.random.default_rng(4)
    for _ in range(38):
        x = int(rng.integers(dx0 + 4, dx1 - 6))
        y = int(rng.integers(dy0 + 4, H - 12))
        c.line([(x, y), (x - 2, y + 5)], "teal6")
    # the door leaf folded against the right jamb
    edge = c.rect(dx1 - 8, dy0 + 3, dx1 - 3, H - 1)
    c.fill(edge, "teal3")
    c.fill(c.rect(dx1 - 8, dy0 + 3, dx1 - 8, H - 1), "mag2")
    c.fill(c.rect(dx1 - 3, dy0 + 3, dx1 - 3, H - 1), "ink1")
    return c


def rain_frames():
    """Three small overlays for the door pane."""
    out = []
    dx0, dx1, dy0 = 158, 213, 30
    px0, py0, px1, py1 = dx0 + 9, dy0 + 12, dx1 - 9, dy0 + 66
    w, h = px1 - px0 + 1, py1 - py0 + 1
    for f in range(3):
        c = Canvas(w, h)
        rng = np.random.default_rng(20 + f)
        for _ in range(9):
            x = int(rng.integers(2, w - 1))
            y = int(rng.integers(0, h - 6))
            if 33 <= y <= 36:
                continue
            c.px(x, y, "teal5")
            c.px(x, y + 1, "teal5")
            c.px(x - 1, y + 2, "teal4")
        out.append(c)
    return out, (px0, py0)


# ------------------------------------------------------------------ sill
def sill():
    W = HOLE[2]
    c = Canvas(W, 15)
    A = c.rect(0, 1, W - 1, 14)
    yy, xx = c.grid()
    c.grad(A, ["warm1", "warm2", "warm3", "warm4"], W + 40, 0, 0, 0, dither=1.0)
    c.glow(A, "warm5", 18, 8, 110, amt=0.9, power=1.2, ry=40)
    c.glow(A, "warm6", 14, 9, 46, amt=0.8, power=1.3, ry=20)
    rng = np.random.default_rng(3)
    for _ in range(26):
        x = int(rng.integers(0, W - 14))
        y = int(rng.integers(3, 12))
        c.fill(c.rect(x, y, x + int(rng.integers(5, 14)), y), "warm2" if x > 60 else "warm4")
    # far edge in shadow, near edge catching light
    c.fill(c.rect(0, 0, W - 1, 0), "ink1", 150)
    c.fill(c.rect(0, 1, W - 1, 1), "warm0")
    c.fill(c.rect(0, 2, W - 1, 2), "warm1")
    c.fill(c.rect(0, 13, W - 1, 13), "warm3")
    c.dither(c.rect(0, 13, 120, 13), "warm6", np.clip(1.0 - xx / 120.0, 0, 1))
    c.fill(c.rect(0, 14, W - 1, 14), "warm0")
    return c


# ------------------------------------------------------------------ staff wall
def lamp(c):
    """An interrogation-style desk lamp standing on the sill, aimed at the visitor."""
    base = c.ell(186, 201, 11, 3.4)
    c.shade(base, "warm", light=(0.6, -0.5), contrast=0.9, bias=-0.1)
    stem = c.rect(185, 181, 187, 199)
    c.fill(stem, "warm3")
    c.fill(c.rect(187, 181, 187, 199), "warm5")
    hood = c.poly([(178, 163), (178, 181), (199, 189), (199, 153)])
    c.shade(hood, ["warm0", "warm1", "warm2", "warm3"], light=(0.2, -0.8), contrast=1.0, round_px=5)
    c.fill(c.rect(178, 163, 178, 181), "warm1")
    c.outline("ink0", hood | stem | base)
    mouth = c.rect(199, 154, 201, 188)
    c.fill(mouth, "warm7")
    c.fill(c.rect(199, 153, 201, 155), "warm5")
    c.fill(c.rect(199, 187, 201, 189), "warm5")
    c.fill(c.rect(200, 160, 201, 182), "white")
    c.px(176, 172, "warm4")
    c.px(176, 171, "warm4")


def wall():
    c = Canvas(400, 224, "teal1")
    A = c.all()
    yy, xx = c.grid()
    hx, hy, hw, hh = HOLE
    hole = c.rect(hx, hy, hx + hw - 1, hy + hh - 1)
    c.grad(A, ["ink0", "ink1", "teal1"], 60, 0, 60, 224, dither=1.0)
    # boards
    for x in range(6, 400, 26):
        c.fill(c.rect(x, 0, x, 204), "ink0")
    # lamp spill on the wall around the window corner
    c.glow(A, "teal2", 186, 176, 120, amt=0.8, power=1.3)
    c.glow(A, "warm1", 186, 180, 70, amt=0.7, power=1.2)
    c.glow(A, "warm2", 190, 186, 34, amt=0.6, power=1.2)

    # staff counter edge under the window (the slip printer lives here)
    c.fill(c.rect(0, 205, 399, 223), "warm1")
    c.grad(c.rect(0, 208, 399, 223), ["warm0", "warm1", "warm2"], 400, 0, 120, 0, dither=1.0)
    c.glow(c.rect(0, 208, 399, 223), "warm3", 190, 208, 130, amt=0.6, ry=20)
    c.fill(c.rect(0, 205, 399, 205), "warm5")
    c.dither(c.rect(0, 205, 399, 205), "warm3", np.clip(abs(xx - 190) / 200.0, 0, 1))
    c.fill(c.rect(0, 206, 399, 207), "warm3")
    c.dither(c.rect(0, 206, 399, 207), "warm2", np.clip(abs(xx - 190) / 160.0, 0, 1))
    c.fill(c.rect(0, 223, 399, 223), "ink0")
    # slip slot
    c.fill(c.rrect(176, 211, 384, 220, 2), "steel1")
    c.fill(c.rect(176, 211, 384, 211), "steel3")
    c.fill(c.rect(179, 214, 381, 217), "ink0")
    c.fill(c.rect(179, 218, 381, 218), "steel2")
    c.px(388, 215, "grn3")
    c.px(389, 215, "grn1")

    # window frame
    outer = c.rect(hx - 5, hy - 5, hx + hw + 4, hy + hh + 4)
    frame = outer & ~hole
    c.fill(frame, "steel1")
    c.fill(c.rect(hx - 5, hy - 5, hx + hw + 4, hy - 5), "steel3")
    c.fill(c.rect(hx - 5, hy - 5, hx - 5, hy + hh + 4), "steel2")
    c.fill(c.rect(hx - 5, hy + hh + 4, hx + hw + 4, hy + hh + 4), "ink0")
    c.fill(c.rect(hx + hw + 4, hy - 5, hx + hw + 4, hy + hh + 4), "steel0")
    c.fill(c.rect(hx - 1, hy - 1, hx + hw, hy - 1), "ink0")
    c.fill(c.rect(hx - 1, hy - 1, hx - 1, hy + hh), "ink0")
    c.fill(c.rect(hx + hw, hy - 1, hx + hw, hy + hh), "steel2")
    c.fill(c.rect(hx - 1, hy + hh, hx + hw, hy + hh), "steel3")
    c.glow(frame, "warm3", 190, 186, 60, amt=0.7)
    c.glow(frame, "steel4", 190, 186, 30, amt=0.5)
    for bx, by in ((hx - 3, hy - 3), (hx + hw + 2, hy - 3), (hx - 3, hy + hh + 2), (hx + hw + 2, hy + hh + 2),
                   (hx + hw // 2, hy - 3), (hx + hw // 2, hy + hh + 2)):
        c.px(bx, by, "steel4")
        c.px(bx, by + 1, "ink0")
    c.erase(hole)

    # monitor
    c.fill(c.rect(72, 0, 96, 13), "steel0")
    c.fill(c.rect(72, 0, 72, 13), "steel2")
    hous = c.rrect(8, 12, 158, 128, 5)
    c.shade(hous, "steel_dark", light=(0.7, 0.5), contrast=0.8, round_px=5, round_amt=0.5, bias=-0.06)
    c.outline("ink0", hous)
    c.fill(c.rrect(13, 17, 153, 119, 3), "ink0")
    sx, sy, sw, sh = SCREEN
    c.fill(c.rect(sx, sy, sx + sw - 1, sy + sh - 1), "grn0")
    draw_text(c, 16, 118, "HALL CAM", "steel2")
    c.fill(c.ell(132, 123, 2.2, 2.2), "steel2")
    c.fill(c.ell(140, 123, 2.2, 2.2), "steel2")
    c.px(132, 122, "steel4")
    c.px(140, 122, "steel4")
    c.px(149, 123, "grn4")
    c.px(150, 123, "grn2")
    # cable
    c.line([(30, 129), (30, 136)], "ink0", 2)

    # pinboard with two blank notes (text is drawn by the game)
    fr = c.rrect(8, 136, 158, 199, 2)
    c.fill(fr, "warm1")
    c.fill(c.rect(8, 136, 158, 136), "warm3")
    c.outline("ink0", fr)
    cork = c.rect(11, 139, 155, 196)
    c.fill(cork, "warm3")
    c.dither(cork, "warm2", 0.5)
    c.speckle(cork, "warm4", 0.05, seed=5)
    c.speckle(cork, "warm1", 0.05, seed=6)
    c.glow(cork, "warm4", 160, 190, 70, amt=0.6)
    for (x0, y0, x1, y1, pc, pin) in ((15, 143, 84, 192, "paper3", "red2"), (90, 143, 151, 192, "manila2", "cyan2")):
        c.fill(c.rect(x0 + 1, y0 + 1, x1 + 1, y1 + 1), "warm0")
        note = c.rect(x0, y0, x1, y1)
        c.fill(note, pc)
        c.fill(c.rect(x0, y1, x1, y1), "paper1" if pc == "paper3" else "manila0")
        mx = (x0 + x1) // 2
        c.fill(c.rect(mx, y0 - 2, mx + 1, y0), pin)
        c.px(mx, y0 - 2, "white")
        c.px(mx + 1, y0 + 1, "ink1")
    lamp(c)
    return c


GLOW_STEPS = 24                  # shades the lamp's cone of light falls off in


def lamp_glow():
    """Additive cone of lamplight, centred on the lamp mouth at (30, 150).

    It falls off in the picture's alpha, in GLOW_STEPS even steps, and not by thinning out in
    an ordered pattern like the other lights: the view through the window is shown at twice
    its size, and a pattern that coarse lay over the visitor's face like a print screen. The
    colour and the strength are the averages of the patterned version it replaces."""
    c = Canvas(250, 210)
    yy, xx = c.grid()
    dx, dy = xx - 30.0, yy - 150.0
    d = np.sqrt(dx * dx + dy * dy)
    ang = (dx * 0.95 - dy * 0.3) / np.maximum(d, 1e-3)       # cosine to the aim direction
    t = np.clip(1.0 - d / 235.0, 0, 1) ** 1.5 * np.clip((ang - 0.15) / 0.7, 0, 1)
    tone = 0.4 * np.array(col("warm6"), dtype=np.float32) + 0.6 * np.array(col("warm7"), dtype=np.float32)
    level = np.round(t * GLOW_STEPS) / GLOW_STEPS
    lit = level > 0
    c.a[lit, :3] = np.round(tone).astype(np.uint8)
    c.a[:, :, 3] = np.round(level * 255.0).astype(np.uint8)
    return c


def glass():
    W, H = HOLE[2], HOLE[3]
    c = Canvas(W, H)
    yy, xx = c.grid()
    u = (xx + yy * 0.7) % 190
    m = ((u > 30) & (u < 52)) | ((u > 60) & (u < 66))
    c.fill(m & (bayer(H, W) < 0.5), "teal7")
    return c


# ------------------------------------------------------------------ shutter
def shutter():
    W, H = HOLE[2], HOLE[3] + 4
    c = Canvas(W, H, "steel2")
    yy, xx = c.grid()
    tones = ["steel4", "steel3", "steel2", "steel2", "steel2", "steel1", "steel1", "steel0"]
    for i, tname in enumerate(tones):
        c.fill((yy % 8) == i, tname)
    A = c.all()
    c.dither(A & ((yy % 8) < 5), "steel1", np.clip((xx - 60) / 260.0, 0, 0.7))
    c.dither(A & ((yy % 8) >= 1) & ((yy % 8) < 5), "steel3", np.clip(1.0 - np.sqrt((xx - 10.0) ** 2 + (yy - 170.0) ** 2) / 150.0, 0, 0.8))
    c.glow(A & ((yy % 8) == 0), "steel5", 10, 170, 170, amt=0.9)
    # side guides
    for x0 in (0, W - 4):
        c.fill(c.rect(x0, 0, x0 + 3, H - 1), "steel0")
        c.fill(c.rect(x0 + (3 if x0 == 0 else 0), 0, x0 + (3 if x0 == 0 else 0), H - 1), "ink1")
    # worn stencil
    tm = text_mask(W, H, (W - text_width("CLOSED", True, 3)) // 2, 60, "CLOSED", bold=True, scale=3)
    c.fill(tm & (bayer(H, W) < 0.8) & ((yy % 8) != 7), "red1")
    c.fill(tm & (bayer(H, W) < 0.3) & ((yy % 8) < 2), "red2")
    c.speckle(A & ~tm, "warm2", 0.006, seed=9)
    c.speckle(A, "steel0", 0.01, seed=10)
    # bottom bar with hazard stripes and a handle
    bar = c.rect(0, H - 14, W - 1, H - 1)
    c.fill(bar, "ink1")
    stripe = bar & (((xx + yy) // 6) % 2 == 0) & (yy > H - 13) & (yy < H - 2)
    c.fill(bar & (yy > H - 13) & (yy < H - 2), "ink0")
    c.fill(stripe, "amber")
    c.dither(stripe, "warm4", np.clip((xx - 40) / 220.0, 0, 0.8))
    c.fill(c.rect(0, H - 14, W - 1, H - 14), "steel4")
    c.fill(c.rrect(W // 2 - 14, H - 11, W // 2 + 14, H - 5, 2), "steel1")
    c.fill(c.rect(W // 2 - 12, H - 10, W // 2 + 12, H - 10), "steel4")
    c.outline("ink0", c.rrect(W // 2 - 14, H - 11, W // 2 + 14, H - 5, 2))
    return c


def shutter_dents():
    W, H = HOLE[2], HOLE[3] + 4
    c = Canvas(W, H)
    for cx, cy, r in ((92, 96, 9), (124, 112, 10), (104, 132, 8)):
        d = c.ell(cx, cy, r, r * 0.8)
        c.fill(d, "steel1")
        c.fill(c.ell(cx - 1, cy - 1, r - 2, r * 0.8 - 2), "steel0")
        c.fill(c.edge(d, 1, 1) | c.edge(d, 0, 1), "steel5")
        c.fill(c.edge(d, -1, -1) | c.edge(d, 0, -1), "ink1")
        c.fill(c.ell(cx + 1, cy + 1, 2, 1.5), "ink1")
    return c


# ------------------------------------------------------------------ monitor
def crt_overlay():
    sw, sh = SCREEN[2], SCREEN[3]
    c = Canvas(sw, sh)
    yy, xx = c.grid()
    c.fill((yy % 2) == 1, "ink0", 70)
    # vignette and rounded glass corners
    d = np.maximum(np.abs(xx - sw / 2.0) / (sw / 2.0), np.abs(yy - sh / 2.0) / (sh / 2.0))
    r2 = ((xx - sw / 2.0) / (sw / 2.0)) ** 2 + ((yy - sh / 2.0) / (sh / 2.0)) ** 2
    c.fill((r2 > 1.25) & (bayer(sh, sw) < (r2 - 1.25) * 2.2), "ink0", 255)
    corner = c.all() & ~c.rrect(0, 0, sw - 1, sh - 1, 5)
    c.fill(corner, "ink0", 255)
    # a soft reflection, top left
    c.fill(c.seg([(8, 5), (30, 5)], 1) | c.seg([(6, 7), (6, 16)], 1), "grn5", 46)
    del d
    return c


def hall_cam():
    """The corridor outside, as the hall camera sees it (phosphor green)."""
    sw, sh = SCREEN[2], SCREEN[3]
    c = Canvas(sw, sh, "grn0")
    A = c.all()
    yy, xx = c.grid()
    # far wall and floor
    c.fill(c.rect(0, 0, sw - 1, 54), "grn0")
    c.dither(c.rect(0, 0, sw - 1, 54), "grn1", 0.35)
    floor = c.rect(0, 55, sw - 1, sh - 1)
    c.fill(floor, "grn0")
    c.dither(floor, "grn1", np.clip((yy - 55) / 60.0, 0, 0.6))
    c.fill(c.rect(0, 55, sw - 1, 55), "grn2")
    for i in range(-6, 14):
        x_far = sw / 2 + i * 10
        x_near = sw / 2 + i * 34
        c.line([(x_far, 56), (x_near, sh - 1)], "grn1")
    for y in (62, 72, 86):
        c.fill(c.rect(0, y, sw - 1, y), "grn1")
    # the street door at the far end, light leaking in
    c.fill(c.rect(88, 8, 116, 54), "grn1")
    c.fill(c.rect(90, 10, 114, 54), "grn0")
    c.fill(c.rect(94, 14, 110, 30), "grn2")
    c.dither(c.rect(94, 14, 110, 30), "grn3", 0.4)
    c.glow(floor, "grn2", 102, 56, 34, amt=0.8, ry=22)
    # a bench and a sign
    c.fill(c.rect(8, 44, 50, 46), "grn2")
    c.fill(c.rect(10, 47, 11, 54), "grn1")
    c.fill(c.rect(47, 47, 48, 54), "grn1")
    c.fill(c.rect(8, 34, 50, 35), "grn1")
    c.fill(c.rect(16, 12, 40, 26), "grn1")
    c.fill(c.rect(19, 15, 37, 16), "grn2")
    c.fill(c.rect(19, 19, 33, 19), "grn2")
    c.fill(c.rect(19, 22, 35, 22), "grn2")
    del A
    return c


# ------------------------------------------------------------------ desk and panels
def desk():
    c = Canvas(400, 76, "warm2")
    A = c.all()
    yy, xx = c.grid()
    c.grad(A, ["warm0", "warm1", "warm2"], 400, 76, 150, 0, dither=1.0)
    c.glow(A, "warm3", 190, -10, 240, amt=0.85, power=1.2, ry=90)
    c.glow(A, "warm4", 190, -14, 120, amt=0.6, power=1.3, ry=44)
    rng = np.random.default_rng(12)
    for _ in range(70):
        x = int(rng.integers(0, 380))
        y = int(rng.integers(4, 74))
        c.fill(c.rect(x, y, x + int(rng.integers(6, 22)), y), "warm1" if rng.random() < 0.6 else "warm0")
    for y in (25, 50):
        c.fill(c.rect(0, y, 399, y), "warm0")
        c.dither(c.rect(0, y + 1, 399, y + 1), "warm3", np.clip(1.0 - abs(xx - 190) / 200.0, 0, 0.8))
    c.fill(c.rect(0, 0, 399, 0), "ink0")
    c.fill(c.rect(0, 1, 399, 1), "warm4")
    c.dither(c.rect(0, 1, 399, 1), "warm2", np.clip(abs(xx - 190) / 210.0, 0, 1))
    # three felt mats: tools, talk, decide
    for x0, x1 in ((4, 139), (143, 262), (266, 395)):
        mat = c.rrect(x0, 6, x1, 71, 3)
        c.fill(c.rrect(x0 + 1, 7, x1 + 1, 72, 3), "warm0")
        c.fill(mat, "teal1")
        c.dither(mat, "teal2", np.clip(1.0 - (np.abs(xx - 190) / 260.0 + yy / 160.0), 0, 0.9))
        c.inline(mat, "ink1")
        c.fill(c.rect(x0 + 3, 7, x1 - 3, 7), "teal3")
    return c


def dialogue():
    c = Canvas(400, 60, "ink1")
    yy, xx = c.grid()
    A = c.all()
    c.fill(A, "ink0")
    body = c.rrect(2, 2, 397, 57, 3)
    c.fill(body, "ink1")
    c.dither(body, "teal1", np.clip(1.0 - yy / 70.0, 0, 0.7))
    c.inline(body, "teal3")
    c.fill(c.rect(5, 2, 394, 2), "teal4")
    for bx, by in ((6, 6), (393, 6), (6, 53), (393, 53)):
        c.px(bx, by, "teal4")
    return c


def board():
    """Clipboard backing for the two documents on the right."""
    c = Canvas(240, 360, "ink0")
    yy, xx = c.grid()
    b = c.rect(1, 0, 239, 359)
    c.grad(b, ["warm0", "warm1", "warm2"], 240, 360, 0, 0, dither=1.0)
    rng = np.random.default_rng(31)
    for _ in range(80):
        x = int(rng.integers(2, 220))
        y = int(rng.integers(0, 359))
        c.fill(c.rect(x, y, x + int(rng.integers(6, 18)), y), "warm0")
    c.fill(c.rect(0, 0, 0, 359), "ink0")
    c.fill(c.rect(1, 0, 1, 359), "warm3")
    return c


def paper(w, h, base="paper3", shade="paper2", edge="paper1", seed=1, stain=False, holes=False):
    c = Canvas(w + 2, h + 2)
    c.fill(c.rect(2, 2, w + 1, h + 1), "ink0", 110)
    p = c.rect(0, 0, w - 1, h - 1)
    c.fill(p, base)
    yy, xx = c.grid()
    c.dither(p, shade, np.clip((xx / float(w)) * 0.35 + (yy / float(h)) * 0.25 - 0.18, 0, 0.5))
    c.speckle(p, shade, 0.02, seed=seed)
    c.fill(c.rect(0, h - 1, w - 1, h - 1), edge)
    c.fill(c.rect(w - 1, 0, w - 1, h - 1), edge)
    c.fill(c.rect(0, 0, w - 1, 0), "paper4" if base.startswith("paper") else "manila3")
    if stain:
        ring = c.ell(w - 30, h - 22, 13, 12) & ~c.ell(w - 30, h - 22, 11, 10)
        c.dither(ring & p, shade, 0.75)
        c.dither(c.ell(w - 22, h - 14, 3, 2) & p, shade, 0.6)
    if holes:
        for x in (10, w - 11):
            c.fill(c.ell(x, 6, 2.2, 2.2), "warm0")
            c.px(x, 8, edge)
    return c


def printout(w, h, seed=4):
    """Tonight's contact list as it lies on the desk: tractor-feed printout with a hole every
    ten pixels down both margins and a perforation beside each."""
    c = paper(w, h, seed=seed)
    yy, xx = c.grid()
    p = c.rect(0, 0, w - 1, h - 1)
    for x in (0, w - 11):
        c.dither(c.rect(x, 0, x + 10, h - 1) & p, "paper2", 0.5)
        for y in range(6, h - 3, 10):
            c.fill(c.ell(x + 5, y, 2.2, 2.2), "warm0")
    for x in (11, w - 12):
        c.fill(c.rect(x, 0, x, h - 2) & ((yy % 3) == 0), "paper1")
    return c


def clip():
    c = Canvas(64, 16)
    body = c.rrect(4, 4, 59, 14, 3)
    c.shade(body, "steel", light=(-0.4, -0.8), contrast=0.9, round_px=3)
    spring = c.rrect(18, 0, 45, 9, 3)
    c.shade(spring, "steel", light=(-0.4, -0.8), contrast=1.0, round_px=3, bias=0.08)
    c.fill(c.ell(31.5, 5, 3, 2), "ink1")
    c.outline("ink0", body | spring)
    return c


def main():
    d = "clinic"
    h = hall()
    h.save(d + "/hall.png")
    ho = hall_door_open()
    ho.save(d + "/door_open.png")
    frames, pos = rain_frames()
    for i, f in enumerate(frames):
        f.save(d + "/rain_%d.png" % i)
    s = sill()
    s.save(d + "/sill.png")
    w = wall()
    w.save(d + "/wall.png")
    lg = lamp_glow()
    lg.save(d + "/lamp_glow.png")
    g = glass()
    g.save(d + "/glass.png")
    sh = shutter()
    sh.save(d + "/shutter.png")
    sd = shutter_dents()
    sd.save(d + "/shutter_dents.png")
    crt = crt_overlay()
    crt.save(d + "/crt_overlay.png")
    hc = hall_cam()
    hc.save(d + "/hall_cam.png")
    dk = desk()
    dk.save(d + "/desk.png")
    dg = dialogue()
    dg.save(d + "/dialogue.png")
    bd = board()
    bd.save(d + "/board.png")
    sheet = paper(232, 164, seed=2, stain=True)
    sheet.save(d + "/sheet.png")
    lst = printout(232, 164)
    lst.save(d + "/list.png")
    rec = paper(232, 186, base="manila3", shade="manila2", edge="manila1", seed=3, holes=True)
    rec.save(d + "/record.png")
    cl = clip()
    cl.save(d + "/clip.png")

    # review composite of the empty scene
    comp = Canvas(640, 360, "ink0")
    comp.blit(h, HOLE[0], HOLE[1])
    comp.blit(s, HOLE[0], HOLE[1] + HOLE[3] - 15)
    comp.blit(w, 0, 0)
    comp.blit(hc, SCREEN[0], SCREEN[1])
    comp.blit(dg, 0, 224)
    comp.blit(dk, 0, 284)
    comp.blit(bd, 400, 0)
    comp.blit(sheet, 404, 3)
    comp.blit(rec, 404, 171)
    comp.blit(cl, 488, 0)
    os.makedirs(OUT, exist_ok=True)
    comp.scaled(2).image().convert("RGB").save(os.path.join(OUT, "clinic_empty.png"))
    comp2 = Canvas(HOLE[2] * 2 + 12, HOLE[3] + 8, "ink0")
    comp2.blit(sh, 0, 0)
    comp2.blit(sd, 0, 0)
    h2 = h.copy()
    h2.blit(ho, 0, 0)
    comp2.blit(h2, HOLE[2] + 12, 0)
    comp2.scaled(2).image().convert("RGB").save(os.path.join(OUT, "clinic_parts.png"))
    print("clinic art written")


if __name__ == "__main__":
    main()
