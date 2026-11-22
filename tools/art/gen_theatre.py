"""The back-room theatre for the closing film: the room the surgeon's headcam sees, the chair the
patient sits in, the lamp, the tray, the crew, and the small parts the close-ups need.

The wide shot is laid out in the film's logical frame (320 x 180, shown at twice the size). Every
full-frame layer is 344 x 204: the frame plus a 12-pixel margin on each side, so the camera can
shake without showing an edge. They all go at the same place (view space 108, 38).

  room        back wall, monitor on its arm, gas cart, the back door with its EXIT sign
  door_open   the back door swung open
  chair       headrest and back, behind the patient (PatientRig.back goes in front of it)
  armrest     the hand board across the lap, in front of the body (PatientRig.front goes on it)
  tray        instruments and the sealed parts, lower left
  crew        the assistant by the door; crew_relief is the relief crew in orange
  crew_down   the assistant on the floor against the door, after a patient wakes
  decal_*     what an incident leaves on the wall (blood, or scorch marks with reduced blood)
  lamp        the theatre lamp, pivot at its arm (LAMP_PIVOT), lamp_lit adds the light
  lamp_glow   additive pool of lamplight on the chair

Close-up pieces are in the 220 x 186 close-up space of gen_scopes (shown at twice the size):
board (the hand board with the grip bar), gloves holding a driver or forceps (tool tip at
GLOVE_TIP), the hatch and cartridges at the wrist, gauze, eye_empty, the jacks and voice boxes
at Lux's and Juno's ports, kip/eyes_front_fixed and dana/iris_fixed for the repaired optics.
The film frame pieces are drape (the surgical drape round a close-up) and lens_crack (the
headcam's glass after a hit), both 320 x 180. queue_0..2 are hall-camera silhouettes.
No picture here has words in it, so none needs a twin per language.
"""
import os

import numpy as np
from scipy import ndimage as ndi

import gen_scopes
from people import CLOTH, OUTLINE, SKIN, grow, smooth, stroke
from px import ASSETS, OUT, Canvas, col, contact_sheet, from_image

M = 12                      # shake margin round the 320 x 180 frame
FW, FH = 320 + 2 * M, 180 + 2 * M
LAMP_PIVOT = (56, 0)        # in lamp.png; it hangs at LAMP_AT in the frame
LAMP_AT = (236, -34)
GLOVE_TIP = (5, 5)          # in glove_*.png
GLOW_STEPS = 20
D = "theatre"

NITRILE = ["1e1230", "3a2050", "5c3478", "8450b0", "b888e0"]
RELIEF = ["2a1a1a", "7a3a1a", "c86a1e", "f09a3a", "fbd08a"]
SCRUBS = CLOTH["scrubs"]
ORANGE = ["2a1418", "6a2c1c", "b4501e", "e88a34", "f8c070"]


def frame(fill=None):
    c = Canvas(FW, FH, fill)
    return c


def L(c, kind, *a, **kw):
    """A mask in the logical frame: the margin added to every coordinate."""
    if kind == "rect":
        x0, y0, x1, y1 = a
        return c.rect(x0 + M, y0 + M, x1 + M, y1 + M)
    if kind == "rrect":
        x0, y0, x1, y1, r = a
        return c.rrect(x0 + M, y0 + M, x1 + M, y1 + M, r)
    if kind == "ell":
        cx, cy, rx, ry = a
        return c.ell(cx + M, cy + M, rx, ry)
    if kind == "poly":
        return c.poly([(x + M, y + M) for x, y in a[0]])
    if kind == "seg":
        return c.seg([(x + M, y + M) for x, y in a[0]], kw.get("width", 1))
    raise ValueError(kind)


def rot_ell(c, cx, cy, rx, ry, ang):
    yy, xx = c.grid()
    dx, dy = xx - cx, yy - cy
    ca, sa = np.cos(ang), np.sin(ang)
    u = (dx * ca + dy * sa) / rx
    v = (-dx * sa + dy * ca) / ry
    return u * u + v * v <= 1.0


def stepped_alpha(c, t, tone):
    level = np.round(np.clip(t, 0, 1) * GLOW_STEPS) / GLOW_STEPS
    c.a[level > 0, :3] = np.array(col(tone), dtype=np.uint8)
    c.a[:, :, 3] = np.round(level * 255.0).astype(np.uint8)


# ------------------------------------------------------------------ the room
def room():
    c = frame("teal1")
    yy, xx = c.grid()
    X, Y = xx - M, yy - M
    wall = Y < 118
    floor = ~wall
    # tiled back wall, darkest in the top corners, lifted where the lamp falls behind the chair
    c.grad(wall, ["ink1", "teal1", "teal2"], 160 + M, -40, 160 + M, 120 + M, dither=1.0)
    c.glow(wall, "teal3", 160 + M, 70 + M, 150, amt=0.9, power=1.3, ry=90)
    c.glow(wall, "teal4", 165 + M, 60 + M, 80, amt=0.55, power=1.6, ry=60)
    grout = wall & (((X % 22) == 0) | ((Y % 14) == 0))
    c.dither(grout, "ink1", 0.55)
    c.dither(wall & (((X % 22) == 1) | ((Y % 14) == 1)), "teal4", 0.12)
    # dado rail and skirting
    c.fill(L(c, "rect", -M, 84, 320 + M, 85), "steel1")
    c.fill(L(c, "rect", -M, 84, 320 + M, 84), "steel3")
    c.fill(L(c, "rect", -M, 112, 320 + M, 117), "teal1")
    c.fill(L(c, "rect", -M, 112, 320 + M, 112), "teal3")
    # floor: dark resin, a sheen under the chair
    c.grad(floor, ["teal1", "ink1", "ink0"], 160 + M, 118 + M, 160 + M, FH, dither=1.0)
    c.glow(floor, "teal3", 160 + M, 126 + M, 120, amt=0.5, ry=14)
    for k in range(-7, 9):
        c.line([(160 + M + k * 10, 118 + M), (160 + M + k * 46, FH)], "ink0")
    # a service pipe up the wall
    pipe = L(c, "rect", 228, -M, 231, 111)
    c.shade(pipe, "steel", light=(-1.0, 0.0), round_px=2)
    for y in (20, 62, 100):
        c.fill(L(c, "rect", 226, y, 233, y + 2), "steel2")
    # the monitor on its swing arm
    c.fill(L(c, "rect", -M, 34, 16, 37), "steel1")
    c.fill(L(c, "rect", -M, 34, 16, 34), "steel3")
    c.fill(L(c, "rect", 14, 30, 18, 42), "steel2")
    mon = L(c, "rrect", 18, 18, 72, 62, 3)
    c.shade(mon, "steel_dark", light=(-0.8, -0.4), round_px=3)
    c.outline(OUTLINE, mon)
    glass = L(c, "rect", 22, 22, 68, 54)
    c.fill(glass, "grn0")
    c.dither(glass, "grn1", 0.25)
    trace = [(22, 40), (30, 40), (32, 38), (34, 40), (38, 40), (40, 30), (42, 46), (44, 40), (54, 40), (56, 38), (58, 40), (68, 40)]
    c.line([(x + M, y + M) for x, y in trace], "grn2")
    c.fill(L(c, "rect", 24, 24, 34, 25), "grn2")
    c.fill(L(c, "rect", 56, 24, 66, 28), "grn1")
    c.px(70 + M, 58 + M, "grn3")
    # gas cart: the green cylinder strapped to it, the hose coiled on the hook
    cyl = L(c, "rrect", 12, 52, 24, 118, 5)
    c.shade(cyl, ["0e2418", "1f4a2c", "2f7a3e", "58b858"], light=(-0.8, -0.2), round_px=6)
    c.outline(OUTLINE, cyl)
    c.fill(L(c, "rect", 15, 44, 21, 52), "steel3")
    c.fill(L(c, "rect", 13, 42, 23, 44), "steel4")
    c.outline(OUTLINE, L(c, "rect", 13, 42, 23, 52))
    cart = L(c, "rect", 26, 74, 62, 120)
    c.shade(cart, "steel", light=(-0.8, -0.3), round_px=3, bias=-0.1)
    c.outline(OUTLINE, cart)
    for y in (82, 94, 106):
        c.fill(L(c, "rect", 28, y, 60, y), "steel1")
        c.fill(L(c, "rect", 40, y + 4, 48, y + 5), "steel4")
    c.fill(L(c, "rect", 24, 72, 64, 74), "steel4")
    c.outline(OUTLINE, L(c, "rect", 24, 72, 64, 74))
    for x in (28, 58):
        c.fill(L(c, "rect", x, 121, x + 3, 124), "ink0")
    hose = L(c, "seg", [(18, 44), (30, 36), (44, 44), (40, 58), (30, 62), (36, 70)], width=2)
    c.fill(hose, "steel1")
    c.fill(L(c, "seg", [(18, 43), (30, 35), (44, 43)], width=1), "steel3")
    c.fill(L(c, "rect", 22, 120, 30, 120), "steel1")
    c.fill(L(c, "rect", 22, 120, 30, 120), "steel1")
    strap = L(c, "rect", 11, 80, 25, 83)
    c.fill(strap, "warm1")
    # the back door
    frame_m = L(c, "rect", 254, 24, 316, 117)
    c.fill(frame_m, "steel1")
    c.outline(OUTLINE, frame_m)
    door = L(c, "rect", 258, 28, 312, 117)
    c.shade(door, "steel", light=(-0.8, -0.3), round_px=2, bias=-0.15, contrast=0.8)
    c.glow(door, "steel3", 270 + M, 50 + M, 50, amt=0.3)
    c.outline(OUTLINE, door)
    win = L(c, "rect", 272, 38, 298, 64)
    c.fill(win, "teal1")
    c.dither(win, "teal2", np.clip((Y - 38) / 40.0, 0, 0.6))
    wires = win & ((((X + Y) % 6) == 0) | (((X - Y) % 6) == 0))
    c.fill(wires, "steel2")
    c.outline(OUTLINE, win)
    c.fill(L(c, "rect", 271, 37, 299, 37), "steel4")
    bar = L(c, "rrect", 262, 76, 308, 81, 2)
    c.shade(bar, "steel", light=(-0.5, -1.0), round_px=2)
    c.outline(OUTLINE, bar)
    kick = L(c, "rect", 260, 100, 310, 114)
    c.dither(kick, "steel3", 0.35)
    for x, y in ((261, 30), (309, 30), (261, 114), (309, 114)):
        c.px(x + M, y + M, "steel4")
    # the EXIT sign: a green box, a doorway and an arrow, no words
    sign = L(c, "rect", 272, 13, 298, 21)
    c.fill(sign, "grn2")
    c.fill(L(c, "rect", 273, 14, 297, 20), "grn3")
    c.fill(L(c, "rect", 275, 15, 279, 19), "grn5")
    c.fill(L(c, "rect", 276, 16, 278, 19), "grn2")
    c.fill(L(c, "rect", 283, 17, 293, 17), "grn5")
    c.fill(L(c, "poly", [(292, 14), (296, 17), (292, 20)]), "grn5")
    c.outline(OUTLINE, sign)
    c.glow(wall, "grn1", 285 + M, 17 + M, 26, amt=0.45, ry=10)
    return c


def door_open():
    c = frame()
    yy, xx = c.grid()
    X, Y = xx - M, yy - M
    hole = L(c, "rect", 258, 28, 312, 117)
    c.fill(hole, "ink0")
    corridor = hole & (Y > 40)
    c.grad(corridor, ["ink0", "red0"], 285 + M, 40 + M, 285 + M, 117 + M, dither=1.0)
    c.glow(hole, "red0", 285 + M, 30 + M, 34, amt=0.9)
    c.fill(L(c, "poly", [(270, 117), (300, 117), (292, 60), (278, 60)]), "ink1")
    # the door itself, swung out toward the camera past the frame
    slab = L(c, "poly", [(312, 26), (326, 18), (326, 128), (312, 117)])
    c.shade(slab, "steel", light=(-0.8, -0.3), round_px=2, bias=-0.1)
    c.outline(OUTLINE, slab)
    c.fill(L(c, "rect", 316, 64, 318, 76), "steel4")
    return c


# ------------------------------------------------------------------ the chair
VINYL = ["07090c", "0e1820", "16303a", "22505a", "347070"]


def chair():
    c = frame()
    head = L(c, "rrect", 126, 4, 194, 54, 12)
    c.shade(head, VINYL, light=(-0.6, -0.5), round_px=10)
    c.outline(OUTLINE, head)
    c.fill(L(c, "rect", 154, 54, 166, 70), "steel1")
    back = L(c, "rrect", 72, 34, 248, 140, 18)
    c.shade(back, VINYL, light=(-0.6, -0.5), round_px=14, bias=-0.05)
    for x in (100, 220):
        c.fill(L(c, "rect", x, 46, x, 132) & back, "07090c")
    c.outline(OUTLINE, back)
    # the frame shows where the vinyl stops
    for x in (66, 250):
        post = L(c, "rect", x, 70, x + 4, 140)
        c.shade(post, "steel", light=(-0.8, 0.0), round_px=2)
        c.outline(OUTLINE, post)
    return c


def armrest():
    c = frame()
    yy, xx = c.grid()
    X, Y = xx - M, yy - M
    for x0, x1 in ((40, 76), (244, 280)):
        arm = L(c, "rrect", x0, 128, x1, 150, 5)
        c.shade(arm, VINYL, light=(-0.6, -0.6), round_px=5)
        c.outline(OUTLINE, arm)
        leg = L(c, "rect", (x0 + x1) // 2 - 3, 150, (x0 + x1) // 2 + 3, 180 + M)
        c.shade(leg, "steel", light=(-0.8, 0.0), round_px=2)
        c.outline(OUTLINE, leg)
    # the hand board across the lap, covered by a drape
    board = L(c, "poly", [(64, 136), (256, 136), (268, 180 + M), (52, 180 + M)])
    c.shade(board, ["0c2a2c", "16484a", "22686a", "3a8a88"], light=(-0.4, -1.0), round_px=8, bias=0.05)
    top = board & (Y <= 141)
    c.fill(top, "3a8a88")
    c.dither(top, "6ab4ac", 0.35)
    c.fill(board & (Y == 136), "6ab4ac")
    for k, x in enumerate((84, 118, 150, 182, 214, 238)):
        fold = L(c, "seg", [(x, 144), (x - 4 + (k % 2) * 6, 180 + M)], width=1)
        c.fill(fold & board, "0c2a2c")
        c.fill(L(c, "seg", [(x + 1, 146), (x - 3 + (k % 2) * 6, 180 + M)], width=1) & board, "22686a")
    c.outline(OUTLINE, board)
    return c


# ------------------------------------------------------------------ lamp and its light
def lamp(lit=False):
    c = Canvas(112, 56)
    px_, py_ = LAMP_PIVOT
    arm = c.rect(px_ - 2, 0, px_ + 2, 18)
    c.shade(arm, "steel", light=(-1.0, 0.0), round_px=2)
    c.outline(OUTLINE, arm)
    yoke = c.rect(px_ - 8, 16, px_ + 8, 21)
    c.shade(yoke, "steel_dark", light=(-0.8, -0.6), round_px=2)
    c.outline(OUTLINE, yoke)
    dome = c.ell(px_, 32, 50, 14)
    c.shade(dome, ["07090c", "1b2228", "2e3a42", "4a5a63", "70838a"], light=(-0.5, -1.0), round_px=8)
    c.outline(OUTLINE, dome)
    face = c.ell(px_, 37, 44, 9)
    c.fill(face, "0b1014")
    leds = c.none()
    for k in range(7):
        a = np.pi * (0.1 + 0.8 * k / 6.0)
        lx = px_ - np.cos(a) * 34
        ly = 37 + np.sin(a) * 3
        leds |= c.ell(lx, ly, 4, 2.6)
    leds |= c.ell(px_, 37, 6, 3.2)
    if lit:
        out = Canvas(112, 56)
        out.fill(grow(leds, 1), "teal7")
        out.fill(leds, "white")
        return out
    c.fill(leds, "1b2228")
    c.fill(leds & c.ell(px_, 35, 60, 2), "2e3a42")
    return c


def lamp_glow():
    c = frame()
    yy, xx = c.grid()
    X, Y = xx - M, yy - M
    dx, dy = (X - 162.0) / 120.0, (Y - 72.0) / 92.0
    pool = np.clip(1.0 - np.sqrt(dx * dx + dy * dy), 0, 1) ** 1.4
    # the cone from the lamp head down onto the chair
    ax, ay = LAMP_AT[0] * 1.0, LAMP_AT[1] + 40.0
    vx, vy = X - ax, Y - ay
    along = (vx * -0.8 + vy * 0.6)
    across = np.abs(vx * 0.6 + vy * 0.8)
    cone = np.clip(along / 200.0, 0, 1) * np.clip(1.0 - across / (14.0 + along * 0.55), 0, 1)
    t = np.maximum(pool * 0.75, cone * 0.35)
    stepped_alpha(c, t, "teal7")
    return c


# ------------------------------------------------------------------ tray and parts on it
def tray():
    c = frame()
    stand = L(c, "rect", 34, 146, 38, 180 + M)
    c.shade(stand, "steel", light=(-0.8, 0.0), round_px=2)
    c.outline(OUTLINE, stand)
    top = L(c, "poly", [(-M, 126), (78, 122), (86, 140), (-M, 148)])
    c.shade(top, "steel", light=(-0.5, -1.0), round_px=3, bias=0.05)
    c.outline(OUTLINE, top)
    lip = L(c, "poly", [(-M, 148), (86, 140), (86, 143), (-M, 151)])
    c.fill(lip, "steel1")
    c.outline(OUTLINE, lip)
    # two sealed parts in their blisters, a paper label on each
    for x0, y0 in ((6, 126), (34, 124)):
        pack = L(c, "rrect", x0, y0, x0 + 22, y0 + 12, 2)
        c.fill(pack, "dbe6e0", 150)
        c.fill(L(c, "rect", x0 + 3, y0 + 4, x0 + 15, y0 + 7), "70838a")
        c.fill(L(c, "rect", x0 + 3, y0 + 4, x0 + 15, y0 + 4), "dbe6e0")
        c.px(x0 + 13 + M, y0 + 6 + M, "5ee6e0")
        c.fill(L(c, "rect", x0 + 16, y0 + 3, x0 + 20, y0 + 9), "efe6cf")
        c.outline(OUTLINE, pack)
    # a driver and forceps laid along the front
    c.fill(L(c, "seg", [(58, 134), (80, 130)], width=1), "dbe6e0")
    c.fill(L(c, "seg", [(50, 136), (60, 134)], width=2), "e0a030")
    c.fill(L(c, "seg", [(4, 142), (40, 138)], width=1), "a3b5b6")
    c.fill(L(c, "seg", [(4, 143), (40, 140)], width=1), "70838a")
    return c


# ------------------------------------------------------------------ the crew
def crew(cloth=SCRUBS, cap=SCRUBS):
    """The assistant, standing between the chair and the back door, masked, watching the patient."""
    c = frame()
    body = L(c, "poly", [(236, 136), (240, 84), (250, 72), (276, 72), (286, 84), (292, 136)])
    c.shade(body, cloth, light=(-0.8, -0.2), round_px=10)
    c.fill(L(c, "poly", [(256, 72), (263, 86), (270, 72)]), cloth[0])
    c.outline(OUTLINE, body)
    neck = L(c, "rect", 257, 62, 268, 74)
    c.shade(neck, SKIN["priya"][1:], light=(-0.8, -0.2), round_px=4)
    head = L(c, "ell", 263, 50, 12, 15)
    c.shade(head, SKIN["priya"][1:], light=(-0.8, -0.2), round_px=8)
    capm = L(c, "poly", [(250, 46), (251, 36), (258, 32), (270, 32), (276, 38), (276, 46), (263, 42)])
    c.shade(capm, cap, light=(-0.8, -0.4), round_px=6)
    mask = L(c, "poly", [(251, 52), (275, 52), (274, 62), (263, 66), (252, 62)])
    c.fill(mask, "a3b5b6")
    c.fill(mask & L(c, "rect", 240, 55, 290, 55), "70838a")
    c.fill(mask & L(c, "rect", 240, 59, 290, 59), "70838a")
    for ex in (257, 268):
        c.fill(L(c, "rect", ex - 1, 47, ex + 1, 48), "07090c")
        c.px(ex + M, 47 + M, "dbe6e0")
    c.outline(OUTLINE, head | capm | mask | neck)
    # arms folded in front, gloved
    arms = L(c, "rrect", 244, 96, 284, 108, 5)
    c.shade(arms, cloth, light=(-0.8, -0.6), round_px=5)
    c.outline(OUTLINE, arms)
    for gx in (246, 276):
        g = L(c, "ell", gx + 4, 102, 4, 3)
        c.shade(g, NITRILE if cloth is SCRUBS else RELIEF, light=(-0.8, -0.4), round_px=4)
        c.outline(OUTLINE, g)
    return c


def crew_down(cloth=SCRUBS):
    c = frame()
    legs = L(c, "poly", [(244, 120), (300, 116), (304, 126), (246, 132)])
    c.shade(legs, cloth, light=(-0.6, -0.6), round_px=5)
    c.outline(OUTLINE, legs)
    body = L(c, "poly", [(282, 126), (284, 90), (296, 82), (312, 86), (316, 126)])
    c.shade(body, cloth, light=(-0.8, -0.3), round_px=8)
    c.outline(OUTLINE, body)
    head = L(c, "ell", 290, 80, 11, 12)
    c.shade(head, SKIN["priya"][1:], light=(-0.8, -0.2), round_px=7)
    c.fill(L(c, "rect", 282, 82, 296, 88), "a3b5b6")
    c.fill(L(c, "rect", 284, 76, 286, 77), "07090c")
    c.fill(L(c, "poly", [(280, 74), (288, 66), (300, 70), (296, 76)]), cloth[2])
    c.outline(OUTLINE, head)
    arm = L(c, "seg", [(286, 98), (270, 112), (262, 118)], width=5)
    c.shade(arm, cloth, light=(-0.8, -0.3), round_px=3)
    c.outline(OUTLINE, arm)
    hand = L(c, "ell", 259, 119, 5, 4)
    c.shade(hand, NITRILE if cloth is SCRUBS else RELIEF, light=(-0.8, -0.3), round_px=3)
    c.outline(OUTLINE, hand)
    # the headcam's mount, knocked off and lying by them
    c.fill(L(c, "rect", 226, 124, 236, 128), "1b2228")
    c.px(234 + M, 125 + M, "e23b3b")
    return c


def decals(clean=False):
    c = frame()
    yy, xx = c.grid()
    X, Y = xx - M, yy - M
    rng = np.random.default_rng(17)
    if clean:
        # scorch with a charred rim and soot climbing the wall, a burnt sweep across it, embers,
        # dents and a torn wall panel: no blood. The rim is what reads on the dark tiles.
        for k, (cx, cy, r) in enumerate(((292, 60, 16), (214, 30, 11), (104, 22, 9))):
            # ragged, not round: a round ring reads as a porthole
            ang = np.arctan2(Y - cy, X - cx)
            wob = 1 + 0.24 * np.sin(3 * ang + 1.7 * k) + 0.13 * np.sin(7 * ang + 0.9 + k)
            d = np.sqrt((X - cx) ** 2 + ((Y - cy) / 0.8) ** 2) / wob
            c.dither((d < r * 1.3) & (d >= r * 0.6), "7a4630", np.clip(0.75 - np.abs(d - r) / (r * 0.45), 0, 0.75))
            c.dither(d < r, "07090c", np.clip(1.3 - d / r, 0, 0.95))
            soot = (np.abs(X - cx) < r * 0.7) & (Y < cy - r * 0.5) & (Y > cy - r * 2.6)
            c.dither(soot, "0b1014", np.clip(0.75 - (cy - Y) / (r * 3.2), 0, 0.7))
        sweep = L(c, "seg", [(196, 46), (304, 70)], width=2)
        c.dither(ndi.binary_dilation(sweep, iterations=1) & ~sweep, "7a4630", 0.6)
        c.fill(sweep, "07090c")
        for x, y in ((286, 56), (298, 66), (291, 49), (210, 33), (218, 26), (101, 25), (250, 58)):
            c.px(x + M, y + M, "dc9a4e")
        for x0, y0, x1, y1 in ((284, 52, 300, 70), (206, 32, 216, 44)):
            c.line([(x0 + M, y0 + M), (x1 + M, y1 + M)], "steel3")
            c.line([(x1 + M, y0 + M), (x0 + M, y1 + M)], "ink0")
        return c
    smear = L(c, "poly", [(284, 40), (296, 46), (302, 88), (294, 118), (286, 116), (288, 82)])
    c.fill(smear, "5a1418")
    c.dither(smear, "a02024", 0.4)
    for _ in range(40):
        x, y = 200 + rng.random() * 110, 20 + rng.random() * 90
        r = 0.6 + rng.random() * 2.2
        c.fill(L(c, "ell", x, y, r, r), "a02024" if rng.random() < 0.6 else "5a1418")
    for x0 in (212, 236, 262):
        c.fill(L(c, "seg", [(x0, 40), (x0 + 1, 64 + (x0 % 9) * 3)], width=1), "5a1418")
    pool = L(c, "ell", 270, 128, 38, 5)
    c.fill(pool, "5a1418")
    c.dither(pool, "a02024", 0.3)
    c.fill(L(c, "ell", 262, 127, 12, 2), "e23b3b", 120)
    return c


# ------------------------------------------------------------------ close-up pieces (220 x 186)
def board():
    """The hand board as the close-up sees it: drape, and the same grip bar the counter uses."""
    W, H = gen_scopes.W, gen_scopes.H
    c = Canvas(W, H, "16484a")
    yy, xx = c.grid()
    c.shade(c.all(), ["0c2a2c", "16484a", "22686a", "3a8a88"], light=(-0.6, -0.8), round_px=80, round_amt=0.4)
    for k, x in enumerate(range(-40, W + 40, 34)):
        fold = c.seg([(x, 0), (x + 30 + (k % 3) * 8, H)], 2)
        c.fill(fold, "0c2a2c")
        c.fill(c.seg([(x + 2, 0), (x + 32 + (k % 3) * 8, H)], 1), "3a8a88")
    c.glow(c.all(), "6ab4ac", 110, 70, 90, amt=0.35)
    src = from_image(os.path.join(ASSETS, "scope", "grip_bg.png"))
    r, g, b = (src.a[:, :, i].astype(int) for i in range(3))
    dev = (r - b < 8)
    box = np.zeros_like(dev)
    box[70:140, 14:210] = True
    keep = ndi.binary_opening(ndi.binary_fill_holes(dev & box), iterations=2)
    c.a[keep] = src.a[keep]
    return c


def glove(tool="driver", palette=NITRILE):
    c = Canvas(96, 96)
    tx, ty = GLOVE_TIP
    if tool == "driver":
        c.fill(c.seg([(tx, ty), (46, 46)], 2), "a3b5b6")
        c.fill(c.seg([(tx, ty), (44, 44)], 1), "dbe6e0")
        c.fill(c.seg([(42, 42), (64, 64)], 6), "1b2228")
        c.fill(c.seg([(44, 44), (62, 62)], 2), "e0a030")
    else:
        c.fill(c.seg([(tx, ty), (50, 44)], 1), "a3b5b6")
        c.fill(c.seg([(tx, ty), (44, 50)], 1), "dbe6e0")
        c.fill(c.seg([(48, 44), (56, 52)], 3), "70838a")
    cuff = c.seg([(70, 72), (100, 102)], 30)
    palm = rot_ell(c, 58, 60, 21, 16, np.pi / 4)
    index = c.seg([(54, 44), (38, 30), (30, 24)], 7)
    thumb = c.seg([(46, 66), (34, 46), (30, 34)], 7)
    knuck = c.seg([(66, 50), (58, 40)], 9)
    hand = smooth(palm | index | thumb | knuck, 1)
    c.shade(hand | cuff, palette, light=(-0.6, -0.8), round_px=7)
    c.fill(c.seg([(68, 74), (76, 66)], 2) & cuff, palette[1])
    c.outline(OUTLINE, hand | cuff)
    stroke(c, [(46, 62), (54, 52)], palette[1])
    stroke(c, [(40, 36), (48, 44)], palette[1])
    c.px(33, 27, palette[4])
    c.px(32, 37, palette[4])
    # the tool's tip shows past the fingers
    if tool == "driver":
        c.fill(c.seg([(tx, ty), (24, 24)], 2), "a3b5b6")
        c.fill(c.seg([(tx, ty), (22, 22)], 1), "dbe6e0")
    else:
        c.fill(c.seg([(tx, ty), (24, 20)], 1), "dbe6e0")
        c.fill(c.seg([(tx, ty), (20, 24)], 1), "a3b5b6")
    return c


def hatch():
    c = Canvas(38, 22)
    rim = c.rrect(0, 0, 37, 21, 4)
    c.shade(rim, CLOTH["chrome"], light=(-0.8, 0.3), round_px=3, bias=-0.05)
    c.outline(OUTLINE, rim)
    well = c.rrect(4, 4, 33, 17, 3)
    c.fill(well, "07090c")
    c.fill(c.rect(5, 5, 32, 6), "1b2228")
    for x in (6, 30):
        c.fill(c.rect(x, 9, x + 2, 12), "d4a040")
    for x, y in ((2, 2), (35, 2), (2, 19), (35, 19)):
        c.px(x, y, "1b2228")
    return c


def cartridge(new=False):
    c = Canvas(30, 12)
    body = c.rrect(1, 1, 28, 10, 4)
    if new:
        c.shade(body, "steel", light=(-0.6, -0.9), round_px=4)
        c.fill(c.rect(6, 4, 20, 4), "dbe6e0")
        c.fill(c.rect(23, 4, 25, 6), "5ee6e0")
        c.px(24, 5, "c8fff6")
    else:
        c.shade(body, ["2a1a1a", "5a3a22", "9a6a2c", "d4a040"], light=(-0.6, -0.9), round_px=4)
        c.dither(body, "1c1214", 0.35)
        c.fill(c.rect(22, 3, 25, 8), "1c1214")
        c.px(23, 5, "b06a3c")
    c.fill(c.rect(0, 4, 1, 7), "70838a")
    c.fill(c.rect(28, 4, 29, 7), "70838a")
    c.outline(OUTLINE, body)
    return c


def gauze():
    c = Canvas(56, 48)
    yy, xx = c.grid()
    pad = smooth(c.rect(4, 6, 51, 41), 2)
    c.fill(pad, "efe6cf")
    c.dither(pad & (((xx + yy) % 4) == 0), "d9cdaf", 0.9)
    c.dither(pad, "b3a587", np.clip((yy - 20) / 40.0, 0, 0.4))
    c.outline("8c7f68", pad)
    for a, b in (((0, 10), (55, 2)), ((0, 46), (55, 36))):
        t = c.seg([a, b], 5)
        c.fill(t, "e2c58a")
        c.dither(t, "c9a468", 0.3)
    return c


def eye_empty():
    c = Canvas(48, 48)
    yy, xx = c.grid()
    d = np.sqrt((xx - 24.0) ** 2 + (yy - 24.0) ** 2)
    hole = d <= 22
    c.fill(hole, "07090c")
    c.dither(hole & (d > 16), "1b2228", 0.5)
    for k in range(8):
        a = k * np.pi / 4 + 0.3
        x0, y0 = 24 + np.cos(a) * 20, 24 + np.sin(a) * 20
        x1, y1 = 24 + np.cos(a) * 12, 24 + np.sin(a) * 12
        c.line([(x0, y0), (x1, y1)], "2a8f96" if k % 3 else "a02024")
    c.fill(c.ell(24, 24, 3, 3), "14484f")
    return c


def jack(new=False):
    c = Canvas(56, 56)
    if new:
        gen_scopes.socket(c, 28, 28, r=24, pins=6)
        return c
    src = from_image(os.path.join(ASSETS, "scope", "lux", "port.png"))
    piece = src.crop(96 - 28, 86 - 28, 96 + 28, 86 + 28)
    keep = piece.ell(28, 28, 25.5, 25.5)
    piece.a[~keep] = 0
    return piece


def jack_hole():
    c = Canvas(56, 56)
    hole = c.ell(28, 28, 25, 25)
    c.fill(hole, "07090c")
    c.dither(hole & ~c.ell(28, 28, 18, 18), "4a2a22", 0.4)
    for k in range(6):
        a = k * np.pi / 3 + 0.4
        c.line([(28 + np.cos(a) * 22, 28 + np.sin(a) * 22), (28 + np.cos(a) * 9, 28 + np.sin(a) * 9)], "d4a040" if k % 2 else "5ee6e0")
    return c


def voice_box(new=False):
    src = from_image(os.path.join(ASSETS, "scope", "juno", "port.png"))
    piece = src.crop(43, 43, 86, 134)
    keep = piece.rrect(0, 0, 42, 90, 6)
    piece.a[~keep] = 0
    if not new:
        piece.dither(piece.rrect(3, 3, 39, 87, 5), "4a2a22", 0.25)
        piece.fill(piece.ell(21, 83, 2, 2), "a02024")
        return piece
    c = Canvas(43, 91)
    vb = c.rrect(1, 1, 41, 89, 6)
    c.shade(vb, ["0b1014", "1b2228", "2e3a42", "4a5a63", "70838a"], light=(-0.8, 0.3), round_px=6)
    for gy in range(13, 79, 8):
        c.fill(c.rect(9, gy, 33, gy + 2), "a3b5b6")
        c.fill(c.rect(9, gy + 3, 33, gy + 3), "0b1014")
    c.fill(c.ell(21, 83, 2, 2), "5ee6e0")
    c.px(21, 82, "c8fff6")
    c.outline(OUTLINE, vb)
    return c


def voice_hole():
    c = Canvas(43, 91)
    hole = c.rrect(1, 1, 41, 89, 6)
    c.fill(hole, "07090c")
    for k, y in enumerate(range(12, 84, 12)):
        c.line([(4, y), (20, y + 4), (38, y - 2)], "a02024" if k % 2 else "2a8f96")
    return c


def kip_fixed_front():
    orig = gen_scopes.optic_eye
    gen_scopes.optic_eye = lambda *a, **kw: orig(*a, **{**kw, "cracked": False, "cracks": None})
    try:
        return gen_scopes.eyes("kip")["eyes_front"]
    finally:
        gen_scopes.optic_eye = orig


def dana_fixed_iris():
    c = Canvas(48, 48)
    c.fill(c.ell(24, 24, 3, 3), "5a1418")
    c.fill(c.ell(24, 24, 1.5, 1.5), "a02024")
    return c


# ------------------------------------------------------------------ the film frame (320 x 180)
def drape():
    c = Canvas(320, 180)
    yy, xx = c.grid()
    win = c.rrect(56, 6, 264, 150, 12)
    cloth = ~win
    c.shade(cloth, ["0c2a2c", "16484a", "22686a", "3a8a88"], light=(-0.6, -0.8), round_px=30, round_amt=0.4)
    for k, x in enumerate(range(-20, 340, 26)):
        f = c.seg([(x, 0), (x + 18 - (k % 3) * 9, 180)], 2) & cloth
        c.fill(f, "0c2a2c")
        c.fill(c.seg([(x + 2, 0), (x + 20 - (k % 3) * 9, 180)], 1) & cloth, "3a8a88")
    edge = grow(win, 3) & cloth
    c.fill(edge, "6ab4ac")
    c.fill(grow(win, 1) & cloth, "0c2a2c")
    c.dither(grow(win, 8) & cloth & ~edge, "0c2a2c", 0.35)
    return c


def lens_crack():
    c = Canvas(320, 180)
    rng = np.random.default_rng(5)
    cx, cy = 196, 74
    for k in range(11):
        a = k * 2 * np.pi / 11 + rng.random() * 0.4
        pts = [(cx, cy)]
        x, y, ln = cx, cy, 0
        while 0 <= x < 320 and 0 <= y < 180 and ln < 260:
            step = 12 + rng.random() * 18
            a += (rng.random() - 0.5) * 0.5
            x, y = x + np.cos(a) * step, y + np.sin(a) * step
            pts.append((x, y))
            ln += step
        c.line(pts, "dbe6e0")
        c.line([(px_ + 1, py_) for px_, py_ in pts[:4]], "7fbfb0")
    for r in (8, 15):
        ring = c.ell(cx, cy, r, r * 0.9) & ~c.ell(cx, cy, r - 1, r * 0.9 - 1)
        c.dither(ring, "dbe6e0", 0.7)
    c.fill(c.ell(cx, cy, 4, 4), "ffffff", 200)
    c.a[:, :, 3] = np.where(c.a[:, :, 3] > 0, np.minimum(c.a[:, :, 3], 210), 0).astype(np.uint8)
    return c


def queue(kind):
    """An unseen visitor on the hall camera: a plain silhouette, never one of the cast."""
    c = Canvas(20, 44)
    if kind == 0:
        m = c.ell(10, 8, 5, 6) | c.poly([(3, 14), (17, 14), (18, 40), (2, 40)]) | c.poly([(4, 6), (10, 0), (16, 6)])
    elif kind == 1:
        m = c.ell(10, 9, 5, 5) | c.poly([(1, 15), (19, 15), (17, 40), (3, 40)])
    else:
        m = c.ell(9, 8, 4, 5) | c.poly([(4, 14), (14, 14), (15, 40), (4, 40)]) | c.rect(14, 18, 19, 30)
    m |= c.rect(5, 40, 8, 43) | c.rect(12, 40, 15, 43)
    c.fill(m, "1f4a2c")
    c.fill(grow(m, 1) & ~m, "2f7a3e")
    c.dither(m, "0e2418", 0.4)
    return c


# ------------------------------------------------------------------ review
def patient_layers(pid, attack=False):
    base = os.path.join(ASSETS, "patients", pid)
    names = ["body", "pupils", "head", "brows_neutral", "mouth_closed", "lids"]
    if attack:
        names = ["body", "pupils", "head", "brows_angry", "mouth_turn", "turn"]
    back = Canvas(160, 176)
    for n in names:
        p = os.path.join(base, n + ".png")
        if os.path.exists(p):
            back.blit(from_image(p), 0, 0)
    front = from_image(os.path.join(base, ("attack" if attack else "hands_a") + ".png"))
    return back, front


def scene(layers, pid=None, attack=False):
    s = Canvas(FW, FH, "ink0")
    order = ["room", "door_open", "decals", "crew", "crew_down", "chair", "BACK", "armrest", "FRONT", "tray", "lamp", "glow"]
    pb = pf = None
    if pid:
        pb, pf = patient_layers(pid, attack)
    for k in order:
        if k == "BACK" and pb is not None:
            s.blit(pb, 80 + M, -24 + M)
        elif k == "FRONT" and pf is not None:
            s.blit(pf, 80 + M, -24 + M)
        elif k == "lamp" and "lamp" in layers:
            s.blit(layers["lamp"], LAMP_AT[0] - LAMP_PIVOT[0] + M, LAMP_AT[1] + M)
        elif k == "glow" and "glow" in layers:
            g = layers["glow"]
            alpha = g.a[:, :, 3:4].astype(np.float32) / 255.0 * 0.5
            rgb = s.a[:, :, :3].astype(np.float32) + g.a[:, :, :3].astype(np.float32) * alpha
            s.a[:, :, :3] = np.clip(rgb, 0, 255).astype(np.uint8)
        elif k in layers and layers[k] is not None:
            s.blit(layers[k], 0, 0)
    return s.crop(M, M, M + 320, M + 180)


def main():
    out = {}
    out["room"] = room()
    out["door_open"] = door_open()
    out["chair"] = chair()
    out["armrest"] = armrest()
    out["lamp"] = lamp()
    out["lamp_lit"] = lamp(lit=True)
    out["lamp_glow"] = lamp_glow()
    out["tray"] = tray()
    out["crew"] = crew()
    out["crew_relief"] = crew(ORANGE, ORANGE)
    out["crew_down"] = crew_down()
    out["crew_down_relief"] = crew_down(ORANGE)
    out["decal_blood"] = decals()
    out["decal_scorch"] = decals(clean=True)
    out["board"] = board()
    out["glove_driver"] = glove("driver")
    out["glove_forceps"] = glove("forceps")
    out["glove_driver_relief"] = glove("driver", RELIEF)
    out["glove_forceps_relief"] = glove("forceps", RELIEF)
    out["hatch"] = hatch()
    out["cart_old"] = cartridge()
    out["cart_new"] = cartridge(True)
    out["gauze"] = gauze()
    out["eye_empty"] = eye_empty()
    out["jack_old"] = jack()
    out["jack_new"] = jack(True)
    out["jack_hole"] = jack_hole()
    out["box_old"] = voice_box()
    out["box_new"] = voice_box(True)
    out["box_hole"] = voice_hole()
    out["drape"] = drape()
    out["lens_crack"] = lens_crack()
    for k in range(3):
        out["queue_%d" % k] = queue(k)
    for name, c in out.items():
        c.save("%s/%s.png" % (D, name))
    kip_fixed_front().save(D + "/kip/eyes_front_fixed.png")
    dana_fixed_iris().save(D + "/dana/iris_fixed.png")

    # review composites (not shipped)
    os.makedirs(OUT, exist_ok=True)
    base = dict(room=out["room"], chair=out["chair"], armrest=out["armrest"], tray=out["tray"],
                crew=out["crew"], lamp=out["lamp"], glow=out["lamp_glow"])
    lit = out["lamp"].copy()
    lit.blit(out["lamp_lit"], 0, 0)
    base["lamp"] = lit
    shots = []
    for pid in ("rook", "juno", "kip"):
        shots.append((pid, scene(base, pid)))
    shots.append(("attack", scene(base, "bo", attack=True)))
    after = dict(base, crew=None, crew_down=out["crew_down"], door_open=out["door_open"], decals=out["decal_blood"])
    shots.append(("after", scene(after)))
    after2 = dict(after, decals=out["decal_scorch"], crew_down=out["crew_down_relief"])
    shots.append(("after clean", scene(after2)))
    contact_sheet(shots, os.path.join(OUT, "theatre_wide.png"), scale=2, per_row=2)
    parts = [(k, out[k]) for k in ("board", "glove_driver", "glove_forceps", "glove_driver_relief", "hatch", "cart_old",
                                   "cart_new", "gauze", "eye_empty", "jack_old", "jack_new", "jack_hole", "box_old",
                                   "box_new", "box_hole", "queue_0", "queue_1", "queue_2")]
    contact_sheet(parts, os.path.join(OUT, "theatre_parts.png"), scale=2, per_row=6)
    print("theatre art written")


if __name__ == "__main__":
    main()
