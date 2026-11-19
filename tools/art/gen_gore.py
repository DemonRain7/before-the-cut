"""Damage and blood for the attack scenes.

Run from tools/art:  python gen_gore.py
Writes game/assets/fx: the window cracking and breaking, blood on the glass and on the
player's side of the counter, shutter damage, glass shards and the tunnel-vision vignette.
Everything is drawn here from shapes and noise; nothing is traced or imported.

Window art is 220 x 186 (the counter window). Positions below are window-local.
"""
import os

import numpy as np
from scipy import ndimage as ndi

from people import grow, shrink, stroke
from px import OUT, Canvas, bayer, contact_sheet

HOLE_W, HOLE_H = 220, 186
D = "fx"

# where the three blows land on the glass (also used by the game: see clinic_view.gd)
HIT_HAND = (170, 118)      # the open palm, on our right
HIT_TOOL = (60, 126)       # the weapon (saw, torch, lock, fist, picks), on our left
HIT_HEAD = (110, 50)       # the forehead


# ------------------------------------------------------------------ blood
def blood(c, m, wet=True, seed=0):
    """Paint a blood shape: darker where it pools, a wet edge toward the lamp."""
    if not m.any():
        return c
    rng = np.random.default_rng(seed + 5)
    c.fill(m, "red1")
    e = ndi.distance_transform_edt(m)
    c.fill(m & (e >= 3.0), "861a1e")
    c.dither(m & (e >= 4.5), "red0", 0.55)
    c.fill(c.edge(m, 1, 0) | c.edge(m, 0, 1), "red0")
    if wet:
        shifted = np.zeros_like(m)
        shifted[2:, 2:] = m[:-2, :-2]
        band = m & ~shifted & shrink(m, 1)
        c.dither(band, "red2", 0.7)
        ys, xs = np.nonzero(m & (e >= 4.0))
        for _ in range(min(4, len(ys) // 30)):
            i = rng.integers(0, len(ys))
            c.px(xs[i] - 1, ys[i] - 2, "red3")
    return c


def splat(size, seed, spikes=10, core=0.2, reach=1.0, drops=16, aim=None, spread=0.6):
    """A burst of blood thrown from the centre: lumpy core, tapering fingers, stray drops."""
    rng = np.random.default_rng(seed)
    c = Canvas(size, size)
    cx = cy = (size - 1) / 2.0
    R = size / 2.0 - 2.0
    rc = size * core
    m = c.none()
    for _ in range(8):
        a = rng.uniform(0, 2 * np.pi)
        d = rng.uniform(0, rc * 0.6)
        r = rng.uniform(rc * 0.45, rc * 0.95)
        m |= c.ell(cx + np.cos(a) * d, cy + np.sin(a) * d, r, r * rng.uniform(0.7, 1.0))
    for i in range(spikes):
        a = 2 * np.pi * i / spikes + rng.uniform(-0.3, 0.3) if aim is None else aim + rng.normal(0, spread)
        length = rc * 0.6 + rng.uniform(0.3, 1.0) ** 1.3 * (R - rc * 0.6) * reach
        w0 = max(1.0, rng.uniform(0.05, 0.11) * size * 0.5)
        n = max(2, int(length))
        for s in range(n):
            t = s / (n - 1.0)
            r = max(0.5, w0 * (1.0 - t) ** 0.9)
            d = rc * 0.4 + (length - rc * 0.4) * t
            m |= c.ell(cx + np.cos(a) * d, cy + np.sin(a) * d, r, r)
        if rng.random() < 0.7:            # the drop that ran ahead of the finger
            d = length + rng.uniform(2, 6) * size / 48.0
            r = rng.uniform(0.6, 1.9) * max(1.0, size / 56.0)
            if d + r < R + 1:
                m |= c.ell(cx + np.cos(a) * d, cy + np.sin(a) * d, r, r)
    for _ in range(drops):
        a = rng.uniform(0, 2 * np.pi) if aim is None else aim + rng.normal(0, spread * 1.3)
        d = rng.uniform(rc, R)
        r = rng.choice([0.5, 0.5, 0.8, 1.2, 1.6]) * max(1.0, size / 64.0)
        m |= c.ell(cx + np.cos(a) * d, cy + np.sin(a) * d, r, r)
    return blood(c, m, seed=seed)


def drag_down(m, drag, rng, strength=0.85):
    """Pull every pixel of a print downward into streaks of uneven length."""
    h, w = m.shape
    out = m.copy()
    reach = drag * rng.uniform(0.15, 1.0, w)
    reach = ndi.uniform_filter1d(reach, 2)
    b = bayer(h, w)
    for k in range(1, drag + 1):
        sh = np.zeros_like(m)
        sh[k:, :] = m[:-k, :]
        t = k / np.maximum(reach, 1.0)
        out |= sh & (t[None, :] <= 1.0) & (b > t[None, :] * strength)
    return out


def handprint(seed=1, drag=0, thumb=-1):
    """A bloody palm pressed flat on the far side of the glass, fingers up.
    thumb=-1 puts the thumb on our left."""
    rng = np.random.default_rng(seed)
    w, h = 42, 54 + drag
    c = Canvas(w, h)
    cx = 21
    fingers = ((-9, -13, 12), (-3, -5, 5), (3, 4, 4), (9, 12, 10))
    m = c.ell(cx, 38, 10, 8) | c.ell(cx - 5, 31, 6, 5) | c.ell(cx + 5, 31, 6, 5)
    gaps = c.ell(cx, 35, 3.6, 3.0)                       # the hollow of the palm never touched
    for bx, tx, ty in fingers:
        m |= c.seg([(cx + bx, 28), (cx + tx, ty + 5)], 3)
        m |= c.ell(cx + tx, ty + 2, 2.5, 3.8)
        for t in (0.38, 0.72):                           # the joints did not touch either
            jx = cx + bx + (tx - bx) * t
            jy = 28 + (ty + 5 - 28) * t
            gaps |= c.ell(jx, jy, 2.6, 1.1)
    m |= c.seg([(cx + thumb * 9, 38), (cx + thumb * 16, 29)], 4)
    m |= c.ell(cx + thumb * 17, 27, 2.7, 3.6)
    gaps |= c.ell(cx + thumb * 13, 33, 2.2, 1.2)
    m &= ~gaps
    m &= rng.random((h, w)) > 0.1                        # skin ridges: a broken film
    if drag:
        m = drag_down(m, drag, rng)
    for _ in range(9):                                   # what flew off the hand when it hit
        a = rng.uniform(0, 2 * np.pi)
        d = rng.uniform(14, 22)
        m |= c.ell(cx + np.cos(a) * d * 0.8, 30 + np.sin(a) * d, 0.7, 0.7)
    return blood(c, m, wet=False, seed=seed)


def smear(seed=3, drag=30):
    """A forehead on the glass: one blot and the long run below it."""
    rng = np.random.default_rng(seed)
    w, h = 46, 26 + drag
    c = Canvas(w, h)
    m = c.none()
    for _ in range(7):
        m |= c.ell(23 + rng.uniform(-9, 9), 11 + rng.uniform(-4, 4), rng.uniform(3, 7), rng.uniform(2.5, 5))
    m &= rng.random((h, w)) > 0.06
    m = drag_down(m, drag, rng, strength=0.7)
    for _ in range(12):
        a = rng.uniform(np.pi, 2 * np.pi)
        d = rng.uniform(10, 21)
        r = rng.choice([0.6, 0.8, 1.3])
        m |= c.ell(23 + np.cos(a) * d, 12 + np.sin(a) * d * 0.55, r, r)
    return blood(c, m, seed=seed)


def castoff(seed=5):
    """Blood flung off a spinning blade: an arc of stretched drops."""
    rng = np.random.default_rng(seed)
    w, h = 64, 56
    c = Canvas(w, h)
    m = c.none()
    for i in range(26):
        t = i / 25.0 + rng.uniform(-0.02, 0.02)
        a = np.pi * (1.05 - 0.75 * t)                    # sweeps from our lower left up and over
        r = 24 + rng.uniform(-3, 3) + 8 * t
        x, y = 30 + np.cos(a) * r * 1.05, 50 - np.sin(a) * r
        ta = a - np.pi / 2
        ln = rng.uniform(1, 6) * (0.4 + t)
        wd = rng.choice([1, 1, 2, 3])
        m |= c.seg([(x, y), (x + np.cos(ta) * ln, y - np.sin(ta) * ln)], wd)
        if rng.random() < 0.5:
            m |= c.ell(x + rng.uniform(-5, 5), y + rng.uniform(-5, 5), 0.7, 0.7)
    m |= c.ell(12, 44, 5, 4) | c.ell(17, 39, 3.5, 3)
    m = drag_down(m, 12, rng, strength=0.9)
    return blood(c, m, seed=seed)


def gouge(seed=6):
    """What the saw leaves in the glass: scored arcs with crushed white edges."""
    rng = np.random.default_rng(seed)
    w, h = 56, 52
    c = Canvas(w, h)
    for k, r in enumerate((13, 17, 22)):
        a0 = np.pi * rng.uniform(0.95, 1.1)
        a1 = np.pi * rng.uniform(0.2, 0.42)
        pts = [(26 + np.cos(a) * r * 1.05, 34 - np.sin(a) * r) for a in np.linspace(a0, a1, 16)]
        stroke(c, [(x + 1, y + 1) for x, y in pts], "ink1")
        stroke(c, pts, "dbe6e0")
        if k == 1:
            stroke(c, [(x, y - 1) for x, y in pts[3:11]], "ffffff")
    c.speckle(c.ell(26, 30, 22, 20) & ~c.alpha(), "ffffff", 0.04, seed=seed)
    return c


def scorch(seed=7):
    """Where the torch touched: a melted pit in a halo of soot."""
    rng = np.random.default_rng(seed)
    s = 52
    c = Canvas(s, s)
    yy, xx = c.grid()
    d = np.hypot(xx - 26, yy - 26)
    c.dither(c.all(), "ink1", np.clip(1.15 - d / 21.0, 0, 0.92))
    c.dither(d < 13, "ink0", np.clip(1.3 - d / 11.0, 0, 1))
    for i in range(9):                                   # heat cracks
        a = 2 * np.pi * i / 9 + rng.uniform(-0.3, 0.3)
        pts = [(26 + np.cos(a) * 6, 26 + np.sin(a) * 6)]
        r = 6.0
        while r < rng.uniform(15, 24):
            r += rng.uniform(4, 7)
            a += rng.uniform(-0.3, 0.3)
            pts.append((26 + np.cos(a) * r, 26 + np.sin(a) * r))
        stroke(c, pts, "a3b5b6")
    pit = c.ell(26, 26, 6.5, 6)
    c.fill(pit, "warm1")
    c.fill(c.ell(26, 26, 4.5, 4), "warm0")
    c.fill(c.edge(pit, -1, 0) | c.edge(pit, 0, -1), "warm3")
    for x in (23, 27, 30):                               # glass that ran before it set
        ln = int(rng.uniform(5, 12))
        stroke(c, [(x, 31), (x, 31 + ln)], "warm2")
        c.px(x, 31 + ln, "warm3")
    return c


def scorch_hot():
    """The same pit while it is still glowing (drawn additively, fades out)."""
    s = 52
    c = Canvas(s, s)
    yy, xx = c.grid()
    d = np.hypot(xx - 26, yy - 26)
    c.dither(d < 20, "7a2a10", np.clip(1.0 - d / 20.0, 0, 0.9))
    c.dither(d < 12, "warm4", np.clip(1.25 - d / 11.0, 0, 1))
    c.fill(d < 6.5, "warm6")
    c.fill(d < 4.0, "warm7")
    c.fill(d < 2.0, "white")
    for x, ln in ((23, 7), (27, 11), (30, 6)):
        stroke(c, [(x, 31), (x, 31 + ln)], "warm5")
        c.px(x, 31 + ln, "warm7")
    return c


def smash(seed, w=48, h=46, knuckles=0):
    """Where something heavy and blunt met the glass: the crushed white point, short splits
    running off it and a ring punched down round it. knuckles: that many crushed points in
    a row (a fist) in place of one (a bike lock)."""
    c = Canvas(w, h)
    cx, cy = w / 2.0, h / 2.0
    if knuckles:
        pts = [(cx + (i - (knuckles - 1) / 2.0) * 9.0, cy - 2 + abs(i - (knuckles - 1) / 2.0) * 1.6) for i in range(knuckles)]
    else:
        pts = [(cx, cy)]
    lines = []
    for k, (x, y) in enumerate(pts):
        lines += crack_set(seed + k, x, y, 7 if knuckles else 9, min(w, h) * (0.4 if knuckles else 0.46))
    draw_cracks(c, lines, 1.0)
    rings(c, seed + 20, cx, cy, (14, 21) if knuckles else (7, 13), n=11, keep=0.72)
    for k, (x, y) in enumerate(pts):
        crush(c, seed + 30 + k, x, y, 2.5 if knuckles else 3.4)
    return c


def slit(seed=95):
    """Ten points dragged down the glass: two hands of five fine scratches, each starting
    where its tip bit in."""
    rng = np.random.default_rng(seed)
    w, h = 60, 48
    c = Canvas(w, h)
    for x0, y0 in ((9, 6), (25, 13)):
        for i in range(5):
            x = x0 + i * 4.5 + rng.uniform(-0.6, 0.6)
            y = y0 + abs(i - 2) * 2.0 + rng.uniform(-1, 1)
            ln = rng.uniform(19, 27)
            bend = rng.uniform(5, 9)
            pts = [(x + bend * (t ** 1.5), y + ln * t) for t in np.linspace(0, 1, 7)]
            stroke(c, [(px + 1, py + 1) for px, py in pts], "ink1")
            stroke(c, pts, "dbe6e0")
            c.px(int(round(x)), int(round(y)), "ffffff")
    c.speckle(c.rect(6, 4, w - 6, h - 4) & ~c.alpha(), "ffffff", 0.03, seed=seed)
    return c


def spray(seed=9, w=70, h=44, n=110):
    """A fine cough of blood across the glass."""
    rng = np.random.default_rng(seed)
    c = Canvas(w, h)
    m = c.none()
    for _ in range(n):
        x = w / 2.0 + rng.normal(0, w * 0.2)
        y = h * 0.4 + rng.normal(0, h * 0.2)
        r = rng.choice([0.5, 0.5, 0.5, 0.8, 1.2, 1.8])
        m |= c.ell(x, y, r, r * rng.uniform(1.0, 1.8))
    m = drag_down(m, 7, rng, strength=1.0)
    return blood(c, m, seed=seed)


# ------------------------------------------------------------------ the window
def crack_set(seed, cx, cy, n, reach):
    """Radial cracks from one impact: a list of (points, grows_from) polylines."""
    rng = np.random.default_rng(seed)
    out = []
    for i in range(n):
        a = 2 * np.pi * i / n + rng.uniform(-0.28, 0.28)
        pts = [(cx, cy)]
        total = reach * rng.uniform(0.5, 1.0)
        r = 0.0
        while r < total:
            step = rng.uniform(7, 15)
            r += step
            a += rng.uniform(-0.3, 0.3)
            x, y = pts[-1]
            pts.append((x + np.cos(a) * step, y + np.sin(a) * step * 0.92))
        out.append((pts, 0.0))
        if rng.random() < 0.5 and len(pts) > 3:
            k = int(rng.integers(1, len(pts) - 1))
            ba = a + rng.choice([-1, 1]) * rng.uniform(0.5, 0.95)
            bp = [pts[k]]
            for _ in range(int(rng.integers(2, 5))):
                st = rng.uniform(6, 12)
                ba += rng.uniform(-0.25, 0.25)
                x, y = bp[-1]
                bp.append((x + np.cos(ba) * st, y + np.sin(ba) * st * 0.92))
            out.append((bp, k / float(len(pts))))
    return out


def cut_line(pts, frac):
    """The first frac of a polyline, by length."""
    if frac >= 1.0:
        return pts
    seg = [np.hypot(pts[i + 1][0] - pts[i][0], pts[i + 1][1] - pts[i][1]) for i in range(len(pts) - 1)]
    left = sum(seg) * frac
    out = [pts[0]]
    for i, s in enumerate(seg):
        if left >= s:
            out.append(pts[i + 1])
            left -= s
        else:
            t = left / max(s, 1e-6)
            out.append((pts[i][0] + (pts[i + 1][0] - pts[i][0]) * t, pts[i][1] + (pts[i + 1][1] - pts[i][1]) * t))
            break
    return out


def draw_cracks(c, lines, grow_to):
    for pts, start in lines:
        if grow_to <= start + 0.1:
            continue
        part = cut_line(pts, 1.0 if start > 0 else grow_to)
        if len(part) < 2:
            continue
        stroke(c, [(x + 1, y + 1) for x, y in part], "ink1")
    for pts, start in lines:
        if grow_to <= start + 0.1:
            continue
        part = cut_line(pts, 1.0 if start > 0 else grow_to)
        if len(part) < 2:
            continue
        stroke(c, part, "dbe6e0")
        if start == 0.0:
            stroke(c, [(x + 1, y) for x, y in part[:2]], "ffffff")


def rings(c, seed, cx, cy, radii, n=13, keep=0.62):
    rng = np.random.default_rng(seed)
    for r in radii:
        for i in range(n):
            if rng.random() > keep:
                continue
            a0 = 2 * np.pi * i / n + rng.uniform(-0.1, 0.1)
            a1 = a0 + 2 * np.pi / n
            r0, r1 = r * rng.uniform(0.85, 1.12), r * rng.uniform(0.85, 1.12)
            p0 = (cx + np.cos(a0) * r0, cy + np.sin(a0) * r0 * 0.92)
            p1 = (cx + np.cos(a1) * r1, cy + np.sin(a1) * r1 * 0.92)
            stroke(c, [(p0[0] + 1, p0[1] + 1), (p1[0] + 1, p1[1] + 1)], "ink1")
            stroke(c, [p0, p1], "a3b5b6")


def crush(c, seed, cx, cy, r):
    """The crushed white point of an impact."""
    rng = np.random.default_rng(seed)
    yy, xx = c.grid()
    d = np.hypot(xx - cx, yy - cy)
    c.fill((d < r * 2.6) & (rng.random((c.h, c.w)) < 0.22 * np.clip(1.4 - d / (r * 2.6), 0, 1)), "ffffff")
    c.fill(d < r, "ffffff")
    c.fill(d < r * 0.45, "a3b5b6")


def cracks(stage):
    """Stage 1..3 of the window breaking. Each stage keeps everything from the one before."""
    c = Canvas(HOLE_W, HOLE_H)
    plan = [
        # impact, seed, cracks, reach, crack growth per stage, ring radii per stage
        (HIT_HAND, 41, 9, 64, (0.5, 0.8, 1.0), ((9,), (9, 20), (9, 20, 33))),
        (HIT_TOOL, 52, 10, 78, (0.0, 0.6, 1.0), ((), (8, 18), (8, 18, 31))),
        (HIT_HEAD, 63, 11, 96, (0.0, 0.0, 1.0), ((), (), (10, 23, 40))),
    ]
    for (cx, cy), seed, n, reach, growth, ring_plan in plan:
        g = growth[stage - 1]
        if g <= 0.0:
            continue
        draw_cracks(c, crack_set(seed, cx, cy, n, reach), g)
        rings(c, seed + 1, cx, cy, ring_plan[stage - 1])
        crush(c, seed + 2, cx, cy, 2.6 if g < 1.0 else 3.4)
    if stage == 3:
        rng = np.random.default_rng(77)
        for _ in range(7):                               # chips that have already fallen out
            x, y = rng.uniform(20, 200), rng.uniform(16, 170)
            if 78 < x < 142 and 56 < y < 132:
                continue
            pts = [(x + np.cos(a) * rng.uniform(2.5, 6), y + np.sin(a) * rng.uniform(2.5, 6))
                   for a in np.sort(rng.uniform(0, 2 * np.pi, 5))]
            chip = c.poly(pts)
            c.fill(chip, "ink0", a=150)
            c.fill(grow(chip, 1) & ~chip, "ffffff")
    return c


def glass_broken(seed=21, clean=False):
    """What is left in the frame after the pane goes: a jagged ring of shards.
    clean: nothing on the shards (the --less-blood option)."""
    rng = np.random.default_rng(seed)
    c = Canvas(HOLE_W, HOLE_H)
    yy, xx = c.grid()
    inner = []                                           # walk the frame clockwise, in and out
    def side(n, f):
        for i in range(n):
            t = (i + rng.uniform(0.15, 0.85)) / n
            depth = rng.choice([3, 5, 8, 13, 19, 27], p=[0.2, 0.22, 0.2, 0.18, 0.12, 0.08])
            inner.append(f(t, depth))
    side(13, lambda t, d: (t * HOLE_W, d))
    side(10, lambda t, d: (HOLE_W - 1 - d, t * (HOLE_H - 14)))
    side(13, lambda t, d: ((1 - t) * HOLE_W, HOLE_H - 14 - d * 0.6))
    side(10, lambda t, d: (d, (1 - t) * (HOLE_H - 14)))
    hole = c.poly(inner)
    pane = c.rect(0, 0, HOLE_W - 1, HOLE_H - 14) & ~hole
    c.fill(pane, "teal4", a=96)
    u = (xx + yy * 0.7) % 190
    c.fill(pane & (((u > 30) & (u < 52)) | ((u > 60) & (u < 66)) | (u > 150)) & (bayer(HOLE_H, HOLE_W) < 0.5), "teal7", a=170)
    edge = pane & grow(hole, 1)
    c.fill(grow(edge, 1) & pane, "teal6")
    c.fill(edge, "ffffff")
    for _ in range(16):                                  # cracks running back into the frame
        i = int(rng.integers(0, len(inner)))
        x, y = inner[i]
        tx = 0 if x < 40 else (HOLE_W - 1 if x > HOLE_W - 40 else x + rng.uniform(-14, 14))
        ty = 0 if y < 40 else (HOLE_H - 15 if y > HOLE_H - 54 else y + rng.uniform(-14, 14))
        mid = ((x + tx) / 2 + rng.uniform(-4, 4), (y + ty) / 2 + rng.uniform(-4, 4))
        m = c.seg([(x, y), mid, (tx, ty)], 1) & pane
        c.fill(m, "dbe6e0")
    if clean:
        return c
    drops = c.none()                                     # blood on the lower teeth
    for x in (38, 52, 61, 148, 171, 186):
        col = pane[:, x]
        ys = np.nonzero(col & (yy[:, x] > 110))[0]
        if len(ys):
            y0 = ys.min()
            drops |= c.rect(x, y0, x + int(rng.integers(0, 2)), y0 + int(rng.integers(3, 9)))
    drops |= c.ell(14, 96, 3, 5) | c.ell(203, 120, 2.5, 6)
    blood(c, drops & (pane | grow(pane, 1)), seed=seed)
    return c


def sill_blood(seed=31):
    """Blood on the sill and running off its front edge."""
    rng = np.random.default_rng(seed)
    c = Canvas(HOLE_W, 15)
    m = c.none()
    for cx, rx in ((66, 22), (88, 9), (150, 15), (118, 5)):
        m |= c.ell(cx, 5, rx, 2.6) | c.ell(cx + rng.uniform(-6, 6), 7, rx * 0.6, 2.2)
    for x in (58, 71, 79, 146, 157):
        m |= c.rect(x, 6, x + int(rng.integers(0, 2)), 14)
    for _ in range(22):
        m |= c.ell(rng.uniform(30, 190), rng.uniform(2, 10), 0.7, 0.6)
    return blood(c, m, seed=seed)


def sill_glass(seed=33):
    """Crumbs of safety glass on the sill."""
    rng = np.random.default_rng(seed)
    c = Canvas(HOLE_W, 15)
    for _ in range(90):
        x, y = int(rng.uniform(6, 214)), int(rng.uniform(1, 11))
        c.px(x, y, rng.choice(["ffffff", "b9e3d0", "7fbfb0", "dbe6e0"]))
    for _ in range(9):
        x, y = rng.uniform(12, 208), rng.uniform(3, 9)
        pts = [(x, y), (x + rng.uniform(3, 8), y + rng.uniform(-2, 1)), (x + rng.uniform(1, 5), y + rng.uniform(2, 4))]
        tri = c.poly(pts)
        c.fill(tri, "teal6")
        c.fill(c.edge(tri, 0, -1), "ffffff")
        c.fill(c.edge(tri, 0, 1), "teal4")
    return c


def shard(seed, size):
    rng = np.random.default_rng(seed)
    c = Canvas(size, size)
    k = int(rng.integers(3, 5))
    ang = np.sort(rng.uniform(0, 2 * np.pi, k))
    pts = [(size / 2 + np.cos(a) * rng.uniform(0.45, 1.0) * (size / 2 - 1), size / 2 + np.sin(a) * rng.uniform(0.45, 1.0) * (size / 2 - 1)) for a in ang]
    m = c.poly(pts)
    c.fill(m, "teal6")
    c.dither(m, "teal7", 0.5)
    c.fill(c.edge(m, -1, 0) | c.edge(m, 0, -1), "ffffff")
    c.fill(c.edge(m, 1, 0) | c.edge(m, 0, 1), "teal4")
    return c


# ------------------------------------------------------------------ the shutter
def dent(seed, rx=11, ry=9, deep=False):
    """A blow from the far side: the slats bulge toward us around a lumpy knuckle shape.
    deep: a blow with a machine behind it, deep enough to see from the hall: the middle
    driven in further and a slat seam torn open across it."""
    rng = np.random.default_rng(seed)
    w, h = rx * 2 + 10, ry * 2 + 10
    c = Canvas(w, h)
    cx, cy = w / 2.0, h / 2.0
    yy, xx = c.grid()
    m = c.none()
    for _ in range(5):                                   # never a clean oval
        m |= c.ell(cx + rng.uniform(-3, 3), cy + rng.uniform(-2, 2), rx * rng.uniform(0.6, 0.95), ry * rng.uniform(0.6, 0.95))
    lit = ((xx - cx) * -0.75 + (yy - cy) * 0.5) / float(rx)      # the lamp is low on our left
    c.fill(m, "steel3")
    c.dither(m & (lit > 0.05), "steel4", np.clip(lit * 1.6, 0, 1))
    c.dither(m & (lit > 0.45), "steel5", np.clip(lit * 1.3 - 0.3, 0, 0.9))
    c.dither(m & (lit < -0.05), "steel1", np.clip(-lit * 1.7, 0, 1))
    c.dither(m & (lit < -0.45), "steel0", np.clip(-lit * 1.3 - 0.3, 0, 0.9))
    for k in (-1, 0, 1):                                 # the slat seams bend over the bump
        y0 = cy + k * 8 + 1
        pts = [(x, y0 - (1.0 - min(1.0, abs(x - cx) / rx) ** 2) * 3.0) for x in np.linspace(cx - rx - 2, cx + rx + 2, 11)]
        c.fill(c.seg(pts, 1) & m, "steel0")
        c.fill(c.seg([(x, y + 1) for x, y in pts], 1) & m, "steel5")
    c.fill((c.edge(m, 1, 0) | c.edge(m, 0, -1)) & m, "ink1")      # the far lip falls into shadow
    c.fill((c.edge(m, -1, 0) | c.edge(m, 0, 1)) & m, "white")     # the near lip catches the lamp
    ring = grow(m, 2) & ~m
    c.speckle(ring, "warm2", 0.16, seed=seed)            # paint flaking off around it
    c.speckle(ring, "ink1", 0.12, seed=seed + 1)
    for _ in range(4):                                   # stress creases running off along the slats
        s_ = rng.choice([-1, 1])
        y = cy + rng.uniform(-ry, ry) * 0.8
        x = cx + s_ * rx * 0.9
        stroke(c, [(x, y), (x + s_ * rng.uniform(3, 6), y + rng.uniform(-1, 1))], "ink1")
    if deep:
        rng = np.random.default_rng(seed + 50)
        core = c.ell(cx + 1, cy, rx * 0.5, ry * 0.45) & m      # where it went furthest: a sharper bump
        c.dither(core & (lit > 0.0), "steel5", 0.75)
        c.dither(core & (lit <= 0.0), "steel0", 0.75)
        c.fill(c.edge(core, 1, 0) | c.edge(core, 0, -1), "ink1")
        c.fill(c.edge(core, -1, 0) | c.edge(core, 0, 1), "white")
        y = cy + rng.uniform(-1.5, 1.5)                  # and a slat seam torn open across it
        split = c.seg([(cx - rx * 0.55, y), (cx + rng.uniform(-2, 2), y + rng.uniform(-1, 1)), (cx + rx * 0.5, y + rng.uniform(-1.5, 1.5))], 1) & m
        c.fill(grow(split, 1) & m & ~split, "white")
        c.fill(split, "ink0")
        c.speckle(grow(m, 4) & ~grow(m, 2), "warm2", 0.12, seed=seed + 2)
        c.speckle(grow(m, 4) & ~grow(m, 2), "ink1", 0.1, seed=seed + 3)
    return c


CUT_W, CUT_H = 96, 40


def cut_path():
    return [(4, 30), (20, 25), (38, 22), (55, 17), (74, 13), (92, 9)]


def cut_saw(seed=71, clean=False):
    """The saw comes through the slats: a torn slit, left to right.
    clean: the same cut with nothing on the blade, for the --less-blood option."""
    rng = np.random.default_rng(seed)
    c = Canvas(CUT_W, CUT_H)
    pts = cut_path()
    slit = c.seg(pts, 3)
    lip = grow(slit, 2) & ~slit
    c.dither(grow(slit, 4) & ~grow(slit, 2), "steel0", 0.5)
    c.fill(lip, "steel1")
    yy, xx = c.grid()
    c.fill(lip & (rng.random((CUT_H, CUT_W)) < 0.45), "steel5")       # torn bright metal
    c.fill(lip & (rng.random((CUT_H, CUT_W)) < 0.12), "white")
    c.fill(slit, "ink0")
    for i in range(1, len(pts) - 1):                     # curls of swarf
        x, y = pts[i]
        s = 1 if i % 2 else -1
        stroke(c, [(x, y + s * 2), (x + 2, y + s * 5), (x + 4, y + s * 4)], "steel4")
    if clean:
        return c
    b = c.none()                                         # and what the blade carried with it
    for x in (14, 31, 47, 66):
        y = int(np.interp(x, [p[0] for p in pts], [p[1] for p in pts])) + 3
        b |= c.rect(x, y, x, y + int(rng.integers(4, 11)))
        b |= c.ell(x, y, 1.6, 1.2)
    blood(c, b, seed=seed)
    return c


def saw_tooth(clean=False):
    """The rim of the disc showing through the slit (drawn at the cutting end).
    clean: bare steel, for the --less-blood option."""
    c = Canvas(26, 26)
    yy, xx = c.grid()
    d = np.hypot(xx - 13, yy - 13)
    a = np.arctan2(yy - 13, xx - 13)
    disc = d < 10.5
    c.fill(disc, "steel3")
    c.fill(disc & (d > 7.5), "steel5")
    c.fill((d < 12.6) & (d >= 10.5) & (((a * 16 / (2 * np.pi)) % 1.0) < 0.5), "steel5")
    c.fill(disc & (d < 7.5) & (((a * 5 / (2 * np.pi)) % 1.0) < 0.3), "steel2")
    c.fill(d < 2.5, "steel1")
    c.outline("ink0")
    if not clean:
        blood(c, disc & (d > 6) & (a > 0.3) & (a < 1.9))
    return c


def burn():
    """The torch drawing a line through the slats: what stays when it cools."""
    c = Canvas(CUT_W, CUT_H)
    pts = cut_path()
    line = c.seg(pts, 2)
    c.dither(grow(line, 5) & ~grow(line, 2), "ink1", 0.45)
    c.fill(grow(line, 2) & ~line, "ink0")
    c.fill(grow(line, 1) & ~line, "warm1")
    c.fill(line, "ink0")
    rng = np.random.default_rng(73)
    for x in (12, 26, 43, 60, 79):                       # slag that ran and set
        y = int(np.interp(x, [p[0] for p in pts], [p[1] for p in pts])) + 2
        ln = int(rng.integers(3, 12))
        stroke(c, [(x, y), (x, y + ln)], "warm1")
        c.px(x, y + ln, "warm2")
        c.px(x, y + ln + 1, "warm3")
    return c


def burn_hot():
    """The same line while it is white hot (drawn additively)."""
    c = Canvas(CUT_W, CUT_H)
    pts = cut_path()
    line = c.seg(pts, 2)
    c.dither(grow(line, 7) & ~grow(line, 4), "7a2a10", 0.4)
    c.dither(grow(line, 4) & ~grow(line, 2), "warm4", 0.7)
    c.fill(grow(line, 2) & ~grow(line, 1), "warm5")
    c.fill(grow(line, 1) & ~line, "warm6")
    c.fill(line, "warm7")
    c.fill(c.seg(pts, 1), "white")
    rng = np.random.default_rng(73)
    for x in (12, 26, 43, 60, 79):
        y = int(np.interp(x, [p[0] for p in pts], [p[1] for p in pts])) + 2
        ln = int(rng.integers(3, 12))
        stroke(c, [(x, y), (x, y + ln)], "warm5")
        c.px(x, y + ln, "warm7")
    return c


def scrape(seed=97):
    """The picks through the shutter: ten points scoring the slats along the cut path, two
    hands of five. Each groove skips where its point chattered over a seam, and the metal it
    turned up catches the lamp here and there."""
    rng = np.random.default_rng(seed)
    c = Canvas(CUT_W, CUT_H)
    pts = cut_path()
    for k in range(10):
        off = (k - 4.5) * 2.0 + (1.5 if k >= 5 else -1.5)
        line = [(x + rng.uniform(-0.5, 0.5), y + off + rng.uniform(-0.4, 0.4)) for x, y in pts]
        keep = np.ones(CUT_W, dtype=bool)
        x = int(rng.integers(2, 9))
        while x < CUT_W:
            gap = int(rng.integers(1, 4))
            keep[x:x + gap] = False
            x += gap + int(rng.integers(4, 12))
        groove = c.seg(line, 1) & keep[None, :]
        if k in (0, 5):
            c.fill(c.seg([(x, y - 1) for x, y in line], 1) & keep[None, :] & ~groove, "steel5")
        c.fill(groove, "ink0")
        ys, xs = np.nonzero(groove)
        for i in rng.integers(0, max(1, len(xs)), 4):
            if len(xs):
                c.px(xs[i], ys[i] - 1, "white")
    for x in (10, 27, 45, 63, 81):                       # where the tips came through a seam
        y = int(np.interp(x, [p[0] for p in pts], [p[1] for p in pts]))
        hole = c.ell(x, y + rng.uniform(-3, 3), 1.5, 1.2)
        c.fill(grow(hole, 1) & ~hole, "steel1")
        c.fill(hole, "ink0")
    return c


def pick_tips():
    """Five chrome points showing through the slats where the scrape has got to."""
    c = Canvas(26, 26)
    m = c.none()
    for i in range(5):
        x = 5.0 + i * 4.0
        y0 = 3.0 + abs(i - 2) * 2.5
        m |= c.poly([(x - 1.4, y0), (x + 1.4, y0), (x + 0.4, y0 + 15), (x - 0.4, y0 + 15)])
    c.fill(m, "steel4")
    c.fill(m & ~c.edge(m, -1, 0), "steel5")
    c.fill(c.edge(m, 1, 0) & m, "steel2")
    for i in range(5):
        x = int(5 + i * 4)
        c.px(x, int(3 + abs(i - 2) * 2.5) + 2, "white")
    c.outline("ink0")
    return c


def paste_mask(m, other, x0, y0):
    """OR the shape of a painted canvas into mask m, its top-left corner at (x0, y0), clipped."""
    h, w = m.shape
    a = other.alpha()
    oh, ow = a.shape
    x0, y0 = int(x0), int(y0)
    xa, ya = max(0, x0), max(0, y0)
    xb, yb = min(w, x0 + ow), min(h, y0 + oh)
    if xb > xa and yb > ya:
        m[ya:yb, xa:xb] |= a[ya - y0:yb - y0, xa - x0:xb - x0]
    return m


def gush(c, rng, cx, base, height, power=1.0, lean=0.0):
    """Blood driven upward from one point on a hard edge: a crushed pool, thick fingers
    tapering as they climb, and the fine spray that went furthest."""
    m = c.ell(cx, base, 30 * power, 5)
    for _ in range(7):
        m |= c.ell(cx + rng.normal(0, 13 * power), base - 3 - rng.uniform(0, 8), rng.uniform(4, 9) * power, rng.uniform(3, 6) * power)
    for _ in range(int(16 * power)):
        a = -np.pi / 2 + lean + rng.normal(0, 0.5)
        length = rng.uniform(0.3, 1.0) ** 1.2 * height * power
        w0 = rng.uniform(1.6, 4.4) * power
        steps = max(2, int(length))
        for s in range(steps):
            t = s / (steps - 1.0)
            r = max(0.5, w0 * (1.0 - t) ** 0.8)
            m |= c.ell(cx + np.cos(a) * length * t, base - 2 + np.sin(a) * length * t, r, r)
        if rng.random() < 0.8:                           # the drop that outran its finger
            d = length + rng.uniform(3, 9)
            r = rng.uniform(0.8, 2.2)
            m |= c.ell(cx + np.cos(a) * d, base - 2 + np.sin(a) * d, r, r)
    for _ in range(int(70 * power)):
        a = -np.pi / 2 + lean + rng.normal(0, 0.8)
        d = rng.uniform(10, height + 6) * power
        r = rng.choice([0.5, 0.5, 0.8, 1.2])
        m |= c.ell(cx + np.cos(a) * d, base - 2 + np.sin(a) * d, r, r)
    return m


def shutter_splash(seed=81):
    """The shutter lands on whatever was over the sill: blood driven up the slats from under
    its bottom bar, heaviest where the two arms were, then running back down."""
    rng = np.random.default_rng(seed)
    w, h = HOLE_W, 96
    c = Canvas(w, h)
    m = gush(c, rng, 166, h - 3, h - 16, 1.0, -0.12)     # the open hand, on our right
    m |= gush(c, rng, 64, h - 3, h - 16, 0.8, 0.15)      # the weapon arm, on our left
    for _ in range(50):
        m |= c.ell(rng.uniform(8, 212), rng.uniform(16, h - 6), 0.6, 0.6)
    m = drag_down(m, 14, rng, strength=1.0)
    return blood(c, m, seed=seed)


def shutter_gore(seed=91):
    """Our side of the emergency shutter after an attack that got through: where it came
    down on them, what they clawed on the way back under it, and all of it running."""
    rng = np.random.default_rng(seed)
    w, h = HOLE_W, 190
    c = Canvas(w, h)
    m = gush(c, rng, 112, h - 12, 118, 1.25)
    m = paste_mask(m, splat(118, seed + 1, spikes=17, core=0.2, drops=44), 52, 78)
    m = paste_mask(m, splat(64, seed + 2, spikes=11, drops=20), 6, 22)
    m = paste_mask(m, splat(52, seed + 3, spikes=10, drops=16), 160, 118)
    m = paste_mask(m, handprint(seed + 4, drag=74, thumb=1), 18, 62)       # dragged down, twice
    m = paste_mask(m, handprint(seed + 5, drag=96, thumb=-1), 164, 24)
    for _ in range(120):
        r = rng.choice([0.5, 0.5, 0.8, 1.2, 1.7])
        m |= c.ell(rng.uniform(4, 216), rng.uniform(6, h - 14), r, r)
    m = drag_down(m, 30, rng, strength=0.95)
    m &= c.rect(0, 0, w - 1, h - 9)                      # nothing on the rubber foot of the bar
    return blood(c, m, seed=seed)


# ------------------------------------------------------------------ the player's eyes
def vignette():
    """Tunnel vision: an ordered-dither ring, clear in the middle. Tinted by the game."""
    w, h = 640, 360
    c = Canvas(w, h)
    yy, xx = c.grid()
    d = np.sqrt(((xx - w / 2.0) / (w * 0.56)) ** 2 + ((yy - h / 2.0) / (h * 0.6)) ** 2)
    t = np.clip((d - 0.52) / 0.5, 0, 1) ** 1.25
    b = np.kron(bayer(h // 2 + 1, w // 2 + 1), np.ones((2, 2)))[:h, :w]      # 2 px cells
    c.fill(t > b, "white")
    return c


def main():
    def put(name, canvas):
        canvas.save("%s/%s.png" % (D, name))
        return (name, canvas)

    small = [put("splat_s%d" % i, splat(18 + 4 * i, 100 + i, spikes=7, drops=6)) for i in range(3)]
    mid = [put("splat_m%d" % i, splat(40 + 8 * i, 200 + i, spikes=9 + i, drops=14)) for i in range(3)]
    big = [put("splat_l%d" % i, splat(92 + 26 * i, 300 + i, spikes=13 + i, core=0.17, drops=34)) for i in range(3)]
    aimed = [put("splat_a%d" % i, splat(72, 400 + i, spikes=11, core=0.12, drops=28, aim=np.pi * (0.2 + 0.3 * i), spread=0.35)) for i in range(2)]
    glass = [put("hand_0", handprint(1, drag=0)), put("hand_1", handprint(2, drag=22)), put("smear_0", smear()),
             put("castoff_0", castoff()), put("gouge_0", gouge()), put("scorch", scorch()), put("scorch_hot", scorch_hot()),
             put("spray_0", spray()), put("smash_0", smash(120)), put("smash_1", smash(130, 62, 52, knuckles=4)),
             put("slit_0", slit())]
    shards = [put("shard_%d" % i, shard(500 + i, s)) for i, s in enumerate((6, 8, 10, 13, 16, 20, 25, 31))]
    sh = [put("dent_%d" % i, dent(600 + i, rx, ry)) for i, (rx, ry) in enumerate(((11, 9), (13, 10), (9, 8)))]
    sh += [put("cut_saw", cut_saw()), put("saw_tooth", saw_tooth()), put("burn", burn()), put("burn_hot", burn_hot())]
    sh += [put("cut_saw_clean", cut_saw(clean=True)), put("saw_tooth_clean", saw_tooth(clean=True))]
    sh += [put("dent_deep_%d" % i, dent(610 + i, rx, ry, deep=True)) for i, (rx, ry) in enumerate(((15, 12), (17, 13), (14, 11)))]
    sh += [put("scrape", scrape()), put("pick_tips", pick_tips())]
    contact_sheet(small + mid + aimed + glass + shards + sh, os.path.join(OUT, "gore_items.png"), scale=3, per_row=8, bg="teal3")
    contact_sheet(big, os.path.join(OUT, "gore_big.png"), scale=2, per_row=3, bg="paper3")
    wide = [put("crack_%d" % s, cracks(s)) for s in (1, 2, 3)]
    wide += [put("glass_broken", glass_broken()), put("glass_broken_clean", glass_broken(clean=True))]
    contact_sheet(wide, os.path.join(OUT, "gore_window.png"), scale=2, per_row=2, bg="teal2")
    strips = [put("sill_blood", sill_blood()), put("sill_glass", sill_glass()), put("shutter_splash", shutter_splash())]
    contact_sheet(strips, os.path.join(OUT, "gore_strips.png"), scale=3, per_row=1, bg="steel2")
    contact_sheet([put("shutter_gore", shutter_gore())], os.path.join(OUT, "gore_shutter.png"), scale=3, per_row=1, bg="steel2")
    v = vignette()
    v.save(D + "/vignette.png")
    print("gore art written")


if __name__ == "__main__":
    main()
