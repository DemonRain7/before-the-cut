"""Shared drawing helpers for the patient busts (160 x 176 layers).

Every patient is a stack of same-sized transparent layers, so the game can blink, glance,
talk and move hands without any per-patient offsets:

  body      torso, neck, and the eye whites that show through the holes in the head
  pupils    irises and pupils (shifted a pixel or two for the gaze)
  head      skull, hair, ears, nose, fixed implants; the eye openings are holes
  brows_*   neutral / angry / worried
  mouth_*   closed / a / b (talking) / upset / angry
  lids      closed eyelids for a blink
  hands_*   a / b (idle pair) / react (pressure) [/ attack]

The body meets the window sill at y = BASE_Y; hands reach over the sill below that line.
Light comes from the desk lamp, low on the left; a cool rim from the street sits on the right.
"""
import numpy as np
from scipy import ndimage as ndi

from px import Canvas

W, H = 160, 176
BASE_Y = 160
LIGHT = (-0.8, 0.3)
OUTLINE = "ink1"
RIM = "teal5"

SKIN = {
    "kip": ["2a1a24", "5c3230", "96553f", "c98058", "eeb082", "fbdcb0"],
    "rook": ["1c1218", "3a2020", "5e3428", "8a4e34", "b3704a", "d89a68"],
    "vale": ["252030", "4a3a48", "866a68", "b89a8c", "dcc4b0", "f2e6d4"],
    "juno": ["24161e", "4e2c2c", "7e4a38", "ac6c4a", "d6966a", "f2c494"],
    "maren": ["2a1c24", "5e3a38", "9a6050", "c98a70", "e8b498", "f8dcc4"],
    "priya": ["20121a", "442624", "704234", "9a5e44", "c0805c", "dea67e"],
    "ozzie": ["2a1618", "5c3430", "925646", "bc7e62", "dca486", "f2caa8"],
    "lux": ["2a1820", "5a3428", "8a5a3e", "b47e56", "d8a274", "f0c898"],
    "dana": ["241a20", "4e3438", "866062", "b48c84", "d8b4a4", "f0d8c8"],
    "bo": ["261a16", "52342a", "84583e", "ae7c56", "d2a072", "ecc494"],
}
CLOTH = {
    "hivis": ["4a2a22", "8a5a22", "c98a22", "e8b83a", "f8e088"],
    "hood": ["0b1014", "121c22", "1a2a31", "244049", "33606a"],
    "vest": ["0b1014", "1b2228", "2e3a42", "4a5a63", "70838a"],
    "thermal": ["1c1214", "3a2a2a", "5e4a44", "8a7468", "b8a492"],
    "suit": ["07090c", "121820", "1e2832", "34424e", "56687a"],
    "shirt": ["5a4e52", "8c7f68", "d9cdaf", "efe6cf", "fbf6e6"],
    "leather": ["07090c", "14121a", "241e2c", "3c3248", "5c5070"],
    "holo": ["14484f", "2a8f96", "5ee6e0", "c8fff6"],
    "canvas": ["1c1214", "2a1a1a", "4a2a22", "7a4630", "a86a3c"],
    "glove": ["3a2a1a", "6a4a2a", "9a7a4a", "c9a468", "e2c58a"],
    "apron": ["140e10", "2a1a1a", "3e2620", "5a3a2a"],
    "ginger": ["2a1418", "6a2c1c", "b4501e", "e88a34", "f8c070"],
    "black": ["07090c", "0e141c", "1a2632", "2c4250", "4a7080"],
    "violet": ["160c24", "30184a", "562c7a", "8450b0", "b888e0", "e4c4f8"],
    "grey": ["1b2228", "3e4a52", "70838a", "a3b5b6", "dbe6e0"],
    "chrome": ["1b2228", "2e3a42", "5a6c76", "9ab0b4", "dbe6e0", "ffffff"],
    "brass": ["2a1a1a", "5a3a22", "9a6a2c", "d4a040", "f4d880"],
    "scrubs": ["0c2a2c", "16484a", "22686a", "3a8a88", "6ab4ac"],
    "raincoat": ["0e1218", "1a2230", "2a3646", "40506a", "62748c"],
    "trench": ["2a2016", "4a3a26", "6e5a3c", "948058", "bca67a"],
    "cook": ["5a524a", "8a8270", "b8ae96", "dcd4bc", "f2ecd8"],
    "hoodie": ["0e0c14", "1c1826", "2e2a3c", "48425a", "6a6480"],
    "tank": ["07090c", "12161c", "1e242c", "2e3640", "48525e"],
    "inkhair": ["0a0608", "16100f", "241a18", "3a2c28", "5a4840"],
    "ash": ["1c2024", "3a4046", "626a70", "8e969a", "bcc2c2"],
    "silver": ["3a4046", "626a70", "8e969a", "bcc2c2", "e2e6e2"],
    "greasy": ["14181c", "262e34", "46545c", "748890", "a8bcbc", "d4e0dc"],
}


def disk(r):
    y, x = np.ogrid[-r:r + 1, -r:r + 1]
    return x * x + y * y <= r * r + 0.5


def smooth(m, r=2):
    return ndi.binary_opening(ndi.binary_closing(m, structure=disk(r)), structure=disk(r))


def grow(m, n=1):
    return ndi.binary_dilation(m, iterations=n)


def shrink(m, n=1):
    return ndi.binary_erosion(m, iterations=n)


def layer():
    return Canvas(W, H)


def head_mask(c, cx, cy, w, h, jaw=0.8, chin=0.42, drop=0.0):
    """Skull ellipse plus a jaw polygon; cy is the eye line."""
    skull = c.ell(cx, cy - h * 0.08, w / 2.0, h * 0.42)
    jy = cy + h * 0.30
    by = cy + h * 0.52 + drop
    jawp = c.poly([(cx - w / 2.0, cy - 2), (cx - w * jaw / 2.0, jy), (cx - w * chin / 2.0, by),
                   (cx + w * chin / 2.0, by), (cx + w * jaw / 2.0, jy), (cx + w / 2.0, cy - 2)])
    return smooth(skull | jawp, 3)


def almond(c, ex, ey, rx, ry):
    return c.ell(ex, ey, rx, ry) & c.ell(ex, ey + ry * 0.7, rx * 1.25, ry * 1.5) & c.ell(ex, ey - ry * 0.7, rx * 1.25, ry * 1.5)


def paint(c, mask, rmp, **kw):
    """Shade a volume lit by the desk lamp."""
    kw.setdefault("light", LIGHT)
    kw.setdefault("round_px", 7.0)
    c.shade(mask, rmp, **kw)


def finish(c, mask, rim=True, outline=True):
    """Cool rim on the street side, then the dark outline."""
    if rim:
        c.fill(c.edge(mask, 1, 0) & mask, RIM)
    if outline:
        c.outline(OUTLINE, mask)


def stroke(c, pts, color, width=1):
    c.fill(c.seg(pts, width), color)


# ------------------------------------------------------------------ face parts
def eye_whites(body, holes, lid_shadow="paper1"):
    """Sclera painted on the body layer behind the head's eye holes."""
    for m in holes:
        g = grow(m, 1)
        body.fill(g, "paper3")
        ys = np.nonzero(m)[0]
        if len(ys):
            top = ys.min()
            yy, _ = body.grid()
            body.fill(g & (yy <= top + 1), lid_shadow)


def natural_pupil(pupils, ex, ey, iris, r=3.2):
    pupils.fill(pupils.ell(ex, ey, r, r), iris[0])
    pupils.fill(pupils.ell(ex, ey + 0.4, r - 0.9, r - 0.9), iris[1])
    pupils.fill(pupils.ell(ex, ey, 1.5, 1.5), "ink0")
    pupils.px(ex - 1, ey - 2, "white")


def lid_lines(head, hole, skin, lash=1):
    """Dark upper lid and a soft lower lid drawn on the head around an eye hole."""
    yy, xx = head.grid()
    ys, xs = np.nonzero(hole)
    cy = (ys.min() + ys.max()) / 2.0
    ring = grow(hole, 1) & ~hole
    head.fill(ring & (yy <= cy), OUTLINE)
    head.fill(ring & (yy > cy), skin[2])
    if lash > 1:
        ring2 = grow(hole, 2) & ~grow(hole, 1)
        head.fill(ring2 & (yy < cy - 1), OUTLINE)


def blink(lids, hole, skin):
    yy, xx = lids.grid()
    g = grow(hole, 1)
    lids.fill(g, skin[3])
    ys = np.nonzero(hole)[0]
    cy = int(round((ys.min() + ys.max()) / 2.0)) + 1
    lids.fill(g & (yy == cy + 1), OUTLINE)
    lids.fill(g & (yy < cy - 1), skin[4])


def nose(head, cx, y0, y1, skin, w=3):
    stroke(head, [(cx + 1, y0), (cx + w - 1, y1 - 2)], skin[2])
    stroke(head, [(cx - w, y1), (cx + w, y1)], skin[2])
    head.px(cx - w, y1 - 1, skin[2])
    head.px(cx + w, y1 - 1, skin[1])
    stroke(head, [(cx - 1, y1 - 2), (cx, y1 - 1)], skin[5])
    head.px(cx - 2, y1, skin[1])
    head.px(cx + 2, y1, skin[1])


def brow(c, x0, y0, x1, y1, color, width=2):
    m = c.seg([(x0, y0), (x1, y1)], width)
    c.fill(m, color)


def brows_set(cx, cy, dx, color, width=2, lift=0, span=8):
    """Three brow layers. dx is the eye offset from the centre line."""
    out = {}
    for name, (inner, outer) in {"neutral": (-10, -11), "angry": (-7, -12), "worried": (-13, -9)}.items():
        c = layer()
        for s in (-1, 1):
            xi, xo = cx + s * (dx - span + 2), cx + s * (dx + span)
            brow(c, xi, cy + inner - lift, xo, cy + outer - lift, color, width)
        out[name] = c
    return out


def mouth_frames(cx, my, skin, width=9, curve=0.0, lip=None, teeth="paper3"):
    """closed / a / b / upset / angry mouth layers. curve > 0 smiles, < 0 frowns."""
    dark = "1a0c10"
    out = {}
    hw = width // 2

    c = layer()
    pts = [(cx - hw, my - round(curve * 2)), (cx - hw + 2, my), (cx + hw - 2, my), (cx + hw, my - round(curve * 2))]
    stroke(c, pts, dark)
    stroke(c, [(cx - 2, my + 2), (cx + 2, my + 2)], skin[2])
    if lip:
        stroke(c, [(cx - hw + 2, my + 1), (cx + hw - 2, my + 1)], lip)
    out["closed"] = c

    c = layer()
    m = c.ell(cx, my + 0.5, hw - 0.5, 1.8)
    c.fill(m, dark)
    stroke(c, [(cx - 2, my - 1), (cx + 2, my - 1)], teeth)
    c.outline(skin[1], m)
    out["a"] = c

    c = layer()
    m = c.ell(cx, my + 1, hw - 1, 3.2)
    c.fill(m, dark)
    stroke(c, [(cx - 2, my - 1), (cx + 2, my - 1)], teeth)
    stroke(c, [(cx - 1, my + 3), (cx + 1, my + 3)], "8a3038")
    c.outline(skin[1], m)
    out["b"] = c

    c = layer()
    m = c.ell(cx, my + 1, hw - 1, 2.6)
    c.fill(m, dark)
    stroke(c, [(cx - hw, my + 2), (cx - hw + 1, my + 1)], dark)
    stroke(c, [(cx + hw, my + 2), (cx + hw - 1, my + 1)], dark)
    stroke(c, [(cx - 2, my - 1), (cx + 1, my - 1)], teeth)
    c.outline(skin[1], m)
    out["upset"] = c

    c = layer()
    m = c.rrect(cx - hw - 1, my - 2, cx + hw + 1, my + 4, 2)
    c.fill(m, dark)
    stroke(c, [(cx - hw + 1, my - 2), (cx + hw - 1, my - 2)], teeth)
    stroke(c, [(cx - hw + 2, my + 4), (cx + hw - 2, my + 4)], teeth)
    stroke(c, [(cx - 1, my + 2), (cx + 1, my + 2)], "8a3038")
    c.outline(skin[1], m)
    out["angry"] = c
    return out


# ------------------------------------------------------------------ hands at bust scale
def sleeve(c, x, y0, y1, w, cloth):
    m = c.rrect(x - w // 2, y0, x + w // 2, y1, 2)
    paint(c, m, cloth, round_px=4)
    return m


def hand_rest(c, x, y, w, skin, lifted=(), nails=None, seams=None, side=1, h=13):
    """A hand lying on the sill, fingers toward the viewer. side=1: thumb on the right."""
    fw = max(3, (w - 3) // 4)
    w = fw * 4 + 3
    x0 = x - w // 2
    back = c.rrect(x0, y, x0 + w - 1, y + h - 6, 2)
    m = back.copy()
    fingers = []
    for i in range(4):
        fx = x0 + i * (fw + 1)
        up = 3 if i in lifted else 0
        f = c.rrect(fx, y + 4, fx + fw - 1, y + h - up, 1)
        fingers.append((f, fx, up))
        m |= f
    tx = x0 + w if side > 0 else x0 - 3
    thumb = c.rrect(tx - 1, y + 1, tx + 2, y + 7, 1)
    m |= thumb
    paint(c, m, skin, round_px=3, round_amt=0.4, contrast=0.8)
    for f, fx, up in fingers:
        if fx > x0:
            stroke(c, [(fx - 1, y + 5), (fx - 1, y + h - up)], skin[1])
        if up:
            c.fill(f, skin[5])
            stroke(c, [(fx, y + h - up + 1), (fx + fw - 1, y + h - up + 1)], "warm0")
        if nails:
            stroke(c, [(fx + 1, y + h - up - 1), (fx + fw - 2, y + h - up - 1)], nails)
    stroke(c, [(x0 + 1, y + 4), (x0 + w - 2, y + 4)], skin[4])
    if seams:
        stroke(c, [(x0 + 1, y + 2), (x0 + w - 2, y + 2)], seams)
    c.outline(OUTLINE, m)
    return m


def fist(c, x, y, w, skin, knuckle=None, h=11, side=1):
    m = c.rrect(x - w // 2, y, x + w // 2, y + h, 3)
    tx = x + w // 2 + 1 if side > 0 else x - w // 2 - 3
    m |= c.rrect(tx - 1, y + 4, tx + 2, y + 9, 1)
    paint(c, m, skin, round_px=3, round_amt=0.5)
    fw = (w - 2) // 4
    for i in range(1, 4):
        fx = x - w // 2 + 1 + i * fw
        stroke(c, [(fx, y + 3), (fx, y + h - 1)], skin[1])
    stroke(c, [(x - w // 2 + 1, y + 6), (x + w // 2 - 1, y + 6)], skin[2])
    for i in range(4):
        kx = x - w // 2 + 2 + i * fw + fw // 2 - 1
        c.px(kx, y + 1, knuckle or skin[5])
        c.px(kx + 1, y + 1, knuckle or skin[5])
    c.outline(OUTLINE, m)
    return m


def palm_up(c, x, y, w, skin, side=1, h=12):
    """A raised open hand, palm toward the viewer, fingers up."""
    fw = max(3, (w - 3) // 4)
    w = fw * 4 + 3
    x0 = x - w // 2
    m = c.rrect(x0, y, x0 + w - 1, y + h, 3)
    for i, ln in enumerate((9, 11, 11, 8) if side > 0 else (8, 11, 11, 9)):
        fx = x0 + i * (fw + 1)
        m |= c.rrect(fx, y - ln, fx + fw - 1, y + 2, 1)
    tx = x0 + w + 1 if side > 0 else x0 - 4
    m |= c.rrect(tx - 1, y + 1, tx + 2, y + 8, 1)
    paint(c, m, skin, round_px=4, round_amt=0.5, bias=0.06)
    for i in range(1, 4):
        fx = x0 + i * (fw + 1) - 1
        stroke(c, [(fx, y - 8), (fx, y + 1)], skin[1])
    stroke(c, [(x0 + 2, y + 5), (x0 + w - 3, y + 6)], skin[2])
    c.outline(OUTLINE, m)
    return m


def palm_flat(c, x, y, w, skin, side=1, h=14, wet=False):
    """An open hand slammed flat against the glass: fingers spread, pads squashed pale.
    (x, y) is the top centre of the palm; side is the thumb side."""
    hw = w // 2
    m = c.rrect(x - hw, y, x + hw, y + h, 4)
    spread = (-8, -3, 2, 7) if side > 0 else (-7, -2, 3, 8)
    lens = (11, 14, 13, 10) if side > 0 else (10, 13, 14, 11)
    pads = []
    for i in range(4):
        bx = x - hw + 2 + i * (w - 5) / 3.0
        tx, ty = bx + spread[i] * 0.7, y - lens[i]
        m |= c.seg([(bx, y + 3), (tx, ty)], 4)
        pads.append((tx, ty))
    tt = (x + side * (hw + 8), y + h * 0.1)
    m |= c.seg([(x + side * (hw - 2), y + h * 0.6), tt], 4)
    pads.append(tt)
    paint(c, m, skin, round_px=4, round_amt=0.5, bias=0.02)
    for i in range(3):                                   # the gaps between the fingers
        bx = x - hw + 2 + (i + 0.5) * (w - 5) / 3.0
        c.px(int(round(bx)), y + 1, skin[1])
        c.px(int(round(bx)), y + 2, skin[1])
    stroke(c, [(x - hw + 3, y + h * 0.42), (x + hw - 3, y + h * 0.5)], skin[2])
    stroke(c, [(x - side * 1, y + h * 0.45), (x + side * (hw - 5), y + h - 2)], skin[2])
    pale = skin[-1]
    for tx, ty in pads:
        c.fill(c.ell(tx, ty + 1.2, 1.5, 1.9) & m, pale)
    c.fill(c.ell(x - side * 4, y + h - 4, 4.2, 2.4) & m, pale)
    c.fill(c.ell(x + side * 5, y + h - 5, 2.6, 2.6) & m, pale)
    c.fill(c.ell(x, y + 3, hw - 3, 1.6) & m, pale)
    if wet:                                              # blood caught in the creases
        rng = np.random.default_rng(int(x) * 7 + int(y))
        c.fill(m & (rng.random(m.shape) < 0.16), "red1")
        stroke(c, [(x - hw + 3, y + h * 0.42 + 1), (x + hw - 3, y + h * 0.5 + 1)], "red1")
        for tx, ty in pads[:4]:
            c.px(int(round(tx)), int(round(ty)) + 4, "red1")
            c.px(int(round(tx)), int(round(ty)) + 5, "red0")
    c.outline(OUTLINE, m)
    return m


def blood_run(c, pts, wide=False, bead=True, clip=None):
    """A run of blood down skin; pts is its path, top to bottom."""
    m = c.seg(pts, 2 if wide else 1)
    if clip is not None:
        m &= clip
    c.fill(m, "red1")
    if wide:
        c.fill(c.edge(m, 1, 0) & m, "red0")
        c.fill(c.edge(m, -1, 0) & m, "red2")
    x0, y0 = pts[0]
    c.px(int(round(x0)), int(round(y0)), "red0")
    if bead:
        x, y = pts[-1]
        c.px(int(round(x)), int(round(y)) + 1, "red2")
        c.px(int(round(x)), int(round(y)) + 2, "red1")


def threads(c, mask, roots, seed=0, color="2a1436", tip="6a3c86"):
    """Dark threads crawling under the skin. Each root is (x, y, angle, length); angles are
    in image space, so -pi/2 points up. Drawn only inside mask."""
    rng = np.random.default_rng(seed)
    veins = c.none()
    ends = c.none()

    def crawl(x, y, a, length, depth):
        nonlocal veins, ends
        pts = [(x, y)]
        d = 0.0
        while d < length:
            step = rng.uniform(2.5, 4.5)
            a += rng.uniform(-0.6, 0.6)
            x, y = x + np.cos(a) * step, y + np.sin(a) * step
            pts.append((x, y))
            d += step
            if depth < 2 and rng.random() < 0.32:
                crawl(x, y, a + rng.choice([-1.0, 1.0]) * rng.uniform(0.6, 1.2), (length - d) * rng.uniform(0.4, 0.8) + 3, depth + 1)
        veins |= c.seg(pts, 1)
        ends |= c.seg(pts[-2:], 1)

    for x, y, a, length in roots:
        crawl(x, y, a, length, 0)
    c.fill(veins & mask, color)
    c.fill(ends & mask, tip)
    return veins & mask


def silhouette(layers, scale=0.62):
    """A phosphor-green figure for the hall camera, from the union of the given layers."""
    from PIL import Image
    a = np.zeros((H, W), dtype=bool)
    for l in layers:
        a |= l.alpha()
    a[BASE_Y:, :] = False
    ys, xs = np.nonzero(a)
    crop = a[ys.min():BASE_Y, xs.min():xs.max() + 1]
    im = Image.fromarray((crop * 255).astype(np.uint8), "L")
    nw, nh = max(1, int(round(im.width * scale))), max(1, int(round(im.height * scale)))
    small = np.array(im.resize((nw, nh), Image.LANCZOS)) > 110
    c = Canvas(nw + 2, nh + 1)
    m = np.zeros((nh + 1, nw + 2), dtype=bool)
    m[1:, 1:-1] = small
    c.fill(m, "grn0")
    c.dither(m, "grn1", 0.5)
    c.fill(c.edge(m, 1, 0) | c.edge(m, 0, -1), "grn3")
    c.fill(c.edge(m, -1, 0), "grn1")
    return c
