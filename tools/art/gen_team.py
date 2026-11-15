"""Trauma Team art: the call box on the desk, the dispatch imprint on the intake card and
the two responders who come in through the hall door.

Run from tools/art:  python gen_team.py

The crew is our own design: dark armour, an amber visor bar and a teal pulse-line badge,
seen against the street light of the open door. No emblem or outfit is taken from another
game, and the medical cross is deliberately not used.
"""
import os

import numpy as np

from font_data import text_width
from gen_clinic import HOLE, hall, hall_door_open, text_mask
from gen_ui import IH, IW, OUTLINE, shadow
from people import grow, smooth, stroke
from px import OUT, Canvas, bayer, contact_sheet

PULSE = [(0, 4), (4, 4), (6, 0), (9, 8), (11, 2), (13, 4), (18, 4)]     # the badge: one heartbeat
TEAM_POS = (104, 26)             # where team.png sits inside the window opening when they are in
TEAM_W, TEAM_H = 116, 160


def pulse_pts(x, y, sx=1.0, sy=1.0):
    return [(x + px * sx, y + py * sy) for px, py in PULSE]


# ------------------------------------------------------------------ desk
def call_box(armed=False):
    """A wall call box: a pulse screen and one red button under a clear guard."""
    c = Canvas(IW, IH)
    body = c.rrect(4, 3, 31, 35, 3)
    shadow(c, body)
    c.shade(body, ["2a0a0e", "5a1418", "8a1c1c", "a8262a"], light=(-0.7, -0.6), round_px=4)
    c.outline(OUTLINE, body)
    c.fill(c.rect(6, 5, 29, 5), "c8483c")
    # screen
    scr = c.rect(8, 7, 27, 15)
    c.fill(grow(scr, 1) & body, "0b1014")
    c.fill(scr, "14484f" if armed else "0a2e34")
    stroke(c, pulse_pts(9, 7), "c8fff6" if armed else "2a8f96")
    if armed:
        c.px(9, 8, "ff7a6a")
        c.px(26, 8, "ff7a6a")
    # the button in its well
    well = c.ell(17.5, 25.5, 8.4, 7.6)
    c.fill(well, "0b1014")
    btn = c.ell(17.5, 25.5, 6.2, 5.6)
    if armed:
        c.fill(c.ell(17.5, 25.5, 9.6, 8.8) & body & ~well, "e8704a")
        c.shade(btn, ["c8483c", "e8704a", "ff9a7a", "fbe9b5"], light=(-0.5, -0.6), round_px=3)
        c.px(15, 23, "ffffff")
        c.px(16, 23, "ffffff")
        # the guard stands open above the button
        c.fill(c.rect(9, 16, 26, 17), "7fbfb0")
        c.fill(c.rect(9, 16, 26, 16), "c8fff6")
    else:
        c.shade(btn, ["3a0d10", "6a1418", "a02024", "c8483c"], light=(-0.5, -0.6), round_px=3)
        guard = c.rrect(8, 17, 27, 34, 2)
        frame = guard & ~c.rrect(9, 18, 26, 33, 2)
        c.fill(guard & (bayer(IH, IW) < 0.3), "7fbfb0")
        c.fill(frame, "4c8a8c")
        stroke(c, [(11, 23), (15, 19)], "c8fff6")
        stroke(c, [(14, 24), (17, 21)], "b9e3d0")
        c.fill(c.rect(15, 17, 20, 17), "a3b5b6")          # the hinge
    return c


def ink_team(color="c8281c", w=76, h=24, seed=5):
    """The dispatch imprint that lands on the intake card when the call goes out."""
    c = Canvas(w, h)
    frame = c.rrect(0, 0, w - 1, h - 1, 3) & ~c.rrect(2, 2, w - 3, h - 3, 2)
    ring = c.ell(13.5, 11.5, 8.6, 8.6) & ~c.ell(13.5, 11.5, 6.9, 6.9)
    beat = c.seg(pulse_pts(6, 8, 0.84, 0.9), 1)
    beat |= np.roll(beat, 1, axis=0)
    tx = 27
    words = text_mask(w, h, tx, 2, "TRAUMA", bold=True) | text_mask(w, h, tx, 12, "TEAM", bold=True)
    rule = c.rect(tx + text_width("TEAM", True) + 4, 15, w - 6, 16) | c.rect(tx + text_width("TEAM", True) + 4, 19, w - 12, 19)
    m = frame | ring | (beat & c.ell(13.5, 11.5, 6.9, 6.9)) | words | rule
    rng = np.random.default_rng(seed)
    noise = rng.random((h, w))
    worn = (noise < 0.08) | ((bayer(h, w) > 0.86) & (noise < 0.45))
    c.fill(m & ~worn, color)
    c.fill(m & worn & (noise > 0.05), color, 110)
    return c


# ------------------------------------------------------------------ the crew
def responder(c, lights, cx, top, scale, beacon, tool):
    """One armoured figure, mostly a shape against the door light. Returns its mask."""
    def S(v):
        return v * scale

    yy, xx = c.grid()
    helmet = c.ell(cx, top + S(11), S(9.5), S(11)) | c.rect(cx - S(9), top + S(11), cx + S(9), top + S(19))
    neck = c.rect(cx - S(5), top + S(19), cx + S(5), top + S(25))
    shoulders = c.rrect(cx - S(25), top + S(23), cx + S(25), top + S(40), int(S(6)))
    chest = c.poly([(cx - S(21), top + S(30)), (cx + S(21), top + S(30)), (cx + S(16), top + S(76)), (cx - S(16), top + S(76))])
    belt = c.rect(cx - S(17), top + S(74), cx + S(17), top + S(81))
    arm_l = c.seg([(cx - S(22), top + S(32)), (cx - S(25), top + S(58)), (cx - S(21), top + S(80))], int(S(10)))
    arm_r = c.seg([(cx + S(22), top + S(32)), (cx + S(25), top + S(58)), (cx + S(21), top + S(80))], int(S(10)))
    leg_l = c.poly([(cx - S(17), top + S(80)), (cx - S(1), top + S(80)), (cx - S(3), top + S(150)), (cx - S(16), top + S(150))])
    leg_r = c.poly([(cx + S(1), top + S(80)), (cx + S(17), top + S(80)), (cx + S(16), top + S(150)), (cx + S(3), top + S(150))])
    body = smooth(helmet | neck | shoulders | chest | belt | arm_l | arm_r | leg_l | leg_r, 1)

    c.fill(body, "0b1014")
    # plates catch a little of the counter lamp on the near side
    plate = (shoulders | chest) & body
    c.shade(plate, ["07090c", "0b1014", "121c22", "1a2a31", "244049"], light=(-0.9, -0.3), round_px=5, contrast=1.2)
    c.shade(helmet & body, ["07090c", "0b1014", "121c22", "1a2a31", "2e3a42"], light=(-0.9, -0.5), round_px=4, contrast=1.2)
    c.fill(belt & body, "07090c")
    c.fill(c.rect(cx - S(4), top + S(75), cx + S(4), top + S(80)) & body, "2e3a42")
    # plate seams
    c.fill(c.rect(cx - S(14), top + S(52), cx + S(14), top + S(52)) & body, "07090c")
    c.fill(c.rect(cx, top + S(40), cx, top + S(74)) & body, "07090c")
    for knee_x in (cx - S(9), cx + S(9)):
        knee = c.ell(knee_x, top + S(112), S(6), S(7)) & body
        c.shade(knee, ["0b1014", "121c22", "1a2a31", "244049"], light=(-0.9, -0.4), round_px=3, bias=0.12)
    # street neon on the far edge, lamp on the near edge
    c.rim(body, 1, 0, "a02a5e")
    c.rim(body & (yy < top + S(60)), 1, 0, "e0457b")
    c.rim(body & (yy < top + S(100)), -1, 0, "33606a")
    c.rim(helmet & body, 0, -1, "33606a")
    c.outline("07090c", body)

    # the visor bar and the badge are the only bright things on them
    visor = c.rect(cx - S(7), top + S(10), cx + S(7), top + S(12)) & body
    c.fill(visor, "e0a030")
    c.fill(c.rect(cx - S(3), top + S(10), cx + S(4), top + S(10)) & body, "fbe9b5")
    badge = pulse_pts(cx - S(9), top + S(43), S(0.95), S(0.8))
    stroke(c, badge, "5ee6e0")
    lights.fill(grow(visor, 1), "e0a030", 70)
    lights.fill(visor, "fbe9b5", 150)

    if tool == "pole":
        # a catch pole, held upright in the near hand
        px = cx - S(27)
        pole = c.seg([(px, top + S(84)), (px + S(3), top - S(6))], 2)
        c.fill(pole, "70838a")
        c.fill(c.seg([(px + 1, top + S(84)), (px + S(3) + 1, top - S(6))], 1), "2e3a42")
        loop = c.ell(px + S(3), top - S(11), S(5), S(6)) & ~c.ell(px + S(3), top - S(11), S(3.4), S(4.4))
        c.fill(loop, "a3b5b6")
        c.fill(c.rect(px - 2, top + S(56), px + 3, top + S(64)), "0b1014")
        body = body | pole | loop
    elif tool == "case":
        # a hard case with the pulse badge, carried low on the far side
        x0, y0 = cx + S(15), top + S(84)
        box = c.rrect(x0, y0, x0 + S(22), y0 + S(17), 2)
        c.shade(box, ["0b1014", "1a2a31", "244049", "33606a"], light=(-0.8, -0.4), round_px=3)
        c.outline("07090c", box)
        c.fill(c.rect(x0 + S(7), y0 - 3, x0 + S(15), y0 - 1), "2e3a42")
        c.fill(c.rect(x0 + 2, y0 + S(8), x0 + S(20), y0 + S(8)), "e0a030")
        body = body | box

    bx, by = beacon
    c.fill(c.rect(bx - 1, by - 2, bx + 2, by), "2e3a42")
    return body, (bx, by)


def beacon_glow(c, bx, by, core, mid, far):
    yy, xx = c.grid()
    c.glow(c.all(), far, bx + 0.5, by - 1, 15, amt=0.75, power=1.3)
    c.glow(c.all(), mid, bx + 0.5, by - 1, 8, amt=0.95, power=1.0)
    c.fill(c.rect(bx - 1, by - 3, bx + 2, by - 1), core)
    c.px(bx, by - 3, "ffffff")


def team():
    """Returns (bodies, steady lights, red beacon frame, blue beacon frame)."""
    c = Canvas(TEAM_W, TEAM_H)
    lights = Canvas(TEAM_W, TEAM_H)
    # the far one first, then the lead in front of them
    back_cx, back_top, back_s = 84, 16, 0.86
    lead_cx, lead_top, lead_s = 42, 8, 1.0
    b_mask, b_beacon = responder(c, lights, back_cx, back_top, back_s,
                                 (int(back_cx + 20 * back_s), int(back_top + 22 * back_s)), "case")
    l_mask, l_beacon = responder(c, lights, lead_cx, lead_top, lead_s,
                                 (int(lead_cx - 22 * lead_s), int(lead_top + 22 * lead_s)), "pole")
    del b_mask, l_mask
    red = Canvas(TEAM_W, TEAM_H)
    blue = Canvas(TEAM_W, TEAM_H)
    beacon_glow(red, l_beacon[0], l_beacon[1], "ff7a6a", "e23b3b", "a02024")
    beacon_glow(blue, b_beacon[0], b_beacon[1], "c8fff6", "5ee6e0", "2a8f96")
    return c, lights, red, blue


def main():
    cb, cba = call_box(False), call_box(True)
    cb.save("ui/call_team.png")
    cba.save("ui/call_team_armed.png")
    ink = ink_team()
    ink.save("ui/ink_refer.png")
    body, lights, red, blue = team()
    body.save("clinic/team.png")
    lights.save("clinic/team_lights.png")
    red.save("clinic/team_red.png")
    blue.save("clinic/team_blue.png")

    os.makedirs(OUT, exist_ok=True)
    contact_sheet([("call_team", cb), ("armed", cba), ("ink_refer", ink)], os.path.join(OUT, "team_ui.png"),
                  scale=6, per_row=3, bg="teal1")
    # review composite: the crew in the open doorway, both beacon frames
    W, H = HOLE[2], HOLE[3]
    comp = Canvas(W * 2 + 6, H, "ink0")
    for i, frame in enumerate((red, blue)):
        scene = hall()
        scene.blit(hall_door_open(), 0, 0)
        scene.blit(body, TEAM_POS[0], TEAM_POS[1])
        scene.blit(lights, TEAM_POS[0], TEAM_POS[1])
        scene.blit(frame, TEAM_POS[0], TEAM_POS[1])
        comp.blit(scene, i * (W + 6), 0)
    comp.scaled(3).image().convert("RGB").save(os.path.join(OUT, "team_scene.png"))
    print("team art written")


if __name__ == "__main__":
    main()
