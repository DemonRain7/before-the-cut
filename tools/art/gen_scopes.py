"""Close-up views for the three tools: penlight (eyes), grip bar (hand) and port scope (socket).

Every view is 220 x 186, the size of the counter window. The game stacks:
  eyes:  eyes_back -> iris_r / iris_l (moved by the light) -> pupil frame (natural eyes) -> eyes_front
  grip:  grip_bg -> grip_open or grip_closed
  port:  port (-> port_threads, pulsing, when tonight's port sign is threads)
Left and right are the patient's own: the patient's right eye is on our left.
"""
import os
import sys

import numpy as np

from people import CLOTH, OUTLINE, SKIN, grow, smooth, stroke
from px import OUT, Canvas, contact_sheet

W, H = 220, 186
EYE_R = (60, 86)
EYE_L = (160, 86)
THREAD = "1a0c1e"


def almond(c, ex, ey, rx, ry):
    return c.ell(ex, ey, rx, ry) & c.ell(ex, ey + ry * 0.7, rx * 1.25, ry * 1.5) & c.ell(ex, ey - ry * 0.7, rx * 1.25, ry * 1.5)


def skin_field(c, skin, contrast=0.55, bias=0.05):
    c.shade(c.all(), skin[1:], light=(-0.8, 0.3), contrast=contrast, round_amt=0.0, bias=bias, dither=0.9)


def nose_bridge(c, skin):
    yy, xx = c.grid()
    band = c.rect(112, 40, 124, H - 1)
    c.dither(band, skin[2], np.clip((yy - 40) / 200.0 + 0.25, 0, 0.7))
    c.dither(c.rect(100, 64, 104, H - 1), skin[4], np.clip((yy - 64) / 160.0 + 0.2, 0, 0.6))


def brow_big(c, ex, ey, color, inner=-34, outer=-30, width=6, span=38, side=1):
    """side=1: the brow's inner end is on the right (the patient's right eye, on our left)."""
    xi, xo = ex + side * span * 0.8, ex - side * span
    stroke(c, [(xi, ey + inner), (ex, ey + (inner + outer) / 2.0 - 3), (xo, ey + outer)], color, width)


# ------------------------------------------------------------------ eye kinds
def natural_eye(front, back, ex, ey, skin, red=False, tired=False):
    yy, xx = front.grid()
    hole = almond(front, ex, ey, 30, 16)
    # sclera behind the opening
    wide = grow(hole, 3)
    back.fill(wide, "efe6cf")
    back.fill(wide & (yy < ey - 9), "b3a587")
    back.dither(wide & (yy < ey - 5), "b3a587", 0.5)
    back.dither(wide & (np.abs(xx - ex) > 22), "e0a090", 0.5)
    if red:
        back.dither(wide, "e09080", 0.3)
        for s in (-1, 1):
            stroke(back, [(ex + s * 29, ey + 1), (ex + s * 19, ey - 2), (ex + s * 13, ey + 3)], "c8483c")
            stroke(back, [(ex + s * 28, ey + 5), (ex + s * 20, ey + 7)], "c8483c")
    # lids on the front layer
    front.erase(hole)
    ring1 = grow(hole, 1) & ~hole
    ring3 = grow(hole, 3) & ~hole
    front.fill(ring3 & (yy < ey - 1), OUTLINE)
    front.fill(ring1 & (yy >= ey - 1), "a8483c" if red else skin[2])
    crease = almond(front, ex, ey - 5, 34, 17)
    cr = grow(crease, 1) & ~crease & (yy < ey - 10)
    front.fill(cr & ~grow(hole, 3), skin[2])
    for dx in (-27, -22, 22, 27):
        stroke(front, [(ex + dx, ey - 9 + abs(dx) // 6), (ex + dx + (2 if dx > 0 else -2), ey - 14 + abs(dx) // 6)], OUTLINE)
    if tired:
        bag = almond(front, ex, ey + 9, 26, 12)
        b = grow(bag, 1) & ~bag & (yy > ey + 14)
        front.fill(b, skin[2])
        front.dither(bag & (yy > ey + 14), skin[2], 0.3)
    return hole


def iris_natural(dark, light, r=15):
    c = Canvas(48, 48)
    yy, xx = c.grid()
    c.fill(c.ell(24, 24, r, r), "0b1014")
    inner = c.ell(24, 24, r - 1.6, r - 1.6)
    c.fill(inner, dark)
    d = np.sqrt((xx - 24.0) ** 2 + (yy - 24.0) ** 2)
    c.dither(inner, light, np.clip(1.15 - d / (r - 2.0), 0, 1) * 0.9)
    for a in np.linspace(0, 2 * np.pi, 14, endpoint=False):
        x0, y0 = 24 + np.cos(a) * 5, 24 + np.sin(a) * 5
        x1, y1 = 24 + np.cos(a) * (r - 3), 24 + np.sin(a) * (r - 3)
        stroke(c, [(x0, y0), (x1, y1)], light)
    c.dither(inner & (yy > 26), dark, 0.35)
    return c


def optic_eye(front, back, ex, ey, cracked=True):
    yy, xx = front.grid()
    outer = front.ell(ex, ey, 33, 33)
    front.fill(grow(outer, 1), OUTLINE)
    front.shade(outer, CLOTH["chrome"], light=(-0.8, 0.3), round_px=5, bias=-0.04)
    hole = front.ell(ex, ey, 23, 23)
    front.fill(grow(hole, 2), "0b1014")
    front.erase(hole)
    for a in (0.5, 2.1, 3.7, 5.3):
        sx, sy = int(ex + np.cos(a) * 28), int(ey + np.sin(a) * 28)
        front.fill(front.ell(sx, sy, 1.6, 1.6), "1b2228")
        front.px(sx, sy - 1, "dbe6e0")
    back.fill(grow(hole, 3), "07090c")
    back.dither(hole & (yy < ey - 8), "14484f", 0.4)
    stroke(back, [(ex - 16, ey - 12), (ex - 8, ey - 17)], "2a8f96")
    if cracked:
        for pts in ([(ex - 14, ey - 18), (ex + 2, ey - 2), (ex - 2, ey + 9), (ex + 12, ey + 19)],
                    [(ex + 2, ey - 2), (ex + 19, ey - 9)], [(ex - 2, ey + 9), (ex - 15, ey + 13)],
                    [(ex + 2, ey - 2), (ex + 9, ey + 4)]):
            stroke(front, pts, "c8fff6")
        stroke(front, [(ex - 13, ey - 17), (ex + 1, ey - 3)], "5ee6e0")
    return hole


def iris_optic():
    c = Canvas(48, 48)
    c.fill(c.ell(24, 24, 14, 14), "1b2228")
    c.fill(c.ell(24, 24, 12.4, 12.4), "14484f")
    c.fill(c.ell(24, 24, 9, 9), "2a8f96")
    c.fill(c.ell(24, 24, 6.4, 6.4), "07090c")
    for a in np.linspace(0, 2 * np.pi, 6, endpoint=False):
        stroke(c, [(24 + np.cos(a) * 7, 24 + np.sin(a) * 7), (24 + np.cos(a) * 12, 24 + np.sin(a) * 12)], "14484f")
    c.px(21, 20, "c8fff6")
    c.px(20, 21, "5ee6e0")
    return c


def housing_eye(front, back, ex, ey, hw, hh, back_col, line_col):
    """A rectangular implant: combat optic or display eye. Returns the hole mask."""
    yy, xx = front.grid()
    box = front.rrect(ex - hw - 7, ey - hh - 7, ex + hw + 7, ey + hh + 7, 5)
    front.fill(grow(box, 1), OUTLINE)
    front.shade(box, ["0b1014", "1b2228", "2e3a42", "4a5a63", "70838a"], light=(-0.8, 0.3), round_px=5, bias=-0.06)
    front.fill(box & (yy == ey - hh - 7), "a3b5b6")
    hole = front.rrect(ex - hw, ey - hh, ex + hw, ey + hh, 3)
    front.fill(grow(hole, 2), "07090c")
    front.erase(hole)
    back.fill(grow(hole, 3), back_col)
    back.fill(grow(hole, 3) & (yy % 3 == 0), line_col)
    return hole


def iris_combat():
    c = Canvas(48, 48)
    c.fill(c.rrect(8, 21, 40, 27, 2), "8a5a22")
    c.fill(c.rrect(10, 22, 38, 26, 1), "c9781e")
    c.fill(c.rect(17, 23, 31, 25), "f2c979")
    c.fill(c.rect(22, 23, 26, 25), "fbe9b5")
    return c


def iris_display(rows, color="c8fff6", color2="5ee6e0", n=4):
    c = Canvas(48, 48)
    h, w = len(rows), len(rows[0])
    x0, y0 = 24 - w * n // 2, 24 - h * n // 2
    for r, row in enumerate(rows):
        for q, ch in enumerate(row):
            if ch == "#":
                c.fill(c.rect(x0 + q * n, y0 + r * n, x0 + q * n + n - 1, y0 + r * n + n - 1), color if r < 2 else color2)
    return c


HEART = [".#.#.", "#####", "#####", ".###.", "..#.."]


# ------------------------------------------------------------------ eyes per patient
def eyes(pid):
    skin = SKIN[pid]
    front, back = Canvas(W, H), Canvas(W, H, "07090c")
    yy, xx = front.grid()
    skin_field(front, skin)
    nose_bridge(front, skin)
    out = {}
    if pid == "kip":
        natural_eye(front, back, EYE_R[0], EYE_R[1], skin)
        optic_eye(front, back, EYE_L[0], EYE_L[1])
        brow_big(front, EYE_R[0], EYE_R[1], "6a2c1c", inner=-36, outer=-27, width=5)
        brow_big(front, EYE_L[0], EYE_L[1] - 4, "6a2c1c", inner=-36, outer=-27, width=5, side=-1)
        for fx, fy in ((22, 132), (34, 140), (46, 134), (70, 142), (84, 136), (140, 144), (176, 140), (190, 146), (58, 150)):
            front.fill(front.rect(fx, fy, fx + 1, fy + 1), skin[2])
        for tri in ([(0, 0), (60, 0), (30, 26)], [(50, 0), (120, 0), (88, 22)], [(110, 0), (180, 0), (150, 26)], [(170, 0), (219, 0), (219, 30)]):
            m = front.poly(tri)
            front.shade(m, CLOTH["ginger"], light=(-0.8, 0.3), round_px=8)
            front.outline(OUTLINE, m)
        out["iris_r"] = iris_natural("4a2a16", "9a6230")
        out["iris_l"] = iris_optic()
    elif pid == "rook":
        natural_eye(front, back, EYE_R[0], EYE_R[1], skin, red=True)
        natural_eye(front, back, EYE_L[0], EYE_L[1], skin, red=True)
        front.dither(front.rect(0, 40, W - 1, 62), skin[1], 0.5)
        brow_big(front, EYE_R[0], EYE_R[1], "100a0c", inner=-22, outer=-30, width=8)
        brow_big(front, EYE_L[0], EYE_L[1], "100a0c", inner=-22, outer=-30, width=8, side=-1)
        stroke(front, [(203, 20), (196, 150)], skin[5], 2)
        for t in (36, 58, 112, 134):
            stroke(front, [(193, t), (207, t + 2)], skin[1])
        front.dither(front.rect(0, 0, W - 1, 22), skin[1], 0.5)
        out["iris_r"] = iris_natural("20120c", "5a3820", r=14)
        out["iris_l"] = iris_natural("20120c", "5a3820", r=14)
    elif pid == "vale":
        for ex, ey in (EYE_R, EYE_L):
            housing_eye(front, back, ex, ey, 32, 13, "07090c", "0b1014")
        front.fill(front.rect(EYE_R[0] + 40, EYE_R[1] - 2, EYE_L[0] - 40, EYE_L[1] + 2), "2e3a42")
        front.fill(front.rect(EYE_R[0] + 40, EYE_R[1] - 2, EYE_L[0] - 40, EYE_R[1] - 2), "70838a")
        brow_big(front, EYE_R[0], EYE_R[1] - 4, "0e141c", inner=-32, outer=-32, width=4)
        brow_big(front, EYE_L[0], EYE_L[1] - 4, "0e141c", inner=-32, outer=-32, width=4, side=-1)
        hair = front.poly([(0, 0), (W, 0), (W, 22), (150, 12), (96, 26), (40, 14), (0, 24)])
        front.shade(hair, CLOTH["black"], light=(-0.8, 0.3), round_px=10)
        front.outline(OUTLINE, hair)
        out["iris_r"] = iris_combat()
        out["iris_l"] = iris_combat()
    elif pid == "juno":
        for ex, ey in (EYE_R, EYE_L):
            housing_eye(front, back, ex, ey, 32, 16, "0a2e34", "0e3a42")
        brow_big(front, EYE_R[0], EYE_R[1] - 6, "160c24", inner=-34, outer=-30, width=4)
        brow_big(front, EYE_L[0], EYE_L[1] - 6, "160c24", inner=-34, outer=-30, width=4, side=-1)
        hair = front.poly([(0, 0), (150, 0), (40, 44), (0, 60)])
        front.shade(hair, CLOTH["violet"], light=(-0.8, 0.3), round_px=14)
        front.outline(OUTLINE, hair)
        front.dither(front.poly([(150, 0), (W, 0), (W, 34), (170, 22)]), CLOTH["violet"][1], 0.5)
        jaw = front.poly([(0, 150), (60, 166), (160, 166), (W, 150), (W, H), (0, H)])
        front.shade(jaw, CLOTH["chrome"], light=(-0.8, 0.3), round_px=12, bias=-0.04)
        stroke(front, [(0, 149), (60, 165), (160, 165), (W, 149)], OUTLINE)
        out["iris_r"] = iris_display(HEART)
        out["iris_l"] = iris_display(HEART)
    elif pid == "maren":
        natural_eye(front, back, EYE_R[0], EYE_R[1], skin, tired=True)
        natural_eye(front, back, EYE_L[0], EYE_L[1], skin, tired=True)
        brow_big(front, EYE_R[0], EYE_R[1], "70838a", inner=-33, outer=-29, width=5)
        brow_big(front, EYE_L[0], EYE_L[1], "70838a", inner=-33, outer=-29, width=5, side=-1)
        for s, ex in ((-1, EYE_R[0]), (1, EYE_L[0])):
            for k in range(3):
                stroke(front, [(ex + s * 36, EYE_R[1] - 2 + k * 5), (ex + s * 48, EYE_R[1] - 6 + k * 9)], skin[2])
            front.dither(front.ell(ex + s * 6, EYE_R[1] + 44, 34, 16), "c8705e", 0.4)
        front.dither(front.ell(110, 30, 90, 12), "c8705e", 0.3)
        strap = front.rect(0, 0, W - 1, 12)
        front.fill(strap, "2a1a1a")
        front.fill(front.rect(0, 12, W - 1, 12), "5a3a2a")
        front.fill(front.rect(0, 13, W - 1, 13), OUTLINE)
        out["iris_r"] = iris_natural("2c3a26", "7a9460")
        out["iris_l"] = iris_natural("2c3a26", "7a9460")
    out["eyes_front"] = front
    out["eyes_back"] = back
    return out


def pupil(r):
    c = Canvas(24, 24)
    c.fill(c.ell(12, 12, r, r), "07090c")
    return c


def light():
    c = Canvas(110, 110)
    for col, r, amt in (("5c3230", 54, 0.9), ("8a5a22", 44, 0.9), ("c98a22", 32, 0.95), ("f2c979", 20, 1.0), ("fbe9b5", 9, 1.2)):
        c.glow(c.all(), col, 55, 55, r, amt=amt, power=0.8)
    return c


def frame():
    """The scope's dark surround: a rounded viewing window and a strip for the caption."""
    c = Canvas(W, H, "07090c")
    yy, xx = c.grid()
    view = c.rrect(5, 5, W - 6, 158, 6)
    c.fill(grow(view, 1) & ~view, "2e3a42")
    c.fill(grow(view, 2) & ~grow(view, 1), "0b1014")
    c.erase(view)
    strip = c.rect(5, 163, W - 6, H - 5)
    c.fill(strip, "0b1014")
    c.fill(c.rect(5, 163, W - 6, 163), "1b2228")
    for x, y in ((2, 2), (W - 3, 2), (2, H - 3), (W - 3, H - 3)):
        c.px(x, y, "4a5a63")
    return c


def vignette():
    """Dithered darkening toward the corners of the viewing window."""
    c = Canvas(W, H)
    yy, xx = c.grid()
    d = np.sqrt(((xx - 110) / 120.0) ** 2 + ((yy - 82) / 90.0) ** 2)
    c.dither(c.all(), "07090c", np.clip((d - 0.72) * 2.2, 0, 0.9))
    return c


# ------------------------------------------------------------------ grip
def grip_bg():
    c = Canvas(W, H, "2a1a1a")
    yy, xx = c.grid()
    c.grad(c.all(), ["1c1214", "2a1a1a", "4a2a22", "7a4630"], 220, 0, 20, 186, dither=1.0)
    for y in (34, 76, 128, 166):
        c.fill(c.rect(0, y, W - 1, y), "1c1214")
    rng = np.random.default_rng(5)
    for _ in range(60):
        x, y = int(rng.integers(0, 200)), int(rng.integers(0, 186))
        c.fill(c.rect(x, y, x + int(rng.integers(8, 30)), y), "2a1a1a")
    # base plate
    plate = c.rrect(22, 82, 198, 128, 5)
    c.fill(c.rrect(24, 85, 200, 131, 5), "140e10")
    c.shade(plate, ["0b1014", "1b2228", "2e3a42", "4a5a63"], light=(-0.8, 0.3), round_px=6)
    c.outline(OUTLINE, plate)
    for x in (30, 190):
        for y in (89, 121):
            c.fill(c.ell(x, y, 2, 2), "0b1014")
            c.px(x, y - 1, "70838a")
    # posts and the bar
    for x in (40, 180):
        post = c.rrect(x - 8, 90, x + 8, 120, 3)
        c.shade(post, CLOTH["chrome"], light=(-0.8, 0.3), round_px=4)
        c.outline(OUTLINE, post)
    bar = c.rrect(44, 98, 176, 112, 6)
    c.shade(bar, ["0b1014", "1b2228", "2e3a42", "4a5a63"], light=(0, -1.0), round_px=5, contrast=1.3)
    c.fill(bar & (xx % 6 == 0), "0b1014")
    c.fill(c.rect(48, 100, 172, 100), "70838a")
    c.outline(OUTLINE, bar)
    # cable and a small dial housing on the patient's far side
    stroke(c, [(198, 106), (210, 110), (219, 124)], "0b1014", 3)
    return c


def hand_big(skin, closed, scale=1.0, sleeve=None, cuff=None, knuckle=None, joints=False, seams=None, nails=None, scar=False):
    c = Canvas(W, H)
    yy, xx = c.grid()
    cx = 110
    aw = int(46 * scale)
    pw = int(64 * scale) // 4 * 4
    fw = pw // 4
    x0 = cx - pw // 2
    arm = c.rect(cx - aw // 2, 0, cx + aw // 2, 54)
    palm = c.rrect(x0, 40, x0 + pw - 1, 98, 9)
    m = arm | palm
    side = 1
    fingers = []
    if closed:
        for i in range(4):
            f = c.rrect(x0 + i * fw + 1, 86 + (2 if i in (0, 3) else 0), x0 + (i + 1) * fw - 1, 119 - (3 if i == 3 else 0), 5)
            fingers.append(f)
            m |= f
        thumb = c.rrect(x0 + pw - 6, 64, x0 + pw + 12, 116, 7)
    else:
        for i, ln in enumerate((48, 58, 54, 40)):
            f = c.rrect(x0 + i * fw + 1, 88, x0 + (i + 1) * fw - 1, 98 + int(ln * scale), 5)
            fingers.append(f)
            m |= f
        thumb = smooth(c.seg([(x0 + pw - 4, 70), (x0 + pw + 22, 96)], 15), 2)
    m |= thumb
    c.shade(m, skin, light=(-0.8, 0.3), round_px=9, round_amt=0.6, contrast=0.8)
    for i, f in enumerate(fingers):
        if i > 0:
            fx = x0 + i * fw
            stroke(c, [(fx, 92), (fx, 96 + (20 if closed else 40))], skin[1])
        ys, xs = np.nonzero(f)
        top, bot = ys.min(), ys.max()
        if closed:
            c.fill(f & (yy >= top + 2) & (yy <= top + 5), skin[-1] if knuckle is None else knuckle)
            c.fill(f & (yy == top + 17), skin[1])
            c.fill(f & (yy >= bot - 3), skin[1])
        else:
            for k in (0.42, 0.7):
                c.fill(f & (yy == int(top + (bot - top) * k)), skin[2] if not joints else skin[0])
            if nails:
                c.fill(f & (yy >= bot - 7) & (yy <= bot - 2) & (xx > xs.min() + 1) & (xx < xs.max() - 1), nails)
            if knuckle is not None:
                c.fill(f & (yy >= top + 6) & (yy <= top + 8), knuckle)
    if seams:
        c.fill(palm & (yy == 60), seams)
        c.fill(palm & (yy == 61), skin[-1])
    if joints:
        for i in range(4):
            fx = x0 + i * fw + fw // 2
            c.fill(c.ell(fx, 78, 2.4, 2.4), skin[0])
            c.px(fx - 1, 77, skin[-1])
    if scar:
        stroke(c, [(cx - 20, 44), (cx - 6, 72)], skin[-1], 2)
    c.outline(OUTLINE, m)
    c.outline(OUTLINE, thumb)
    if sleeve is not None:
        sl = c.rect(cx - aw // 2 - 5, 0, cx + aw // 2 + 5, 30)
        c.shade(sl, sleeve, light=(-0.8, 0.3), round_px=8)
        c.outline(OUTLINE, sl)
    if cuff is not None:
        cf = c.rect(cx - aw // 2 - 3, 28, cx + aw // 2 + 3, 38)
        c.fill(cf, cuff[0])
        c.fill(cf & (yy >= 36), cuff[1])
        c.outline(OUTLINE, cf)
    return c


def grip(pid):
    kw = {
        "kip": dict(skin=SKIN["kip"], sleeve=CLOTH["hivis"], nails="fbdcb0"),
        "rook": dict(skin=SKIN["rook"], scale=1.2, knuckle="c8483c", scar=True, nails="d89a68"),
        "vale": dict(skin=SKIN["vale"], sleeve=CLOTH["suit"], cuff=("efe6cf", "b3a587"), nails="f2e6d4"),
        "juno": dict(skin=CLOTH["chrome"], sleeve=CLOTH["leather"], joints=True),
        "maren": dict(skin=CLOTH["glove"] + ["f0dba8"], sleeve=CLOTH["canvas"], seams="6a4a2a", cuff=("9a7a4a", "6a4a2a")),
    }[pid]
    return {"grip_open": hand_big(closed=False, **kw), "grip_closed": hand_big(closed=True, **kw)}


# ------------------------------------------------------------------ ports
def socket(c, x, y, r=24, pins=8, burnt=(), scuffed=False):
    ring = c.ell(x, y, r, r)
    c.fill(grow(ring, 1), OUTLINE)
    c.shade(ring, CLOTH["chrome"], light=(-0.8, 0.3), round_px=5, bias=-0.06)
    well = c.ell(x, y, r - 7, r - 7)
    c.fill(grow(well, 1), "0b1014")
    c.fill(well, "1b2228")
    c.fill(c.ell(x, y, 4.5, 4.5), "07090c")
    for i in range(pins):
        a = 2 * np.pi * i / pins + 0.4
        px_, py_ = int(round(x + np.cos(a) * (r - 12))), int(round(y + np.sin(a) * (r - 12)))
        if i in burnt:
            c.fill(c.ell(px_, py_, 3.2, 3.2), "07090c")
            c.px(px_, py_, "b06a3c")
            c.px(px_ + 1, py_ - 1, "7a4630")
        else:
            c.fill(c.ell(px_, py_, 2.2, 2.2), "d4a040")
            c.px(px_ - 1, py_ - 1, "f4d880")
    if scuffed:
        for a, ln in ((0.3, 7), (1.6, 5), (2.8, 9), (4.2, 6), (5.3, 8)):
            x0, y0 = x + np.cos(a) * (r - 5), y + np.sin(a) * (r - 5)
            stroke(c, [(x0, y0), (x0 + np.cos(a + 1.4) * ln, y0 + np.sin(a + 1.4) * ln)], "1b2228")
            stroke(c, [(x0 + 1, y0 + 1), (x0 + 1 + np.cos(a + 1.4) * ln * 0.6, y0 + 1 + np.sin(a + 1.4) * ln * 0.6)], "ffffff")
    return ring


def wrist(c, skin, y0=38, y1=148):
    """A forearm lying across the view."""
    yy, xx = c.grid()
    arm = c.rect(0, y0, W - 1, y1)
    c.shade(arm, skin[1:], light=(-0.2, -1.0), contrast=0.8, round_px=40, round_amt=0.3, bias=0.02, dither=0.9)
    c.fill(c.rect(0, y0 - 1, W - 1, y0 - 1), OUTLINE)
    c.fill(c.rect(0, y1 + 1, W - 1, y1 + 1), OUTLINE)
    for x in (64, 70):
        stroke(c, [(x - 40, y0 + 22), (x, y0 + 24), (x + 30, y0 + 20)], skin[2])
    return arm


def threads(c, x, y, seed=3, n=9, color=THREAD, r0=25, aim=None, spread=np.pi, reach=(22, 46)):
    """Dark threads leaving a port at (x, y), starting r0 from its centre. With no aim they leave all
    round; with one (radians: 0 is right, pi/2 down) they fan out over aim - spread .. aim + spread."""
    rng = np.random.default_rng(seed)
    for i in range(n):
        if aim is None:
            a = 2 * np.pi * i / n + rng.uniform(-0.25, 0.25)
        else:
            a = aim + spread * ((2.0 * i / (n - 1) - 1.0) if n > 1 else 0.0) + rng.uniform(-0.2, 0.2)
        px_, py_ = x + np.cos(a) * r0, y + np.sin(a) * r0
        ln = rng.integers(reach[0], reach[1])
        pts = [(px_, py_)]
        for k in range(4):
            a += rng.uniform(-0.5, 0.5)
            px_, py_ = px_ + np.cos(a) * ln / 4.0, py_ + np.sin(a) * ln / 4.0
            pts.append((px_, py_))
            if k == 1:
                b = a + rng.choice([-0.9, 0.9])
                stroke(c, [(px_, py_), (px_ + np.cos(b) * 10, py_ + np.sin(b) * 10),
                           (px_ + np.cos(b + 0.4) * 17, py_ + np.sin(b + 0.4) * 17)], color)
        stroke(c, pts, color)
        stroke(c, pts[:2], color, 2)


def veins(skin_mask, fans, halo="4a2440"):
    """The port_threads overlay: each fan is a set of threads() arguments. A bruise of dithered
    colour runs along every thread, and only the bare skin in skin_mask shows any of it."""
    t = Canvas(W, H)
    for kw in fans:
        threads(t, **kw)
    line = t.alpha()
    t.dither(grow(line, 1) & ~line, halo, 0.5)
    t.erase(~skin_mask)
    return t


def port(pid):
    """The calm port, and port_threads: the same skin with dark threads under it, laid over the port
    when tonight's port sign is threads. Every patient has both."""
    skin = SKIN[pid]
    c = Canvas(W, H, "0b1014")
    yy, xx = c.grid()
    out = {}
    if pid == "kip":
        c.fill(c.all(), "121c22")
        arm = wrist(c, skin)
        sl = c.rect(0, 30, 44, 156)
        c.shade(sl, CLOTH["hivis"], light=(-0.2, -1.0), round_px=10)
        c.fill(c.rect(34, 30, 38, 156), "a3b5b6")
        c.outline(OUTLINE, sl)
        ring = socket(c, 124, 92, scuffed=True)
        for fx, fy in ((84, 60), (166, 70), (176, 120), (92, 130), (150, 136)):
            c.px(fx, fy, skin[2])
        out["port_threads"] = veins(arm & ~grow(sl, 1) & ~grow(ring, 2),
                                    [dict(x=124, y=92, seed=11, n=9, r0=27, reach=(26, 52))])
    elif pid == "rook":
        c.fill(c.all(), "121c22")
        arm = wrist(c, skin, 28, 158)
        c.glow(c.all(), "3a2020", 118, 94, 54, amt=0.9, power=0.9)
        c.glow(c.all(), "1c1218", 118, 94, 36, amt=0.8, power=0.9)
        ring = socket(c, 118, 94, r=26, burnt=(1, 2))
        for dx, dy in ((-34, -18), (30, 26), (38, -12), (-26, 30), (8, -38), (-40, 6)):
            c.fill(c.rect(118 + dx, 94 + dy, 119 + dx, 95 + dy), "7a4630")
            c.px(118 + dx + 2, 94 + dy + 1, "1c1218")
        stroke(c, [(150, 60), (176, 78), (204, 82)], skin[5], 2)
        for t in (158, 172, 188):
            stroke(c, [(t, 64 + (t - 150) // 3), (t + 2, 76 + (t - 150) // 3)], skin[5])
        # the burnt pins are on the lower rim: the threads run out from that side
        out["port_threads"] = veins(arm & ~grow(ring, 2),
                                    [dict(x=118, y=94, seed=13, n=8, r0=29, aim=1.58, spread=1.3, reach=(30, 58))],
                                    halo="8a4466")
    elif pid == "maren":
        c.fill(c.all(), "121c22")
        arm = wrist(c, skin)
        gl = c.rect(150, 30, W - 1, 156)
        c.shade(gl, CLOTH["glove"], light=(-0.2, -1.0), round_px=12)
        c.fill(c.rect(150, 30, 153, 156), "6a4a2a")
        for y in (58, 92, 126):
            stroke(c, [(160, y), (W - 1, y + 3)], "6a4a2a")
        c.outline(OUTLINE, gl)
        ring = socket(c, 96, 94)
        # they run toward the glove and go on under its cuff
        out["port_threads"] = veins(arm & ~grow(gl, 1) & ~grow(ring, 2),
                                    [dict(x=96, y=94, seed=17, n=8, r0=27, aim=0.0, spread=1.35, reach=(30, 60))])
        burn = smooth(c.ell(40, 74, 16, 9) | c.ell(50, 80, 10, 7), 2)
        c.fill(burn, skin[5])
        c.dither(burn, "f8c8c0", 0.5)
        c.fill(grow(burn, 1) & ~burn, skin[3])
        stroke(c, [(32, 72), (46, 76)], "ffffff")
        for x in (20, 130, 140):
            stroke(c, [(x, 120), (x + 8, 132)], skin[2])
    elif pid == "vale":
        neck = c.rect(34, 0, 186, H - 1)
        c.shade(neck, skin[1:], light=(-1.0, 0.1), contrast=0.8, round_px=50, round_amt=0.3, dither=0.9)
        c.fill(c.rect(33, 0, 33, H - 1), OUTLINE)
        c.fill(c.rect(187, 0, 187, H - 1), OUTLINE)
        c.dither(c.rect(34, 0, 186, 20), skin[1], 0.6)
        flaps = c.none()
        for s, pts in ((-1, [(0, 100), (62, 132), (48, H), (0, H)]), (1, [(W, 100), (158, 132), (172, H), (W, H)])):
            flap = c.poly(pts)
            c.shade(flap, CLOTH["suit"], light=(-0.8, 0.3), round_px=10)
            c.outline(OUTLINE, flap)
            flaps |= flap
        for x, y in ((56, 142), (164, 142)):
            c.fill(c.ell(x, y, 2, 2), "dbe6e0")
        ring = socket(c, 110, 84)
        out["port_threads"] = veins(neck & ~grow(flaps, 1) & ~grow(ring, 2), [dict(x=110, y=84, seed=7, n=10, r0=27)])
    elif pid == "juno":
        neck = c.rect(30, 0, 190, H - 1)
        c.shade(neck, skin[1:], light=(-1.0, 0.1), contrast=0.8, round_px=50, round_amt=0.3, dither=0.9)
        c.fill(c.rect(29, 0, 29, H - 1), OUTLINE)
        c.fill(c.rect(191, 0, 191, H - 1), OUTLINE)
        c.dither(c.rect(30, 0, 190, 22), skin[1], 0.6)
        vb = c.rrect(44, 44, 84, 132, 6)
        c.shade(vb, ["0b1014", "1b2228", "2e3a42", "4a5a63"], light=(-0.8, 0.3), round_px=6)
        for gy in range(56, 122, 8):
            c.fill(c.rect(52, gy, 76, gy + 2), "70838a")
            c.fill(c.rect(52, gy + 3, 76, gy + 3), "0b1014")
        c.fill(c.ell(64, 126, 2, 2), "5ee6e0")
        c.outline(OUTLINE, vb)
        jacks = c.none()
        for i in range(4):
            y = 40 + i * 26
            j = c.rrect(118, y, 146, y + 18, 3)
            jacks |= j
            c.fill(grow(j, 1), OUTLINE)
            c.shade(j, CLOTH["chrome"], light=(-0.8, 0.3), round_px=4, bias=-0.05)
            c.fill(c.rect(123, y + 5, 141, y + 13), "07090c")
            for k in range(4):
                c.fill(c.rect(125 + k * 4, y + 7, 126 + k * 4, y + 11), "d4a040")
        for a, b in (((96, 30), (104, 62)), ((156, 50), (170, 84)), ((98, 120), (108, 150))):
            stroke(c, [a, b], skin[5], 2)
            for k in (0.25, 0.5, 0.75):
                mx, my = a[0] + (b[0] - a[0]) * k, a[1] + (b[1] - a[1]) * k
                stroke(c, [(mx - 3, my + 1), (mx + 3, my - 1)], skin[5])
        burn = smooth(c.seg([(152, 112), (176, 142)], 9), 2)
        c.fill(burn, "7a4630")
        c.dither(burn, "4a2a22", 0.5)
        c.fill(grow(burn, 1) & ~burn, skin[2])
        top = c.poly([(0, 160), (70, 172), (150, 172), (W, 160), (W, H), (0, H)])
        c.shade(top, CLOTH["leather"], light=(-0.8, 0.3), round_px=8)
        c.outline(OUTLINE, top)
        # out from every jack, sideways: toward the voice box and toward the back of the neck
        fans = []
        for i in range(4):
            fans.append(dict(x=132, y=49 + i * 26, seed=19 + i, n=2, r0=19, aim=np.pi, spread=0.45, reach=(20, 40)))
            fans.append(dict(x=132, y=49 + i * 26, seed=29 + i, n=2, r0=19, aim=0.0, spread=0.45, reach=(18, 34)))
        out["port_threads"] = veins(neck & ~grow(vb, 1) & ~grow(jacks, 2) & ~grow(top, 1), fans)
    out["port"] = c
    return out


# ------------------------------------------------------------------ export
PATIENTS = ["kip", "rook", "vale", "juno", "maren"]


def main(only=None):
    frame().save("scope/frame.png")
    vignette().save("scope/vignette.png")
    light().save("scope/light.png")
    grip_bg().save("scope/grip_bg.png")
    for r in range(4, 11):
        pupil(r).save("scope/pupil_%d.png" % r)
    for pid in PATIENTS:
        if only and pid not in only:
            continue
        parts = {}
        parts.update(eyes(pid))
        parts.update(grip(pid))
        parts.update(port(pid))
        for k, c in parts.items():
            c.save("scope/%s/%s.png" % (pid, k))
        # review sheet
        ev = Canvas(W, H, "07090c")
        ev.blit(parts["eyes_back"])
        for key, (ex, ey) in (("iris_r", EYE_R), ("iris_l", EYE_L)):
            ev.blit(parts[key], ex - 24, ey - 24)
        ev.blit(parts["eyes_front"])
        ev.blit(vignette())
        ev.blit(frame())
        g1 = grip_bg()
        g1.blit(parts["grip_open"])
        g2 = grip_bg()
        g2.blit(parts["grip_closed"])
        pt = parts["port"].copy()
        pt.blit(parts["port_threads"])
        contact_sheet([("eyes", ev), ("grip open", g1), ("grip closed", g2), ("port", parts["port"]), ("port threads", pt)],
                      os.path.join(OUT, "scope_%s.png" % pid), scale=2, per_row=5)
    print("scopes written")


if __name__ == "__main__":
    main(sys.argv[1:] or None)
