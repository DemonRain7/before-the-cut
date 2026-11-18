"""The staff side of the counter, as the doctor sees it from the chair.

The service window fills the middle of the screen at twice the size of everything else: the
game draws the hall, the visitor, the glass and the shutter there. This file paints what is on
the doctor's side of the glass, at screen resolution: the two side walls with their pinboards
and instruments, the desk along the bottom, the lamp, and the things that hang or lie there
and open when they are clicked.

Screen layout (640 x 360):
  window      100,0    440 x 300   transparent here; view pixels are 2 x 2 screen pixels
  left wall     0,0    100 x 300   pinboard (reference sheet, contact list), lender's meter, hall monitor
  right wall  540,0    100 x 300   pinboard (intake card, counter guide), control plate with four pads
  desk          0,300  640 x 60    tool mat, transcript (drawn by the game), talk mat
"""
import os

import numpy as np

from font_data import draw_text, text_width
from gen_ui import pad, shadow
from px import ASSETS, OUT, Canvas, from_image

WIN = (100, 0, 440, 300)
METER = (6, 172, 88, 48)          # the lender's meter: the lit face the game writes on
THUMB = (17, 232, 66, 47)         # the hall monitor on the wall: half the size of the real picture
CAM_GLASS = (7, 7, 132, 94)       # the glass inside cam_panel.png
VIEW = (-240, -100, 2)            # where the old 640 x 360 scene space lands on the screen


def walls(c):
    yy, xx = c.grid()
    left = c.rect(0, 0, 99, 299)
    right = c.rect(540, 0, 639, 299)
    both = left | right
    c.grad(both, ["ink0", "ink1", "teal1"], 0, -60, 0, 340, dither=1.0)
    for x in (9, 31, 53, 75, 564, 586, 608, 630):
        c.fill(c.rect(x, 0, x, 299), "ink0")
    # the lamp spills on the wall beside it; the far side only gets what the room gives back
    c.glow(left, "teal2", 120, 250, 150, amt=0.8, power=1.3)
    c.glow(left, "warm1", 112, 262, 80, amt=0.7, power=1.2)
    c.glow(left, "warm2", 106, 272, 36, amt=0.6, power=1.2)
    c.glow(right, "teal2", 528, 268, 110, amt=0.55, power=1.3)

    # window frame: a steel upright on each side, riveted
    fl = c.rect(94, 0, 99, 299)
    fr = c.rect(540, 0, 545, 299)
    c.fill(fl | fr, "steel1")
    c.fill(c.rect(94, 0, 94, 299), "steel2")
    c.fill(c.rect(99, 0, 99, 299), "ink0")
    c.fill(c.rect(540, 0, 540, 299), "steel2")
    c.fill(c.rect(545, 0, 545, 299), "steel0")
    c.glow(fl, "warm3", 110, 262, 90, amt=0.7)
    c.glow(fl, "steel4", 104, 268, 40, amt=0.5)
    c.glow(fr, "steel3", 536, 270, 60, amt=0.5)
    for y in range(10, 300, 46):
        for x in (96, 542):
            c.px(x, y, "steel4")
            c.px(x, y + 1, "ink0")
            c.px(x + 1, y, "steel3")


def pinboard(c, x0, y0, x1, y1, glow_x):
    fr = c.rrect(x0, y0, x1, y1, 2)
    c.fill(fr, "warm1")
    c.fill(c.rect(x0, y0, x1, y0), "warm3")
    c.outline("ink0", fr)
    cork = c.rect(x0 + 3, y0 + 3, x1 - 3, y1 - 3)
    c.fill(cork, "warm2")
    c.dither(cork, "warm3", 0.45)
    c.speckle(cork, "warm4", 0.04, seed=x0 + 5)
    c.speckle(cork, "warm1", 0.06, seed=x0 + 6)
    c.glow(cork, "warm4", glow_x, y1 + 60, 120, amt=0.5)
    c.fill(c.rect(x0 + 3, y0 + 3, x1 - 3, y0 + 3), "warm0")
    c.fill(c.rect(x0 + 3, y0 + 3, x0 + 3, y1 - 3), "warm0")


def meter(c):
    x, y, w, h = METER
    hous = c.rrect(x - 4, y - 4, x + w + 3, y + h + 3, 3)
    c.shade(hous, "steel_dark", light=(0.7, 0.5), contrast=0.8, round_px=4, round_amt=0.5, bias=-0.06)
    c.outline("ink0", hous)
    c.fill(c.rect(x - 1, y - 1, x + w, y + h), "ink0")
    face = c.rect(x, y, x + w - 1, y + h - 1)
    c.fill(face, "grn0")
    yy, xx = c.grid()
    c.dither(face, "ink1", np.clip((yy - y) / float(h) * 0.7, 0, 0.7))
    c.fill(c.rect(x, y, x + w - 1, y), "ink1")
    for sx in (x - 3, x + w + 1):
        for sy in (y - 3, y + h + 1):
            c.px(sx, sy, "steel3")


def thumb(c):
    x, y, w, h = THUMB
    hous = c.rrect(2, y - 6, 97, y + h + 19, 4)
    c.shade(hous, "steel_dark", light=(0.7, 0.5), contrast=0.8, round_px=5, round_amt=0.5, bias=-0.06)
    c.outline("ink0", hous)
    c.fill(c.rrect(x - 3, y - 3, x + w + 2, y + h + 2, 2), "ink0")
    c.fill(c.rect(x, y, x + w - 1, y + h - 1), "grn0")
    draw_text(c, 7, y + h + 5, "HALL CAM", "steel3")
    c.fill(c.ell(80, y + h + 11, 2.2, 2.2), "steel2")
    c.px(80, y + h + 10, "steel4")
    c.px(89, y + h + 11, "grn4")
    c.px(90, y + h + 11, "grn2")


def controls(c):
    """The plate on the right wall that carries the four pads the game draws."""
    plate = c.rrect(543, 187, 636, 299, 3)
    c.shade(plate, "steel_dark", light=(-0.6, 0.5), contrast=0.7, round_px=5, round_amt=0.4, bias=-0.1)
    c.outline("ink0", plate)
    yy, xx = c.grid()
    stripe = c.rect(545, 242, 634, 244)
    c.fill(stripe, "ink0")
    c.fill(stripe & (((xx + yy) // 4) % 2 == 0), "amber")
    c.dither(stripe, "ink0", 0.35)
    for sx, sy in ((545, 189), (634, 189), (545, 297), (634, 297)):
        c.px(sx, sy, "steel3")
    # conduit up the wall
    c.fill(c.rect(628, 0, 631, 186), "steel0")
    c.fill(c.rect(628, 0, 628, 186), "steel2")
    for y in (40, 110):
        c.fill(c.rect(626, y, 633, y + 3), "steel1")
        c.fill(c.rect(626, y, 633, y), "steel3")


def desk(c):
    band = c.rect(0, 300, 639, 359)
    yy, xx = c.grid()
    c.grad(band, ["warm0", "warm1", "warm2"], 640, 380, 200, 290, dither=1.0)
    c.glow(band, "warm3", 150, 290, 280, amt=0.85, power=1.2, ry=80)
    c.glow(band, "warm4", 140, 288, 130, amt=0.6, power=1.3, ry=40)
    rng = np.random.default_rng(12)
    for _ in range(110):
        x = int(rng.integers(0, 620))
        y = int(rng.integers(304, 358))
        c.fill(c.rect(x, y, x + int(rng.integers(6, 22)), y), "warm1" if rng.random() < 0.6 else "warm0")
    c.fill(c.rect(0, 300, 639, 300), "ink0")
    c.fill(c.rect(0, 301, 639, 301), "warm4")
    c.dither(c.rect(0, 301, 639, 301), "warm2", np.clip(np.abs(xx - 150) / 330.0, 0, 1))
    # two felt mats: the tools on the left, the intercom keys on the right
    for x0, x1 in ((1, 118), (521, 638)):
        mat = c.rrect(x0, 303, x1, 358, 3)
        c.fill(c.rrect(x0 + 1, 304, x1 + 1, 359, 3), "warm0")
        c.fill(mat, "teal1")
        c.dither(mat, "teal2", np.clip(1.0 - (np.abs(xx - 150) / 420.0 + (yy - 300) / 120.0), 0, 0.9))
        c.inline(mat, "ink1")
        c.fill(c.rect(x0 + 3, 304, x1 - 3, 304), "teal3")


def lamp(c):
    """The interrogation lamp, bolted to the window upright and aimed through the glass. Its
    light is the additive cone the game lays over the hall, so the mouth stays at about (160, 242)."""
    mount = c.rect(95, 232, 102, 258)
    c.shade(mount, "steel", light=(-0.6, -0.5), contrast=0.9, round_px=2, bias=-0.05)
    arm = c.rect(103, 241, 117, 248)
    c.fill(arm, "warm2")
    c.fill(c.rect(103, 241, 117, 242), "warm4")
    c.fill(c.rect(103, 248, 117, 248), "warm0")
    hood = c.poly([(116, 226), (116, 262), (158, 279), (158, 205)])
    c.shade(hood, ["warm0", "warm1", "warm2", "warm3"], light=(0.2, -0.8), contrast=1.0, round_px=10)
    c.fill(c.rect(116, 226, 117, 262), "warm1")
    c.outline("ink0", hood | arm | mount)
    for y in (235, 254):
        c.px(98, y, "steel5")
        c.px(98, y + 1, "ink0")
    c.fill(c.rect(158, 206, 162, 278), "warm7")
    c.fill(c.rect(158, 205, 162, 209), "warm5")
    c.fill(c.rect(158, 275, 162, 279), "warm5")
    c.fill(c.rect(160, 220, 162, 264), "white")
    for i in range(3):
        c.fill(c.rect(124 + i * 9, 236 + i * 3, 125 + i * 9, 250 + i * 4), "warm0")


def booth():
    c = Canvas(640, 360)
    walls(c)
    pinboard(c, 4, 4, 91, 164, 120)
    pinboard(c, 548, 4, 623, 184, 520)
    meter(c)
    thumb(c)
    controls(c)
    desk(c)
    lamp(c)
    wx, wy, ww, wh = WIN
    hole = c.rect(wx, wy, wx + ww - 1, wy + wh - 1)
    lampm = c.rect(100, 200, 164, 284)          # the lamp reaches in front of the window
    c.erase(hole & ~lampm)
    return c


# ------------------------------------------------------------------ things that open
def obj_sheet():
    """The reference sheet as it hangs on the board: small, but plainly a printed form."""
    c = Canvas(80, 92)
    yy, xx = c.grid()
    c.fill(c.rect(4, 6, 77, 90), "ink0", 120)
    p = c.rect(2, 3, 75, 88)
    c.fill(p, "paper3")
    c.dither(p, "paper2", np.clip(xx / 80.0 * 0.35 + yy / 92.0 * 0.3 - 0.15, 0, 0.5))
    c.fill(c.rect(2, 88, 75, 88), "paper1")
    c.fill(c.rect(75, 3, 75, 88), "paper1")
    c.fill(c.rect(2, 3, 75, 14), "teal4")
    c.fill(c.rect(2, 14, 75, 14), "teal2")
    draw_text(c, 39 - text_width("NORMAL", True) // 2, 4, "NORMAL", "paper4", bold=True)
    eye = c.ell(19, 28, 11, 6)
    c.fill(eye, "paper4")
    c.outline("inkt", eye)
    c.fill(c.ell(19, 28, 4, 4), "teal4")
    c.fill(c.ell(19, 28, 1.6, 1.6), "inkt")
    for i, wd in enumerate((36, 28, 34)):
        c.fill(c.rect(35, 23 + i * 5, 35 + wd, 23 + i * 5), "inks")
    for i in range(6):
        y = 42 + i * 7
        c.fill(c.rect(7, y, 11, y + 4), "inks")
        c.fill(c.rect(8, y + 1, 10, y + 3), "paper4")
        c.fill(c.rect(15, y + 2, 15 + (52, 44, 56, 38, 50, 46)[i], y + 2), "inks")
    c.fill(c.rect(6, 84, 40, 84), "teal4")
    c.outline("ink0", p)
    c.fill(c.rect(37, 0, 40, 3), "red2")
    c.px(37, 0, "white")
    c.px(40, 4, "ink1")
    return c


def obj_card():
    """The intake card on its clipboard, hung by the clip."""
    c = Canvas(80, 104)
    yy, xx = c.grid()
    board = c.rrect(3, 8, 76, 101, 3)
    shadow(c, board, 2, 2)
    c.shade(board, "wood", light=(-0.6, -0.4), contrast=0.7, round_px=4, round_amt=0.3)
    for y in (30, 58, 84):
        c.fill(c.rect(4, y, 75, y), "warm0", 120)
    c.outline("ink0", board)
    c.fill(c.rect(9, 18, 72, 97), "ink0", 110)
    p = c.rect(8, 16, 70, 95)
    c.fill(p, "manila3")
    c.dither(p, "manila2", np.clip(xx / 80.0 * 0.4 + yy / 104.0 * 0.3 - 0.15, 0, 0.55))
    c.fill(c.rect(8, 95, 70, 95), "manila1")
    c.fill(c.rect(70, 16, 70, 95), "manila1")
    draw_text(c, 11, 18, "INTAKE", "inkt", bold=True)
    c.fill(c.rect(11, 29, 44, 29), "inks")
    # the decision box, still empty
    box = c.rect(49, 19, 67, 30)
    c.fill(box & ~c.rect(50, 20, 66, 29), "red1")
    c.fill(box & (((xx + yy) % 3) == 0) & ~c.rect(50, 20, 66, 29), "manila3")
    for i in range(6):
        y = 36 + i * 10
        c.fill(c.rect(11, y, 17, y + 6), "8a7a5a")
        c.fill(c.rect(12, y + 1, 16, y + 5), "manila3")
        c.fill(c.rect(21, y + 2, 21 + (44, 36, 46, 30, 40, 34)[i], y + 2), "inks")
        c.fill(c.rect(21, y + 5, 21 + (30, 40, 24, 38, 28, 42)[i], y + 5), "pencil")
    c.line([(12, 39), (14, 42), (18, 35)], "inkt", 1)
    c.line([(12, 57), (16, 61)], "red1", 1)
    c.line([(16, 57), (12, 61)], "red1", 1)
    clipm = c.rrect(24, 5, 55, 15, 3)
    spring = c.rrect(31, 1, 48, 10, 3)
    c.shade(clipm, "steel", light=(-0.4, -0.8), contrast=0.9, round_px=3)
    c.shade(spring, "steel", light=(-0.4, -0.8), contrast=1.0, round_px=3, bias=0.08)
    c.fill(c.ell(39.5, 5, 3, 2), "ink1")
    c.outline("ink0", clipm | spring)
    return c


def obj_guide():
    """The counter guide: a thin booklet on a string."""
    c = Canvas(80, 46)
    c.line([(40, 0), (22, 9)], "paper1", 1)
    c.line([(40, 0), (58, 9)], "paper1", 1)
    c.fill(c.rect(39, 0, 41, 2), "steel4")
    cover = c.rrect(6, 8, 73, 42, 2)
    shadow(c, cover, 2, 2)
    c.shade(cover, ["teal1", "teal2", "teal3", "teal4"], light=(-0.6, -0.5), contrast=0.7, round_px=4, round_amt=0.3)
    c.fill(c.rect(6, 8, 10, 42) & cover, "teal1")
    c.fill(c.rect(11, 8, 11, 42) & cover, "teal5")
    c.outline("ink0", cover)
    c.fill(c.rect(74, 11, 75, 43), "paper2")
    c.fill(c.rect(8, 43, 75, 44), "paper1")
    draw_text(c, 17, 13, "COUNTER", "paper3", bold=True)
    draw_text(c, 17, 25, "GUIDE", "paper3", bold=True)
    q = c.ell(62, 29, 7, 7)
    c.fill(q, "amber")
    c.outline("ink0", q)
    draw_text(c, 62 - text_width("?", True) // 2, 23, "?", "ink0", bold=True)
    return c


def obj_list():
    """Tonight's contacts: a strip of tractor-feed printout under a red tack, the Lanterns'
    paper lantern stamped in the corner. The handler pins a fresh one up every night."""
    c = Canvas(80, 46)
    yy, xx = c.grid()
    c.fill(c.rect(6, 6, 77, 45), "ink0", 120)
    p = c.rect(4, 3, 75, 43)
    c.fill(p, "paper3")
    c.dither(p, "paper2", np.clip(xx / 80.0 * 0.3 + yy / 46.0 * 0.3 - 0.1, 0, 0.5))
    # the feed margins, their holes and the perforation beside them
    for x in (4, 69):
        c.fill(c.rect(x, 3, x + 6, 43), "paper2")
        for y in range(6, 42, 6):
            c.fill(c.rect(x + 2, y, x + 3, y + 1), "warm1")
    for x in (11, 68):
        c.fill(c.rect(x, 3, x, 43) & ((yy % 2) == 0), "paper1")
    # the header in lantern red
    c.fill(c.rect(12, 5, 67, 16), "red1")
    c.fill(c.rect(12, 17, 67, 17), "red0")
    tw = text_width("CONTACTS", True)
    assert tw <= 54, "list header too wide (%d)" % tw
    draw_text(c, 40 - tw // 2, 6, "CONTACTS", "paper4", bold=True)
    # two printed entries: an alias, then its lines
    for i, y in enumerate((21, 32)):
        c.fill(c.rect(14, y, 14 + (24, 30)[i], y + 1), "inkt")
        c.fill(c.rect(14, y + 4, 14 + (40, 34)[i], y + 4), "inks")
        c.fill(c.rect(14, y + 7, 14 + (32, 38)[i], y + 7), "inks")
    # the paper lantern
    lan = c.ell(61, 31, 4, 5)
    c.fill(lan, "red2")
    c.fill(c.rect(60, 29, 62, 33) & lan, "amber")
    c.fill(c.rect(59, 25, 63, 25), "ink1")
    c.fill(c.rect(59, 37, 63, 37), "ink1")
    c.fill(c.rect(61, 23, 61, 24), "ink1")
    c.fill(c.rect(4, 43, 75, 43), "paper1")
    c.outline("ink0", p)
    # the tack
    c.fill(c.ell(40, 2, 2.5, 2.2), "red2")
    c.px(39, 1, "white")
    return c


def tool_glass():
    """The glazier's key on the control plate: a pane with a fresh pane sliding over it."""
    c = Canvas(36, 38)
    yy, xx = c.grid()
    frame = c.rrect(4, 5, 29, 31, 2)
    shadow(c, frame)
    c.shade(frame, "steel", light=(-0.7, -0.6), contrast=0.9, round_px=3)
    pane = c.rect(7, 8, 26, 28)
    c.fill(pane, "teal2")
    u = (xx + yy * 0.7) % 17
    c.fill(pane & (u > 3) & (u < 7), "teal5")
    c.fill(pane & (u > 9) & (u < 11), "teal4")
    c.line([(17, 8), (14, 15), (19, 19), (15, 28)], "teal7", 1)
    c.line([(14, 15), (8, 17)], "teal7", 1)
    c.line([(19, 19), (26, 22)], "teal7", 1)
    c.outline("ink0", frame)
    key = c.seg([(21, 23), (31, 33)], 4)
    head = c.ell(21, 23, 4.5, 4.5) & ~c.rect(17, 21, 20, 24)
    shadow(c, key | head, 1, 1)
    c.shade(key | head, "steel", light=(-0.7, -0.6), contrast=1.0, round_px=2, bias=0.1)
    c.outline("ink0", key | head)
    return c


def cam_panel():
    """The hall camera pulled up close: the housing around a 132 x 94 picture."""
    gx, gy, gw, gh = CAM_GLASS
    w, h = gw + gx * 2, gh + gy * 2
    c = Canvas(w, h)
    hous = c.rrect(0, 0, w - 1, h - 1, 5)
    c.shade(hous, "steel_dark", light=(0.7, 0.5), contrast=0.8, round_px=5, round_amt=0.5, bias=-0.06)
    c.outline("ink0", hous)
    c.fill(c.rrect(gx - 3, gy - 3, gx + gw + 2, gy + gh + 2, 3), "ink0")
    c.fill(c.rect(gx, gy, gx + gw - 1, gy + gh - 1), "grn0")
    for sx, sy in ((2, 2), (w - 3, 2), (2, h - 3), (w - 3, h - 3)):
        c.px(sx, sy, "steel3")
    return c


def main():
    b = booth()
    b.save("clinic/booth.png")
    cp = cam_panel()
    cp.save("clinic/cam_panel.png")
    things = {"obj_sheet": obj_sheet(), "obj_card": obj_card(), "obj_guide": obj_guide(), "obj_list": obj_list(),
              "tool_glass": tool_glass(),
              "pad_w": pad(40, 54), "pad_w_hot": pad(40, 54, hot=True)}
    for name, canvas in things.items():
        canvas.save("ui/%s.png" % name)

    # review composite: the empty counter with everything hung where the game hangs it
    comp = Canvas(640, 360, "ink0")
    vx, vy, vs = VIEW
    try:
        hall = from_image(os.path.join(ASSETS, "clinic", "hall.png")).scaled(vs)
        sill = from_image(os.path.join(ASSETS, "clinic", "sill.png")).scaled(vs)
        comp.blit(hall, 170 * vs + vx, 14 * vs + vy)
        comp.blit(sill, 170 * vs + vx, 185 * vs + vy)
    except Exception as err:            # the clinic art has not been generated yet
        print("booth composite without the hall:", err)
    comp.blit(b, 0, 0)
    try:
        comp.blit(from_image(os.path.join(ASSETS, "clinic", "dialogue.png")), 120, 300)
        icons = (("tool_light", 2, 304), ("tool_grip", 42, 304), ("tool_port", 82, 304),
                 ("talk_ask", 522, 304), ("talk_calm", 562, 304), ("talk_press", 602, 304),
                 ("stamp_treat", 548, 193), ("lever_up", 548, 248))
        for name, x, y in icons:
            comp.blit(from_image(os.path.join(ASSETS, "ui", name + ".png")), x, y)
    except Exception as err:
        print("booth composite without the icons:", err)
    comp.blit(things["obj_sheet"], 8, 8)
    comp.blit(things["obj_list"], 8, 112)
    comp.blit(things["obj_card"], 546, 8)
    comp.blit(things["obj_guide"], 546, 128)
    comp.blit(things["tool_glass"], 596, 248)
    os.makedirs(OUT, exist_ok=True)
    comp.scaled(2).image().convert("RGB").save(os.path.join(OUT, "booth_empty.png"))
    print("booth art written")


if __name__ == "__main__":
    main()
