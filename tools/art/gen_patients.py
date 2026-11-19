"""The patients of the clinic, drawn as layered busts. See people.py for the layer list.

Left and right in notes are the patient's own; on screen the patient's right is on our left.
Optional layers: pupils_b (a second glyph for display eyes), pupils_react.

Any part can be the one that is wrong tonight, so every patient carries the art for each:
  <layer>_t            the same picture with dark threads at the port, where the bust shows the
                       port: the hands of Kip, Rook, Ozzie and Bo (hands_a_t, hands_b_t,
                       hands_react_t and their gestures), Juno's neck (body_t), Lux's temple
                       (head_t). Vale's port is under his collar, Maren's under her glove cuff,
                       Priya's under her scrub sleeve and Dana's under her coat collar, so their
                       threads show only in the close-up.
  hands_<gesture>      a temper gesture the plain hands_react does not show: hands_fist (Kip's
                       fist, Rook's quiet one on the sill, Ozzie's CHOP, Lux's, Dana's at her belt,
                       Bo's cocked PISTON), hands_point (Vale, Priya, Lux, Dana), hands_slam (a
                       palm slapped on the glass: everyone but Rook).
meta "gestures" maps every gesture a patient's temper signs use to the layer that shows it
(Rook's slam is hands_react, his fists banging the counter; Maren's freeze is hands_a). Every
gesture layer whose bust shows the port has its _t twin.
Eyes and grip signs are behaviour (the close-up's pupils, the grip's timing), and speech is
words, so they need no picture of their own.

Every patient can turn on the player, so every one carries the layers of that scene:
  turn / turn_clean    face overlay: dark threads under the skin, the eyes, and (not in the
                       clean one) blood
  mouth_turn / _b      two frames of the scream
  mouth_turn_clean, mouth_turn_b_clean
                       the same two frames with nothing on the teeth or the chin
  attack / _b          the wind-up: weapon raised, free hand open (two frames, so the weapon runs)
  attack_s1 / _b       first blow: the free hand flat on the glass
  attack_s2 / _b       second blow: the weapon on the glass as well
  attack_s1_clean, attack_s1_b_clean, attack_s2_clean, attack_s2_b_clean
                       the same four blow poses with a dry palm
The _clean layers are what the --less-blood option shows. meta "attack" names the weapon's
style (saw, torch, lock, fist, picks, laser, cleaver, arc, baton, spike), which picks the game's
sounds and marks, and the points where the hand and the weapon meet the glass.
"""
import json
import os
import sys

import numpy as np

import people as P
from people import (BASE_Y, CLOTH, H, OUTLINE, SKIN, W, almond, blink, blood_run, brows_set, eye_whites, finish,
                    fist, grow, hand_rest, head_mask, layer, lid_lines, mouth_frames, natural_pupil, nose, paint,
                    palm_flat, palm_up, silhouette, sleeve, smooth, stroke, threads)
from px import ASSETS, OUT, Canvas, contact_sheet

CX = 80
GAUNTLET = ["140e10", "2a1a1a", "3e2620", "5a3a2a", "7a4630", "a86a3c"]
GLOVE = CLOTH["glove"] + ["f0dba8"]


def new_patient():
    return {"body": layer(), "pupils": layer(), "head": layer(), "lids": layer(),
            "hands_a": layer(), "hands_b": layer(), "hands_react": layer()}


def torso(c, pts, cloth, **kw):
    m = smooth(c.poly(pts), 2)
    yy, _ = c.grid()
    m &= yy < BASE_Y
    paint(c, m, cloth, round_px=9, **kw)
    return m


def neck(c, x0, x1, y0, y1, skin, shadow=3):
    m = c.rect(x0, y0, x1, y1)
    paint(c, m, skin, round_px=5, bias=-0.1)
    yy, _ = c.grid()
    c.fill(m & (yy < y0 + shadow), skin[1])
    c.dither(m & (yy >= y0 + shadow) & (yy < y0 + shadow + 4), skin[1], 0.5)
    return m


def wrist_port(c, x, y, burnt=False, scar=None):
    c.fill(c.ell(x, y, 3.2, 3.2), "steel1")
    c.fill(c.ell(x, y, 2.4, 2.4), "steel4")
    c.fill(c.ell(x, y, 1.2, 1.2), "ink0")
    c.px(x - 1, y - 2, "steel5")
    if burnt:
        for dx, dy in ((-4, 1), (3, 3), (-3, -3), (4, -1), (0, 4), (-5, -1)):
            c.px(x + dx, y + dy, "ink1")
        c.px(x, y, "warm4")
        c.px(x + 1, y - 1, "warm3")
    if scar:
        stroke(c, [(x + 4, y - 5), (x + 7, y + 2)], scar)


def rictus(cx, my, skin, hw=9, gape=0, bloody=True, teeth="paper3"):
    """A mouth dragged back off the teeth. gape drops the jaw."""
    c = layer()
    dark = "1a0c10"
    top, bot = my - 3, my + 4 + gape
    m = c.rrect(cx - hw, top, cx + hw, bot, 3)
    for s in (-1, 1):                                    # the corners pull up and back
        m |= c.seg([(cx + s * hw, top + 2), (cx + s * (hw + 2), top - 1)], 2)
    c.fill(m, dark)
    for x in range(cx - hw + 2, cx + hw - 1):
        c.px(x, top + 1, teeth)
        if (x - cx) % 3 != 0:
            c.px(x, top + 2, teeth)
    for x in range(cx - hw + 3, cx + hw - 2):
        c.px(x, bot - 1, teeth)
        if gape and (x - cx) % 3 != 1:
            c.px(x, bot - 2, teeth)
    if gape >= 3:
        tongue = c.ell(cx, bot - 4, hw - 4, 1.8) & m
        c.fill(tongue, "8a3038")
        c.px(cx - 1, bot - 5, "c0505a")
    c.outline(skin[1], m)
    if bloody:
        for dx in (-4, 2, 5):
            c.px(cx + dx, top + 2, "red1")
        c.px(cx - 2, bot - 1, "red1")
        blood_run(c, [(cx + hw - 1, bot + 1), (cx + hw, bot + 5)])
        blood_run(c, [(cx - 3, bot + 1), (cx - 3, bot + 3)], bead=False)
    return c


def saw_disc(c, cx, cy, r, phase=0.0):
    """Vale's rig: a toothed disc. phase turns it between frames."""
    yy, xx = c.grid()
    d = np.hypot(xx - cx, yy - cy)
    a = np.arctan2(yy - cy, xx - cx) / (2 * np.pi)
    n = max(10, int(round(r * 1.15)))
    teeth = (d < r + 2.3) & (d >= r - 0.5) & (((a * n + phase) % 1.0) < 0.5)
    disc = d < r
    c.fill(grow(disc | teeth, 1), "ink0")
    c.fill(teeth, "dbe6e0")
    c.fill(disc, "steel3")
    c.fill(disc & (d > r - 3.4), "steel4")
    c.fill(disc & (d > r - 1.7), "steel5")
    c.fill(disc & (d < r - 4.5) & (d > 3.6) & (((a * 5 + phase * 0.6) % 1.0) < 0.26), "steel1")
    lit = (xx - cx) * -0.75 + (yy - cy) * 0.5
    c.dither(disc & (lit > r * 0.35), "dbe6e0", 0.45)
    for k in range(3):                                   # the blur of it turning
        a0 = phase * 0.37 + k * 0.31
        arc = disc & (np.abs(d - (r - 4.5 - k * 2.6)) < 0.7) & (((a - a0) % 1.0) < 0.2)
        c.fill(arc, "white")
    c.fill(d < 3.3, "steel1")
    c.fill(d < 1.7, "red2")
    c.px(int(cx), int(cy), "red3")


def glyph(c, cx, cy, rows, color, color2=None):
    for r, row in enumerate(rows):
        for q, ch in enumerate(row):
            if ch == "#":
                c.px(cx - 2 + q, cy - 2 + r, color2 if (color2 and r >= 2) else color)


def twin(c, mask, roots, seed, halo="4a2440"):
    """The _t twin of a layer: the same picture with dark threads under the skin in mask, each
    with a dithered bruise along it so it reads at the size of the bust."""
    t = c.copy()
    line = threads(t, mask, roots, seed=seed)
    t.dither((grow(line, 1) & ~line) & mask, halo, 0.5)
    return t


def u_lock(c, x, y, ang, hw, ln, w=4, glint=0.3):
    """Kip's bike lock, held by its crossbar at (x, y), the steel shackle standing out of the fist.
    ang tilts it (0 is straight up, negative leans left); hw is half the shackle's width and ln
    the length of its legs; glint (0..1) is where the light sits on the shackle."""
    rx, ry = np.cos(ang), np.sin(ang)
    ux, uy = np.sin(ang), -np.cos(ang)

    def at(u, v):
        return (x + rx * u + ux * v, y + ry * u + uy * v)

    pts = [at(-hw, 0), at(-hw, ln)]
    for k in range(1, 12):
        t = np.pi * k / 12.0
        pts.append(at(-hw * np.cos(t), ln + hw * np.sin(t)))
    pts += [at(hw, ln), at(hw, 0)]
    shackle = c.seg(pts, w)
    c.fill(grow(shackle, 1), OUTLINE)
    paint(c, shackle, CLOTH["chrome"], round_px=2, bias=-0.05)
    gx, gy = pts[int(round(glint * (len(pts) - 1)))]
    c.fill(c.ell(gx, gy, 1.3, 1.3) & shackle, "white")
    bar = c.seg([at(-hw - 4, 0), at(hw + 4, 0)], w + 3)
    c.fill(grow(bar, 1), OUTLINE)
    paint(c, bar, ["0b1014", "1b2228", "2e3a42", "4a5a63"], round_px=2)
    c.fill(c.seg([at(-hw - 2, 0), at(hw + 2, 0)], 1) & bar, "red2")
    kx, ky = at(hw + 2, 0)
    c.px(kx, ky, "ink0")
    return at(0, ln + hw)


def picks(c, fingers, ln, glint=0.5):
    """DEFT picks snapped out of the fingertips: each finger is (base, tip) and its pick runs on
    the same line for ln pixels. glint (0..1) is where the light sits on them."""
    for (bx, by), (tx, ty) in fingers:
        a = np.arctan2(ty - by, tx - bx)
        ex, ey = tx + np.cos(a) * ln, ty + np.sin(a) * ln
        pk = c.seg([(tx, ty), (ex, ey)], 1)
        c.fill(grow(pk, 1) & ~pk, OUTLINE)
        c.fill(pk, "steel4")
        c.px(tx + (ex - tx) * glint, ty + (ey - ty) * glint, "white")
        c.px(ex, ey, "white")


def up_fingers(x, y, w, side):
    """The fingers of palm_up(c, x, y, w, ...), as (base, tip) pairs."""
    fw = max(3, (w - 3) // 4)
    w = fw * 4 + 3
    x0 = x - w // 2
    lens = (9, 11, 11, 8) if side > 0 else (8, 11, 11, 9)
    return [((x0 + i * (fw + 1) + (fw - 1) / 2.0, y), (x0 + i * (fw + 1) + (fw - 1) / 2.0, y - lens[i])) for i in range(4)]


def flat_fingers(x, y, w, side):
    """The fingers of palm_flat(c, x, y, w, side, ...), as (base, tip) pairs."""
    hw = w // 2
    spread = (-8, -3, 2, 7) if side > 0 else (-7, -2, 3, 8)
    lens = (11, 14, 13, 10) if side > 0 else (10, 13, 14, 11)
    out = []
    for i in range(4):
        bx = x - hw + 2 + i * (w - 5) / 3.0
        out.append(((bx, y + 3), (bx + spread[i] * 0.7, y - lens[i])))
    return out


# ====================================================================== Kip
def kip():
    p = new_patient()
    skin, hair, cloth = SKIN["kip"], CLOTH["ginger"], CLOTH["hivis"]
    cy = 78
    body, head = p["body"], p["head"]
    yy, xx = body.grid()

    # jacket, too big for him
    jm = torso(body, [(CX - 46, 136), (CX - 30, 119), (CX + 30, 119), (CX + 46, 136), (CX + 50, 162), (CX - 50, 162)], cloth)
    hood = body.poly([(CX - 13, 114), (CX + 13, 114), (CX, 140)])
    paint(body, hood, CLOTH["hood"], round_px=4)
    band = jm & (yy >= 146) & (yy <= 150) & ~hood
    body.fill(band, "steel4")
    body.dither(band, "steel5", np.clip(1.0 - (xx - 30) / 90.0, 0, 1))
    body.fill(jm & (yy == 151), cloth[1])
    stroke(body, [(CX, 140), (CX, 160)], "steel2")
    stroke(body, [(CX + 1, 140), (CX + 1, 160)], cloth[1])
    strap = body.seg([(CX + 30, 118), (CX - 22, 162)], 7) & jm
    paint(body, strap, CLOTH["hood"], round_px=3)
    body.fill(body.rect(CX + 4, 139, CX + 9, 144) & strap, "steel4")
    finish(body, jm)
    for s in (-1, 1):
        flap = body.poly([(CX + s * 9, 112), (CX + s * 26, 116), (CX + s * 21, 134), (CX + s * 6, 126)])
        paint(body, flap, cloth, round_px=4, bias=0.1 if s < 0 else -0.05)
        body.outline(OUTLINE, flap)
    nk = neck(body, CX - 7, CX + 7, 104, 118, skin)
    body.outline(OUTLINE, nk & (yy < 113))

    # head
    for s in (-1, 1):
        ear = head.ell(CX + s * 25, cy + 3, 4, 6)
        paint(head, ear, skin, round_px=3)
        head.outline(OUTLINE, ear)
    hm = head_mask(head, CX, cy, 50, 58, jaw=0.78, chin=0.42)
    paint(head, hm, skin, round_px=13, round_amt=0.7)
    head.fill(head.edge(hm, 1, 0), P.RIM)
    for fx, fy in ((-17, 9), (-13, 11), (-20, 12), (12, 10), (16, 12), (19, 9), (-15, 13)):
        head.px(CX + fx, cy + fy, skin[2])
    nose(head, CX, cy + 1, cy + 11, skin)
    head.outline(OUTLINE, hm)

    # natural right eye (our left), cheap cracked optic on the left (our right)
    eye_r = almond(head, CX - 13, cy, 7, 4.6)
    eye_whites(body, [eye_r])
    head.erase(eye_r)
    lid_lines(head, eye_r, skin)
    natural_pupil(p["pupils"], CX - 13, cy, ("4a2a16", "9a6230"))
    ox, oy = CX + 13, cy
    head.fill(head.ell(ox, oy, 8.6, 8.6), OUTLINE)
    ring = head.ell(ox, oy, 7.6, 7.6)
    paint(head, ring, CLOTH["chrome"], round_px=3, bias=-0.05)
    head.fill(head.ell(ox, oy, 5.2, 5.2), "ink0")
    head.fill(head.ell(ox, oy, 4.2, 4.2), "cyan0")
    head.fill(head.ell(ox, oy, 2.2, 2.2), "ink0")
    head.px(ox - 2, oy - 3, "cyan2")
    head.px(ox - 3, oy - 2, "cyan1")
    stroke(head, [(ox - 4, oy - 5), (ox + 1, oy), (ox, oy + 3), (ox + 4, oy + 6)], "cyan3")
    stroke(head, [(ox + 1, oy), (ox + 5, oy - 2)], "cyan3")
    head.px(ox - 9, oy - 5, "steel2")
    head.px(ox + 9, oy + 5, "steel2")
    blink(p["lids"], eye_r, skin)

    # ginger hair, slept on
    hmask = head.ell(CX, cy - 16, 27.5, 18) & (yy < cy - 14)
    for tri in ([(56, 62), (48, 42), (68, 52)], [(64, 54), (63, 33), (78, 50)], [(74, 52), (84, 30), (92, 50)],
                [(86, 52), (102, 35), (102, 56)], [(98, 58), (113, 47), (107, 66)],
                [(57, 60), (62, 68), (69, 60)], [(68, 60), (75, 66), (82, 60)], [(98, 60), (100, 67), (104, 60)],
                [(54, 60), (55, 75), (58, 64)], [(103, 60), (106, 73), (106, 60)]):
        hmask |= head.poly(tri)
    hmask = smooth(hmask, 1)
    paint(head, hmask, hair, round_px=8, round_amt=0.7, contrast=1.1)
    for a, b in (((62, 58), (58, 46)), ((72, 54), (70, 40)), ((82, 52), (85, 38)), ((92, 54), (98, 42))):
        stroke(head, [a, b], hair[4])
    head.fill(head.edge(hmask, 1, 0), P.RIM)
    head.outline(OUTLINE, hmask)

    # courier headset on his right ear
    cup = head.ell(CX - 27, cy + 3, 5, 8)
    paint(head, cup, CLOTH["vest"], round_px=3)
    head.outline(OUTLINE, cup)
    head.px(CX - 28, cy + 1, "cyan2")
    stroke(head, [(CX - 27, cy + 11), (CX - 22, cy + 20), (CX - 13, cy + 22)], "steel1")
    head.fill(head.rect(CX - 14, cy + 21, CX - 11, cy + 23), "ink0")
    stroke(head, [(CX - 29, cy - 5), (CX - 33, cy - 22)], "steel2")
    head.px(CX - 33, cy - 23, "cyan2")

    brows = brows_set(CX, cy, 13, hair[0], width=2, lift=-1)
    mouths = mouth_frames(CX, cy + 19, skin, width=9, curve=-0.5)

    # hands
    def sill_hands(c, lifts, clench=False, left=True):
        """His hands on the sill (left=False: only the right one). Returns the bare skin of the
        right hand and wrist, where the port is."""
        bare = c.none()
        for i, x in enumerate((CX - 24, CX + 24)):
            if i == 1 and not left:
                continue
            sl = sleeve(c, x, 144, 153, 16, cloth)
            c.outline(OUTLINE, sl)
            wr = c.rect(x - 5, 153, x + 5, 158)
            paint(c, wr, skin, round_px=3)
            c.outline(OUTLINE, wr)
            if i == 0:
                wrist_port(c, x, 155)
            if i == 0 and clench:
                hand = fist(c, x, 157, 17, skin, h=11, side=1)
            else:
                hand = hand_rest(c, x, 158, 17, skin, lifted=lifts[i], side=1 if i == 0 else -1)
            if i == 0:
                bare = (wr | hand) & ~c.ell(x, 155, 3.8, 3.8)
        return bare

    bare = {}
    for name, lifts in (("hands_a", ((1,), ())), ("hands_b", ((), (0, 2)))):
        bare[name] = sill_hands(p[name], lifts)
    c = p["hands_react"]
    for i, x in enumerate((CX - 34, CX + 34)):
        sl = c.seg([(x - (4 if i == 0 else -4), 162), (x, 138)], 13)
        paint(c, sl, cloth, round_px=4)
        c.outline(OUTLINE, sl)
        palm = palm_up(c, x, 122, 17, skin, side=-1 if i == 0 else 1)
        if i == 0:
            wrist_port(c, x, 139)
            bare["hands_react"] = palm & ~c.ell(x, 139, 3.8, 3.8)
    p["hands_fist"] = layer()                            # "His hand closed into a fist."
    bare["hands_fist"] = sill_hands(p["hands_fist"], ((), ()), clench=True)

    # ---- the turn: the KITE lens spins and the bike lock comes off his belt
    face_skin = (hm & ~hmask & ~head.ell(ox, oy, 9.6, 9.6) & ~cup) | body.rect(CX - 7, 104, CX + 7, 118)

    def turn_face(bloody):
        t = layer()
        ty, tx = t.grid()
        roots = [(CX - 4, 118, -1.7, 30), (CX + 3, 118, -1.45, 26), (CX - 1, 117, -1.6, 20),
                 (CX - 20, cy + 6, 0.6, 12), (CX + 21, cy + 10, 2.5, 10), (CX - 18, cy - 7, -1.9, 8)]
        threads(t, face_skin, roots, seed=53)
        ex, ey = CX - 13, cy                             # the natural eye forced wide, the pupil a point
        wide = almond(t, ex, ey, 8.0, 5.6)
        t.fill(grow(wide, 1), OUTLINE)
        t.fill(wide, "paper3")
        t.fill(wide & (ty <= ey - 4), "paper1")
        for dx, dy in ((-6, 0), (-5, 1), (6, 1), (5, -1)):
            t.px(ex + dx, ey + dy, "red2" if bloody else "c98058")
        t.fill(t.ell(ex, ey, 2.4, 2.4), "4a2a16")
        t.fill(t.ell(ex, ey, 1.0, 1.0), "ink0")
        t.px(ex - 1, ey - 1, "white")
        t.fill((grow(wide, 1) & ~wide) & (ty > ey + 1), "red1" if bloody else skin[1])
        t.glow(t.all(), "red1", ox, oy, 13, amt=0.85)   # the cracked lens runs red
        t.fill(t.ell(ox, oy, 4.2, 4.2), "red0")
        t.fill(t.ell(ox, oy, 2.2, 2.2), "red2")
        t.px(ox, oy, "white")
        stroke(t, [(ox - 4, oy - 5), (ox + 1, oy), (ox, oy + 3), (ox + 4, oy + 6)], "red3")
        if bloody:                                       # the optic's seat weeps
            blood_run(t, [(ox - 2, oy + 8), (ox - 3, oy + 14), (ox - 2, oy + 22)], wide=True)
            blood_run(t, [(ox + 4, oy + 8), (ox + 5, oy + 13)])
            blood_run(t, [(CX - 2, cy + 12), (CX - 2, cy + 15)], bead=False)
        return t

    p["turn"] = turn_face(True)
    p["turn_clean"] = turn_face(False)
    for tag, bloody in (("", True), ("_clean", False)):
        p["mouth_turn" + tag] = rictus(CX, cy + 19, skin, hw=8, gape=4, bloody=bloody)
        p["mouth_turn_b" + tag] = rictus(CX, cy + 19, skin, hw=8, gape=1, bloody=bloody)

    def hivis_arm(c, a, b, w):
        arm = c.seg([a, b], w)
        paint(c, arm, cloth, round_px=4)
        (ax, ay), (bx, by) = a, b
        ln = max(1e-6, float(np.hypot(bx - ax, by - ay)))
        nx, ny = -(by - ay) / ln, (bx - ax) / ln
        mx, my = ax + (bx - ax) * 0.7, ay + (by - ay) * 0.7
        band = c.seg([(mx - nx * w, my - ny * w), (mx + nx * w, my + ny * w)], 3) & arm
        c.fill(band, "steel4")
        c.dither(band, "steel5", 0.5)
        c.outline(OUTLINE, arm)

    def free_hand(c, flat, wet=True):
        if flat:
            hivis_arm(c, (CX + 52, 170), (141, 136), 15)
            wr = c.rrect(133, 121, 145, 133, 3)
            paint(c, wr, skin, round_px=3)
            c.outline(OUTLINE, wr)
            palm_flat(c, 138, 109, 24, skin, side=-1, h=15, wet=wet)
        else:
            hivis_arm(c, (CX + 44, 168), (CX + 36, 140), 14)
            palm_up(c, CX + 36, 122, 19, skin, side=-1, h=12)

    def lock_arm(c, elbow, wrist, fw, lock, glint):
        """His right arm with the lock; lock is u_lock's (x, y, ang, hw, ln, w), and the fist closes
        on the crossbar. Returns where the top of the shackle is."""
        hivis_arm(c, elbow, wrist, 16 if fw > 20 else 15)
        bx, by = wrist
        wr = c.rrect(bx - 5, by - 8, bx + 5, by - 1, 2)
        paint(c, wr, skin, round_px=3)
        c.outline(OUTLINE, wr)
        wrist_port(c, bx, by - 4)
        lx, ly, ang, hw, ln, w = lock
        top = u_lock(c, lx, ly, ang, hw, ln, w=w, glint=glint)
        fist(c, int(lx), int(ly) - 6, fw, skin, h=12, side=1)
        return top

    for tag, k in (("", 0), ("_b", 1)):
        a = layer()                                      # wind-up: the lock comes off his belt, shaking
        lock_arm(a, (CX - 52, 170), (CX - 42, 132), 20, (CX - 42, 118 - k, (-0.08, 0.06)[k], 8, 18, 4), 0.25 + 0.4 * k)
        free_hand(a, False)
        p["attack" + tag] = a
        for clean, wet in (("", True), ("_clean", False)):
            a = layer()                                  # first blow: his palm on the glass
            lock_arm(a, (CX - 52, 170), (CX - 42, 132), 20, (CX - 42, 118 - k, (-0.22, -0.1)[k], 8, 18, 4), 0.35 + 0.4 * k)
            free_hand(a, True, wet)
            p["attack_s1" + tag + clean] = a
            a = layer()                                  # second blow: the lock rings off the glass
            tx, ty = lock_arm(a, (CX - 38, 176), (CX - 33 - k, 152), 22, (47 - k, 138 + k, (-0.55, -0.5)[k], 9, 19, 5), 0.6 - 0.4 * k)
            for ang in (-2.8, -2.1, -1.4, 2.6):
                r0, r1 = 7 + k, 12 + 2 * k
                stroke(a, [(tx + np.cos(ang) * r0, ty + np.sin(ang) * r0), (tx + np.cos(ang) * r1, ty + np.sin(ang) * r1)], "paper3")
            free_hand(a, True, wet)
            p["attack_s2" + tag + clean] = a

    p["hands_slam"] = layer()                            # "Slapped the glass, all of him at once."
    bare["hands_slam"] = sill_hands(p["hands_slam"], ((), ()), left=False)
    free_hand(p["hands_slam"], True, wet=False)

    # dark threads out from the wrist port, on every picture that shows it
    sill_roots = [(CX - 24, 158, 1.57, 12), (CX - 27, 157, 2.3, 9), (CX - 21, 157, 0.85, 9),
                  (CX - 28, 155, 3.1, 4), (CX - 20, 154, -0.1, 4)]
    react_roots = [(CX - 34, 136, -1.57, 14), (CX - 37, 136, -2.0, 11), (CX - 31, 136, -1.15, 11)]
    for name, m in bare.items():
        p[name + "_t"] = twin(p[name], m, react_roots if name == "hands_react" else sill_roots, seed=71)

    p.update({"brows_" + k: v for k, v in brows.items()})
    p.update({"mouth_" + k: v for k, v in mouths.items()})
    meta = {"zones": {"eyes": [54, 66, 52, 22], "hands": [42, 157, 76, 17], "port": [46, 143, 20, 14]},
            "face": {"brows": "worried", "mouth": "closed"}, "blink": [1.4, 3.2], "mouth_y": cy + 19,
            "attack": {"style": "lock", "hand": [138, 108], "tool": [32, 114], "head": [CX, cy - 16], "face": [CX, cy + 8]},
            "gestures": {"raise": "hands_react", "fist": "hands_fist", "slam": "hands_slam"}}
    return p, meta


# ====================================================================== Rook
def rook():
    p = new_patient()
    skin = SKIN["rook"]
    cy = 70
    body, head = p["body"], p["head"]
    yy, xx = body.grid()

    tm = torso(body, [(2, 140), (26, 119), (134, 119), (158, 140), (160, 162), (0, 162)], CLOTH["thermal"])
    trap = body.poly([(CX - 19, 98), (CX + 19, 98), (CX + 52, 123), (CX - 52, 123)])
    paint(body, trap, skin, round_px=6, bias=-0.1)
    body.fill(trap & (yy < 106), skin[1])
    body.dither(trap & (yy >= 106) & (yy < 110), skin[1], 0.5)
    finish(body, tm | trap)
    vest = smooth(body.poly([(30, 121), (130, 121), (137, 162), (23, 162)]), 2)
    vest &= ~body.poly([(CX - 19, 118), (CX + 19, 118), (CX, 148)]) & (yy < BASE_Y)
    paint(body, vest, CLOTH["vest"], round_px=8)
    stroke(body, [(CX - 19, 121), (CX - 1, 147)], "c98a22", 2)
    stroke(body, [(CX + 19, 121), (CX + 1, 147)], "8a5a22", 2)
    body.outline(OUTLINE, vest)
    for s in (-1, 1):
        pad = body.poly([(CX + s * 40, 117), (CX + s * 70, 127), (CX + s * 75, 142), (CX + s * 44, 135)])
        paint(body, pad, CLOTH["hivis"], round_px=4, bias=0.08 if s < 0 else -0.12)
        body.fill(pad & (((xx + yy * s) // 4) % 2 == 0), "ink1")
        body.outline(OUTLINE, pad)
        body.px(CX + s * 45, 123, "steel5")
        body.px(CX + s * 68, 132, "steel5")
    tag = body.rect(CX + 26, 142, CX + 40, 148)
    body.fill(tag, "steel1")
    stroke(body, [(CX + 28, 144), (CX + 38, 144)], "steel4")
    stroke(body, [(CX + 28, 146), (CX + 35, 146)], "steel3")

    for s in (-1, 1):
        ear = head.ell(CX + s * 29, cy + 2, 5, 7)
        paint(head, ear, skin, round_px=3)
        head.outline(OUTLINE, ear)
        head.px(CX + s * 29, cy + 1, skin[1])
        head.px(CX + s * 29, cy + 3, skin[1])
    hm = head_mask(head, CX, cy, 58, 62, jaw=0.96, chin=0.62)
    paint(head, hm, skin, round_px=14, round_amt=0.7)
    head.dither(hm & (yy < cy - 13), skin[1], np.clip((cy - 11 - yy) / 16.0, 0, 0.55))
    beard = hm & ((yy > cy + 14) | ((np.abs(xx - CX) > 20) & (yy > cy + 6)))
    head.dither(beard & ~head.ell(CX, cy + 21, 9, 5), skin[1], 0.4)
    head.dither(hm & head.rect(CX - 25, cy - 7, CX + 25, cy - 4), skin[1], 0.6)
    head.fill(head.edge(hm, 1, 0), P.RIM)
    nose(head, CX, cy + 1, cy + 13, skin, w=4)
    stroke(head, [(CX + 1, cy + 3), (CX - 1, cy + 7)], skin[5])
    stroke(head, [(CX + 22, cy - 15), (CX + 19, cy + 10)], skin[5])
    for t in (-10, -4, 6):
        stroke(head, [(CX + 18, cy + t), (CX + 23, cy + t + 1)], skin[1])
    head.outline(OUTLINE, hm)
    holes = [almond(head, CX + s * 14, cy, 5.6, 3.4) for s in (-1, 1)]
    eye_whites(body, holes)
    for i, hmk in enumerate(holes):
        s = -1 if i == 0 else 1
        g = grow(hmk, 1)
        body.dither(g, "e09080", 0.4)
        body.px(CX + s * 18, cy, "red2")
        body.px(CX + s * 10, cy + 1, "red2")
        head.erase(hmk)
        lid_lines(head, hmk, skin)
        head.fill(g & ~hmk & (yy > cy), "a8483c")
        natural_pupil(p["pupils"], CX + s * 14, cy, ("20120c", "5a3820"), r=2.9)
        blink(p["lids"], hmk, skin)

    brows = brows_set(CX, cy, 14, "100a0c", width=3, lift=-3, span=9)
    mouths = mouth_frames(CX, cy + 22, skin, width=11, curve=-1.0)

    def arm_and_hand(c, i, ox, oy, lifted):
        """One forearm and hand on the sill. Returns the bare skin of it, the port left out."""
        x = CX + (-34 if i == 0 else 34)
        arm = c.rrect(x - 10 + ox, 142 + oy, x + 10 + ox, 158 + oy, 3)
        paint(c, arm, skin, round_px=5)
        c.outline(OUTLINE, arm)
        cuff = c.rrect(x - 12, 137, x + 12, 143, 2)
        paint(c, cuff, CLOTH["thermal"], round_px=3)
        c.outline(OUTLINE, cuff)
        if i == 0:
            wrist_port(c, x + ox, 151 + oy, burnt=True, scar=skin[5])
        hand = hand_rest(c, x + ox, 158 + oy, 23, skin, lifted=lifted, side=1 if i == 0 else -1, h=14)
        for k in range(4):
            c.px(x + ox - 9 + k * 6, 162 + oy, "b0403a")
            c.px(x + ox - 8 + k * 6, 162 + oy, "c8483c")
        return ((arm & ~grow(cuff, 1)) | hand) & ~c.ell(x + ox, 151 + oy, 3.8, 3.8)

    def port_roots(x, y, spec):
        """Thread roots leaving a port at (x, y): spec is (angle, length) pairs."""
        return [(x + np.cos(a) * 4, y + np.sin(a) * 4, a, ln) for a, ln in spec]

    bare = {}
    for name, jerk in (("hands_a", False), ("hands_b", True)):
        for i in (0, 1):
            j = jerk and i == 0
            m = arm_and_hand(p[name], i, -2 if j else 0, -2 if j else 0, (0, 1, 2, 3) if j else ())
            if i == 0:
                bare[name] = (m, port_roots(CX - 34 - (2 if j else 0), 151 - (2 if j else 0),
                                            ((1.57, 14), (2.3, 10), (0.8, 10), (-2.5, 8), (0.1, 8))))
    c = p["hands_react"]
    for i, x in enumerate((CX - 30, CX + 30)):
        arm = c.seg([(x + (-9 if i == 0 else 9), 138), (x, 158)], 21)
        paint(c, arm, skin, round_px=5)
        c.outline(OUTLINE, arm)
        if i == 0:
            wrist_port(c, x - 5, 148, burnt=True, scar=skin[5])
        hand = fist(c, x, 158, 26, skin, knuckle="c8483c", h=13, side=1 if i == 0 else -1)
        if i == 0:
            bare["hands_react"] = ((arm | hand) & ~c.ell(x - 5, 148, 3.8, 3.8),
                                   port_roots(x - 5, 148, ((1.77, 12), (2.4, 9), (0.6, 10), (-1.9, 8))))
        for dx in (-19, -16, 16, 19):
            stroke(c, [(x + dx, 172), (x + dx + (3 if dx > 0 else -3), 167)], "warm7")
    c = p["hands_fist"] = layer()                        # "Quiet, polite. The LOADER fist shut."
    x = CX - 34
    arm = c.rrect(x - 10, 142, x + 10, 158, 3)
    paint(c, arm, skin, round_px=5)
    for k, tx in enumerate((x - 6, x - 1, x + 5)):       # the cords of the forearm stand out
        stroke(c, [(tx, 144), (tx + (-1, 0, 1)[k], 156)], skin[4])
        stroke(c, [(tx + 1, 145), (tx + 1 + (-1, 0, 1)[k], 156)], skin[1])
    c.outline(OUTLINE, arm)
    cuff = c.rrect(x - 12, 137, x + 12, 143, 2)
    paint(c, cuff, CLOTH["thermal"], round_px=3)
    c.outline(OUTLINE, cuff)
    wrist_port(c, x, 151, burnt=True, scar=skin[5])
    hand = fist(c, x, 156, 24, skin, knuckle="f4e6dc", h=13, side=1)
    for kx in (x - 8, x + 2):                            # gripped white, but still raw
        c.px(kx, 158, "c8483c")
    bare["hands_fist"] = (((arm & ~grow(cuff, 1)) | hand) & ~c.ell(x, 151, 3.8, 3.8),
                          port_roots(x, 151, ((1.57, 14), (2.3, 10), (0.8, 10), (-2.5, 8), (0.1, 8))))
    arm_and_hand(c, 1, 0, 0, ())                         # the other hand lies where it was
    for name, (m, roots) in bare.items():
        p[name + "_t"] = twin(p[name], m, roots, seed=73)

    # ---- the turn: the LOADER arm cranks back and every piston in it hisses
    face_skin = (hm | (trap & ~vest & (yy < 118) & (np.abs(xx - CX) < 38))) & ~grow(holes[0] | holes[1], 1)

    def turn_face(bloody):
        t = layer()
        ty, tx = t.grid()
        roots = [(CX - 12, 114, -1.62, 32), (CX + 11, 114, -1.5, 30), (CX - 1, 110, -1.57, 24), (CX - 34, 120, -1.1, 16),
                 (CX + 34, 120, -2.0, 16), (CX - 24, cy + 12, -1.7, 12), (CX + 24, cy + 10, -1.4, 12)]
        threads(t, face_skin, roots, seed=59)
        for s in (-1, 1):                                # the whites flood red, the pupils go to points
            ex = CX + s * 14
            e = almond(t, ex, cy, 6.6, 4.4)
            t.fill(grow(e, 1), OUTLINE)
            t.fill(e, "e8b0a0")
            t.dither(e, "c8483c", 0.45)
            t.fill(e & (ty <= cy - 3), "a8483c")
            t.fill(t.ell(ex, cy, 1.6, 1.6), "20120c")
            t.px(ex, cy, "ink0")
            t.px(ex - 1, cy - 1, "white")
            t.fill((grow(e, 1) & ~e) & (ty > cy + 1), "red1" if bloody else "a8483c")
        if bloody:
            blood_run(t, [(CX - 2, cy + 14), (CX - 3, cy + 18)], bead=False)
            blood_run(t, [(CX + 2, cy + 14), (CX + 2, cy + 17), (CX + 3, cy + 19)])
            blood_run(t, [(CX - 20, cy + 4), (CX - 21, cy + 10)])
        return t

    p["turn"] = turn_face(True)
    p["turn_clean"] = turn_face(False)
    for tag, bloody in (("", True), ("_clean", False)):
        p["mouth_turn" + tag] = rictus(CX, cy + 21, skin, hw=10, gape=4, bloody=bloody)
        p["mouth_turn_b" + tag] = rictus(CX, cy + 21, skin, hw=10, gape=1, bloody=bloody)

    def loader_arm(c, elbow, wrist, fw, fh, pump, big=False, lift=0):
        """His right arm with the LOADER rig out: a piston down each side of the forearm (pump,
        0..1, is how far the rods are out), chrome braces, the burnt port, and the fist."""
        (ax, ay), (bx, by) = elbow, wrist
        aw = 24 if big else 20
        arm = c.seg([elbow, wrist], aw)
        paint(c, arm, skin, round_px=5)
        c.outline(OUTLINE, arm)
        ln = max(1e-6, float(np.hypot(bx - ax, by - ay)))
        dx, dy = (bx - ax) / ln, (by - ay) / ln
        nx, ny = -dy, dx
        k = 0.42 + 0.18 * pump
        for s in (-1, 1):
            o = s * (aw / 2.0 - 2)
            p0 = (ax + nx * o, ay + ny * o)
            p1 = (bx + nx * o - dx * 3, by + ny * o - dy * 3)
            pm = (p0[0] + (p1[0] - p0[0]) * k, p0[1] + (p1[1] - p0[1]) * k)
            rod = c.seg([pm, p1], 2)
            c.fill(grow(rod, 1), OUTLINE)
            c.fill(rod, "steel5")
            cyl = c.seg([p0, pm], 5)
            c.fill(grow(cyl, 1), OUTLINE)
            paint(c, cyl, CLOTH["vest"], round_px=2)
            c.px(pm[0] - dx, pm[1] - dy, "steel5")
        for t_ in (0.3, 0.8):                            # the braces that hold it on
            mx, my = ax + (bx - ax) * t_, ay + (by - ay) * t_
            h = aw / 2.0 + 1
            band = c.seg([(mx - nx * h, my - ny * h), (mx + nx * h, my + ny * h)], 3)
            c.fill(grow(band, 1), OUTLINE)
            paint(c, band, CLOTH["chrome"], round_px=2)
        wrist_port(c, bx - dx * 7, by - dy * 7, burnt=True, scar=skin[5])
        fist(c, int(bx), int(by) - fh + 4 - lift, fw, skin, knuckle="c8483c", h=fh, side=1)
        if pump > 0.5:                                   # steam out of the cylinders
            for s in (-1, 1):
                o = s * (aw / 2.0 + 3)
                sx, sy = ax + nx * o + dx * 12, ay + ny * o + dy * 12
                c.dither(c.ell(sx, sy, 3.5, 2.5), "paper1", 0.5)
                c.dither(c.ell(sx + s * 2, sy - 3, 2.5, 2.0), "paper3", 0.4)

    def free_hand(c, flat, wet=True):
        if flat:
            a, b = (CX + 56, 172), (140, 122)
        else:
            a, b = (CX + 50, 172), (CX + 40, 132)
        arm = c.seg([a, b], 19)
        paint(c, arm, skin, round_px=5)
        c.outline(OUTLINE, arm)
        cuff = c.seg([a, (a[0] + (b[0] - a[0]) * 0.18, a[1] + (b[1] - a[1]) * 0.18)], 22)
        paint(c, cuff, CLOTH["thermal"], round_px=3)
        c.outline(OUTLINE, cuff)
        if flat:
            palm_flat(c, 138, 109, 27, skin, side=-1, h=16, wet=wet)
        else:
            fist(c, CX + 40, 120, 24, skin, knuckle="c8483c", h=14, side=-1)

    for tag, k in (("", 0), ("_b", 1)):
        a = layer()                                      # wind-up: cranked back, the rods running
        loader_arm(a, (CX - 56, 174), (CX - 48, 122), 28, 17, (0.0, 1.0)[k], lift=k)
        free_hand(a, False)
        p["attack" + tag] = a
        for clean, wet in (("", True), ("_clean", False)):
            a = layer()                                  # first blow: his palm on the glass
            loader_arm(a, (CX - 56, 174), (CX - 48, 122), 28, 17, (0.4, 0.9)[k], lift=1 - k)
            free_hand(a, True, wet)
            p["attack_s1" + tag + clean] = a
            a = layer()                                  # second blow: the LOADER fist on the glass
            loader_arm(a, (CX - 44, 178), (CX - 42 - k, 130), 34, 21, (1.0, 0.7)[k], big=True)
            for ang in (-2.6, -2.0, -1.2, 2.8, 0.3):
                r0, r1 = 20 + k, 25 + 2 * k
                stroke(a, [(38 + np.cos(ang) * r0, 122 + np.sin(ang) * r0), (38 + np.cos(ang) * r1, 122 + np.sin(ang) * r1)], "paper3")
            free_hand(a, True, wet)
            p["attack_s2" + tag + clean] = a

    p.update({"brows_" + k: v for k, v in brows.items()})
    p.update({"mouth_" + k: v for k, v in mouths.items()})
    meta = {"zones": {"eyes": [CX - 26, cy - 10, 52, 20], "hands": [CX - 50, 157, 100, 18], "port": [CX - 46, 141, 24, 16]},
            "face": {"brows": "angry", "mouth": "closed"}, "blink": [3.0, 6.0], "mouth_y": cy + 22,
            "attack": {"style": "fist", "hand": [138, 108], "tool": [38, 122], "head": [CX, cy - 18], "face": [CX, cy + 8]},
            "gestures": {"slam": "hands_react", "fist": "hands_fist"}}
    return p, meta


# ====================================================================== Vale
def vale():
    p = new_patient()
    skin, suit, hair = SKIN["vale"], CLOTH["suit"], CLOTH["black"]
    cy = 68
    body, head = p["body"], p["head"]
    yy, xx = body.grid()

    jm = torso(body, [(CX - 54, 136), (CX - 40, 120), (CX + 40, 120), (CX + 54, 136), (CX + 56, 162), (CX - 56, 162)], suit)
    finish(body, jm)
    # off-centre closure, buttons, pocket square and a company badge
    stroke(body, [(CX + 9, 122), (CX + 9, 159)], "ink0")
    stroke(body, [(CX + 10, 123), (CX + 10, 159)], suit[3])
    for by in (129, 141, 153):
        body.px(CX + 5, by, "steel5")
        body.px(CX + 5, by + 1, "steel2")
    for s in (-1, 1):
        stroke(body, [(CX + s * 30, 123), (CX + s * 46, 133)], suit[3])
    stroke(body, [(CX - 34, 139), (CX - 25, 139)], "paper3")
    stroke(body, [(CX - 34, 140), (CX - 27, 140)], "paper1")
    badge = body.rect(CX + 22, 137, CX + 34, 143)
    body.fill(badge, "steel1")
    stroke(body, [(CX + 24, 139), (CX + 32, 139)], "steel4")
    stroke(body, [(CX + 24, 141), (CX + 29, 141)], "amber")
    # the collar, buttoned to the jaw
    colm = body.rrect(CX - 13, 92, CX + 13, 121, 2)
    paint(body, colm, suit, round_px=5, bias=0.1)
    stroke(body, [(CX - 12, 92), (CX + 12, 92)], "paper3")
    stroke(body, [(CX - 12, 93), (CX + 12, 93)], "paper1")
    stroke(body, [(CX, 96), (CX, 120)], "ink0")
    for by in (104, 110, 116):
        body.px(CX + 2, by, "steel5")
    body.fill(body.edge(colm, 1, 0), P.RIM)
    body.outline(OUTLINE, colm)
    for dx, dy, colr in ((0, 0, "red2"), (-1, 1, "red2"), (0, 1, "red3"), (1, 1, "red1"), (0, 2, "red1")):
        body.px(CX - 7 + dx, 108 + dy, colr)

    for s in (-1, 1):
        ear = head.ell(CX + s * 24, cy + 3, 3.6, 6)
        paint(head, ear, skin, round_px=3)
        head.outline(OUTLINE, ear)
    hm = head_mask(head, CX, cy, 48, 64, jaw=0.8, chin=0.42)
    paint(head, hm, skin, round_px=13, round_amt=0.7)
    for s in (-1, 1):
        head.dither(hm & head.ell(CX + s * 15, cy + 15, 5, 8), skin[2], 0.5)
    head.fill(head.edge(hm, 1, 0), P.RIM)
    nose(head, CX, cy + 1, cy + 13, skin, w=2)
    head.outline(OUTLINE, hm)
    # combat optics: no whites, no lids. The lens is a hole; the emitter sits behind it.
    housings = head.none()
    for s in (-1, 1):
        ex = CX + s * 13
        hs = head.rrect(ex - 8, cy - 4, ex + 8, cy + 4, 2)
        housings |= grow(hs, 1)
        head.fill(hs, "steel1")
        stroke(head, [(ex - 6, cy - 4), (ex + 6, cy - 4)], "steel4")
        stroke(head, [(ex - 6, cy + 4), (ex + 6, cy + 4)], "steel0")
        head.outline("ink0", hs)
        stroke(head, [(ex + s * 9, cy), (CX + s * 23, cy - 1)], "steel1")
        lens = head.rrect(ex - 6, cy - 2, ex + 6, cy + 2, 1)
        body.fill(grow(lens, 2), "ink0")
        head.erase(lens)
        stroke(p["pupils"], [(ex - 3, cy), (ex + 3, cy)], "c9781e")
        stroke(p["pupils"], [(ex - 1, cy), (ex + 1, cy)], "warm6")
        p["pupils"].px(ex, cy, "warm7")
    stroke(head, [(CX - 4, cy), (CX + 4, cy)], "steel1")

    hmask = head.poly([(CX - 25, cy - 6), (CX - 25, cy - 22), (CX - 15, cy - 33), (CX + 6, cy - 37), (CX + 21, cy - 30),
                       (CX + 26, cy - 14), (CX + 25, cy - 5), (CX + 21, cy - 16), (CX + 4, cy - 21), (CX - 6, cy - 14),
                       (CX - 19, cy - 17)])
    hmask = smooth(hmask, 1)
    paint(head, hmask, hair, round_px=6, round_amt=0.6, contrast=1.0)
    stroke(head, [(CX - 15, cy - 26), (CX + 8, cy - 33)], hair[3])
    stroke(head, [(CX - 10, cy - 22), (CX + 14, cy - 27)], hair[2])
    stroke(head, [(CX - 2, cy - 30), (CX + 10, cy - 33)], hair[4])
    head.fill(head.edge(hmask, 1, 0), P.RIM)
    head.outline(OUTLINE, hmask)

    brows = brows_set(CX, cy, 13, "0e141c", width=2, lift=-1, span=7)
    mouths = mouth_frames(CX, cy + 22, skin, width=9, curve=0.5)

    def sleeves(c, spread=0, sides=(-1, 1)):
        for s in sides:
            sl = c.seg([(CX + s * 38, 145), (CX + s * (19 + spread), 158)], 13)
            paint(c, sl, suit, round_px=4)
            c.outline(OUTLINE, sl)
            cuff = c.seg([(CX + s * (20 + spread), 156), (CX + s * (15 + spread), 160)], 9)
            c.fill(cuff, "paper3")
            c.fill(c.edge(cuff, 0, 1), "paper1")
            c.outline(OUTLINE, cuff)

    for name in ("hands_a", "hands_b"):
        c = p[name]
        sleeves(c)
        m = c.rrect(CX - 15, 157, CX + 15, 169, 4)
        paint(c, m, skin, round_px=4, round_amt=0.5)
        for i in range(-3, 4):
            stroke(c, [(CX + i * 4, 159), (CX + i * 4, 167)], skin[2] if i % 2 else skin[1])
        stroke(c, [(CX - 12, 158), (CX + 12, 158)], skin[5])
        c.outline(OUTLINE, m)
    c = p["hands_react"]
    sleeves(c, spread=2)
    fist(c, CX - 13, 157, 20, skin, knuckle="white", h=12, side=1)
    hand_rest(c, CX + 13, 158, 17, skin, side=-1)
    p["hands_point"] = c = layer()                       # "Jaw set and voice hardened": a finger at you
    sleeves(c, sides=(1,))
    hand_rest(c, CX + 13, 158, 17, skin, side=-1)
    arm = c.seg([(CX - 44, 166), (CX - 30, 140)], 14)
    paint(c, arm, suit, round_px=4)
    c.outline(OUTLINE, arm)
    cuff = c.rrect(CX - 38, 133, CX - 22, 139, 2)
    c.fill(cuff, "paper3")
    c.fill(c.edge(cuff, 0, 1), "paper1")
    c.outline(OUTLINE, cuff)
    fist(c, CX - 26, 121, 18, skin, h=13, side=1)
    tip = c.rrect(CX - 25, 129, CX - 19, 141, 2)
    paint(c, tip, skin, round_px=3, bias=0.16)
    c.outline(OUTLINE, tip)

    # ---- the turn: what shows once he stops pretending
    face_skin = hm & ~hmask & ~housings

    def turn_face(bloody):
        t = layer()
        roots = [(CX - 11, 93, -1.75, 30), (CX - 5, 93, -1.45, 22), (CX + 6, 93, -1.6, 26), (CX + 12, 93, -1.3, 32),
                 (CX - 22, cy + 5, 0.9, 12), (CX + 22, cy + 5, 2.2, 12), (CX - 15, cy - 6, -1.9, 9), (CX + 15, cy - 6, -1.2, 9)]
        threads(t, face_skin, roots, seed=31)
        for s in (-1, 1):                                # optics down to pinpoints
            ex = CX + s * 13
            t.glow(t.all(), "red1", ex, cy, 12, amt=0.85)
            t.fill(t.rrect(ex - 6, cy - 2, ex + 6, cy + 2, 1), "red0")
            stroke(t, [(ex - 1, cy), (ex + 1, cy)], "red2")
            stroke(t, [(ex, cy - 1), (ex, cy + 1)], "red2")
            t.px(ex, cy, "white")
        if bloody:                                       # the housings weep
            blood_run(t, [(CX - 16, cy + 5), (CX - 17, cy + 12), (CX - 16, cy + 21)], wide=True)
            blood_run(t, [(CX - 10, cy + 5), (CX - 10, cy + 11)])
            blood_run(t, [(CX + 15, cy + 5), (CX + 16, cy + 15), (CX + 15, cy + 27)], wide=True)
            blood_run(t, [(CX + 9, cy + 5), (CX + 9, cy + 9)])
            blood_run(t, [(CX - 2, cy + 14), (CX - 2, cy + 18)], bead=False)
            blood_run(t, [(CX + 2, cy + 14), (CX + 2, cy + 17)], bead=False)
        return t

    p["turn"] = turn_face(True)
    p["turn_clean"] = turn_face(False)
    for tag, bloody in (("", True), ("_clean", False)):
        p["mouth_turn" + tag] = rictus(CX, cy + 22, skin, hw=9, gape=0, bloody=bloody)
        p["mouth_turn_b" + tag] = rictus(CX, cy + 22, skin, hw=9, gape=4, bloody=bloody)

    def saw_arm(c, elbow, wrist, hub, r, phase, show_fist=True):
        (ax, ay), (bx, by), (hx, hy) = elbow, wrist, hub
        arm = c.seg([elbow, wrist], 15)
        paint(c, arm, suit, round_px=4)
        c.outline(OUTLINE, arm)
        # the sleeve has split along the forearm; the casing under it stands open and lit
        slot = c.seg([(ax + (bx - ax) * 0.2, ay + (by - ay) * 0.2), wrist], 5) & arm
        c.fill((grow(slot, 1) & ~slot) & arm, "steel4")
        c.fill(slot, "ink0")
        for t_ in (0.35, 0.55, 0.75, 0.92):
            x, y = int(ax + (bx - ax) * t_), int(ay + (by - ay) * t_)
            c.px(x, y, "red2")
            c.px(x + 1, y, "red3")
        for s in (-1, 1):                                # what is left of the cuff
            flap = c.poly([(bx + s * 4, by + 2), (bx + s * 11, by - 3), (bx + s * 9, by + 5)])
            c.fill(flap, "paper3")
            c.outline(OUTLINE, flap)
        if show_fist:
            fist(c, int(bx), int(by) - 13, 20, skin, knuckle="white", h=13, side=1)
        for s in (-1, 1):                                # the yoke that carries the disc
            prong = c.seg([(bx + s * 5, by - 2), (hx + s * 4, hy)], 3)
            c.fill(prong, "steel2")
            c.fill(c.edge(prong, -1, 0) & prong, "steel4")
            c.outline("ink0", prong)
        saw_disc(c, hx, hy, r, phase)

    def free_hand(c, flat, wet=True):
        if flat:
            sl = c.seg([(CX + 52, 170), (140, 132)], 15)
            paint(c, sl, suit, round_px=4)
            c.outline(OUTLINE, sl)
            cuff = c.rrect(131, 125, 148, 131, 2)
            c.fill(cuff, "paper3")
            c.outline(OUTLINE, cuff)
            palm_flat(c, 138, 109, 25, skin, side=-1, h=15, wet=wet)
        else:
            sl = c.seg([(CX + 44, 168), (CX + 36, 142)], 14)
            paint(c, sl, suit, round_px=4)
            c.outline(OUTLINE, sl)
            cuff = c.rrect(CX + 28, 136, CX + 44, 141, 2)
            c.fill(cuff, "paper3")
            c.outline(OUTLINE, cuff)
            palm_up(c, CX + 36, 122, 21, skin, side=-1, h=13)

    for tag, phase in (("", 0.0), ("_b", 0.5)):
        a = layer()                                      # wind-up
        saw_arm(a, (CX - 50, 170), (CX - 42, 132), (CX - 40, 104), 14, phase)
        free_hand(a, False)
        p["attack" + tag] = a
        for clean, wet in (("", True), ("_clean", False)):
            a = layer()                                  # first blow: the palm
            saw_arm(a, (CX - 50, 170), (CX - 42, 132), (CX - 40, 104), 14, phase + 0.25)
            free_hand(a, True, wet)
            p["attack_s1" + tag + clean] = a
            a = layer()                                  # second blow: the saw goes to the glass
            saw_arm(a, (CX - 44, 170), (39, 139), (32, 114), 18, phase, show_fist=False)
            free_hand(a, True, wet)
            p["attack_s2" + tag + clean] = a

    p["hands_slam"] = c = layer()                        # "Cold anger, face and voice. A palm on glass."
    sleeves(c, sides=(-1,))
    hand_rest(c, CX - 13, 158, 17, skin, side=1)
    free_hand(c, True, wet=False)

    p.update({"brows_" + k: v for k, v in brows.items()})
    p.update({"mouth_" + k: v for k, v in mouths.items()})
    meta = {"zones": {"eyes": [CX - 24, cy - 9, 48, 18], "hands": [CX - 42, 150, 84, 23], "port": [CX - 14, 98, 28, 24]},
            "face": {"brows": "neutral", "mouth": "closed"}, "blink": None, "mouth_y": cy + 22,
            "attack": {"style": "saw", "hand": [138, 108], "tool": [32, 114], "head": [CX, cy - 16], "face": [CX, cy + 8]},
            "gestures": {"point": "hands_point", "fist": "hands_react", "slam": "hands_slam"}}
    return p, meta


# ====================================================================== Juno
HEART = [".#.#.", "#####", "#####", ".###.", "..#.."]
NOTE = ["..###", "..#.#", "..#..", "###..", "###.."]
SQUINT_L = ["#....", ".##..", "...##", ".##..", "#...."]
SQUINT_R = [r[::-1] for r in SQUINT_L]


def juno():
    p = new_patient()
    skin, hair, chrome = SKIN["juno"], CLOTH["violet"], CLOTH["chrome"]
    cy = 76
    body, head = p["body"], p["head"]
    yy, xx = body.grid()

    jm = torso(body, [(CX - 48, 142), (CX - 34, 123), (CX + 34, 123), (CX + 48, 142), (CX + 50, 162), (CX - 50, 162)], CLOTH["leather"])
    top = body.poly([(CX - 15, 121), (CX + 15, 121), (CX + 9, 162), (CX - 9, 162)]) & (yy < BASE_Y)
    for i, colr in enumerate(("cyan0", "cyan1", "cyan2", "cyan1")):
        body.fill(top & ((yy // 2) % 4 == i), colr)
    body.dither(top, "mag1", np.clip((xx - CX + 2) / 24.0, 0, 0.6))
    finish(body, jm)
    for bx, by in ((35, 139), (39, 133), (43, 127)):
        spike = body.poly([(bx - 3, by + 2), (bx + 3, by - 4), (bx - 7, by - 10)])
        paint(body, spike, chrome, round_px=2, bias=0.12)
        body.outline(OUTLINE, spike)
    for s in (-1, 1):
        lap = body.poly([(CX + s * 14, 120), (CX + s * 31, 125), (CX + s * 21, 150), (CX + s * 8, 162)]) & (yy < BASE_Y)
        paint(body, lap, CLOTH["leather"], round_px=4, bias=0.16 if s < 0 else 0.04)
        body.outline(OUTLINE, lap)
        for t in (0.15, 0.4, 0.65, 0.9):
            body.px(int(CX + s * (29 - 9 * t)), int(127 + 24 * t), "steel5")
    # neck: voice box grille on her right, four jacks on her left, scars and a cable burn
    nk = neck(body, CX - 9, CX + 9, 100, 126, skin, shadow=7)
    vb = body.rrect(CX - 7, 109, CX - 2, 119, 1)
    body.fill(vb, "steel1")
    for gy in (111, 113, 115, 117):
        stroke(body, [(CX - 6, gy), (CX - 3, gy)], "steel4")
    body.px(CX - 5, 118, "cyan2")
    body.outline("ink0", vb)
    jacks = body.none()
    for i in range(4):
        y = 108 + i * 4
        jacks |= body.rect(CX + 4, y, CX + 6, y + 2)
        body.fill(body.rect(CX + 4, y, CX + 6, y + 2), "steel4")
        body.px(CX + 5, y + 1, "ink0")
    stroke(body, [(CX + 1, 108), (CX + 2, 122)], skin[5])
    stroke(body, [(CX + 7, 110), (CX + 8, 115)], skin[5])
    for dx, dy in ((7, 118), (8, 119), (7, 120), (8, 121), (6, 121)):
        body.px(CX + dx, dy, "7a4630")
    body.px(CX + 7, 119, "4a2a22")
    body.outline(OUTLINE, nk & (yy < 121))

    for s in (-1, 1):
        ear = head.ell(CX + s * 25, cy + 3, 3.6, 5.6)
        paint(head, ear, skin, round_px=3)
        head.outline(OUTLINE, ear)
    hm = head_mask(head, CX, cy, 50, 56, jaw=0.8, chin=0.44)
    paint(head, hm, skin, round_px=13, round_amt=0.7)
    head.dither(hm & (xx > CX + 9) & (yy < cy - 9), hair[1], 0.55)
    jawm = hm & head.poly([(CX - 32, cy + 4), (CX - 9, cy + 13), (CX + 9, cy + 13), (CX + 32, cy + 4), (CX + 32, cy + 44), (CX - 32, cy + 44)])
    paint(head, jawm, chrome, round_px=6, round_amt=0.6, bias=-0.04)
    stroke(head, [(CX - 26, cy + 6), (CX - 9, cy + 13), (CX + 9, cy + 13), (CX + 26, cy + 6)], "ink1")
    head.px(CX - 20, cy + 12, "white")
    head.px(CX + 20, cy + 12, "steel5")
    stroke(head, [(CX, cy + 25), (CX, cy + 28)], chrome[1])
    head.fill(head.edge(hm, 1, 0), P.RIM)
    nose(head, CX, cy + 1, cy + 9, skin, w=2)
    head.outline(OUTLINE, hm)
    ring = head.ell(CX + 27, cy + 13, 5, 6) & ~head.ell(CX + 27, cy + 13, 3.4, 4.4)
    head.fill(ring, "d4a040")
    head.px(CX + 24, cy + 10, "f4d880")
    head.outline(OUTLINE, ring)
    head.px(CX + 26, cy + 1, "steel5")
    head.px(CX + 26, cy + 4, "cyan2")
    # display eyes: the screens are holes, the glyphs sit behind them
    housings = head.none()
    for s in (-1, 1):
        ex = CX + s * 13
        hs = head.rrect(ex - 8, cy - 5, ex + 8, cy + 5, 2)
        housings |= grow(hs, 1)
        head.fill(hs, "steel1")
        stroke(head, [(ex - 6, cy - 5), (ex + 6, cy - 5)], "steel4")
        stroke(head, [(ex - 6, cy + 5), (ex + 6, cy + 5)], "steel0")
        head.outline("ink0", hs)
        scr = head.rrect(ex - 6, cy - 3, ex + 6, cy + 3, 1)
        body.fill(grow(scr, 2), "0a2e34")
        head.erase(scr)
        glyph(p["pupils"], ex, cy, HEART, "cyan3", "cyan2")
        glyph(p.setdefault("pupils_b", layer()), ex, cy, NOTE, "cyan3", "cyan2")
        r = p.setdefault("pupils_react", layer())
        r.fill(grow(scr, 2), "cyan3")
        glyph(r, ex, cy, SQUINT_L if s < 0 else SQUINT_R, "14484f")
        p["lids"].fill(scr, "0a2e34")
        stroke(p["lids"], [(ex - 4, cy), (ex + 4, cy)], "cyan1")

    # big violet hair swept to her right, the other side shaved
    hmask = head.ell(CX - 10, cy - 27, 26, 20) & (yy < cy - 14)
    hmask |= head.poly([(CX - 36, cy - 16), (CX - 44, cy - 42), (CX - 26, cy - 58), (CX + 2, cy - 56), (CX + 16, cy - 44), (CX + 12, cy - 24)])
    hmask |= head.poly([(CX - 37, cy - 28), (CX - 40, cy + 10), (CX - 32, cy + 22), (CX - 25, cy + 4), (CX - 25, cy - 14)])
    hmask |= head.poly([(CX + 14, cy - 28), (CX - 20, cy - 9), (CX - 28, cy - 24)])
    hmask = smooth(hmask, 2)
    paint(head, hmask, hair, round_px=10, round_amt=0.8, contrast=1.1)
    for a, b in (((CX - 32, cy - 30), (CX - 20, cy - 52)), ((CX - 24, cy - 24), (CX - 8, cy - 50)),
                 ((CX - 12, cy - 20), (CX + 8, cy - 44)), ((CX - 35, cy - 8), (CX - 34, cy + 10))):
        stroke(head, [a, b], hair[4])
    stroke(head, [(CX - 28, cy - 34), (CX - 18, cy - 54)], hair[5])
    head.dither(hmask & (yy < cy - 40), "mag2", np.clip((cy - 38 - yy) / 14.0, 0, 0.8))
    head.dither(hmask & (yy > cy + 8), "mag2", 0.6)
    head.fill(head.edge(hmask, 1, 0), P.RIM)
    head.outline(OUTLINE, hmask)

    brows = brows_set(CX, cy, 13, hair[0], width=2, lift=1, span=7)
    mouths = mouth_frames(CX, cy + 20, chrome, width=9, curve=0.8, lip="a02a5e")

    def chrome_hand(c, i, lifted=()):
        x = CX + (-24 if i == 0 else 24)
        sl = sleeve(c, x, 144, 155, 16, CLOTH["leather"])
        c.outline(OUTLINE, sl)
        c.px(x - 5, 153, "steel5")
        c.px(x + 5, 153, "steel5")
        hand_rest(c, x, 156, 17, chrome, lifted=lifted, side=1 if i == 0 else -1, seams=chrome[1], h=14)

    for name, lf in (("hands_a", ()), ("hands_b", (2, 3))):
        chrome_hand(p[name], 0)
        chrome_hand(p[name], 1, lifted=lf)
    c = p["hands_react"]
    chrome_hand(c, 0)
    arm = c.seg([(CX + 44, 166), (CX + 30, 140)], 14)
    paint(c, arm, CLOTH["leather"], round_px=4)
    c.outline(OUTLINE, arm)
    fist(c, CX + 26, 124, 20, chrome, h=14, side=-1)
    tip = c.rrect(CX + 19, 132, CX + 25, 144, 2)
    paint(c, tip, chrome, round_px=3, bias=0.16)
    c.px(CX + 21, 141, "white")
    c.outline(OUTLINE, tip)

    def leather_arm(c, a, b, w):
        arm = c.seg([a, b], w)
        paint(c, arm, CLOTH["leather"], round_px=4)
        c.outline(OUTLINE, arm)

    def raised(c, x, y, side, ln, glint):
        """A DEFT hand raised, palm out, the picks snapped out of the fingers (ln 0: none)."""
        leather_arm(c, (x - side * 10, 170), (x, y + 8), 14)
        palm_up(c, x, y, 19, chrome, side=side, h=12)
        if ln:
            picks(c, up_fingers(x, y, 19, side), ln, glint)

    def on_glass(c, elbow, x, y, w, h, side, ln, glint):
        """A DEFT hand flat on the glass, picks out along the fingers (ln 0: none)."""
        leather_arm(c, elbow, (x + side * 2, y + h - 2), 15)
        palm_flat(c, x, y, w, chrome, side=side, h=h)
        if ln:
            picks(c, flat_fingers(x, y, w, side), ln, glint)

    p["hands_slam"] = c = layer()                        # "Slapped the glass, face and voice at once."
    chrome_hand(c, 0)
    on_glass(c, (CX + 52, 170), 138, 109, 25, 15, -1, 0, 0.5)

    # ---- the turn: the IRIS screens go white and the DEFT fingers snap out into picks
    face_skin = (hm & ~jawm & ~hmask & ~housings) | (nk & ~hm & ~grow(vb, 1) & ~jacks & (yy < 121))

    def turn_face(bloody):
        t = layer()
        roots = [(CX + 5, 110, -1.75, 22), (CX + 5, 114, -1.35, 18), (CX + 5, 118, -2.3, 16), (CX + 5, 121, 2.6, 10),
                 (CX + 20, cy + 2, -1.6, 10), (CX - 20, cy + 2, -1.5, 10), (CX + 16, cy - 9, -1.2, 8), (CX - 16, cy - 9, -1.9, 8)]
        threads(t, face_skin, roots, seed=61)
        for s in (-1, 1):
            ex = CX + s * 13
            scr = t.rrect(ex - 6, cy - 3, ex + 6, cy + 3, 1)
            t.glow(t.all(), "cyan3", ex, cy, 11, amt=0.6)
            t.fill(grow(scr, 1), "cyan3")
            t.fill(scr, "white")
            stroke(t, [(ex - 5, cy + 1), (ex + 5, cy + 1)], "c8fff6")
        if bloody:                                       # the scars by the jacks open
            blood_run(t, [(CX + 7, 110), (CX + 8, 116)])
            blood_run(t, [(CX + 7, 118), (CX + 7, 121), (CX + 8, 125)], wide=True)
            blood_run(t, [(CX - 1, cy + 10), (CX - 1, cy + 12)], bead=False)
        return t

    p["turn"] = turn_face(True)
    p["turn_clean"] = turn_face(False)
    for tag, bloody in (("", True), ("_clean", False)):
        p["mouth_turn" + tag] = rictus(CX, cy + 20, chrome, hw=8, gape=4, bloody=bloody, teeth="steel5")
        p["mouth_turn_b" + tag] = rictus(CX, cy + 20, chrome, hw=8, gape=1, bloody=bloody, teeth="steel5")

    for tag, k in (("", 0), ("_b", 1)):
        g = (0.3, 0.75)[k]
        a = layer()                                      # wind-up: both hands up, picks out
        raised(a, CX - 40, 120 - k, 1, 16, g)
        raised(a, CX + 36, 122 + k, -1, 14, 1.0 - g)
        p["attack" + tag] = a
        for clean in ("", "_clean"):                     # her hands are chrome: nothing on them to clean
            a = layer()                                  # first blow: the left hand and its picks on the glass
            raised(a, CX - 40, 119 + k, 1, 16, 1.0 - g)
            on_glass(a, (CX + 52, 170), 138, 109 - k, 25, 15, -1, 12, g)
            p["attack_s1" + tag + clean] = a
            a = layer()                                  # second blow: the right one rakes the glass too
            on_glass(a, (CX - 44, 172), 42 - k, 130, 24, 14, 1, 14, g)
            on_glass(a, (CX + 52, 170), 138, 109, 25, 15, -1, 12, 1.0 - g)
            p["attack_s2" + tag + clean] = a

    # dark threads out from the jacks, for a night the port is the sign
    p["body_t"] = twin(body, nk & ~grow(vb, 1) & ~grow(jacks, 1) & (yy < 121),
                       [(CX + 5, 109, 3.1, 9), (CX + 5, 113, 2.7, 9), (CX + 5, 117, -2.6, 9), (CX + 7, 112, -0.6, 5),
                        (CX + 6, 121, 2.0, 6), (CX + 5, 108, -1.8, 6)], seed=67)

    p.update({"brows_" + k: v for k, v in brows.items()})
    p.update({"mouth_" + k: v for k, v in mouths.items()})
    meta = {"zones": {"eyes": [CX - 24, cy - 9, 48, 18], "hands": [CX - 40, 156, 80, 18], "port": [CX - 12, 104, 24, 20]},
            "face": {"brows": "neutral", "mouth": "closed"}, "blink": [2.0, 4.5], "mouth_y": cy + 20,
            "attack": {"style": "picks", "hand": [138, 104], "tool": [40, 106], "head": [CX, cy - 20], "face": [CX, cy + 8]},
            "gestures": {"point": "hands_react", "slam": "hands_slam"}}
    return p, meta


# ====================================================================== Maren
def maren():
    p = new_patient()
    skin, hair, chrome = SKIN["maren"], CLOTH["grey"], CLOTH["chrome"]
    cy = 82
    body, head = p["body"], p["head"]
    yy, xx = body.grid()

    jm = torso(body, [(CX - 60, 142), (CX - 44, 122), (CX + 44, 122), (CX + 60, 142), (CX + 62, 162), (CX - 62, 162)], CLOTH["canvas"])
    und = body.poly([(CX - 12, 119), (CX + 12, 119), (CX, 136)])
    paint(body, und, CLOTH["thermal"], round_px=3)
    bib = body.rect(CX - 20, 138, CX + 20, 162) & (yy < BASE_Y)
    paint(body, bib, CLOTH["apron"], round_px=6)
    for s in (-1, 1):
        st = body.seg([(CX + s * 19, 138), (CX + s * 30, 122)], 4) & jm
        paint(body, st, CLOTH["apron"], round_px=2)
        body.px(CX + s * 18, 140, "d4a040")
    stroke(body, [(CX + 11, 143), (CX + 11, 133)], "e2c58a")
    body.px(CX + 11, 132, "ink0")
    body.outline(OUTLINE, bib)
    # steel shoulder guard on the welding arm (her right)
    pad = body.poly([(CX - 63, 141), (CX - 45, 121), (CX - 29, 125), (CX - 34, 146), (CX - 63, 153)]) & (yy < BASE_Y)
    paint(body, pad, chrome, round_px=5, bias=-0.06)
    stroke(body, [(CX - 56, 137), (CX - 34, 132)], chrome[1])
    stroke(body, [(CX - 59, 146), (CX - 35, 140)], chrome[1])
    body.px(CX - 42, 127, "white")
    body.px(CX - 37, 143, "steel5")
    finish(body, jm | pad)
    body.outline(OUTLINE, pad)
    for s in (-1, 1):
        flap = body.poly([(CX + s * 10, 117), (CX + s * 25, 122), (CX + s * 18, 133), (CX + s * 8, 127)])
        paint(body, flap, CLOTH["canvas"], round_px=4, bias=0.12 if s < 0 else 0.0)
        body.outline(OUTLINE, flap)
    nk = neck(body, CX - 9, CX + 9, 108, 121, skin, shadow=6)
    body.outline(OUTLINE, nk & (yy < 116))

    for s in (-1, 1):
        ear = head.ell(CX + s * 27, cy + 3, 4, 6)
        paint(head, ear, skin, round_px=3)
        head.outline(OUTLINE, ear)
    hm = head_mask(head, CX, cy, 54, 58, jaw=0.9, chin=0.54)
    paint(head, hm, skin, round_px=13, round_amt=0.7)
    for s in (-1, 1):
        head.dither(hm & head.ell(CX + s * 15, cy + 8, 9, 5), "c8705e", 0.4)
        head.dither(hm & head.ell(CX + s * 23, cy - 2, 4, 6), "c8705e", 0.4)
        stroke(head, [(CX + s * 18, cy + 6), (CX + s * 9, cy + 7)], skin[2])
        stroke(head, [(CX + s * 7, cy + 14), (CX + s * 10, cy + 21)], skin[2])
        stroke(head, [(CX + s * 22, cy - 1), (CX + s * 25, cy - 3)], skin[2])
    head.fill(head.edge(hm, 1, 0), P.RIM)
    nose(head, CX, cy + 2, cy + 12, skin, w=3)
    head.outline(OUTLINE, hm)
    holes = [almond(head, CX + s * 13, cy + 1, 6.6, 3.7) for s in (-1, 1)]
    eye_whites(body, holes)
    for i, hmk in enumerate(holes):
        s = -1 if i == 0 else 1
        head.erase(hmk)
        lid_lines(head, hmk, skin, lash=2)
        natural_pupil(p["pupils"], CX + s * 13, cy + 1, ("2c3a26", "7a9460"), r=3.0)
        blink(p["lids"], hmk, skin)

    hmask = head.ell(CX, cy - 17, 28.5, 18) & (yy < cy - 13)
    hmask |= head.ell(CX + 9, cy - 39, 11, 9)
    for s in (-1, 1):
        hmask |= head.poly([(CX + s * 27, cy - 14), (CX + s * 29, cy + 1), (CX + s * 24, cy - 8)])
    hmask = smooth(hmask, 1)
    paint(head, hmask, hair, round_px=8, round_amt=0.7)
    for a, b in (((CX - 16, cy - 30), (CX - 22, cy - 20)), ((CX + 14, cy - 31), (CX + 21, cy - 22)), ((CX + 4, cy - 44), (CX + 13, cy - 44))):
        stroke(head, [a, b], hair[4])
    head.fill(head.edge(hmask, 1, 0), P.RIM)
    head.outline(OUTLINE, hmask)
    # welding goggles pushed up on the forehead
    strap = head.rect(CX - 28, cy - 23, CX + 28, cy - 19) & (hmask | hm)
    head.fill(strap, CLOTH["apron"][1])
    head.fill(strap & (yy == cy - 23), CLOTH["apron"][3])
    for s in (-1, 1):
        gx, gy = CX + s * 11, cy - 22
        rim_ = head.ell(gx, gy, 8.4, 7.4)
        paint(head, rim_, chrome, round_px=3)
        glass = head.ell(gx, gy, 5.6, 4.8)
        head.fill(glass, "0e2418")
        head.dither(glass, "1f4a2c", 0.5)
        stroke(head, [(gx - 3, gy - 2), (gx - 1, gy - 3)], "8fe07a")
        head.outline(OUTLINE, rim_)
    stroke(head, [(CX - 3, cy - 23), (CX + 3, cy - 23)], "steel2")

    brows = brows_set(CX, cy + 1, 13, "4a5458", width=2, lift=0, span=7)
    mouths = mouth_frames(CX, cy + 21, skin, width=9, curve=0.4)

    def torch_hand(c, x, y):
        arm = c.rrect(x - 10, y - 15, x + 10, y + 1, 3)
        paint(c, arm, chrome, round_px=5, bias=-0.08)
        stroke(c, [(x - 9, y - 9), (x + 9, y - 9)], chrome[1])
        stroke(c, [(x - 9, y - 4), (x + 9, y - 4)], chrome[1])
        c.px(x - 7, y - 12, "white")
        c.px(x + 7, y - 7, "steel0")
        c.outline(OUTLINE, arm)
        hand_rest(c, x, y, 21, GAUNTLET, side=1, seams=GAUNTLET[1], h=14)
        tube = c.rrect(x - 3, y - 6, x + 3, y + 8, 2)
        paint(c, tube, chrome, round_px=2, bias=-0.1)
        c.outline(OUTLINE, tube)
        c.fill(c.ell(x, y + 7, 2.4, 2), "ink0")
        c.px(x, y + 7, "cyan1")

    def glove_cuff(c, x, y=142):
        cuff = c.rrect(x - 10, y, x + 10, y + 16, 3)
        paint(c, cuff, GLOVE, round_px=5)
        stroke(c, [(x - 8, y + 4), (x + 8, y + 4)], GLOVE[1])
        stroke(c, [(x - 8, y + 5), (x + 8, y + 5)], GLOVE[4])
        c.outline(OUTLINE, cuff)

    for name, closed in (("hands_a", False), ("hands_b", True)):
        c = p[name]
        torch_hand(c, CX - 30, 157)
        glove_cuff(c, CX + 30)
        if closed:
            fist(c, CX + 30, 158, 21, GLOVE, knuckle=GLOVE[4], h=12, side=-1)
        else:
            hand_rest(c, CX + 30, 158, 21, GLOVE, side=-1, seams=GLOVE[1], h=14)
    c = p["hands_react"]
    torch_hand(c, CX - 30, 155)
    glove_cuff(c, CX + 30, 140)
    hand_rest(c, CX + 30, 156, 21, GLOVE, lifted=(0, 1, 2, 3), side=-1, seams=GLOVE[1], h=14)

    # ---- the turn: her arm decides, and she watches it happen
    face_skin = (hm | body.rect(CX - 9, 108, CX + 9, 121)) & ~hmask & (yy > cy - 12)

    def turn_face(bloody):
        t = layer()
        ty, tx = t.grid()
        roots = [(CX - 6, 121, -1.7, 34), (CX + 1, 121, -1.5, 26), (CX + 7, 121, -1.35, 36),
                 (CX - 25, cy + 5, 0.5, 12), (CX + 25, cy + 5, 2.6, 12), (CX - 21, cy - 5, 1.2, 8), (CX + 21, cy - 5, 1.9, 8)]
        threads(t, face_skin, roots, seed=47)
        for s in (-1, 1):                                # eyes forced wide, pupils shrunk to dots
            ex, ey = CX + s * 13, cy + 1
            wide = almond(t, ex, ey, 8.0, 5.4)
            t.fill(grow(wide, 1), OUTLINE)
            t.fill(wide, "paper3")
            t.fill(wide & (ty <= ey - 4), "paper1")
            for dx, dy in ((-6, 0), (-5, 1), (6, 1), (5, -1), (-4, -2)):
                t.px(ex + s * dx, ey + dy, "red2" if bloody else "c8705e")
            t.fill(t.ell(ex, ey, 2.3, 2.3), "2c3a26")
            t.fill(t.ell(ex, ey, 1.1, 1.1), "ink0")
            t.px(ex - 1, ey - 1, "white")
            t.fill((grow(wide, 1) & ~wide) & (ty > ey + 1), "red1" if bloody else skin[1])
            stroke(t, [(ex + s * 5, cy + 7), (ex + s * 6, cy + 15)], "dbe6e0")       # tears
            t.px(ex + s * 6, cy + 16, "white")
        if bloody:
            for s in (-1, 1):
                ex = CX + s * 13
                blood_run(t, [(ex - s * 2, cy + 7), (ex - s * 3, cy + 13), (ex - s * 2, cy + 19)], wide=(s < 0))
                blood_run(t, [(ex + s * 1, cy + 7), (ex + s * 1, cy + 11)])
            blood_run(t, [(CX - 2, cy + 14), (CX - 2, cy + 17)], bead=False)
            blood_run(t, [(CX + 3, cy + 14), (CX + 3, cy + 17)], bead=False)
        return t

    p["turn"] = turn_face(True)
    p["turn_clean"] = turn_face(False)
    for tag, bloody in (("", True), ("_clean", False)):
        p["mouth_turn" + tag] = rictus(CX, cy + 21, skin, hw=7, gape=5, bloody=bloody)
        p["mouth_turn_b" + tag] = rictus(CX, cy + 21, skin, hw=7, gape=2, bloody=bloody)

    def torch_arm(c, elbow, block, flare, big, phase):
        (bx, by), (fx, fy) = block, flare
        arm = c.seg([elbow, (bx, by + 10)], 18)
        paint(c, arm, chrome, round_px=5, bias=-0.06)
        c.outline(OUTLINE, arm)
        hw = 14 if big else 12
        blk = c.rrect(bx - hw, by - hw, bx + hw, by + hw, 4)
        paint(c, blk, GAUNTLET, round_px=5)
        c.outline(OUTLINE, blk)
        r = 30 if big else 24
        c.glow(c.all(), "cyan1", fx, fy, r, amt=0.9)
        c.glow(c.all(), "cyan2", fx, fy, r * 0.6, amt=1.0)
        rng = np.random.default_rng(11 + int(phase * 10) + (5 if big else 0))
        n = 9 if big else 7
        for i in range(n):                               # the flare spits
            ang = 2 * np.pi * (i + phase) / n + rng.uniform(-0.2, 0.2)
            ln = rng.uniform(0.5, 1.0) * r * 0.8
            stroke(c, [(fx, fy), (fx + np.cos(ang) * ln, fy + np.sin(ang) * ln)], "cyan3")
            stroke(c, [(fx, fy), (fx + np.cos(ang) * ln * 0.5, fy + np.sin(ang) * ln * 0.5)], "white")
        core = 8 if big else 7
        c.fill(c.ell(fx, fy, core, core), "cyan3")
        c.fill(c.ell(fx, fy, core - 3, core - 3), "white")
        for _ in range(8):
            ang, d = rng.uniform(0, 2 * np.pi), rng.uniform(r * 0.5, r)
            c.px(int(fx + np.cos(ang) * d), int(fy + np.sin(ang) * d), "white")

    def free_hand(c, flat, wet=True):
        if flat:
            gl = c.seg([(CX + 54, 170), (140, 136)], 16)
            paint(c, gl, CLOTH["canvas"], round_px=5)
            c.outline(OUTLINE, gl)
            glove_cuff(c, 138, 123)
            palm_flat(c, 138, 109, 25, GLOVE, side=-1, h=15, wet=wet)
        else:
            gl = c.seg([(CX + 46, 166), (CX + 36, 142)], 16)
            paint(c, gl, CLOTH["canvas"], round_px=5)
            c.outline(OUTLINE, gl)
            glove_cuff(c, CX + 34, 126)
            palm_up(c, CX + 34, 114, 21, GLOVE, side=1, h=13)

    for tag, phase in (("", 0.0), ("_b", 0.5)):
        a = layer()                                      # the hands rise before she does
        torch_arm(a, (CX - 50, 166), (CX - 32, 116), (CX - 32, 112), False, phase)
        free_hand(a, False)
        p["attack" + tag] = a
        for clean, wet in (("", True), ("_clean", False)):
            a = layer()                                  # first blow: the glove
            torch_arm(a, (CX - 50, 166), (CX - 32, 116), (CX - 32, 112), False, phase + 0.25)
            free_hand(a, True, wet)
            p["attack_s1" + tag + clean] = a
            a = layer()                                  # second blow: the torch against the glass
            torch_arm(a, (CX - 46, 170), (34, 118), (32, 114), True, phase)
            free_hand(a, True, wet)
            p["attack_s2" + tag + clean] = a

    p["hands_slam"] = c = layer()                        # "Slapped the glass, hurt, then sorry."
    torch_hand(c, CX - 30, 157)
    free_hand(c, True, wet=False)

    p.update({"brows_" + k: v for k, v in brows.items()})
    p.update({"mouth_" + k: v for k, v in mouths.items()})
    meta = {"zones": {"eyes": [CX - 26, cy - 8, 52, 18], "hands": [CX - 44, 157, 88, 18], "port": [CX + 18, 141, 24, 16]},
            "face": {"brows": "neutral", "mouth": "closed"}, "blink": [3.0, 6.0], "mouth_y": cy + 21,
            "attack": {"style": "torch", "hand": [138, 108], "tool": [32, 114], "head": [CX, cy - 22], "face": [CX, cy + 8]},
            "gestures": {"raise": "hands_react", "freeze": "hands_a", "slam": "hands_slam"}}
    return p, meta


# ====================================================================== shared by the second five
def ring_optic(head, ox, oy):
    """The chrome ring of a round optic, drawn on the head so it stays put when the gaze moves.
    Returns the mask it covers."""
    head.fill(head.ell(ox, oy, 8.6, 8.6), OUTLINE)
    paint(head, head.ell(ox, oy, 7.6, 7.6), CLOTH["chrome"], round_px=3, bias=-0.05)
    head.fill(head.ell(ox, oy, 5.2, 5.2), "ink0")
    head.px(ox - 9, oy - 5, "steel2")
    head.px(ox + 9, oy + 5, "steel2")
    return head.ell(ox, oy, 9.6, 9.6)


def needle(c, base, tip, under=None):
    """One LANCET finger: a steel needle from base to tip, thick at the knuckle, fine at the point."""
    (bx, by), (tx, ty) = base, tip
    mx, my = bx + (tx - bx) * 0.45, by + (ty - by) * 0.45
    m = c.seg([(bx, by), (mx, my)], 2) | c.seg([(bx, by), (tx, ty)], 1)
    ring = grow(m, 1) & ~m
    if under is not None:
        ring &= ~under
    c.fill(ring, OUTLINE)
    c.fill(m, "steel3")
    c.fill(c.seg([(bx, by), (mx, my)], 1), "steel5")
    c.px(tx, ty, "white")
    return m


def crackle(c, x, y, r, n, seed, cols=("cyan3", "white")):
    """Electric arcs off a live point: n jagged lines out to about r."""
    rng = np.random.default_rng(seed)
    for i in range(n):
        a = 2 * np.pi * i / n + rng.uniform(-0.4, 0.4)
        pts = [(x, y)]
        d, ln = 0.0, rng.uniform(0.55, 1.0) * r
        px_, py_ = x, y
        while d < ln:
            step = rng.uniform(2.0, 3.5)
            a2 = a + rng.uniform(-0.9, 0.9)
            px_, py_ = px_ + np.cos(a2) * step, py_ + np.sin(a2) * step
            pts.append((px_, py_))
            d += step
        stroke(c, pts, cols[0])
        stroke(c, pts[:max(2, len(pts) // 2)], cols[1])


def cone(c, bx, by, tx, ty, r):
    """A steel spike from a base of radius r at (bx, by) to a point at (tx, ty), lit by the lamp."""
    yy, xx = c.grid()
    m = c.none()
    for t in np.linspace(0.0, 1.0, 14):
        m |= c.ell(bx + (tx - bx) * t, by + (ty - by) * t, r * (1 - t) + 0.3, r * (1 - t) + 0.3)
    dx, dy = tx - bx, ty - by
    ln = max(1e-6, float(np.hypot(dx, dy)))
    nx, ny = -dy / ln, dx / ln
    lit = ((xx - bx) * nx + (yy - by) * ny) / max(r, 1e-6) * np.sign(nx * -0.75 + ny * 0.5 + 1e-6)
    c.fill(grow(m, 1), "ink0")
    c.fill(m, "steel3")
    c.fill(m & (lit > 0.2), "steel4")
    c.fill(m & (lit > 0.55), "steel5")
    c.fill(m & (lit < -0.45), "steel2")
    c.px(tx, ty, "white")
    return m


def wide_eye(t, ex, ey, iris, bloody, skin, rx=8.0, ry=5.4, pupil=1.0):
    """A natural eye forced wide in the turn: all white, the pupil shrunk to a point."""
    ty, tx = t.grid()
    wide = almond(t, ex, ey, rx, ry)
    t.fill(grow(wide, 1), OUTLINE)
    t.fill(wide, "paper3")
    t.fill(wide & (ty <= ey - ry + 1.4), "paper1")
    for dx, dy in ((-6, 0), (-5, 1), (6, 1), (5, -1)):
        t.px(ex + dx, ey + dy, "red2" if bloody else skin[3])
    t.fill(t.ell(ex, ey, 2.3, 2.3), iris)
    t.fill(t.ell(ex, ey, pupil, pupil), "ink0")
    t.px(ex - 1, ey - 1, "white")
    t.fill((grow(wide, 1) & ~wide) & (ty > ey + 1), "red1" if bloody else skin[1])
    return wide


def port_roots(x, y, spec):
    """Thread roots leaving a port at (x, y): spec is (angle, length) pairs."""
    return [(x + np.cos(a) * 4, y + np.sin(a) * 4, a, ln) for a, ln in spec]


# ====================================================================== Priya
def priya():
    p = new_patient()
    skin, hair, coat, scrubs = SKIN["priya"], CLOTH["inkhair"], CLOTH["raincoat"], CLOTH["scrubs"]
    cy = 76
    body, head = p["body"], p["head"]
    yy, xx = body.grid()

    # a raincoat open over teal scrubs, a fob watch pinned to them
    jm = torso(body, [(CX - 52, 140), (CX - 38, 121), (CX + 38, 121), (CX + 52, 140), (CX + 54, 162), (CX - 54, 162)], coat)
    top = body.poly([(CX - 22, 121), (CX + 22, 121), (CX + 18, 162), (CX - 18, 162)]) & (yy < BASE_Y)
    paint(body, top, scrubs, round_px=6)
    vee = body.poly([(CX - 10, 120), (CX + 10, 120), (CX, 135)])
    paint(body, vee, skin, round_px=4, bias=-0.12)
    body.fill((grow(vee, 1) & ~vee) & top, scrubs[0])
    finish(body, jm)
    for s in (-1, 1):
        lap = body.poly([(CX + s * 17, 120), (CX + s * 32, 124), (CX + s * 24, 146), (CX + s * 19, 162)]) & (yy < BASE_Y)
        paint(body, lap, coat, round_px=4, bias=0.14 if s < 0 else 0.0)
        body.outline(OUTLINE, lap)
    wx, wy = CX + 10, 142                                # upside down, so she can read it
    stroke(body, [(wx, wy - 6), (wx, wy - 3)], "steel4")
    body.px(wx, wy - 7, "d4a040")
    watch = body.ell(wx, wy, 3.3, 3.3)
    body.fill(watch, "steel4")
    body.fill(body.ell(wx, wy, 2.3, 2.3), "paper3")
    body.px(wx, wy, "ink0")
    body.px(wx, wy + 1, "ink0")
    body.px(wx + 1, wy, "ink1")
    body.outline("ink0", watch)
    nk = neck(body, CX - 8, CX + 8, 102, 122, skin, shadow=5)
    body.fill((grow(nk, 1) & ~nk) & (yy < 117), OUTLINE)

    for s in (-1, 1):
        ear = head.ell(CX + s * 25, cy + 3, 3.8, 6)
        paint(head, ear, skin, round_px=3)
        head.outline(OUTLINE, ear)
    hm = head_mask(head, CX, cy, 50, 60, jaw=0.8, chin=0.44)
    paint(head, hm, skin, round_px=13, round_amt=0.7)
    for s in (-1, 1):                                    # a long night under the eyes
        head.dither(hm & head.ell(CX + s * 13, cy + 6, 6, 2.2), skin[2], 0.35)
    head.fill(head.edge(hm, 1, 0), P.RIM)
    nose(head, CX, cy + 1, cy + 12, skin, w=3)
    head.outline(OUTLINE, hm)
    head.px(CX + 25, cy + 8, "d4a040")                   # a gold stud

    # natural right eye (our left); the SCAN optic on her left (our right), red, a reticle in it
    eye_r = almond(head, CX - 13, cy, 6.6, 4.0)
    eye_whites(body, [eye_r])
    head.erase(eye_r)
    lid_lines(head, eye_r, skin, lash=2)
    natural_pupil(p["pupils"], CX - 13, cy, ("2a160c", "6a4022"), r=3.0)
    blink(p["lids"], eye_r, skin)
    ox, oy = CX + 13, cy
    seat = ring_optic(head, ox, oy)
    head.fill(head.ell(ox, oy, 4.2, 4.2), "red0")
    head.dither(head.ell(ox - 1, oy - 1, 3.0, 3.0), "red1", 0.6)
    stroke(head, [(ox - 3, oy), (ox + 3, oy)], "red2")
    stroke(head, [(ox, oy - 3), (ox, oy + 3)], "red2")
    head.px(ox, oy, "red3")
    head.px(ox - 2, oy - 3, "red3")

    # black hair going grey, pulled back into a bun
    bun = head.ell(CX + 4, cy - 37, 9, 6.5)
    paint(head, bun, hair, round_px=5, round_amt=0.7)
    for a, b in (((CX - 2, cy - 40), (CX + 9, cy - 35)), ((CX + 1, cy - 42), (CX + 11, cy - 38))):
        stroke(head, [a, b], hair[3])
    head.outline(OUTLINE, bun)
    line_y = cy - 13 - 6 * np.clip(1 - ((xx - CX) / 24.0) ** 2, 0, 1)    # the hairline, high at the middle
    hmask = head.ell(CX, cy - 17, 27, 19) & (yy < line_y)
    for s in (-1, 1):                                    # pulled back over the tops of her ears
        hmask |= head.poly([(CX + s * 27, cy - 15), (CX + s * 27, cy - 3), (CX + s * 23, cy - 9), (CX + s * 21, cy - 14)])
    hmask = smooth(hmask, 1)
    paint(head, hmask, hair, round_px=8, round_amt=0.7, contrast=1.0)
    for x0 in (-18, -10, -2, 6):                        # combed back to the bun
        y0 = cy - 14 - 6 * (1 - (x0 / 24.0) ** 2)
        stroke(head, [(CX + x0, y0), (CX + x0 * 0.5 + 2, cy - 28), (CX + 3, cy - 34)], hair[3])
    stroke(head, [(CX + 14, cy - 16), (CX + 9, cy - 27), (CX + 5, cy - 34)], "8e969a")      # the grey coming in
    stroke(head, [(CX + 15, cy - 16), (CX + 10, cy - 27)], "bcc2c2")
    head.fill(head.edge(head.alpha(), 1, 0) & hmask, P.RIM)
    head.outline(OUTLINE, hmask)

    brows = brows_set(CX, cy, 13, hair[1], width=2, lift=0, span=7)
    mouths = mouth_frames(CX, cy + 20, skin, width=9, curve=0.3, lip="7a3a36")

    # LANCET hands: the backs are hers, the fingers are steel needles
    def lancet_rest(c, x, y, side, spread=0.0, lift=()):
        """A LANCET hand lying on the sill, the needles toward the viewer. side=1: thumb on our right."""
        back = c.rrect(x - 7, y, x + 7, y + 6, 2)
        tx = x + 8 if side > 0 else x - 10
        back |= c.rrect(tx - 1, y + 1, tx + 2, y + 6, 1)
        paint(c, back, skin, round_px=3, round_amt=0.4, contrast=0.8)
        stroke(c, [(x - 5, y + 1), (x + 5, y + 1)], skin[4])
        c.outline(OUTLINE, back)
        for i in range(4):
            bx = x - 5 + i * 3.3
            ln = (8, 10, 10, 8)[i] - (3 if i in lift else 0)
            needle(c, (bx, y + 6), (bx + (i - 1.5) * spread, y + 6 + ln), back)
        return back

    def lancet_up(c, x, y, side):
        """A LANCET hand raised, palm out, the needles up. Returns the needles' tips."""
        palm = c.rrect(x - 7, y, x + 7, y + 11, 3)
        tx = x + 9 if side > 0 else x - 11
        palm |= c.rrect(tx - 1, y + 3, tx + 2, y + 10, 1)
        paint(c, palm, skin, round_px=4, round_amt=0.5, bias=0.06)
        stroke(c, [(x - 5, y + 5), (x + 5, y + 6)], skin[2])
        c.outline(OUTLINE, palm)
        tips = []
        for i in range(4):
            bx = x - 5 + i * 3.3
            tip = (bx + (i - 1.5) * 0.8, y + 1 - (10, 13, 13, 10)[i])
            needle(c, (bx, y + 1), tip, palm)
            tips.append(tip)
        return tips

    def lancet_flat(c, x, y, w, side=-1, h=15, wet=False):
        """A LANCET hand slammed flat on the glass, the needles splayed."""
        hw = w // 2
        palm = c.rrect(x - hw, y, x + hw, y + h, 4)
        palm |= c.seg([(x + side * (hw - 2), y + h * 0.6), (x + side * (hw + 7), y + h * 0.15)], 4)
        paint(c, palm, skin, round_px=4, round_amt=0.5, bias=0.02)
        pale = skin[-1]
        c.fill(c.ell(x - side * 4, y + h - 4, 4.2, 2.4) & palm, pale)
        c.fill(c.ell(x + side * 5, y + h - 5, 2.6, 2.6) & palm, pale)
        c.fill(c.ell(x, y + 3, hw - 3, 1.6) & palm, pale)
        stroke(c, [(x - hw + 3, y + h * 0.42), (x + hw - 3, y + h * 0.5)], skin[2])
        if wet:
            rng = np.random.default_rng(int(x) * 7 + int(y))
            c.fill(palm & (rng.random(palm.shape) < 0.16), "red1")
            stroke(c, [(x - hw + 3, y + h * 0.42 + 1), (x + hw - 3, y + h * 0.5 + 1)], "red1")
        c.outline(OUTLINE, palm)
        for (bx, by), (tx, ty) in flat_fingers(x, y, w, side):
            needle(c, (bx, by - 2), (tx, ty - 3), palm)
        return palm

    def arms(c, sides=(-1, 1)):
        for s in sides:
            sl = c.seg([(CX + s * 40, 146), (CX + s * 16, 156)], 13)
            paint(c, sl, coat, round_px=4)
            c.outline(OUTLINE, sl)
            cuff = c.seg([(CX + s * 18, 155), (CX + s * 13, 158)], 9)
            paint(c, cuff, scrubs, round_px=2)
            c.outline(OUTLINE, cuff)

    for name, spread, lift in (("hands_a", 0.0, ()), ("hands_b", 0.5, (1,))):
        c = p[name]                                      # "Folded."
        arms(c)
        lancet_rest(c, CX + 7, 158, -1, lift=lift)
        lancet_rest(c, CX - 5, 155, 1, spread=spread)
    c = p["hands_react"]                                 # bristled: both hands up
    for i, x in enumerate((CX - 34, CX + 34)):
        s = -1 if i == 0 else 1                          # s: which side of her; the thumbs point in
        sl = c.seg([(x + s * 6, 170), (x, 134)], 14)
        paint(c, sl, coat, round_px=4)
        c.outline(OUTLINE, sl)
        cuff = c.rrect(x - 8, 130, x + 8, 136, 2)
        paint(c, cuff, scrubs, round_px=2)
        c.outline(OUTLINE, cuff)
        lancet_up(c, x, 119, -s)
    p["hands_point"] = c = layer()                       # "Went cool. One finger aimed at you."
    arms(c, sides=(1,))
    lancet_rest(c, CX + 7, 158, -1)
    arm = c.seg([(CX - 44, 166), (CX - 30, 140)], 14)
    paint(c, arm, coat, round_px=4)
    c.outline(OUTLINE, arm)
    cuff = c.rrect(CX - 38, 133, CX - 22, 139, 2)
    paint(c, cuff, scrubs, round_px=2)
    c.outline(OUTLINE, cuff)
    fist(c, CX - 26, 121, 18, skin, h=13, side=1)
    tip = c.poly([(CX - 25, 130), (CX - 20, 130), (CX - 22, 143)])
    c.fill(grow(tip, 1) & ~c.rect(CX - 34, 121, CX - 18, 133), OUTLINE)
    c.fill(tip, "steel3")
    stroke(c, [(CX - 24, 131), (CX - 23, 139)], "steel5")
    c.px(CX - 22, 143, "white")

    def free_hand(c, flat, wet=True):
        if flat:
            sl = c.seg([(CX + 52, 170), (140, 132)], 15)
            paint(c, sl, coat, round_px=4)
            c.outline(OUTLINE, sl)
            cuff = c.rrect(131, 124, 148, 131, 2)
            paint(c, cuff, scrubs, round_px=2)
            c.outline(OUTLINE, cuff)
            lancet_flat(c, 138, 109, 25, side=-1, h=15, wet=wet)
        else:
            sl = c.seg([(CX + 44, 168), (CX + 36, 142)], 14)
            paint(c, sl, coat, round_px=4)
            c.outline(OUTLINE, sl)
            cuff = c.rrect(CX + 28, 133, CX + 44, 139, 2)
            paint(c, cuff, scrubs, round_px=2)
            c.outline(OUTLINE, cuff)
            lancet_up(c, CX + 36, 121, -1)

    p["hands_slam"] = c = layer()                        # "Slapped the glass, then said sorry."
    arms(c, sides=(-1,))
    lancet_rest(c, CX - 5, 155, 1)
    free_hand(c, True, wet=False)

    # ---- the turn: the SCAN locks on and the needles run up to a beam
    face_skin = (hm & ~hmask & ~seat) | body.rect(CX - 8, 102, CX + 8, 122)

    def turn_face(bloody):
        t = layer()
        roots = [(CX - 4, 122, -1.7, 30), (CX + 4, 122, -1.45, 26), (CX, 121, -1.6, 20),
                 (CX - 21, cy + 6, 0.5, 12), (CX + 22, cy + 10, 2.6, 10), (CX - 18, cy - 8, -1.9, 8)]
        threads(t, face_skin, roots, seed=79)
        wide_eye(t, CX - 13, cy, "2a160c", bloody, skin)
        t.glow(t.all(), "red1", ox, oy, 14, amt=0.85)    # the SCAN burns
        t.fill(t.ell(ox, oy, 4.2, 4.2), "red2")
        stroke(t, [(ox - 3, oy), (ox + 3, oy)], "red3")
        stroke(t, [(ox, oy - 3), (ox, oy + 3)], "red3")
        t.px(ox, oy, "white")
        if bloody:                                       # the optic's seat weeps
            blood_run(t, [(ox - 3, oy + 8), (ox - 4, oy + 14), (ox - 3, oy + 22)], wide=True)
            blood_run(t, [(ox + 4, oy + 8), (ox + 5, oy + 13)])
            blood_run(t, [(CX - 2, cy + 13), (CX - 2, cy + 16)], bead=False)
        return t

    p["turn"] = turn_face(True)
    p["turn_clean"] = turn_face(False)
    for tag, bloody in (("", True), ("_clean", False)):
        p["mouth_turn" + tag] = rictus(CX, cy + 20, skin, hw=8, gape=4, bloody=bloody)
        p["mouth_turn_b" + tag] = rictus(CX, cy + 20, skin, hw=8, gape=1, bloody=bloody)

    def beam_arm(c, elbow, wrist, tip, r, phase):
        """Her right arm up, the LANCET needles drawn together into a point and the beam humming out
        of it. r is the size of the glow; phase makes it flicker."""
        (ax, ay), (bx, by), (tx, ty) = elbow, wrist, tip
        arm = c.seg([elbow, wrist], 15)
        paint(c, arm, coat, round_px=4)
        c.outline(OUTLINE, arm)
        ln = max(1e-6, float(np.hypot(bx - ax, by - ay)))
        dx, dy = (bx - ax) / ln, (by - ay) / ln
        cuff = c.seg([(bx - dx * 6, by - dy * 6), (bx, by)], 13)
        paint(c, cuff, scrubs, round_px=2)
        c.outline(OUTLINE, cuff)
        hx, hy = bx + dx * 5, by + dy * 5
        back = c.ell(hx, hy, 6.5, 6.5)
        paint(c, back, skin, round_px=3)
        c.outline(OUTLINE, back)
        for k in range(4):                               # the needles drawn together
            o = (k - 1.5) * 2.6
            needle(c, (hx - dy * o + dx * 4, hy + dx * o + dy * 4), (tx - dy * o * 0.15, ty + dx * o * 0.15), back)
        c.glow(c.all(), "red1", tx, ty, r, amt=0.9)
        c.glow(c.all(), "red2", tx, ty, r * 0.55, amt=1.0)
        rng = np.random.default_rng(23 + int(phase * 10) + int(r))
        for i in range(7):                               # it spits
            ang = 2 * np.pi * (i + phase) / 7 + rng.uniform(-0.25, 0.25)
            l2 = rng.uniform(0.45, 0.9) * r
            stroke(c, [(tx, ty), (tx + np.cos(ang) * l2, ty + np.sin(ang) * l2)], "red3")
        c.fill(c.ell(tx, ty, r * 0.3, r * 0.3), "red3")
        c.fill(c.ell(tx, ty, r * 0.16, r * 0.16), "white")

    for tag, k in (("", 0), ("_b", 1)):
        a = layer()                                      # wind-up: the hand up, the beam humming
        beam_arm(a, (CX - 50, 170), (CX - 42, 134), (CX - 42, 104), 11 + 2 * k, 0.5 * k)
        free_hand(a, False)
        p["attack" + tag] = a
        for clean, wet in (("", True), ("_clean", False)):
            a = layer()                                  # first blow: her palm on the glass
            beam_arm(a, (CX - 50, 170), (CX - 42, 134), (CX - 42, 104), 12 + k, 0.5 * k + 0.25)
            free_hand(a, True, wet)
            p["attack_s1" + tag + clean] = a
            a = layer()                                  # second blow: the beam on the glass
            beam_arm(a, (CX - 46, 172), (44, 142), (32, 114), 20 + 2 * k, 0.5 * k)
            free_hand(a, True, wet)
            p["attack_s2" + tag + clean] = a

    p.update({"brows_" + k: v for k, v in brows.items()})
    p.update({"mouth_" + k: v for k, v in mouths.items()})
    meta = {"zones": {"eyes": [CX - 24, cy - 9, 48, 18], "hands": [CX - 30, 150, 60, 22], "port": [CX + 6, 136, 32, 14]},
            "face": {"brows": "neutral", "mouth": "closed"}, "blink": [2.5, 5.0], "mouth_y": cy + 20,
            "attack": {"style": "laser", "hand": [138, 108], "tool": [32, 114], "head": [CX, cy - 18], "face": [CX, cy + 8]},
            "gestures": {"raise": "hands_react", "point": "hands_point", "slam": "hands_slam"}}
    return p, meta


# ====================================================================== Ozzie
def ozzie():
    p = new_patient()
    skin, cook, grey, steel = SKIN["ozzie"], CLOTH["cook"], CLOTH["grey"], CLOTH["greasy"]
    white = ["4c4640", "7c766c", "aaa498", "d0cabe", "ece8dc"]       # his hair, what is left of it, gone white
    cy = 80
    body, head = p["body"], p["head"]
    yy, xx = body.grid()

    # a grey undershirt over heavy shoulders, and a stained cook's apron on a neck strap
    tm = torso(body, [(CX - 62, 142), (CX - 44, 122), (CX + 44, 122), (CX + 62, 142), (CX + 64, 162), (CX - 64, 162)], grey)
    finish(body, tm)
    stroke(body, [(CX - 14, 122), (CX, 128), (CX + 14, 122)], grey[1], 2)
    apron = smooth(body.poly([(CX - 24, 131), (CX + 24, 131), (CX + 30, 162), (CX - 30, 162)]), 2) & (yy < BASE_Y)
    paint(body, apron, cook, round_px=8)
    for sx, sy, rx, ry in ((CX - 12, 147, 6, 3.5), (CX + 15, 154, 4, 3), (CX + 5, 138, 3, 2), (CX - 18, 157, 3, 2)):
        stain = apron & body.ell(sx, sy, rx, ry)        # broth and old grease
        body.dither(stain, "9a8a6a", 0.6)
        body.fill(stain & body.ell(sx, sy, rx * 0.5, ry * 0.5), "8a7458")
    body.outline(OUTLINE, apron)
    for s in (-1, 1):
        st = body.seg([(CX + s * 21, 132), (CX + s * 13, 121)], 3)
        paint(body, st, cook, round_px=2)
        body.outline(OUTLINE, st)
    nk = neck(body, CX - 12, CX + 12, 104, 123, skin, shadow=6)
    body.fill((grow(nk, 1) & ~nk) & (yy < 116), OUTLINE)

    for s in (-1, 1):
        ear = head.ell(CX + s * 28, cy + 2, 4.8, 7.6)
        paint(head, ear, skin, round_px=3)
        head.px(CX + s * 28, cy + 1, skin[1])
        head.outline(OUTLINE, ear)
    hm = head_mask(head, CX, cy, 54, 62, jaw=0.9, chin=0.56, drop=1)
    paint(head, hm, skin, round_px=14, round_amt=0.7)
    head.dither(hm & head.ell(CX - 9, cy - 22, 9, 4.5), skin[5], 0.5)        # the lamp on his bald crown
    for fx, fy in ((-14, -18), (11, -21), (17, -13), (-19, -9)):             # age spots
        head.px(CX + fx, cy + fy, skin[2])
        head.px(CX + fx + 1, cy + fy, skin[2])
    for ly in (cy - 16, cy - 19):
        stroke(head, [(CX - 10, ly), (CX - 3, ly + 1), (CX + 4, ly + 1), (CX + 10, ly)], skin[2])
    for s in (-1, 1):
        stroke(head, [(CX + s * 8, cy + 9), (CX + s * 13, cy + 20)], skin[2])
        stroke(head, [(CX + s * 21, cy - 2), (CX + s * 24, cy - 4)], skin[2])
        stroke(head, [(CX + s * 21, cy + 1), (CX + s * 24, cy + 2)], skin[2])
        head.dither(hm & head.ell(CX + s * 15, cy + 9, 6, 4), "c86a5a", 0.35)
    head.dither(hm & ((yy > cy + 15) | ((np.abs(xx - CX) > 19) & (yy > cy + 9))), white[1], 0.3)     # white stubble
    head.fill(head.edge(hm, 1, 0), P.RIM)
    nose(head, CX, cy + 1, cy + 13, skin, w=4)
    head.dither(head.ell(CX, cy + 11, 3.5, 2.5) & hm, "c86a5a", 0.5)
    head.outline(OUTLINE, hm)
    mous = head.poly([(CX - 11, cy + 19), (CX - 8, cy + 15), (CX - 2, cy + 14), (CX + 2, cy + 14), (CX + 8, cy + 15),
                      (CX + 11, cy + 19), (CX + 6, cy + 18), (CX, cy + 17), (CX - 6, cy + 18)])
    paint(head, mous, white, round_px=3)
    head.outline(OUTLINE, mous)
    puff = grow(hm, 2) & ~hm & (yy < cy - 4)           # a little past the skull, above the ears
    hmask = smooth((puff | (hm & ~P.shrink(hm, 4))) & (yy > cy - 17) & (yy < cy + 3) & (np.abs(xx - CX) > 18), 1)
    paint(head, hmask, white, round_px=3, round_amt=0.5)
    for s in (-1, 1):                                    # combed back over the ears
        for k in range(3):
            stroke(head, [(CX + s * (21 + 2 * k), cy - 14 + 2 * k), (CX + s * (24 + 2 * k), cy - 3 + k)], white[1 + k % 2])
    head.dither(grow(hmask, 1) & ~hmask & hm, white[2], 0.5)    # the inner edge thins into the skin
    head.fill(head.edge(head.alpha(), 1, 0) & hmask, P.RIM)
    head.fill(grow(hmask, 1) & ~hmask & ~hm, OUTLINE)    # outlined only against the room and the ears

    # narrow old eyes, milky at the rims of the irises
    holes = [almond(head, CX + s * 13, cy, 5.6, 2.5) for s in (-1, 1)]
    eye_whites(body, holes, lid_shadow="paper2")
    for i, hmk in enumerate(holes):
        ex = CX + (-13 if i == 0 else 13)
        head.erase(hmk)
        lid_lines(head, hmk, skin)
        head.fill((grow(hmk, 2) & ~grow(hmk, 1)) & (yy < cy), skin[2])
        pu = p["pupils"]
        pu.fill(pu.ell(ex, cy, 2.9, 2.9), "b4bcb8")
        pu.fill(pu.ell(ex, cy, 2.0, 2.0), "4e5e50")
        pu.fill(pu.ell(ex, cy, 1.0, 1.0), "ink0")
        pu.px(ex - 1, cy - 1, "white")
        blink(p["lids"], hmk, skin)

    brows = brows_set(CX, cy + 1, 13, white[1], width=3, lift=-1, span=7)     # thick white brows, shadowed under
    for k_, top in brows_set(CX, cy, 13, white[3], width=2, lift=-1, span=7).items():
        brows[k_].blit(top)
    mouths = mouth_frames(CX, cy + 21, skin, width=10, curve=0.5)

    def towel(c, x, y0, y1, w=12):
        """The towel round the CHOP forearm, white with a red stripe."""
        m = c.rrect(x - w, y0, x + w, y1, 3)
        paint(c, m, cook, round_px=4)
        for t_ in range(y0 + 4, y1 - 1, 5):
            stroke(c, [(x - w + 1, t_), (x + w - 1, t_ + 1)], cook[1])
        for t_ in (y0 + 6, y0 + 8):
            stroke(c, [(x - w + 1, t_), (x + w - 1, t_ + 1)], "a02a36")
        c.outline(OUTLINE, m)
        return m

    def chop(c, x, y, lifted=(), clench=False):
        """The CHOP hand on the sill: steel gone dark with grease, the blade folded down its outer edge."""
        if clench:
            m = fist(c, x, y, 21, steel, knuckle=steel[5], h=12, side=1)
        else:
            m = hand_rest(c, x, y, 21, steel, lifted=lifted, side=1, seams=steel[1], h=14)
        c.dither(m, "warm2", 0.18)
        blade = c.rrect(x - 14, y, x - 11, y + 12, 1)
        c.fill(grow(blade, 1) & ~m, OUTLINE)
        c.fill(blade, "steel3")
        stroke(c, [(x - 14, y + 1), (x - 14, y + 11)], "steel5")
        c.px(x - 13, y + 3, "white")
        return m

    def burns(c, arm, spots):
        for bx, by, r in spots:                          # old burns off the stove
            c.fill(c.ell(bx, by, r, r * 0.8) & arm, skin[5])
            c.px(bx, by, skin[4])

    def left_arm(c, x, y, lifted=()):
        """His left forearm and hand on the sill, the greasy socket at the wrist. Returns the bare
        skin (the port left out) and the socket's place."""
        arm = c.rrect(x - 10, y - 17, x + 10, y, 3)
        paint(c, arm, skin, round_px=5)
        burns(c, arm, ((x - 5, y - 13, 2.2), (x + 4, y - 15, 1.6), (x + 6, y - 9, 1.4)))
        c.outline(OUTLINE, arm)
        sx, sy = x, y - 5
        c.dither(c.ell(sx, sy, 5.0, 4.0) & arm, "warm1", 0.5)
        wrist_port(c, sx, sy, burnt=True)
        hand = hand_rest(c, x, y, 21, skin, lifted=lifted, side=-1, h=14)
        return ((arm | hand) & ~c.ell(sx, sy, 3.8, 3.8)), (sx, sy)

    def free_hand(c, flat, wet=True):
        """His left hand on the glass, or up and open. Returns the bare skin and the socket's place."""
        if flat:
            a, b, (sx, sy) = (CX + 56, 172), (140, 126), (140, 131)
        else:
            a, b, (sx, sy) = (CX + 50, 172), (CX + 40, 134), (CX + 41, 138)
        arm = c.seg([a, b], 19 if flat else 18)
        paint(c, arm, skin, round_px=5)
        burns(c, arm, [(a[0] + (b[0] - a[0]) * t_, a[1] + (b[1] - a[1]) * t_, r) for t_, r in ((0.4, 2.2), (0.62, 1.6))])
        c.outline(OUTLINE, arm)
        c.dither(c.ell(sx, sy, 5.0, 4.0) & arm, "warm1", 0.5)
        wrist_port(c, sx, sy, burnt=True)
        if flat:
            hand = palm_flat(c, 138, 109, 27, skin, side=-1, h=16, wet=wet)
        else:
            hand = palm_up(c, CX + 40, 120, 21, skin, side=-1, h=13)
        return ((arm | hand) & ~c.ell(sx, sy, 3.8, 3.8)), (sx, sy)

    bare = {}
    for name, lifts in (("hands_a", ((), ())), ("hands_b", ((2, 3), (0, 1)))):
        c = p[name]
        towel(c, CX - 30, 137, 153)
        chop(c, CX - 30, 153, lifted=lifts[0])
        bare[name] = left_arm(c, CX + 30, 158, lifted=lifts[1])
    c = p["hands_react"]                                 # "Huffed, hands up."
    arm = c.seg([(CX - 30, 168), (CX - 34, 134)], 18)
    paint(c, arm, skin, round_px=5)
    c.outline(OUTLINE, arm)
    towel(c, CX - 33, 140, 158, w=11)
    palm_up(c, CX - 34, 122, 19, steel, side=1, h=12)
    blade = c.rrect(CX - 48, 113, CX - 45, 132, 1)
    c.fill(grow(blade, 1), OUTLINE)
    c.fill(blade, "steel3")
    stroke(c, [(CX - 48, 114), (CX - 48, 131)], "steel5")
    arm = c.seg([(CX + 30, 168), (CX + 34, 134)], 18)
    paint(c, arm, skin, round_px=5)
    burns(c, arm, ((CX + 29, 156, 2.2), (CX + 36, 150, 1.6)))
    c.outline(OUTLINE, arm)
    c.dither(c.ell(CX + 34, 139, 5.0, 4.0) & arm, "warm1", 0.5)
    wrist_port(c, CX + 34, 139, burnt=True)
    palm = palm_up(c, CX + 34, 122, 19, skin, side=-1, h=12)
    bare["hands_react"] = ((arm | palm) & ~c.ell(CX + 34, 139, 3.8, 3.8)), (CX + 34, 139)
    p["hands_fist"] = c = layer()                        # "Went quiet. The blade hand clenched."
    towel(c, CX - 30, 137, 153)
    chop(c, CX - 30, 152, clench=True)
    bare["hands_fist"] = left_arm(c, CX + 30, 158)
    p["hands_slam"] = c = layer()                        # "Slapped the glass, then said sorry."
    towel(c, CX - 30, 137, 153)
    chop(c, CX - 30, 153)
    bare["hands_slam"] = free_hand(c, True, wet=False)
    for name, (m, (sx, sy)) in bare.items():             # threads up the arm from the socket
        a0 = 1.57 if name in ("hands_react", "hands_slam") else -1.57
        p[name + "_t"] = twin(p[name], m, port_roots(sx, sy, ((a0, 13), (a0 - 0.5, 10), (a0 + 0.5, 10), (a0 + 3.1, 5))), seed=83)

    # ---- the turn: the towel drops and the CHOP blade swings out
    face_skin = (hm & ~hmask & ~mous) | body.rect(CX - 12, 104, CX + 12, 123)

    def turn_face(bloody):
        t = layer()
        roots = [(CX - 6, 123, -1.7, 32), (CX + 6, 123, -1.45, 30), (CX, 122, -1.6, 24), (CX - 24, cy + 8, 0.4, 12),
                 (CX + 24, cy + 8, 2.7, 12), (CX - 16, cy - 20, -1.2, 10), (CX + 14, cy - 24, -2.0, 10)]
        threads(t, face_skin, roots, seed=89)
        for s in (-1, 1):
            w = wide_eye(t, CX + s * 13, cy, "b4bcb8", bloody, skin, rx=7.4, ry=4.8)
            t.dither(w & ~t.ell(CX + s * 13, cy, 2.4, 2.4), "e0a090", 0.25)
            t.fill(t.ell(CX + s * 13, cy, 1.0, 1.0), "ink0")
        if bloody:
            blood_run(t, [(CX - 15, cy + 5), (CX - 16, cy + 12), (CX - 15, cy + 20)], wide=True)
            blood_run(t, [(CX + 14, cy + 5), (CX + 15, cy + 10)])
        return t

    p["turn"] = turn_face(True)
    p["turn_clean"] = turn_face(False)
    for tag, bloody in (("", True), ("_clean", False)):
        p["mouth_turn" + tag] = rictus(CX, cy + 21, skin, hw=9, gape=4, bloody=bloody)
        p["mouth_turn_b" + tag] = rictus(CX, cy + 21, skin, hw=9, gape=1, bloody=bloody)

    def cleaver(c, fx, fy, ang, ln, w, glint):
        """The CHOP blade swung out of the fist at (fx, fy) and locked: ang tilts it (0 is straight up),
        ln is its length, w its width; glint (0..1) is where the light runs on the edge. Returns the
        middle of the edge."""
        ux, uy = np.sin(ang), -np.cos(ang)
        nx, ny = np.cos(ang), np.sin(ang)
        gy_, gx_ = c.grid()
        u = (gx_ - fx) * ux + (gy_ - fy) * uy           # along the blade
        v = (gx_ - fx) * nx + (gy_ - fy) * ny           # across it: the edge is at -w/2, the spine at +w/2

        def at(u_, v_):
            return (fx + ux * u_ + nx * v_, fy + uy * u_ + ny * v_)

        bl = c.poly([at(0, -w * 0.5), at(0, w * 0.5), at(ln, w * 0.5), at(ln + 1, -w * 0.2), at(ln - 2, -w * 0.5)])
        c.fill(grow(bl, 1), "ink0")
        c.fill(bl, "steel3")
        sheen = np.abs(u - ln * 0.55 + v * 1.2)          # light across the flat of it
        c.fill(bl & (sheen < 2.4), "steel4")
        c.fill(bl & (sheen < 0.9), "steel5")
        c.fill(bl & (v > w * 0.5 - 2.2), "steel1")      # the thick spine
        c.fill(bl & (v < -w * 0.5 + 1.6), "steel5")     # the edge
        hx, hy = at(ln - 5, w * 0.18)
        c.fill(c.ell(hx, hy, 1.8, 1.8), "ink0")
        gx, gy = at(3 + (ln - 7) * glint, -w * 0.5 + 0.8)
        c.fill(c.ell(gx, gy, 1.3, 1.3) & bl, "white")
        return at(ln * 0.6, -w * 0.5)

    def chop_arm(c, elbow, wrist, ang, ln, w, glint, fw=21):
        arm = c.seg([elbow, wrist], 17)
        paint(c, arm, skin, round_px=5)
        burns(c, arm, [(elbow[0] + (wrist[0] - elbow[0]) * 0.55, elbow[1] + (wrist[1] - elbow[1]) * 0.55, 2.0)])
        c.outline(OUTLINE, arm)
        bx, by = int(wrist[0]), int(wrist[1])
        edge = cleaver(c, bx, by - 8, ang, ln, w, glint)
        fist(c, bx, by - 12, fw, steel, knuckle=steel[5], h=12, side=1)
        return edge

    for tag, k in (("", 0), ("_b", 1)):
        a = layer()                                      # wind-up: the blade out, raised
        chop_arm(a, (CX - 52, 170), (CX - 42, 134), (-0.1, 0.06)[k], 28, 14, 0.2 + 0.5 * k)
        free_hand(a, False)
        p["attack" + tag] = a
        for clean, wet in (("", True), ("_clean", False)):
            a = layer()                                  # first blow: his palm on the glass
            chop_arm(a, (CX - 52, 170), (CX - 42, 134), (-0.25, -0.14)[k], 28, 14, 0.5 + 0.3 * k)
            free_hand(a, True, wet)
            p["attack_s1" + tag + clean] = a
            a = layer()                                  # second blow: the blade bites the glass
            ex, ey = chop_arm(a, (CX - 40, 176), (CX - 30 - k, 134), -0.75, 30, 15, 0.7 - 0.4 * k, fw=23)
            for ang in (-2.7, -2.0, -1.3, 2.6):
                r0, r1 = 5 + k, 10 + 2 * k
                stroke(a, [(ex + np.cos(ang) * r0, ey + np.sin(ang) * r0), (ex + np.cos(ang) * r1, ey + np.sin(ang) * r1)], "paper3")
            free_hand(a, True, wet)
            p["attack_s2" + tag + clean] = a

    p.update({"brows_" + k: v for k, v in brows.items()})
    p.update({"mouth_" + k: v for k, v in mouths.items()})
    meta = {"zones": {"eyes": [CX - 24, cy - 7, 48, 14], "hands": [CX - 46, 156, 92, 17], "port": [CX + 19, 141, 22, 15]},
            "face": {"brows": "neutral", "mouth": "closed"}, "blink": [2.5, 5.0], "mouth_y": cy + 21,
            "attack": {"style": "cleaver", "hand": [138, 108], "tool": [32, 118], "head": [CX, cy - 24], "face": [CX, cy + 8]},
            "gestures": {"raise": "hands_react", "fist": "hands_fist", "slam": "hands_slam"}}
    return p, meta


# ====================================================================== Lux
PROMPT = ["#....", ".#...", "..#..", ".#...", "#.###"]
PROMPT_B = ["#....", ".#...", "..#..", ".#...", "#...."]
GLITCH = ["#...#", ".#.#.", "..#..", ".#.#.", "#...#"]


def lux():
    p = new_patient()
    skin, hair, hood, vio = SKIN["lux"], CLOTH["black"], CLOTH["hoodie"], CLOTH["violet"]
    cy = 78
    body, head = p["body"], p["head"]
    yy, xx = body.grid()

    # a baggy hoodie, the hood bunched round her neck
    jm = torso(body, [(CX - 56, 144), (CX - 40, 122), (CX + 40, 122), (CX + 56, 144), (CX + 58, 162), (CX - 58, 162)], hood)
    stroke(body, [(CX - 30, 152), (CX + 30, 152)], hood[1])
    stroke(body, [(CX - 30, 152), (CX - 26, 162)], hood[1])
    stroke(body, [(CX + 30, 152), (CX + 26, 162)], hood[1])
    finish(body, jm)
    hoodm = smooth(body.ell(CX, 121, 27, 9) | body.ell(CX - 18, 116, 9, 7) | body.ell(CX + 18, 116, 9, 7), 2)
    hoodm &= ~body.ell(CX, 114, 11, 7)
    paint(body, hoodm, hood, round_px=5, bias=0.06)
    stroke(body, [(CX - 22, 118), (CX - 10, 124)], hood[1])
    stroke(body, [(CX + 22, 118), (CX + 10, 124)], hood[1])
    body.outline(OUTLINE, hoodm)
    for s, ln in ((-1, 16), (1, 12)):                    # the drawstrings
        stroke(body, [(CX + s * 7, 126), (CX + s * 8, 126 + ln)], "paper2")
        body.px(CX + s * 8, 127 + ln, "steel4")
        body.px(CX + s * 8, 128 + ln, "steel4")
    nk = neck(body, CX - 7, CX + 7, 102, 121, skin, shadow=6)
    body.fill((grow(nk, 1) & ~nk) & (yy < 115), OUTLINE)
    cab = body.seg([(CX - 8, 109), (CX - 12, 113), (CX - 14, 118)], 2) & ~nk & ~hoodm    # the deck cable, out from behind her neck
    body.fill(grow(cab, 1) & ~nk & ~hoodm & ~cab, OUTLINE)
    body.fill(cab, vio[2])

    ears = {}
    for s in (-1, 1):
        ear = ears[s] = head.ell(CX + s * 24, cy + 3, 3.4, 5.4)
        paint(head, ear, skin, round_px=3)
        head.outline(OUTLINE, ear)
    head.px(CX - 27, cy + 1, "steel5")                   # rings up the ear that shows
    head.px(CX - 27, cy + 4, "steel5")
    hm = head_mask(head, CX, cy, 48, 56, jaw=0.8, chin=0.44)
    paint(head, hm, skin, round_px=12, round_amt=0.7)
    for s in (-1, 1):                                    # no sleep
        head.dither(hm & head.ell(CX + s * 13, cy + 6, 6, 2), skin[2], 0.45)
    head.fill(head.edge(hm, 1, 0), P.RIM)
    nose(head, CX, cy + 1, cy + 10, skin, w=2)
    head.outline(OUTLINE, hm)

    # a KITE lens on her right (our left), scuffed and cracked; an IRIS screen on her left
    ox, oy = CX - 13, cy
    seat = ring_optic(head, ox, oy)
    head.fill(head.ell(ox, oy, 4.2, 4.2), "cyan0")
    head.fill(head.ell(ox, oy, 2.2, 2.2), "ink0")
    head.px(ox - 2, oy - 3, "cyan2")
    head.px(ox - 3, oy - 2, "cyan1")
    stroke(head, [(ox + 4, oy - 5), (ox - 1, oy), (ox, oy + 3), (ox - 3, oy + 6)], "cyan3")
    head.px(ox + 5, oy + 3, "steel4")
    ex = CX + 13
    hs = head.rrect(ex - 8, cy - 5, ex + 8, cy + 5, 2)
    housing = grow(hs, 1)
    head.fill(hs, "steel1")
    stroke(head, [(ex - 6, cy - 5), (ex + 6, cy - 5)], "steel4")
    stroke(head, [(ex - 6, cy + 5), (ex + 6, cy + 5)], "steel0")
    head.outline("ink0", hs)
    scr = head.rrect(ex - 6, cy - 3, ex + 6, cy + 3, 1)
    body.fill(grow(scr, 2), "160c24")
    head.erase(scr)
    glyph(p["pupils"], ex, cy, PROMPT, vio[4], vio[3])
    glyph(p.setdefault("pupils_b", layer()), ex, cy, PROMPT_B, vio[4], vio[3])
    r = p.setdefault("pupils_react", layer())
    r.fill(grow(scr, 2), vio[2])
    glyph(r, ex, cy, GLITCH, vio[5])
    p["lids"].fill(scr, "160c24")
    stroke(p["lids"], [(ex - 4, cy), (ex + 4, cy)], vio[1])

    # a black bob she cuts herself, swept over to her left; the right side shaved round the jack
    jx, jy = CX - 17, cy - 17
    lim = np.where(xx >= CX - 4, cy - 13, cy - 15 + (xx - (CX - 4)) * 0.5)     # the shaved side: hair only above this
    hmask = head.ell(CX + 2, cy - 17, 26, 19) & (yy < lim)
    for tri in ([(CX - 4, cy - 15), (CX + 1, cy - 12), (CX + 6, cy - 15)], [(CX + 6, cy - 15), (CX + 11, cy - 13), (CX + 16, cy - 15)]):
        hmask |= head.poly(tri)
    hmask |= head.poly([(CX + 17, cy - 15), (CX + 28, cy - 12), (CX + 30, cy + 6), (CX + 28, cy + 21), (CX + 22, cy + 23),
                        (CX + 23, cy + 8), (CX + 22, cy - 6)])
    hmask = smooth(hmask, 1)
    paint(head, hmask, hair, round_px=8, round_amt=0.7, contrast=1.1)
    for pts in ([(CX - 13, cy - 28), (CX + 1, cy - 21), (CX + 7, cy - 15)], [(CX - 5, cy - 32), (CX + 10, cy - 23), (CX + 15, cy - 15)],
                [(CX + 6, cy - 34), (CX + 19, cy - 23), (CX + 24, cy - 9)], [(CX + 25, cy - 8), (CX + 26, cy + 14)]):
        stroke(head, pts, hair[4])
    head.fill(head.edge(head.alpha(), 1, 0) & hmask, P.RIM)
    head.outline(OUTLINE, hmask)
    shaved = hm & ~hmask & ~seat & (xx < CX - 13) & (yy < cy - 9)
    head.dither(shaved, hair[2], 0.18)
    # the DIVER jack at her temple, burnt round the rim
    jack = head.ell(jx, jy, 3.4, 3.4)
    head.dither(head.ell(jx, jy, 5.4, 4.8) & hm & ~hmask & ~jack, "warm2", 0.45)
    head.fill(jack, "ink1")
    head.fill(head.ell(jx, jy, 2.4, 2.4), "steel2")
    head.fill(head.ell(jx, jy, 1.2, 1.2), "ink0")
    head.px(jx - 1, jy - 2, "steel4")
    head.px(jx + 3, jy + 2, "warm4")
    head.px(jx - 3, jy + 3, "warm3")
    clean = head.copy()
    # the deck plug in it, the cable up over her hair and away behind her
    plug = head.seg([(jx - 1, jy - 1), (jx - 2, jy - 5)], 4)
    cable = head.seg([(jx - 2, jy - 5), (jx, jy - 10), (CX - 12, cy - 32), (CX - 4, cy - 36)], 2)
    over = clean.alpha()
    wire = (plug | cable) & over
    plugged = grow(wire, 1) & over
    head.fill(plugged & ~wire, OUTLINE)
    head.fill(cable & over, vio[2])
    head.fill(head.edge(cable, -1, 0) & cable & over, vio[3])
    paint(head, plug & over, CLOTH["chrome"], round_px=2)
    head.px(jx - 2, jy - 4, "white")

    brows = brows_set(CX, cy, 13, hair[1], width=2, lift=1, span=6)
    mouths = mouth_frames(CX, cy + 19, skin, width=8, curve=-0.2)

    def sill(c, lifts=((), ()), sides=(0, 1), clench=()):
        for i, x in enumerate((CX - 22, CX + 22)):
            if i not in sides:
                continue
            s = -1 if i == 0 else 1
            if i in clench:
                fist(c, x, 155, 15, skin, h=10, side=-s)
            else:
                hand_rest(c, x, 156, 15, skin, lifted=lifts[i], nails=skin[2], side=-s, h=12)
            sl = c.seg([(x + s * 26, 144), (x + s * 3, 155)], 13)    # the sleeve down over her wrist
            paint(c, sl, hood, round_px=4)
            c.outline(OUTLINE, sl)
            cuff = c.seg([(x + s * 6, 153), (x + s * 2, 156)], 11) & sl
            c.fill(cuff, hood[1])
            c.fill(c.edge(cuff, -s, 0) & cuff, hood[3])

    sill(p["hands_a"])
    sill(p["hands_b"], ((1, 3), (0, 2)))                 # typing on air
    c = p["hands_react"]
    for i, x in enumerate((CX - 32, CX + 32)):
        palm_up(c, x, 122, 15, skin, side=1 if i == 0 else -1, h=11)
        sl = c.seg([(x - (4 if i == 0 else -4), 166), (x, 130)], 15)
        paint(c, sl, hood, round_px=4)
        c.outline(OUTLINE, sl)
    p["hands_point"] = c = layer()                       # "Snapped back, pointing."
    sill(c, sides=(1,))
    fist(c, CX - 26, 121, 16, skin, h=12, side=1)
    tip = c.rrect(CX - 25, 129, CX - 20, 140, 2)
    paint(c, tip, skin, round_px=3, bias=0.16)
    c.outline(OUTLINE, tip)
    arm = c.seg([(CX - 44, 168), (CX - 30, 134)], 15)
    paint(c, arm, hood, round_px=4)
    c.outline(OUTLINE, arm)
    p["hands_fist"] = c = layer()                        # "Went polite. Her hand closed tight."
    sill(c, clench=(0,))

    def free_hand(c, flat, wet=True):
        if flat:
            palm_flat(c, 138, 109, 23, skin, side=-1, h=14, wet=wet)
            sl = c.seg([(CX + 52, 172), (139, 121)], 16)
        else:
            palm_up(c, CX + 36, 120, 17, skin, side=-1, h=12)
            sl = c.seg([(CX + 46, 170), (CX + 36, 129)], 15)
        paint(c, sl, hood, round_px=4)
        c.outline(OUTLINE, sl)

    p["hands_slam"] = c = layer()                        # "Slapped the glass, then said sorry."
    sill(c, sides=(0,))
    free_hand(c, True, wet=False)
    # dark threads out from the jack, for a night the port is the sign
    round_jack = hm & ~hmask & ~seat & ~plugged & ~grow(jack, 1) & head.ell(jx + 3, jy + 3, 14, 12)
    p["head_t"] = twin(head, round_jack, port_roots(jx, jy, ((0.1, 14), (-0.5, 9), (0.7, 9), (2.5, 8), (1.9, 6), (-2.5, 5))), seed=101)

    # ---- the turn: the IRIS goes white and she rips the cable out of her temple
    face_skin = hm & ~hmask & ~seat & ~housing & ~grow(jack, 1)

    def turn_face(bloody):
        t = layer()
        t.a[plugged] = clean.a[plugged]                  # the plug is out
        t.fill(t.ell(jx, jy, 2.4, 2.4), "ink0")
        t.px(jx, jy, "red2" if bloody else "ink1")
        roots = [(jx + 3, jy + 1, 0.1, 30), (jx + 3, jy + 3, 0.7, 24), (jx + 1, jy + 4, 1.4, 20), (jx + 2, jy - 3, -0.5, 14),
                 (CX - 4, 121, -1.6, 22), (CX + 4, 121, -1.5, 18)]
        threads(t, face_skin | body.rect(CX - 7, 102, CX + 7, 121), roots, seed=97)
        t.glow(t.all(), "vio2", ox, oy, 12, amt=0.7)      # the KITE runs violet
        t.fill(t.ell(ox, oy, 4.2, 4.2), "8a7cff")
        t.fill(t.ell(ox, oy, 1.8, 1.8), "white")
        sc = t.rrect(ex - 6, cy - 3, ex + 6, cy + 3, 1)  # the IRIS goes white
        t.glow(t.all(), "c8c0ff", ex, cy, 11, amt=0.6)
        t.fill(grow(sc, 1), "c8c0ff")
        t.fill(sc, "white")
        if bloody:                                       # the torn jack bleeds down her cheek
            blood_run(t, [(jx, jy + 3), (jx - 1, jy + 9), (jx - 2, jy + 18), (jx - 1, jy + 27)], wide=True)
            blood_run(t, [(jx + 2, jy + 3), (jx + 3, jy + 8)])
            blood_run(t, [(CX - 1, cy + 10), (CX - 1, cy + 12)], bead=False)
        return t

    p["turn"] = turn_face(True)
    p["turn_clean"] = turn_face(False)
    for tag, bloody in (("", True), ("_clean", False)):
        p["mouth_turn" + tag] = rictus(CX, cy + 19, skin, hw=7, gape=4, bloody=bloody)
        p["mouth_turn_b" + tag] = rictus(CX, cy + 19, skin, hw=7, gape=1, bloody=bloody)

    def arc_arm(c, elbow, wrist, tip, r, phase):
        """Her right arm up, the torn-out plug in her fist, live and spitting violet; the cable runs from
        it back down into her hood. tip is the plug's live end."""
        (bx, by), (tx, ty) = wrist, tip
        fx, fy = bx, by - 8
        cable = c.seg([(fx + 3, fy + 4), (fx + 9, fy + 16), (CX - 20, 150), (CX - 16, 176)], 2)
        c.fill(grow(cable, 1), OUTLINE)
        c.fill(cable, vio[2])
        arm = c.seg([elbow, wrist], 15)
        paint(c, arm, hood, round_px=4)
        c.outline(OUTLINE, arm)
        pl = c.seg([(fx, fy), (tx, ty)], 4)
        c.fill(grow(pl, 1), OUTLINE)
        paint(c, pl, CLOTH["chrome"], round_px=2)
        fist(c, int(fx), int(fy) - 6, 16, skin, h=11, side=1)
        c.glow(c.all(), "8a7cff", tx, ty, r, amt=0.9)
        c.glow(c.all(), "c8c0ff", tx, ty, r * 0.5, amt=1.0)
        crackle(c, tx, ty, r, 6, seed=31 + int(phase * 10) + int(r), cols=("b8b0ff", "white"))
        c.fill(c.ell(tx, ty, 2.2, 2.2), "white")

    for tag, k in (("", 0), ("_b", 1)):
        a = layer()                                      # wind-up: the plug held up, spitting
        arc_arm(a, (CX - 50, 170), (CX - 42, 134), (CX - 47, 108 - k), 11 + 2 * k, 0.5 * k)
        free_hand(a, False)
        p["attack" + tag] = a
        for clean_, wet in (("", True), ("_clean", False)):
            a = layer()                                  # first blow: her palm on the glass
            arc_arm(a, (CX - 50, 170), (CX - 42, 134), (CX - 47, 108 + k), 12 + k, 0.5 * k + 0.25)
            free_hand(a, True, wet)
            p["attack_s1" + tag + clean_] = a
            a = layer()                                  # second blow: the plug on the glass
            arc_arm(a, (CX - 44, 172), (42, 138), (32, 114), 19 + 2 * k, 0.5 * k)
            free_hand(a, True, wet)
            p["attack_s2" + tag + clean_] = a

    p.update({"brows_" + k: v for k, v in brows.items()})
    p.update({"mouth_" + k: v for k, v in mouths.items()})
    meta = {"zones": {"eyes": [CX - 24, cy - 9, 48, 18], "hands": [CX - 38, 150, 76, 22], "port": [jx - 8, jy - 8, 16, 13]},
            "face": {"brows": "neutral", "mouth": "closed"}, "blink": [2.5, 5.0], "mouth_y": cy + 19,
            "attack": {"style": "arc", "hand": [138, 108], "tool": [32, 114], "head": [CX, cy - 18], "face": [CX, cy + 8]},
            "gestures": {"point": "hands_point", "fist": "hands_fist", "slam": "hands_slam"}}
    return p, meta


# ====================================================================== Dana
def dana():
    p = new_patient()
    skin, hair, coat = SKIN["dana"], CLOTH["ash"], CLOTH["trench"]
    cy = 74
    body, head = p["body"], p["head"]
    yy, xx = body.grid()

    # a plain raincoat, buttoned, open low over a dark shirt; her badge on her belt
    jm = torso(body, [(CX - 52, 140), (CX - 38, 121), (CX + 38, 121), (CX + 52, 140), (CX + 54, 162), (CX - 54, 162)], coat)
    gap = body.poly([(CX - 2, 136), (CX + 2, 136), (CX + 13, 162), (CX - 13, 162)]) & (yy < BASE_Y)
    paint(body, gap, CLOTH["suit"], round_px=4)
    body.fill(gap & (yy >= 151) & (yy <= 153), "ink0")
    body.px(CX - 3, 152, "steel4")
    badge = body.poly([(CX + 2, 147), (CX + 8, 147), (CX + 8, 152), (CX + 5, 155), (CX + 2, 152)])
    paint(body, badge, CLOTH["brass"], round_px=2)
    body.px(CX + 5, 150, "f4d880")
    body.outline("ink0", badge)
    finish(body, jm)
    stroke(body, [(CX - 2, 124), (CX - 2, 136)], coat[1])
    for by_ in (127, 133):
        body.px(CX - 5, by_, "ink1")
        body.px(CX - 5, by_ + 1, coat[1])
    for s in (-1, 1):
        stroke(body, [(CX + s * 22, 124), (CX + s * 40, 134)], coat[1])
        stroke(body, [(CX + s * 30, 141), (CX + s * 33, 152)], coat[1])
    nk = neck(body, CX - 8, CX + 8, 100, 122, skin, shadow=5)
    for s in (-1, 1):                                    # the collar turned up, to her jaw
        col = body.poly([(CX + s * 4, 104), (CX + s * 14, 98), (CX + s * 25, 121), (CX + s * 8, 127)])
        paint(body, col, coat, round_px=4, bias=0.12 if s < 0 else -0.04)
        stroke(body, [(CX + s * 7, 108), (CX + s * 16, 121)], coat[1])
        body.outline(OUTLINE, col)

    for s in (-1, 1):
        ear = head.ell(CX + s * 25, cy + 3, 3.6, 5.8)
        paint(head, ear, skin, round_px=3)
        head.outline(OUTLINE, ear)
    hm = head_mask(head, CX, cy, 50, 60, jaw=0.86, chin=0.5)
    paint(head, hm, skin, round_px=13, round_amt=0.7)
    stroke(head, [(CX - 1, cy - 11), (CX - 1, cy - 8)], skin[3])        # the frown line, kept
    for s in (-1, 1):
        stroke(head, [(CX + s * 21, cy + 2), (CX + s * 23, cy + 1)], skin[3])
    head.fill(head.edge(hm, 1, 0), P.RIM)
    nose(head, CX, cy + 1, cy + 12, skin, w=3)
    head.outline(OUTLINE, hm)

    # a TALON on her right (our left), a red grid in it; her left eye is her own
    tal = CX - 13
    hs = head.rrect(tal - 8, cy - 4, tal + 8, cy + 4, 2)
    housing = grow(hs, 1)
    head.fill(hs, "steel1")
    stroke(head, [(tal - 6, cy - 4), (tal + 6, cy - 4)], "steel4")
    stroke(head, [(tal - 6, cy + 4), (tal + 6, cy + 4)], "steel0")
    head.outline("ink0", hs)
    stroke(head, [(tal - 9, cy), (CX - 23, cy - 1)], "steel1")
    lens = head.rrect(tal - 6, cy - 2, tal + 6, cy + 2, 1)
    body.fill(grow(lens, 2), "1a0408")
    head.erase(lens)
    pu = p["pupils"]
    grid_ = pu.none()
    for gx in range(tal - 9, tal + 10, 3):               # wider than the lens, so it still fills it when her gaze moves
        grid_ |= pu.seg([(gx, cy - 4), (gx, cy + 4)], 1)
    rows = pu.seg([(tal - 9, cy - 1), (tal + 9, cy - 1)], 1) | pu.seg([(tal - 9, cy + 1), (tal + 9, cy + 1)], 1)
    pu.fill(grid_ | rows, "red1")
    pu.fill(grid_ & rows, "red2")
    pu.px(tal, cy, "red3")
    eye_l = almond(head, CX + 13, cy, 6.4, 3.6)
    eye_whites(body, [eye_l])
    head.erase(eye_l)
    lid_lines(head, eye_l, skin)
    natural_pupil(pu, CX + 13, cy, ("33404c", "6e8496"), r=3.0)
    blink(p["lids"], eye_l, skin)

    # short ash-grey hair, cut to be no trouble
    hmask = head.ell(CX, cy - 16, 26.5, 18) & (yy < cy - 14 + (xx - CX) * 0.12)   # the fringe swept to her left
    for s in (-1, 1):
        hmask |= head.poly([(CX + s * 25, cy - 15), (CX + s * 27, cy - 1), (CX + s * 23, cy - 7), (CX + s * 22, cy - 13)])
    hmask = smooth(hmask, 1)
    paint(head, hmask, hair, round_px=8, round_amt=0.7)
    for a, b in (((CX - 16, cy - 28), (CX + 1, cy - 15)), ((CX - 5, cy - 32), (CX + 12, cy - 14)), ((CX + 7, cy - 30), (CX + 21, cy - 14))):
        stroke(head, [a, b], hair[4])
    for a, b in (((CX - 10, cy - 30), (CX + 6, cy - 15)), ((CX + 1, cy - 32), (CX + 17, cy - 14))):
        stroke(head, [a, b], hair[1])
    head.fill(head.edge(head.alpha(), 1, 0) & hmask, P.RIM)
    head.outline(OUTLINE, hmask)

    brows = brows_set(CX, cy, 13, hair[1], width=2, lift=0, span=7)
    mouths = mouth_frames(CX, cy + 21, skin, width=9, curve=-0.4)

    def sleeves(c, sides=(-1, 1)):
        for s in sides:
            sl = c.seg([(CX + s * 42, 145), (CX + s * 26, 156)], 14)
            paint(c, sl, coat, round_px=4)
            c.outline(OUTLINE, sl)
            cuff = c.seg([(CX + s * 28, 154), (CX + s * 23, 158)], 11)
            paint(c, cuff, coat, round_px=2, bias=-0.15)
            c.outline(OUTLINE, cuff)

    def flat(c, s, lifted=()):
        hand_rest(c, CX + s * 19, 157, 19, skin, lifted=lifted, side=1 if s < 0 else -1, h=13)

    for name, lf in (("hands_a", ()), ("hands_b", (3,))):    # "flat on the counter. In view."
        c = p[name]
        sleeves(c)
        flat(c, -1, lf)
        flat(c, 1)
    c = p["hands_react"]
    sleeves(c)
    fist(c, CX - 19, 156, 19, skin, knuckle="white", h=12, side=1)
    flat(c, 1)

    def raised_point(c):
        arm = c.seg([(CX - 44, 166), (CX - 30, 140)], 14)
        paint(c, arm, coat, round_px=4)
        c.outline(OUTLINE, arm)
        cuff = c.rrect(CX - 38, 133, CX - 22, 139, 2)
        paint(c, cuff, coat, round_px=2, bias=-0.15)
        c.outline(OUTLINE, cuff)
        fist(c, CX - 26, 121, 18, skin, h=13, side=1)
        tip = c.rrect(CX - 25, 129, CX - 19, 141, 2)
        paint(c, tip, skin, round_px=3, bias=0.16)
        c.outline(OUTLINE, tip)

    p["hands_point"] = c = layer()                       # "Got sharp, pointing."
    sleeves(c, sides=(1,))
    flat(c, 1)
    raised_point(c)
    p["hands_fist"] = c = layer()                        # "Went still. Her hand went to her belt."
    sleeves(c, sides=(1,))
    flat(c, 1)
    arm = c.seg([(CX - 46, 146), (CX - 16, 152)], 14)
    paint(c, arm, coat, round_px=4)
    c.outline(OUTLINE, arm)
    cuff = c.seg([(CX - 19, 151), (CX - 13, 152)], 12)
    paint(c, cuff, coat, round_px=2, bias=-0.15)
    c.outline(OUTLINE, cuff)
    fist(c, CX - 8, 146, 14, skin, h=11, side=-1)

    def free_hand(c, flat_, wet=True):
        if flat_:
            sl = c.seg([(CX + 52, 170), (140, 132)], 15)
            paint(c, sl, coat, round_px=4)
            c.outline(OUTLINE, sl)
            cuff = c.rrect(131, 124, 148, 131, 2)
            paint(c, cuff, coat, round_px=2, bias=-0.15)
            c.outline(OUTLINE, cuff)
            palm_flat(c, 138, 109, 25, skin, side=-1, h=15, wet=wet)
        else:
            sl = c.seg([(CX + 44, 168), (CX + 36, 142)], 14)
            paint(c, sl, coat, round_px=4)
            c.outline(OUTLINE, sl)
            cuff = c.rrect(CX + 28, 136, CX + 44, 141, 2)
            paint(c, cuff, coat, round_px=2, bias=-0.15)
            c.outline(OUTLINE, cuff)
            palm_up(c, CX + 36, 122, 21, skin, side=-1, h=13)

    p["hands_slam"] = c = layer()                        # "Slapped the glass, then said sorry."
    sleeves(c, sides=(-1,))
    flat(c, -1)
    free_hand(c, True, wet=False)

    # ---- the turn: the grid locks on, and a stun baton snaps out of her sleeve
    face_skin = (hm & ~hmask & ~housing) | (nk & (yy < 122))

    def turn_face(bloody):
        t = layer()
        roots = [(CX - 5, 121, -1.7, 30), (CX + 5, 121, -1.45, 28), (CX, 120, -1.6, 22),
                 (CX - 22, cy + 6, 0.6, 12), (CX + 22, cy + 8, 2.5, 12), (CX + 17, cy - 8, -1.3, 8)]
        threads(t, face_skin, roots, seed=103)
        t.glow(t.all(), "red1", tal, cy, 12, amt=0.85)
        t.fill(t.rrect(tal - 6, cy - 2, tal + 6, cy + 2, 1), "red0")
        for gx in range(tal - 6, tal + 7, 3):
            t.px(gx, cy - 1, "red2")
            t.px(gx, cy + 1, "red2")
        stroke(t, [(tal - 1, cy), (tal + 1, cy)], "red3")
        t.px(tal, cy, "white")
        wide_eye(t, CX + 13, cy, "33404c", bloody, skin)
        if bloody:                                       # the housing weeps
            blood_run(t, [(tal - 3, cy + 5), (tal - 4, cy + 12), (tal - 3, cy + 21)], wide=True)
            blood_run(t, [(tal + 4, cy + 5), (tal + 4, cy + 10)])
            blood_run(t, [(CX + 2, cy + 13), (CX + 2, cy + 16)], bead=False)
        return t

    p["turn"] = turn_face(True)
    p["turn_clean"] = turn_face(False)
    for tag, bloody in (("", True), ("_clean", False)):
        p["mouth_turn" + tag] = rictus(CX, cy + 21, skin, hw=8, gape=3, bloody=bloody)
        p["mouth_turn_b" + tag] = rictus(CX, cy + 21, skin, hw=8, gape=0, bloody=bloody)

    def baton_arm(c, elbow, wrist, ang, ln, phase, big=False):
        """Her right arm with the stun baton out of the sleeve: ang tilts it (0 is straight up), ln is
        how far it reaches past her fist. Returns its live head."""
        arm = c.seg([elbow, wrist], 15)
        paint(c, arm, coat, round_px=4)
        c.outline(OUTLINE, arm)
        bx, by = wrist
        cuff = c.rrect(bx - 8, by - 3, bx + 8, by + 3, 2)
        paint(c, cuff, coat, round_px=2, bias=-0.15)
        c.outline(OUTLINE, cuff)
        fx, fy = bx, by - 10
        ux, uy = np.sin(ang), -np.cos(ang)
        nx, ny = -uy, ux
        tx, ty = fx + ux * ln, fy + uy * ln
        rod = c.seg([(fx - ux * 9, fy - uy * 9), (tx, ty)], 5 if big else 4)
        c.fill(grow(rod, 1), "ink0")
        paint(c, rod, ["07090c", "121820", "1e2832", "34424e"], round_px=2)
        for t_ in (0.45, 0.7):
            gx, gy = fx + ux * ln * t_, fy + uy * ln * t_
            c.fill(c.seg([(gx - nx * 3, gy - ny * 3), (gx + nx * 3, gy + ny * 3)], 1) & grow(rod, 1), "steel2")
        for s in (-1, 1):                                # the two prongs
            pr = c.seg([(tx + nx * s * 1.5, ty + ny * s * 1.5), (tx + ux * 4 + nx * s * 1.5, ty + uy * 4 + ny * s * 1.5)], 1)
            c.fill(grow(pr, 1) & ~rod, "ink0")
            c.fill(pr, "steel5")
        fist(c, int(fx), int(fy) - 6, 17, skin, h=12, side=1)
        hx, hy = tx + ux * 5, ty + uy * 5
        c.glow(c.all(), "cyan3", hx, hy, 8 if big else 6, amt=0.6)
        crackle(c, hx, hy, 10 if big else 7, 5, seed=41 + int(phase * 10) + (5 if big else 0), cols=("dce8ff", "white"))
        c.fill(c.ell(hx, hy, 1.6, 1.6), "white")
        return hx, hy

    for tag, k in (("", 0), ("_b", 1)):
        a = layer()                                      # wind-up: the baton out, crackling
        baton_arm(a, (CX - 50, 170), (CX - 42, 134), (-0.15, -0.05)[k], 24, 0.5 * k)
        free_hand(a, False)
        p["attack" + tag] = a
        for clean, wet in (("", True), ("_clean", False)):
            a = layer()                                  # first blow: her palm on the glass
            baton_arm(a, (CX - 50, 170), (CX - 42, 134), (-0.25, -0.12)[k], 24, 0.5 * k + 0.25)
            free_hand(a, True, wet)
            p["attack_s1" + tag + clean] = a
            a = layer()                                  # second blow: the baton cracks on the glass
            hx, hy = baton_arm(a, (CX - 44, 172), (CX - 34 - k, 142), -0.6, 20, 0.5 * k, big=True)
            for ang in (-2.6, -1.9, -1.2, 2.7):
                r0, r1 = 7 + k, 12 + 2 * k
                stroke(a, [(hx + np.cos(ang) * r0, hy + np.sin(ang) * r0), (hx + np.cos(ang) * r1, hy + np.sin(ang) * r1)], "paper3")
            free_hand(a, True, wet)
            p["attack_s2" + tag + clean] = a

    p.update({"brows_" + k: v for k, v in brows.items()})
    p.update({"mouth_" + k: v for k, v in mouths.items()})
    meta = {"zones": {"eyes": [CX - 24, cy - 9, 48, 18], "hands": [CX - 42, 150, 84, 22], "port": [CX - 14, 98, 28, 26]},
            "face": {"brows": "neutral", "mouth": "closed"}, "blink": [3.0, 6.0], "mouth_y": cy + 21,
            "attack": {"style": "baton", "hand": [138, 108], "tool": [32, 112], "head": [CX, cy - 18], "face": [CX, cy + 8]},
            "gestures": {"point": "hands_point", "fist": "hands_fist", "slam": "hands_slam"}}
    return p, meta


# ====================================================================== Bo
def bo():
    p = new_patient()
    skin, tank, chrome = SKIN["bo"], CLOTH["tank"], CLOTH["chrome"]
    cy = 72
    body, head = p["body"], p["head"]
    yy, xx = body.grid()

    # bare shoulders sloping off a thick neck, a dark tank top
    sh = smooth(body.poly([(CX - 13, 98), (CX + 13, 98), (CX + 30, 112), (CX + 50, 118), (CX + 63, 128), (CX + 70, 146),
                           (CX + 72, 162), (CX - 72, 162), (CX - 70, 146), (CX - 63, 128), (CX - 50, 118), (CX - 30, 112)]), 3)
    sh &= yy < BASE_Y
    paint(body, sh, skin, round_px=16, round_amt=0.6)
    body.fill(sh & body.ell(CX, 101, 15, 5), skin[1])    # under the jaw
    body.dither(sh & body.ell(CX, 104, 16, 6) & (yy >= 103), skin[1], 0.5)
    for s in (-1, 1):
        stroke(body, [(CX + s * 10, 103), (CX + s * 4, 116)], skin[2])                          # the neck cords
        stroke(body, [(CX + s * 5, 119), (CX + s * 27, 115)], skin[4])                          # collarbones
        stroke(body, [(CX + s * 5, 120), (CX + s * 27, 116)], skin[2])
        stroke(body, [(CX + s * 50, 121), (CX + s * 60, 131), (CX + s * 61, 146)], skin[2])     # the shoulder
    finish(body, sh)
    tk = smooth(body.poly([(CX - 32, 117), (CX - 24, 117), (CX - 14, 131), (CX + 14, 131), (CX + 24, 117), (CX + 32, 117),
                           (CX + 42, 162), (CX - 42, 162)]), 2) & (yy < BASE_Y)
    paint(body, tk, tank, round_px=8)
    body.outline(OUTLINE, tk)
    bx_, by_ = CX + 55, 138                              # a bell on his left shoulder, for the round
    bell = body.poly([(bx_ - 4, by_ + 4), (bx_ - 3, by_ - 2), (bx_, by_ - 4), (bx_ + 3, by_ - 2), (bx_ + 4, by_ + 4)])
    body.fill(grow(bell, 1) & ~bell & sh, "1a3040")
    body.dither(bell, "2a4a5a", 0.5)
    body.px(bx_, by_ + 5, "1a3040")

    for s in (-1, 1):
        ear = head.ell(CX + s * 28, cy + 2, 4.8, 6.6)
        paint(head, ear, skin, round_px=3)
        head.dither(ear & head.ell(CX + s * 28, cy + 1, 2.4, 3.2), skin[1], 0.5)
        head.outline(OUTLINE, ear)
    hm = head_mask(head, CX, cy, 56, 58, jaw=0.96, chin=0.6)
    paint(head, hm, skin, round_px=14, round_amt=0.7)
    buzz = hm & head.ell(CX, cy - 14, 27, 16) & (yy < cy - 16)
    head.dither(buzz, "3a2a20", 0.6)
    head.dither(buzz & (yy < cy - 22), "3a2a20", 0.8)
    head.fill(head.edge(hm, 1, 0), P.RIM)
    nose(head, CX + 1, cy + 1, cy + 13, skin, w=4)        # broken more than once
    stroke(head, [(CX - 1, cy + 2), (CX + 1, cy + 5)], skin[5])
    head.px(CX + 2, cy + 6, skin[2])
    head.outline(OUTLINE, hm)
    holes = [almond(head, CX + s * 14, cy, 6.0, 3.4) for s in (-1, 1)]
    eye_whites(body, holes)
    for i, hmk in enumerate(holes):
        head.erase(hmk)
        lid_lines(head, hmk, skin)
        natural_pupil(p["pupils"], CX + (-14 if i == 0 else 14), cy, ("24160c", "6a4424"), r=3.0)
        blink(p["lids"], hmk, skin)
    head.dither(hm & head.ell(CX + 14, cy + 1, 9, 6) & ~grow(holes[1], 1), "7a4a6a", 0.4)   # the left eye swollen
    head.dither(hm & head.ell(CX + 15, cy - 13, 8, 3.2), "b8645a", 0.4)                   # the fresh cut over it, swollen, one strip on it
    stroke(head, [(CX + 9, cy - 12), (CX + 21, cy - 14)], "red1")
    stroke(head, [(CX + 12, cy - 13), (CX + 18, cy - 14)], "red0")
    head.fill(head.rect(CX + 14, cy - 16, CX + 15, cy - 11), "paper2")
    head.fill(head.rect(CX + 14, cy - 11, CX + 15, cy - 11), "paper1")
    head.px(CX + 3, cy + 23, "red1")                     # the split lip
    head.px(CX + 3, cy + 24, "red0")

    brows = brows_set(CX, cy, 14, "2a1a14", width=3, lift=-1, span=8)
    mouths = mouth_frames(CX, cy + 21, skin, width=11, curve=0.9, lip="9a4a44")

    def piston(c, x, y, jerk=0, cocked=False):
        """His right arm on the sill: skin down to the chrome seam at the elbow, the PISTON below it
        and its fist. Returns the bare skin above the seam (the socket left out) and the socket."""
        up = c.rrect(x - 11, y - 31, x + 11, y - 17, 4)
        paint(c, up, skin, round_px=5)
        c.outline(OUTLINE, up)
        j = jerk
        fore = c.rrect(x - 10 + j, y - 17 + j, x + 10 + j, y + 1 + j, 3)
        paint(c, fore, chrome, round_px=5, bias=-0.06)
        for t_ in (y - 10 + j, y - 4 + j):
            stroke(c, [(x - 9 + j, t_), (x + 9 + j, t_)], chrome[1])
        c.outline(OUTLINE, fore)
        rx = x - 7 + j                                   # the piston down the outside of it
        cyl = c.rect(rx - 2, y - 15 + j, rx + 1, y - 7 + j)
        c.fill(grow(cyl, 1), OUTLINE)
        paint(c, cyl, CLOTH["vest"], round_px=2)
        rod = c.rect(rx - 1, y - 7 + j, rx, y - 1 + j - (5 if cocked else 0))
        c.fill(rod, "steel5")
        seam = c.rrect(x - 12, y - 19, x + 12, y - 15, 1)
        paint(c, seam, chrome, round_px=2)
        c.outline(OUTLINE, seam)
        sx, sy = x + 5, y - 23                           # the WORK socket where the chrome meets him
        wrist_port(c, sx, sy, scar=skin[5])
        for dx_ in (-9, -5, 9):
            stroke(c, [(x + dx_, y - 20), (x + dx_ + 1, y - 24)], skin[5])
        if cocked:                                       # "The piston cocked": the fist drawn back, hissing
            fist(c, x + j, y - 4, 22, chrome, knuckle="white", h=12, side=1)
            for s in (-1, 1):
                c.dither(c.ell(x + s * 14, y - 12, 3.5, 2.5), "paper1", 0.5)
                c.dither(c.ell(x + s * 16, y - 15, 2.5, 2.0), "paper3", 0.4)
        else:
            fist(c, x + j, y - 1 + j, 22, chrome, knuckle="white", h=12, side=1)
        return (up & ~c.ell(sx, sy, 3.8, 3.8) & ~grow(seam, 1)), (sx, sy)

    def left_arm(c, x, y):
        arm = c.rrect(x - 11, y - 30, x + 11, y, 4)
        paint(c, arm, skin, round_px=5)
        stroke(c, [(x - 4, y - 26), (x - 3, y - 6)], skin[4])
        c.outline(OUTLINE, arm)
        hand = hand_rest(c, x, y, 21, skin, side=-1, h=13)
        tape = (c.rect(x - 9, y + 2, x + 9, y + 4) & hand) | (c.rect(x - 11, y - 5, x + 11, y - 2) & arm)
        c.fill(tape, "paper2")
        c.fill(tape & c.edge(tape, 0, -1), "paper3")

    bare = {}
    for name, j in (("hands_a", 0), ("hands_b", -2)):    # "It jerks."
        c = p[name]
        bare[name] = piston(c, CX - 32, 158, jerk=j)
        left_arm(c, CX + 32, 158)
    c = p["hands_react"]                                 # "Puffed up, hands up": a guard
    up = c.seg([(CX - 50, 176), (CX - 40, 152)], 20)
    paint(c, up, skin, round_px=5)
    c.outline(OUTLINE, up)
    fore = c.seg([(CX - 40, 150), (CX - 34, 126)], 18)
    paint(c, fore, chrome, round_px=5, bias=-0.06)
    c.outline(OUTLINE, fore)
    seam = c.seg([(CX - 51, 151), (CX - 29, 149)], 4)
    paint(c, seam, chrome, round_px=2)
    c.outline(OUTLINE, seam)
    wrist_port(c, CX - 40, 157, scar=skin[5])
    fist(c, CX - 34, 112, 22, chrome, knuckle="white", h=14, side=1)
    bare["hands_react"] = (up & ~c.ell(CX - 40, 157, 3.8, 3.8) & ~grow(seam, 1)), (CX - 40, 157)
    arm = c.seg([(CX + 48, 176), (CX + 34, 126)], 19)
    paint(c, arm, skin, round_px=5)
    c.outline(OUTLINE, arm)
    c.fill(c.seg([(CX + 26, 128), (CX + 43, 130)], 3) & arm, "paper2")
    fist(c, CX + 34, 112, 22, skin, knuckle="paper3", h=14, side=-1)
    p["hands_fist"] = c = layer()                        # "Went quiet. The piston cocked."
    bare["hands_fist"] = piston(c, CX - 32, 158, cocked=True)
    left_arm(c, CX + 32, 158)

    def free_hand(c, flat, wet=True):
        if flat:
            arm = c.seg([(CX + 58, 174), (140, 124)], 21)
            paint(c, arm, skin, round_px=5)
            c.outline(OUTLINE, arm)
            c.fill(c.seg([(130, 127), (151, 129)], 3) & arm, "paper2")
            palm_flat(c, 138, 109, 27, skin, side=-1, h=16, wet=wet)
        else:
            arm = c.seg([(CX + 50, 174), (CX + 40, 130)], 20)
            paint(c, arm, skin, round_px=5)
            c.outline(OUTLINE, arm)
            c.fill(c.seg([(CX + 31, 131), (CX + 49, 133)], 3) & arm, "paper2")
            fist(c, CX + 40, 116, 22, skin, knuckle="paper3", h=14, side=-1)

    p["hands_slam"] = c = layer()                        # "Slapped the glass, then laughed."
    bare["hands_slam"] = piston(c, CX - 32, 158)
    free_hand(c, True, wet=False)
    for name, (m, (sx, sy)) in bare.items():             # threads climbing the arm from the seam
        a0 = 1.57 if name == "hands_react" else -1.57
        p[name + "_t"] = twin(p[name], m, port_roots(sx, sy, ((a0, 12), (a0 - 0.7, 10), (a0 + 0.7, 10), (a0 - 1.5, 8), (a0 + 1.5, 8))), seed=107)

    # ---- the turn: the PISTON hisses and cocks, a spike out between the knuckles
    face_skin = (hm | (sh & ~tk & (yy < 122) & (np.abs(xx - CX) < 40))) & ~grow(holes[0] | holes[1], 1)

    def turn_face(bloody):
        t = layer()
        roots = [(CX - 10, 116, -1.62, 32), (CX + 10, 116, -1.5, 30), (CX, 112, -1.57, 24), (CX - 30, 120, -1.1, 14),
                 (CX + 30, 120, -2.0, 14), (CX - 24, cy + 12, -1.7, 12), (CX + 24, cy + 10, -1.4, 12)]
        threads(t, face_skin, roots, seed=109)
        for s in (-1, 1):
            wide_eye(t, CX + s * 14, cy, "24160c", bloody, skin, rx=7.6, ry=5.0)
        if bloody:                                       # the cut opens, and the lip splits again
            blood_run(t, [(CX + 14, cy - 13), (CX + 15, cy - 8), (CX + 20, cy - 2), (CX + 21, cy + 8)], wide=True)
            blood_run(t, [(CX + 3, cy + 24), (CX + 3, cy + 29)])
            blood_run(t, [(CX - 2, cy + 14), (CX - 2, cy + 17)], bead=False)
        return t

    p["turn"] = turn_face(True)
    p["turn_clean"] = turn_face(False)
    for tag, bloody in (("", True), ("_clean", False)):
        p["mouth_turn" + tag] = rictus(CX, cy + 21, skin, hw=10, gape=4, bloody=bloody)
        p["mouth_turn_b" + tag] = rictus(CX, cy + 21, skin, hw=10, gape=1, bloody=bloody)

    def spike_arm(c, elbow, wrist, tip, big=False, k=0):
        """His right arm: the skin of it down to the chrome seam at the elbow, the PISTON forearm, the
        fist, and the spike out between the knuckles to tip."""
        (ax, ay), (bx, by), (tx, ty) = elbow, wrist, tip
        ln = max(1e-6, float(np.hypot(bx - ax, by - ay)))
        dx, dy = (bx - ax) / ln, (by - ay) / ln
        nx, ny = -dy, dx
        up = c.seg([(ax - dx * 24, ay - dy * 24), (ax, ay)], 20)
        paint(c, up, skin, round_px=5)
        c.outline(OUTLINE, up)
        fore = c.seg([(ax, ay), (bx, by)], 18)
        paint(c, fore, chrome, round_px=5, bias=-0.06)
        c.outline(OUTLINE, fore)
        rod = c.seg([(ax + nx * 8 + dx * 4, ay + ny * 8 + dy * 4), (bx + nx * 8 - dx * 6, by + ny * 8 - dy * 6)], 3)
        c.fill(grow(rod, 1), OUTLINE)
        paint(c, rod, CLOTH["vest"], round_px=2)
        seam = c.seg([(ax - nx * 11, ay - ny * 11), (ax + nx * 11, ay + ny * 11)], 4)
        paint(c, seam, chrome, round_px=2)
        c.outline(OUTLINE, seam)
        wrist_port(c, ax - dx * 6 - nx * 4, ay - dy * 6 - ny * 4, scar=skin[5])
        for s in (-1, 1):                                # it hisses
            sx, sy = ax + nx * s * 14 + dx * 6, ay + ny * s * 14 + dy * 6
            c.dither(c.ell(sx, sy, 3.5, 2.5), "paper1", 0.5)
            c.dither(c.ell(sx + s * 2, sy - 3, 2.5, 2.0), "paper3", 0.4)
        fw = 26 if big else 22
        fx, fy = int(bx + dx * 2), int(by + dy * 2)
        fist(c, fx, fy - 12, fw, chrome, knuckle="white", h=13, side=1)
        cone(c, fx, fy - 11, tx, ty, 3.6 if big else 3.0)

    for tag, k in (("", 0), ("_b", 1)):
        a = layer()                                      # wind-up: cocked, the spike out
        spike_arm(a, (CX - 52, 166), (CX - 42, 130), (CX - 45 - k, 94 - k))
        free_hand(a, False)
        p["attack" + tag] = a
        for clean, wet in (("", True), ("_clean", False)):
            a = layer()                                  # first blow: his palm on the glass
            spike_arm(a, (CX - 52, 166), (CX - 42, 130), (CX - 46 + k, 95))
            free_hand(a, True, wet)
            p["attack_s1" + tag + clean] = a
            a = layer()                                  # second blow: the spike punches the glass
            spike_arm(a, (CX - 46, 176), (40 - k, 140), (32, 114), big=True)
            for ang in (-2.7, -2.0, -1.2, 2.7):
                r0, r1 = 5 + k, 10 + 2 * k
                stroke(a, [(32 + np.cos(ang) * r0, 114 + np.sin(ang) * r0), (32 + np.cos(ang) * r1, 114 + np.sin(ang) * r1)], "paper3")
            free_hand(a, True, wet)
            p["attack_s2" + tag + clean] = a

    p.update({"brows_" + k: v for k, v in brows.items()})
    p.update({"mouth_" + k: v for k, v in mouths.items()})
    meta = {"zones": {"eyes": [CX - 26, cy - 9, 52, 18], "hands": [CX - 48, 150, 96, 22], "port": [CX - 38, 127, 22, 16]},
            "face": {"brows": "neutral", "mouth": "closed"}, "blink": [2.0, 4.5], "mouth_y": cy + 21,
            "attack": {"style": "spike", "hand": [138, 108], "tool": [32, 114], "head": [CX, cy - 18], "face": [CX, cy + 8]},
            "gestures": {"raise": "hands_react", "fist": "hands_fist", "slam": "hands_slam"}}
    return p, meta


# ====================================================================== export
ORDER = ["body", "pupils", "head"]


def compose(p, brows="neutral", mouth="closed", hands="hands_a", lids=False, bg=None, pupils="pupils", turn=None, body="body",
            head="head"):
    c = Canvas(W, H, bg)
    c.blit(p[body])
    c.blit(p[pupils if pupils in p else "pupils"])
    c.blit(p[head])
    c.blit(p["brows_" + brows])
    if turn:
        c.blit(p[turn])
    c.blit(p["mouth_" + mouth])
    if lids:
        c.blit(p["lids"])
    c.blit(p[hands])
    return c


BUILDERS = {"kip": kip, "rook": rook, "vale": vale, "juno": juno, "maren": maren,
            "priya": priya, "ozzie": ozzie, "lux": lux, "dana": dana, "bo": bo}


def main(only=None):
    metas = {}
    meta_path = os.path.join(ASSETS, "patients", "meta.json")
    if os.path.exists(meta_path):
        with open(meta_path, encoding="utf-8") as f:
            metas = json.load(f)
    for pid, fn in BUILDERS.items():
        if only and pid not in only:
            continue
        p, meta = fn()
        for k, c in p.items():
            c.save("patients/%s/%s.png" % (pid, k))
        sil = silhouette([p["body"], p["head"]])
        sil.save("patients/%s/hallcam.png" % pid)
        meta["layers"] = sorted(p.keys())
        metas[pid] = meta
        sheet = [("neutral", compose(p, bg="teal2")),
                 ("default", compose(p, meta["face"]["brows"], meta["face"]["mouth"], bg="teal2")),
                 ("talk a", compose(p, meta["face"]["brows"], "a", "hands_b", bg="teal2", pupils="pupils_b")),
                 ("talk b / blink", compose(p, "neutral", "b", "hands_b", lids=True, bg="teal2")),
                 ("upset", compose(p, "worried", "upset", "hands_react", bg="teal2")),
                 ("angry", compose(p, "angry", "angry", "hands_react", bg="teal2", pupils="pupils_react")),
                 ("cam", sil)]
        face = meta["face"]
        for g, name in sorted(meta["gestures"].items()):
            sheet.append(("%s: %s" % (g, name[6:]), compose(p, face["brows"], face["mouth"], name, bg="teal2")))
        for t in sorted(k for k in p if k.endswith("_t")):
            if t.startswith("hands_"):
                sheet.append((t[6:-2] + " threads", compose(p, face["brows"], face["mouth"], t, bg="teal2")))
            else:
                sheet.append((t[:-2] + " threads", compose(p, face["brows"], face["mouth"], bg="teal2", **{t[:-2]: t})))
        if "attack" in p:
            b = "worried" if meta["attack"]["style"] == "torch" else "angry"
            sheet += [("turn", compose(p, b, "turn", "attack", bg="teal2", turn="turn")),
                      ("blow 1", compose(p, b, "turn_b", "attack_s1_b", bg="teal2", turn="turn")),
                      ("blow 2", compose(p, b, "turn", "attack_s2", bg="teal2", turn="turn")),
                      ("blow 2 b, clean", compose(p, b, "turn_b_clean", "attack_s2_b_clean", bg="teal2", turn="turn_clean"))]
        contact_sheet(sheet, os.path.join(OUT, "patient_%s.png" % pid), scale=3, per_row=4)
    with open(meta_path, "w", encoding="utf-8", newline="\n") as f:
        json.dump(metas, f, indent=1, sort_keys=True)
    print("patients written:", ", ".join(sorted(metas)))


if __name__ == "__main__":
    main(sys.argv[1:] or None)
