"""The back room for the closing film: one short film for the whole night, shot in near darkness.

The film lights its pictures itself (closing_film.gd lights every textured layer with a few
point lights and draws people as flat shadows with a thin rim of light), so the pictures here
are painted at an even, middling brightness, as if under plain work light. The crew are plain
white masks the film fills in. Nothing here is drawn as if already lit.

The wide shot is at the screen's own size: one pixel here is one pixel on the screen, the size
the patient's own pictures are drawn at in that shot (half their size at the counter).

  room          the back wall: tiles, the door with its wired window, the monitor on its arm,
                the drip stand, the cabinet (720 x 330, drawn at screen -40, 16)
  chair         headrest, back and arms of the theatre chair, from its foot (260 x 190)
  drape         the sheet over the patient's legs, nearest the camera (700 x 120)
  crew_*        the surgeon's and the assistant's poses, white masks facing right (170 x 250,
                the hip at HIP, or at the pose's own hip in POSES); the film mirrors the assistant
  body_floor    a crew member lying on the floor, from the floor (420 x 120)
  legs          hips and legs hung under a patient's own picture when they stand (160 x 124)

The surgeon's view of the part uses the counter's close-up pictures from gen_scopes (220 x 186,
shown at twice the size) and these pieces in the same space:

  board                              the hand board under the hand, with the counter's grip bar
  glove_driver, glove_forceps        the surgeon's gloved hand, the tool's tip at GLOVE_TIP
  hatch, cart_old, cart_new          the hatch at the wrist and the cartridge it holds
  gauze, eye_empty                   the pad over the other eye, the empty socket
  jack_old, jack_new, jack_hole      Lux's port
  box_old, box_new, box_hole         Juno's voice box
  kip/eyes_front_fixed, dana/iris_fixed   the repaired optics
No picture here has words in it, so none needs a twin per language.
"""
import math
import os

import numpy as np
from scipy import ndimage as ndi

import gen_scopes
from people import CLOTH, OUTLINE, smooth, stroke
from px import ASSETS, OUT, Canvas, contact_sheet, from_image

D = "film"
WHITE = "ffffff"

CREW_W, CREW_H = 170, 250
HIP = (78, 196)             # where a crew pose stands in crew_*.png, unless the pose says otherwise
GLOVE_TIP = (5, 5)          # the tool's tip in glove_*.png
NITRILE = ["1e1230", "3a2050", "5c3478", "8450b0", "b888e0"]


# ------------------------------------------------------------------ helpers
def dirv(deg):
    """A unit vector: 0 is up, 90 is forward (right), 180 is down, -90 is back (left)."""
    r = math.radians(deg)
    return (math.sin(r), -math.cos(r))


def add(p, v, k=1.0):
    return (p[0] + v[0] * k, p[1] + v[1] * k)


def capsule(c, a, b, r):
    m = c.seg([a, b], width=max(1, int(round(2 * r))))
    return m | c.ell(a[0], a[1], r, r) | c.ell(b[0], b[1], r, r)


def rot_ell(c, cx, cy, rx, ry, deg):
    """An ellipse turned by deg degrees (clockwise on screen)."""
    yy, xx = c.grid()
    dx, dy = xx - cx, yy - cy
    a = math.radians(deg)
    ca, sa = math.cos(a), math.sin(a)
    u = (dx * ca + dy * sa) / rx
    v = (-dx * sa + dy * ca) / ry
    return u * u + v * v <= 1.0


# ------------------------------------------------------------------ the crew, as shadows
def figure(lean=0.0, tilt=0.0, look=1, near=(170, 0), far=(175, 5), hip=HIP, tool=None, tray=False, hands="open"):
    """A capped, masked figure in a gown, facing right, as a white mask.

    lean tips the body about the hip (positive is forward), tilt the head on top of that
    (positive looks down), look is the way the face points (1 forward, -1 back over the shoulder).
    near and far are each arm's (upper arm, forearm) directions, in dirv() degrees."""
    c = Canvas(CREW_W, CREW_H)
    up = dirv(lean)
    fwd = dirv(lean + 90)
    neck = add(hip, up, 104)
    # the gown: hips to the bottom of the picture
    back_hip = add(hip, fwd, -40)
    front_hip = add(hip, fwd, 34)
    chest = add(add(hip, up, 70), fwd, 40)
    s_front = add(add(neck, fwd, 26), up, -10)
    s_back = add(add(neck, fwd, -36), up, -12)
    mid_back = add(add(hip, up, 56), fwd, -44)
    torso = c.poly([back_hip, mid_back, s_back, add(neck, fwd, -12), add(neck, fwd, 10), s_front, chest, front_hip,
                    (front_hip[0] + 10, CREW_H + 4), (back_hip[0] - 8, CREW_H + 4)])
    torso |= c.ell(s_front[0] - 4, s_front[1] + 6, 15, 13) | c.ell(s_back[0] + 6, s_back[1] + 8, 16, 13)
    # the neck and the head, capped and masked, one mask tie hanging behind
    head_dir = lean + tilt
    hc = add(add(neck, dirv(lean + tilt * 0.4), 30), dirv(head_dir + 90), 2 * look)
    head = rot_ell(c, hc[0], hc[1], 22, 27, head_dir)
    neck_m = capsule(c, add(neck, up, -6), add(hc, dirv(head_dir), -10), 10)
    hf = dirv(head_dir + 90 * look)          # the way the face points
    hu = dirv(head_dir)
    mask = rot_ell(c, *add(add(hc, hf, 18), hu, -9), 8, 10, head_dir)
    nose = rot_ell(c, *add(add(hc, hf, 21), hu, -3), 4, 5, head_dir)
    cap = rot_ell(c, *add(add(hc, hf, -10), hu, 16), 17, 12, head_dir - 12 * look)
    tie = capsule(c, add(add(hc, hf, -20), hu, 6), add(add(hc, hf, -28), hu, -1), 2.0)
    shape = torso | head | neck_m | mask | nose | cap | tie
    # arms: a sleeve to the elbow, then the gloved forearm and hand
    hand_at = []
    for shoulder, (a1, a2), r in ((add(s_back, fwd, 10), far, 0.92), (add(s_front, fwd, -4), near, 1.0)):
        elbow = add(shoulder, dirv(a1 + lean), 50 * r)
        wrist = add(elbow, dirv(a2 + lean), 44 * r)
        shape |= capsule(c, shoulder, elbow, 13 * r) | capsule(c, elbow, wrist, 9 * r)
        hd = dirv(a2 + lean)
        palm = add(wrist, hd, 8)
        shape |= rot_ell(c, palm[0], palm[1], 9 * r, 7 * r, a2 + lean - 90)
        if hands == "open":
            for k, off in enumerate((-5, -1.5, 2, 5.5)):
                base = add(palm, dirv(a2 + lean + 90), off * r)
                tip = add(base, hd, (9 + (2 if k in (1, 2) else 0)) * r)
                shape |= capsule(c, base, tip, 1.6 * r)
        else:
            shape |= c.ell(palm[0], palm[1], 9 * r, 9 * r)
        hand_at.append(palm)
    if tool == "driver":
        p = hand_at[1]
        d = dirv(near[1] + lean + 28)
        shape |= capsule(c, p, add(p, d, 18), 3.2) | capsule(c, add(p, d, 18), add(p, d, 40), 1.1)
    if tray:
        a, b = hand_at
        y = max(a[1], b[1]) - 2
        x0 = min(a[0], b[0]) - 6
        shape |= c.rect(x0, y, x0 + 78, y + 4)
        for k, (dx, hgt) in enumerate(((10, 10), (22, 16), (31, 8), (44, 13), (58, 11), (68, 6))):
            shape |= c.rect(x0 + dx, y - hgt, x0 + dx + (1 if k % 2 else 2), y)
        shape |= c.ell(x0 + 52, y - 3, 6, 3)
    c.fill(shape, WHITE)
    return c


POSES = {
    # scrubbed and waiting: forearms up, gloves at the chest, touching nothing
    "crew_scrub": dict(lean=2, tilt=10, near=(176, 20), far=(178, 26)),
    # bent over the work, the driver in the near hand
    "crew_work": dict(lean=12, tilt=30, near=(140, 104), far=(150, 112), tool="driver", hands="fist"),
    # backing off the chair, the hands up
    "crew_recoil": dict(lean=-12, tilt=-20, near=(62, 8), far=(52, -4), hip=(84, 198)),
    # going over backwards
    "crew_fall": dict(lean=-38, tilt=-30, near=(10, -40), far=(70, 30), hip=(130, 212)),
    # turned to the door behind them
    "crew_look": dict(lean=-2, tilt=-4, look=-1, near=(176, 20), far=(178, 26)),
    # the assistant with the instrument tray
    "crew_tray": dict(lean=0, tilt=16, near=(168, 92), far=(170, 96), tray=True, hands="fist"),
}


def body_floor():
    """Someone lying on the floor, from the floor: shoulder, capped head, an arm out, the glove."""
    w, h = 420, 120
    c = Canvas(w, h)
    m = c.poly([(40, 120), (60, 70), (110, 46), (170, 40), (240, 52), (300, 76), (330, 120)])
    m |= c.ell(76, 64, 30, 24) | c.ell(58, 52, 22, 14)                # the head on its side, the cap
    m |= c.ell(48, 74, 9, 7)                                            # the mask
    m |= capsule(c, (250, 70), (330, 88), 13) | capsule(c, (330, 88), (372, 98), 9)
    m |= c.ell(384, 102, 13, 9)
    for dx, dy in ((8, -6), (13, -2), (14, 3), (11, 8)):
        m |= capsule(c, (390, 100), (392 + dx, 102 + dy), 2.4)
    m |= capsule(c, (372, 100), (364, 112), 3)                         # the thumb
    m |= c.poly([(0, 120), (20, 104), (360, 112), (420, 120)])
    c.fill(m, WHITE)
    return c


def legs():
    """Hips and legs for a patient who stands up out of the chair, as a white mask. The patients'
    own pictures end at the counter, so the film hangs this under them (its row 0 on their row
    LEGS_AT) when one of them stands."""
    w, h = 160, 124
    c = Canvas(w, h)
    m = c.poly([(30, 0), (130, 0), (126, 20), (122, 36), (38, 36), (34, 20)])          # the coat's hem and the hips
    m |= c.poly([(40, 30), (80, 30), (68, 112), (40, 112)])                            # the left leg, a little apart
    m |= c.poly([(80, 30), (120, 30), (122, 112), (94, 112)])
    m |= c.ell(50, 114, 15, 6) | c.ell(110, 114, 15, 6)                                # the boots
    m &= ~c.poly([(77, 44), (83, 44), (90, 112), (70, 112)])                           # daylight between the legs
    c.fill(m, WHITE)
    return c


# ------------------------------------------------------------------ the room
def room():
    w, h = 720, 330
    c = Canvas(w, h, "1a2a31")
    yy, xx = c.grid()
    # wall tiles: 22 x 15 with dark grout, a little uneven in tone
    wall = c.rect(0, 0, w - 1, 262)
    c.fill(wall, "4a5a5e")
    rng = np.random.default_rng(5)
    for ty in range(0, 263, 15):
        for tx in range(-(ty // 15 % 2) * 11, w, 22):
            tone = ["44565a", "4a5a5e", "50605f", "465658"][rng.integers(0, 4)]
            c.fill(c.rect(tx + 1, ty + 1, tx + 20, ty + 13), tone)
    c.fill((yy % 15 == 0) & wall, "2a3438")
    # a band of darker tiles at waist height, and the skirting
    c.fill(c.rect(0, 196, w - 1, 198), "2e3a3e")
    c.fill(c.rect(0, 254, w - 1, 262), "2a3236")
    # the floor
    c.fill(c.rect(0, 263, w - 1, h - 1), "2e3436")
    for k in range(6):
        c.fill(c.rect(0, 267 + k * k * 2, w - 1, 267 + k * k * 2), "262c2e")
    # the ceiling edge
    c.fill(c.rect(0, 0, w - 1, 22), "2a3236")
    c.fill(c.rect(0, 22, w - 1, 24), "3a4448")
    # the door, back left, with a wired window (the film lights the window)
    c.fill(c.rect(64, 70, 166, 262), "3a4246")
    c.fill(c.rect(70, 76, 160, 262), "566064")
    c.fill(c.rect(72, 78, 158, 80), "6a7478")
    c.fill(c.rect(94, 104, 136, 150), "1a2024")
    for gx in range(94, 137, 7):
        c.fill(c.rect(gx, 104, gx, 150), "2a3236")
    for gy in range(104, 151, 7):
        c.fill(c.rect(94, gy, 136, gy), "2a3236")
    c.fill(c.rect(146, 170, 156, 174), "8a969a")           # the handle
    c.fill(c.rect(64, 70, 66, 262) | c.rect(164, 70, 166, 262), "2a3236")
    # the drip stand
    c.fill(c.rect(560, 40, 561, 262), "70838a")
    c.fill(c.rect(548, 40, 574, 41), "70838a")
    c.fill(c.rrect(551, 44, 565, 72, 3), "8a9a98")
    c.fill(c.rect(557, 72, 558, 120), "5a6a6a")
    # the monitor on its arm, back right (the film lights its screen)
    c.fill(c.rect(640, 30, 642, 118), "3a4448")
    c.fill(c.rect(600, 116, 642, 120), "3a4448")
    c.fill(c.rrect(584, 118, 664, 176, 4), "2e3a42")
    c.fill(c.rect(590, 124, 658, 168), "0b1014")
    # the cabinet
    c.fill(c.rect(640, 190, 719, 262), "4a5258")
    c.fill(c.rect(644, 194, 715, 226) | c.rect(644, 230, 715, 258), "566066")
    c.fill(c.rect(676, 208, 684, 210) | c.rect(676, 242, 684, 244), "8a969a")
    return c


def chair():
    """The theatre chair from its foot: headrest, back, and the arms coming forward."""
    c = Canvas(260, 190)
    head = c.rrect(82, 8, 178, 70, 18)
    back = c.poly([(56, 64), (204, 64), (222, 190), (38, 190)]) | c.rrect(50, 56, 210, 100, 16)
    c.shade(back, ["1a2a31", "244049", "33606a", "4c8a8c"], light=(0.0, -1.0), round_px=14, contrast=0.8)
    c.shade(head, ["1a2a31", "244049", "33606a", "4c8a8c", "7fbfb0"], light=(0.0, -1.0), round_px=12)
    c.fill(c.rect(126, 70, 134, 80), "1b2228")             # the post under the headrest
    for side in (-1, 1):
        x0 = 130 + side * 96
        arm = c.poly([(x0 - 14, 120), (x0 + 14, 120), (x0 + side * 40 + 18, 190), (x0 + side * 40 - 18, 190)])
        c.shade(arm, ["1a2a31", "244049", "33606a", "4c8a8c"], light=(0.0, -1.0), round_px=8)
    c.outline("0b1014")
    return c


def drape():
    """The sheet over the patient's legs, from the foot of the chair: the nearest thing to the lens."""
    w, h = 700, 120
    c = Canvas(w, h)
    xs = np.arange(w)
    top = (112 - 92 * np.exp(-((xs - 350) / 190.0) ** 2) - 10 * np.exp(-((xs - 300) / 40.0) ** 2)
           - 12 * np.exp(-((xs - 400) / 44.0) ** 2))
    yy, xx = c.grid()
    m = yy >= top[xx]
    c.shade(m, ["0e2418", "1f4a2c", "2f6a4a", "4a8a6a", "7ab89a"], light=(0.0, -1.0), round_px=40, contrast=0.9)
    # folds running from the knees down to the lens
    for x0, x1 in ((300, 210), (400, 500), (350, 352), (250, 120), (450, 590)):
        c.fill(c.seg([(x0, top[x0] + 6), (x1, h)], width=2) & m, "1f4a2c")
    return c


# ------------------------------------------------------------------ the surgeon's view (close-up space, 220 x 186)
def board():
    """The hand board as the close-up sees it: drape, and the same grip bar the counter uses."""
    W, H = gen_scopes.W, gen_scopes.H
    c = Canvas(W, H, "16484a")
    c.shade(c.all(), ["0c2a2c", "16484a", "22686a", "3a8a88"], light=(-0.6, -0.8), round_px=80, round_amt=0.4)
    for k, x in enumerate(range(-40, W + 40, 34)):
        c.fill(c.seg([(x, 0), (x + 30 + (k % 3) * 8, H)], 2), "0c2a2c")
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


def glove(tool="driver"):
    """The surgeon's gloved hand holding the driver or the forceps, the tip at GLOVE_TIP."""
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
    palm = rot_ell(c, 58, 60, 21, 16, 45)
    index = c.seg([(54, 44), (38, 30), (30, 24)], 7)
    thumb = c.seg([(46, 66), (34, 46), (30, 34)], 7)
    knuck = c.seg([(66, 50), (58, 40)], 9)
    hand = smooth(palm | index | thumb | knuck, 1)
    c.shade(hand | cuff, NITRILE, light=(-0.6, -0.8), round_px=7)
    c.fill(c.seg([(68, 74), (76, 66)], 2) & cuff, NITRILE[1])
    c.outline(OUTLINE, hand | cuff)
    stroke(c, [(46, 62), (54, 52)], NITRILE[1])
    stroke(c, [(40, 36), (48, 44)], NITRILE[1])
    c.px(33, 27, NITRILE[4])
    c.px(32, 37, NITRILE[4])
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
    c.fill(c.rrect(4, 4, 33, 17, 3), "07090c")
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
        c.line([(24 + np.cos(a) * 20, 24 + np.sin(a) * 20), (24 + np.cos(a) * 12, 24 + np.sin(a) * 12)],
               "2a8f96" if k % 3 else "a02024")
    c.fill(c.ell(24, 24, 3, 3), "14484f")
    return c


def jack(new=False):
    c = Canvas(56, 56)
    if new:
        gen_scopes.socket(c, 28, 28, r=24, pins=6)
        return c
    src = from_image(os.path.join(ASSETS, "scope", "lux", "port.png"))
    piece = src.crop(96 - 28, 86 - 28, 96 + 28, 86 + 28)
    piece.a[~piece.ell(28, 28, 25.5, 25.5)] = 0
    return piece


def jack_hole():
    c = Canvas(56, 56)
    hole = c.ell(28, 28, 25, 25)
    c.fill(hole, "07090c")
    c.dither(hole & ~c.ell(28, 28, 18, 18), "4a2a22", 0.4)
    for k in range(6):
        a = k * np.pi / 3 + 0.4
        c.line([(28 + np.cos(a) * 22, 28 + np.sin(a) * 22), (28 + np.cos(a) * 9, 28 + np.sin(a) * 9)],
               "d4a040" if k % 2 else "5ee6e0")
    return c


def voice_box(new=False):
    src = from_image(os.path.join(ASSETS, "scope", "juno", "port.png"))
    piece = src.crop(43, 43, 86, 134)
    piece.a[~piece.rrect(0, 0, 42, 90, 6)] = 0
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
    c.fill(c.rrect(1, 1, 41, 89, 6), "07090c")
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


def main():
    out = {"room": room(), "chair": chair(), "drape": drape(), "body_floor": body_floor(), "legs": legs()}
    for name, kw in POSES.items():
        out[name] = figure(**kw)
    out.update({
        "board": board(), "glove_driver": glove("driver"), "glove_forceps": glove("forceps"),
        "hatch": hatch(), "cart_old": cartridge(), "cart_new": cartridge(True), "gauze": gauze(),
        "eye_empty": eye_empty(), "jack_old": jack(), "jack_new": jack(True), "jack_hole": jack_hole(),
        "box_old": voice_box(), "box_new": voice_box(True), "box_hole": voice_hole(),
    })
    for name, c in out.items():
        c.save("%s/%s.png" % (D, name))
    kip_fixed_front().save(D + "/kip/eyes_front_fixed.png")
    dana_fixed_iris().save(D + "/dana/iris_fixed.png")
    # review sheet (not shipped): the masks as the film shows them, dark on the wall
    os.makedirs(OUT, exist_ok=True)
    review = []
    for name, c in out.items():
        if name.startswith(("crew_", "body_", "legs")):
            shown = Canvas(c.w, c.h, "4a5a5e")
            shown.fill(c.alpha(), "0b1014")
            review.append((name, shown))
        else:
            review.append((name, c))
    contact_sheet(review, os.path.join(OUT, "film_art.png"), scale=1, per_row=5)
    print("film art written")


if __name__ == "__main__":
    main()
