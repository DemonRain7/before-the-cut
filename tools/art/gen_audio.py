"""Synthesised sound effects and ambience for Before the Cut.

Run from tools/art:  python gen_audio.py
Writes 16-bit mono WAV files (22050 Hz) to game/assets/audio. Everything is generated
from oscillators and filtered noise below; no recorded or third-party audio is used.
"""
import os
import wave

import numpy as np
from scipy import signal

from px import ASSETS

SR = 22050
OUTDIR = os.path.join(ASSETS, "audio")
SEED = 1977
rng = np.random.default_rng(SEED)


def t(sec):
    return np.arange(int(SR * sec)) / SR


def noise(sec):
    return rng.uniform(-1.0, 1.0, int(SR * sec))


def lp(x, hz, order=2):
    b, a = signal.butter(order, min(hz, SR * 0.49) / (SR / 2), "low")
    return signal.lfilter(b, a, x)


def hp(x, hz, order=2):
    b, a = signal.butter(order, hz / (SR / 2), "high")
    return signal.lfilter(b, a, x)


def bp(x, lo, hi, order=2):
    b, a = signal.butter(order, [lo / (SR / 2), min(hi, SR * 0.49) / (SR / 2)], "band")
    return signal.lfilter(b, a, x)


def env(n, attack=0.005, decay=0.2, curve=1.0):
    x = np.arange(n) / SR
    a = np.clip(x / max(attack, 1e-5), 0, 1)
    d = np.exp(-np.maximum(x - attack, 0) / max(decay, 1e-5) * curve)
    return a * d


def fade(x, a=0.004, r=0.01):
    n = len(x)
    y = x.copy()
    na, nr = int(SR * a), int(SR * r)
    if na:
        y[:na] *= np.linspace(0, 1, na)
    if nr:
        y[-nr:] *= np.linspace(1, 0, nr)
    return y


def sine(freq, sec, phase=0.0):
    return np.sin(2 * np.pi * freq * t(sec) + phase)


def sweep(f0, f1, sec, shape=1.0):
    x = t(sec)
    k = (x / sec) ** shape
    f = f0 + (f1 - f0) * k
    return np.sin(2 * np.pi * np.cumsum(f) / SR)


def square(freq, sec, duty=0.5):
    return np.where((t(sec) * freq) % 1.0 < duty, 1.0, -1.0)


def mix(*parts):
    n = max(len(p) for p in parts)
    out = np.zeros(n)
    for p in parts:
        out[:len(p)] += p
    return out


def at(base_len_sec, *placed):
    out = np.zeros(int(SR * base_len_sec))
    for start, x in placed:
        i = int(SR * start)
        x = x[:max(0, len(out) - i)]
        out[i:i + len(x)] += x
    return out


def bits(x, levels=12, hold=3):
    y = np.round(x * levels) / levels
    return np.repeat(y[::hold], hold)[:len(x)]


def save(name, x, gain=0.8, norm=True):
    os.makedirs(OUTDIR, exist_ok=True)
    x = np.asarray(x, dtype=np.float64)
    if norm and np.max(np.abs(x)) > 0:
        x = x / np.max(np.abs(x))
    x = np.clip(x * gain, -1, 1)
    data = (x * 32767).astype("<i2")
    with wave.open(os.path.join(OUTDIR, name + ".wav"), "wb") as w:
        w.setnchannels(1)
        w.setsampwidth(2)
        w.setframerate(SR)
        w.writeframes(data.tobytes())
    return len(data) / SR


def loop_noise(sec, shape):
    """Periodic noise: random phases with a chosen magnitude curve, so the loop has no seam."""
    n = int(SR * sec)
    freqs = np.fft.rfftfreq(n, 1 / SR)
    mag = shape(freqs)
    spec = mag * np.exp(1j * rng.uniform(0, 2 * np.pi, len(freqs)))
    spec[0] = 0
    x = np.fft.irfft(spec, n)
    return x / np.max(np.abs(x))


# ------------------------------------------------------------------ ambience
def amb_rain():
    sec = 8.0
    rain = loop_noise(sec, lambda f: np.exp(-((np.log(np.maximum(f, 1)) - np.log(2600)) ** 2) / 0.9))
    rumble = loop_noise(sec, lambda f: np.where(f < 140, 1.0, 0.0) * np.maximum(f, 20) ** -0.5)
    x = t(sec)
    swell = 0.8 + 0.2 * np.sin(2 * np.pi * x / sec) * np.sin(2 * np.pi * 3 * x / sec)
    hum = 0.5 * np.sin(2 * np.pi * 50 * x) + 0.25 * np.sin(2 * np.pi * 100 * x) + 0.1 * np.sin(2 * np.pi * 150 * x)
    out = rain * swell * 0.55 + rumble * 0.5 + hum * 0.16
    # a few window drips, placed away from the seam
    for start, f in ((1.3, 1900), (3.1, 2300), (3.22, 1700), (5.6, 2100), (6.9, 1500)):
        d = sweep(f, f * 0.6, 0.05) * env(int(SR * 0.05), 0.001, 0.015)
        i = int(SR * start)
        out[i:i + len(d)] += d * 0.25
    return out


def amb_drone():
    sec = 16.0
    x = t(sec)
    out = np.zeros_like(x)
    # D minor cluster; every frequency is a multiple of 1/16 Hz so the loop closes
    for f, a in ((73.4375, 0.5), (73.6875, 0.35), (110.0, 0.3), (146.875, 0.2), (174.625, 0.16), (220.0625, 0.08)):
        ph = rng.uniform(0, 2 * np.pi)
        saw = sum(np.sin(2 * np.pi * f * k * x + ph * k) / k for k in range(1, 7))
        out += saw * a * (0.75 + 0.25 * np.sin(2 * np.pi * x * (1 + int(f) % 3) / sec + ph))
    out = lp(np.concatenate([out, out]), 420)[len(out):]
    shimmer = loop_noise(sec, lambda f: np.exp(-((f - 3200) / 500.0) ** 2)) * (0.5 + 0.5 * np.sin(2 * np.pi * x * 2 / sec))
    return out + shimmer * 0.05


def scope_hum():
    sec = 2.0
    x = t(sec)
    out = 0.5 * np.sin(2 * np.pi * 120 * x) + 0.2 * np.sin(2 * np.pi * 240 * x) + 0.12 * np.sin(2 * np.pi * 1800 * x) * (0.5 + 0.5 * np.sin(2 * np.pi * 3 * x))
    return out + loop_noise(sec, lambda f: np.exp(-((f - 5000) / 1500.0) ** 2)) * 0.08


# ------------------------------------------------------------------ door and people
def bell(freq, sec, decay=0.5):
    n = int(SR * sec)
    x = t(sec)
    out = np.zeros(n)
    for mult, a, d in ((1.0, 1.0, 1.0), (2.76, 0.4, 0.6), (5.4, 0.2, 0.35), (8.9, 0.1, 0.2)):
        out += a * np.sin(2 * np.pi * freq * mult * x) * np.exp(-x / (decay * d))
    return out * np.clip(x / 0.002, 0, 1)


def door_chime():
    return at(1.3, (0.0, bell(1318.5, 0.9, 0.35)), (0.28, bell(1046.5, 1.0, 0.45)))


def door_open():
    whoosh = bp(noise(0.5), 300, 2400) * env(int(SR * 0.5), 0.12, 0.16)
    latch = bp(noise(0.05), 1500, 5000) * env(int(SR * 0.05), 0.001, 0.012)
    thump = sweep(140, 60, 0.18) * env(int(SR * 0.18), 0.002, 0.06)
    return at(0.7, (0.0, latch * 0.8), (0.03, whoosh * 0.6), (0.36, thump * 0.7))


def door_slam():
    boom = sweep(160, 45, 0.4) * env(int(SR * 0.4), 0.001, 0.1)
    crack = lp(noise(0.12), 3500) * env(int(SR * 0.12), 0.001, 0.025)
    rattle = bp(noise(0.5), 900, 3000) * env(int(SR * 0.5), 0.02, 0.12) * (0.5 + 0.5 * square(38, 0.5))
    return at(0.7, (0.0, boom), (0.0, crack * 0.9), (0.06, rattle * 0.25))


def step():
    thud = sweep(110, 55, 0.12) * env(int(SR * 0.12), 0.002, 0.04)
    scuff = bp(noise(0.08), 500, 2500) * env(int(SR * 0.08), 0.004, 0.02)
    return mix(thud, scuff * 0.3)


def blip():
    n = int(SR * 0.055)
    x = t(0.055)
    tone = 0.6 * np.sign(np.sin(2 * np.pi * 300 * x)) + 0.8 * np.sin(2 * np.pi * 300 * x) + 0.3 * np.sin(2 * np.pi * 600 * x)
    return lp(tone, 1800) * env(n, 0.004, 0.022)


def blip_glitch():
    n = int(SR * 0.055)
    x = t(0.055)
    tone = np.sign(np.sin(2 * np.pi * 300 * x + 3.0 * np.sin(2 * np.pi * 95 * x)))
    return bits(lp(tone, 2600) * env(n, 0.002, 0.024), 5, 4)


def blip_narrate():
    n = int(SR * 0.02)
    return bp(noise(0.02), 2500, 6000) * env(n, 0.001, 0.006)


# ------------------------------------------------------------------ desk
def pencil():
    sec = 0.34
    x = t(sec)
    strokes = np.clip(np.sin(2 * np.pi * 7.5 * x + 0.4), 0, 1) ** 0.6
    wob = 0.6 + 0.4 * np.sin(2 * np.pi * 31 * x)
    return bp(noise(sec), 1800, 6500) * strokes * wob * fade(np.ones(len(x)), 0.01, 0.05)


def paper():
    sec = 0.32
    x = t(sec)
    return bp(noise(sec), 700, 5000) * np.sin(np.pi * x / sec) ** 2 * (0.7 + 0.3 * np.sin(2 * np.pi * 23 * x))


def stamp():
    thunk = sweep(190, 70, 0.16) * env(int(SR * 0.16), 0.001, 0.045)
    slap = lp(noise(0.05), 2600) * env(int(SR * 0.05), 0.001, 0.012)
    wood = sine(620, 0.05) * env(int(SR * 0.05), 0.001, 0.012)
    return mix(thunk, slap * 0.7, wood * 0.25)


def click():
    return mix(sine(1900, 0.03) * env(int(SR * 0.03), 0.001, 0.006), bp(noise(0.02), 2000, 7000) * env(int(SR * 0.02), 0.001, 0.004) * 0.6)


def hover():
    return sine(1250, 0.025) * env(int(SR * 0.025), 0.002, 0.007)


def tool_pick():
    ring = sum(sine(f, 0.22) * a for f, a in ((2100, 1.0), (3370, 0.5), (5120, 0.3))) * env(int(SR * 0.22), 0.001, 0.05)
    knock = lp(noise(0.03), 1800) * env(int(SR * 0.03), 0.001, 0.008)
    return mix(ring * 0.5, knock)


def tool_put():
    knock = sweep(260, 120, 0.07) * env(int(SR * 0.07), 0.001, 0.02)
    return mix(knock, lp(noise(0.03), 2200) * env(int(SR * 0.03), 0.001, 0.008) * 0.6)


def light_on():
    tick = bp(noise(0.015), 2500, 8000) * env(int(SR * 0.015), 0.0005, 0.004)
    whine = sweep(5200, 6400, 0.25) * env(int(SR * 0.25), 0.02, 0.09) * 0.12
    return at(0.3, (0.0, tick), (0.01, whine))


def grip_squeeze():
    sec = 0.4
    x = t(sec)
    creak = np.sin(2 * np.pi * (140 + 60 * x / sec) * x + 4.0 * np.sin(2 * np.pi * 43 * x))
    return lp(creak, 1400) * np.sin(np.pi * x / sec) ** 0.7 * (0.6 + 0.4 * square(57, sec))


def grip_release():
    spring = sweep(420, 1300, 0.07) * env(int(SR * 0.07), 0.001, 0.02)
    tick = bp(noise(0.02), 1500, 6000) * env(int(SR * 0.02), 0.001, 0.005)
    return mix(spring * 0.6, tick)


def beep():
    return fade(square(880, 0.09) * 0.4 + sine(880, 0.09), 0.003, 0.02)


def beep_low():
    return fade(square(330, 0.16) * 0.4 + sine(330, 0.16), 0.003, 0.03)


def lever():
    clunk = sweep(230, 80, 0.12) * env(int(SR * 0.12), 0.001, 0.035)
    ratchet = at(0.14, *[(i * 0.018, bp(noise(0.01), 1800, 6000) * env(int(SR * 0.01), 0.0005, 0.003)) for i in range(4)])
    return at(0.3, (0.0, ratchet * 0.7), (0.07, clunk))


def printer():
    sec = 0.9
    x = t(sec)
    chatter = square(92, sec, 0.3) * 0.5 + 0.5
    head = bp(noise(sec), 1800, 5200) * chatter
    motor = np.sin(2 * np.pi * 185 * x) * 0.25 + np.sin(2 * np.pi * 370 * x) * 0.1
    lines = (np.sin(2 * np.pi * 5.5 * x) > -0.2).astype(float)
    return fade((head * 0.8 + motor) * lines, 0.01, 0.06)


def tear():
    sec = 0.22
    x = t(sec)
    return hp(noise(sec), 1500) * (x / sec) ** 0.5 * fade(np.ones(len(x)), 0.005, 0.03) * (0.6 + 0.4 * square(140, sec))


# ------------------------------------------------------------------ danger
def shutter_slam():
    boom = sweep(120, 38, 0.6) * env(int(SR * 0.6), 0.001, 0.16)
    clang = sum(sine(f, 0.7) * a for f, a in ((233, 1.0), (391, 0.6), (617, 0.45), (1043, 0.3), (1630, 0.2))) * env(int(SR * 0.7), 0.001, 0.14)
    crash = lp(noise(0.25), 5000) * env(int(SR * 0.25), 0.001, 0.05)
    rattle = bp(noise(0.7), 1200, 4200) * env(int(SR * 0.7), 0.03, 0.16) * (0.5 + 0.5 * square(46, 0.7))
    roll = at(0.2, *[(i * 0.022, bp(noise(0.012), 900, 4000) * env(int(SR * 0.012), 0.0005, 0.004)) for i in range(8)])
    return at(1.1, (0.0, roll * 0.5), (0.17, boom), (0.17, clang * 0.45), (0.17, crash * 0.9), (0.24, rattle * 0.3))


def shutter_roll():
    sec = 0.9
    clacks = [(i * 0.055, bp(noise(0.02), 700, 3600) * env(int(SR * 0.02), 0.0005, 0.006) * (0.6 + 0.4 * rng.random())) for i in range(15)]
    motor = lp(square(64, sec), 500) * fade(np.ones(int(SR * sec)), 0.05, 0.15) * 0.3
    return mix(at(sec, *clacks), motor)


def bang():
    boom = sweep(150, 50, 0.35) * env(int(SR * 0.35), 0.001, 0.09)
    ring = sum(sine(f, 0.5) * a for f, a in ((277, 1.0), (463, 0.5), (741, 0.4), (1210, 0.2))) * env(int(SR * 0.5), 0.001, 0.11)
    crack = lp(noise(0.06), 3800) * env(int(SR * 0.06), 0.001, 0.014)
    return mix(boom, ring * 0.4, crack * 0.8)


def hit():
    smash = hp(noise(0.5), 2200) * env(int(SR * 0.5), 0.001, 0.09)
    shards = at(0.9, *[(0.05 + rng.random() * 0.6, sine(2500 + rng.random() * 4500, 0.08) * env(int(SR * 0.08), 0.001, 0.02) * 0.4) for _ in range(16)])
    thud = sweep(100, 32, 0.5) * env(int(SR * 0.5), 0.001, 0.15)
    return at(1.0, (0.0, smash * 0.8), (0.0, shards), (0.02, thud))


def whine():
    sec = 1.8
    x = t(sec)
    f = 320 * (2.0 ** (2.3 * (x / sec) ** 1.6))
    ph = 2 * np.pi * np.cumsum(f) / SR
    tone = np.sin(ph) * 0.6 + np.sign(np.sin(ph * 2.01)) * 0.12 + np.sin(ph * 3.0) * 0.15
    trem = 0.75 + 0.25 * np.sin(2 * np.pi * (6 + 18 * x / sec) * x)
    # a 60 ms release: the file used to end at 0.6 of full scale, which clicks wherever it stops
    return lp(tone, 6000) * trem * np.clip(x / 0.05, 0, 1) * (0.35 + 0.65 * x / sec) * fade(np.ones(len(x)), 0.0, 0.06)


def alarm():
    sec = 0.6
    a = square(740, 0.3) * 0.5 + sine(740, 0.3)
    b = square(554, 0.3) * 0.5 + sine(554, 0.3)
    return lp(np.concatenate([fade(a, 0.004, 0.01), fade(b, 0.004, 0.01)]), 3200)[:int(SR * sec)]


def heartbeat():
    def thump(f):
        return sweep(f, f * 0.5, 0.11) * env(int(SR * 0.11), 0.004, 0.035)
    return lp(at(0.75, (0.0, thump(78)), (0.2, thump(62) * 0.75)), 260)


def sting():
    sec = 0.9
    x = t(sec)
    out = np.zeros_like(x)
    for f, a in ((98.0, 1.0), (103.8, 0.8), (146.8, 0.5), (207.6, 0.35)):
        out += a * np.sign(np.sin(2 * np.pi * f * x)) * 0.5 + a * np.sin(2 * np.pi * f * x)
    return lp(out, 900) * env(len(x), 0.004, 0.28)


def calm():
    return at(0.9, (0.0, bell(659.3, 0.7, 0.3) * 0.7), (0.12, bell(880.0, 0.75, 0.32) * 0.6))


# ------------------------------------------------------------------ the attack
def scream(sec=1.15, f0=420.0, f1=760.0):
    """A voice pushed past what a throat does: a torn, wavering tone through two formants."""
    x = t(sec)
    k = x / sec
    f = f0 + (f1 - f0) * np.sin(np.pi * np.clip(k * 1.25, 0, 1)) ** 0.7       # up fast, sagging at the end
    f = f * (1.0 + 0.035 * np.sin(2 * np.pi * 31 * x) + 0.2 * lp(noise(sec), 60))
    ph = 2 * np.pi * np.cumsum(f) / SR
    saw = 2.0 * ((ph / (2 * np.pi)) % 1.0) - 1.0
    sub = np.sign(np.sin(ph * 0.5)) * 0.35                                   # the throat breaking up
    src = saw + sub + hp(noise(sec), 1800) * 0.35
    voice = bp(src, 700, 1300) + bp(src, 2300, 3400) * 0.7 + bp(src, 3900, 5200) * 0.25
    voice = np.tanh(voice * 3.0)
    return voice * np.clip(x / 0.03, 0, 1) * np.clip((sec - x) / 0.22, 0, 1) * (0.8 + 0.2 * np.sin(2 * np.pi * 17 * x))


def scream_far():
    """The same voice through a steel shutter."""
    return lp(scream(0.95, 360.0, 600.0), 850, 3) * 1.4


def turn_hit():
    """The moment a patient turns: a low dissonant slab with the floor dropping out under it."""
    sec = 1.3
    x = t(sec)
    cluster = sum(np.sign(np.sin(2 * np.pi * f * x)) * a
                  for f, a in ((61.7, 1.0), (65.4, 0.9), (92.5, 0.6), (130.8, 0.4), (138.6, 0.4), (554.4, 0.12), (587.3, 0.12)))
    body = lp(cluster, 1400) * env(len(x), 0.003, 0.4)
    sub = sweep(70, 28, 0.7) * env(int(SR * 0.7), 0.002, 0.25) * 1.2
    crack = hp(noise(0.05), 2500) * env(int(SR * 0.05), 0.0005, 0.01)
    return mix(body, sub, crack * 0.6)


def glass_crack():
    snap = hp(noise(0.03), 3000) * env(int(SR * 0.03), 0.0005, 0.006)
    ticks = at(0.45, *[(0.02 + rng.random() ** 2 * 0.36,
                        sine(3200 + rng.random() * 5200, 0.012) * env(int(SR * 0.012), 0.0005, 0.003) * (0.25 + 0.5 * rng.random()))
                       for _ in range(22)])
    creak = bp(noise(0.3), 2600, 6200) * env(int(SR * 0.3), 0.01, 0.07) * (0.5 + 0.5 * square(190, 0.3)) * 0.25
    thud = sweep(160, 60, 0.12) * env(int(SR * 0.12), 0.001, 0.03) * 0.5
    return at(0.5, (0.0, snap), (0.0, thud), (0.0, ticks), (0.02, creak))


def glass_shatter():
    burst = hp(noise(0.35), 1800) * env(int(SR * 0.35), 0.0005, 0.07)
    body = bp(noise(0.5), 600, 2600) * env(int(SR * 0.5), 0.001, 0.09) * 0.6
    shards = at(1.5, *[(0.03 + rng.random() ** 1.6 * 1.25,
                        sine(1800 + rng.random() * 6500, 0.14) * env(int(SR * 0.14), 0.0005, 0.03 + rng.random() * 0.03) * (0.15 + 0.4 * rng.random()))
                       for _ in range(46)])
    thud = sweep(110, 36, 0.4) * env(int(SR * 0.4), 0.001, 0.12)
    return at(1.6, (0.0, burst), (0.0, body), (0.0, shards), (0.01, thud * 0.8))


def splat():
    slap = lp(noise(0.09), 1400) * env(int(SR * 0.09), 0.001, 0.02)
    wet = bp(noise(0.3), 300, 2200) * env(int(SR * 0.3), 0.004, 0.06) * (0.55 + 0.45 * np.sin(2 * np.pi * 23 * t(0.3)))
    drops = at(0.5, *[(0.08 + rng.random() * 0.34, sweep(900 + rng.random() * 700, 300, 0.03) * env(int(SR * 0.03), 0.001, 0.008) * 0.35)
                      for _ in range(7)])
    low = sweep(140, 55, 0.14) * env(int(SR * 0.14), 0.001, 0.035)
    return at(0.55, (0.0, slap), (0.0, low * 0.8), (0.01, wet * 0.7), (0.0, drops))


def crunch():
    """The shutter coming down on something that was reaching through."""
    thud = sweep(130, 40, 0.3) * env(int(SR * 0.3), 0.001, 0.08)
    snaps = at(0.35, *[(0.01 + i * 0.028 + rng.random() * 0.01, lp(noise(0.02), 2600) * env(int(SR * 0.02), 0.0005, 0.005) * (0.9 - i * 0.12))
                       for i in range(5)])
    wet = bp(noise(0.3), 250, 1800) * env(int(SR * 0.3), 0.01, 0.07) * 0.6
    return at(0.5, (0.0, thud), (0.0, snaps), (0.03, wet))


def slash():
    sec = 0.4
    x = t(sec)
    whoosh = bp(noise(sec), 500, 5000) * np.exp(-((x - 0.1) / 0.05) ** 2)
    zing = sweep(2600, 900, 0.3) * env(int(SR * 0.3), 0.002, 0.07) * 0.4
    tearing = lp(noise(0.25), 1800) * env(int(SR * 0.25), 0.003, 0.05) * (0.5 + 0.5 * square(70, 0.25))
    return at(0.5, (0.0, whoosh), (0.07, zing), (0.1, tearing * 0.9))


def saw_loop():
    """Vale's saw running free. Every partial fits the half second exactly, so it loops clean."""
    sec = 0.5
    x = t(sec)
    tone = np.sign(np.sin(2 * np.pi * 440 * x)) * 0.25 + np.sin(2 * np.pi * 880 * x) * 0.3 + np.sin(2 * np.pi * 1320 * x + 0.4) * 0.2
    teeth = 0.6 + 0.4 * np.sign(np.sin(2 * np.pi * 96 * x))
    wobble = 1.0 + 0.15 * np.sin(2 * np.pi * 8 * x)
    hiss = loop_noise(sec, lambda f: ((f > 2500) & (f < 8000)) * 1.0) * 0.35
    return (tone * teeth + hiss) * wobble


def saw_grind():
    """The same saw biting glass or steel."""
    sec = 0.7
    x = t(sec)
    f = 2400 + 900 * np.sin(2 * np.pi * 3.1 * x) + 3000 * lp(noise(sec), 30)
    squeal = np.sin(2 * np.pi * np.cumsum(f) / SR) * 0.5 + np.sign(np.sin(2 * np.pi * np.cumsum(f * 1.51) / SR)) * 0.15
    grit = hp(noise(sec), 3500) * (0.5 + 0.5 * square(96, sec)) * 0.6
    low = np.sign(np.sin(2 * np.pi * 96 * x)) * 0.2
    return lp(squeal + grit + low, 9000) * fade(np.ones(len(x)), 0.01, 0.18)


def torch_loop():
    """Maren's torch arm at full flare."""
    sec = 0.6
    x = t(sec)
    roar = loop_noise(sec, lambda f: np.exp(-(np.log2(np.maximum(f, 1.0) / 900.0) ** 2) / 1.2))
    flutter = 0.7 + 0.3 * np.sin(2 * np.pi * 25 * x) * np.sin(2 * np.pi * 5 * x)
    hum = np.sin(2 * np.pi * 110 * x) * 0.25 + np.sign(np.sin(2 * np.pi * 220 * x)) * 0.06
    return roar * flutter + hum


def torch_burst():
    whoomp = sweep(90, 240, 0.25, 0.5) * env(int(SR * 0.25), 0.02, 0.09)
    hiss = hp(noise(0.9), 2500) * env(int(SR * 0.9), 0.02, 0.3) * 0.7
    crackle = at(0.9, *[(rng.random() * 0.8, lp(noise(0.008), 5000) * 0.6) for _ in range(30)])
    return at(1.0, (0.0, whoomp), (0.02, hiss), (0.05, crackle * 0.5))


def clang():
    """Kip's bike lock on glass or steel: a hard knock, then the hollow bar ringing off it
    (a free bar's partials, so it never sounds like a bell)."""
    knock = lp(noise(0.04), 6000) * env(int(SR * 0.04), 0.0005, 0.008)
    ring = sum(sine(f, 0.9) * a for f, a in ((440, 1.0), (1213, 0.6), (2378, 0.4), (3931, 0.22))) * env(int(SR * 0.9), 0.001, 0.2)
    thud = sweep(180, 70, 0.15) * env(int(SR * 0.15), 0.001, 0.04)
    return at(1.0, (0.0, knock), (0.0, ring * 0.5), (0.0, thud * 0.6))


def punch():
    """Rook's LOADER fist landing: the piston's crack, the whole arm's weight behind it, then
    the piston venting."""
    crack = hp(noise(0.03), 1500) * env(int(SR * 0.03), 0.0005, 0.006)
    boom = sweep(95, 34, 0.45) * env(int(SR * 0.45), 0.001, 0.13)
    body = lp(noise(0.2), 700) * env(int(SR * 0.2), 0.001, 0.05)
    vent = bp(noise(0.5), 2500, 7000) * env(int(SR * 0.5), 0.05, 0.12) * 0.25
    return at(0.8, (0.0, crack * 0.7), (0.0, boom), (0.0, body * 0.8), (0.12, vent))


def servo_loop():
    """Rook's LOADER arm wound up: a servo whine with the pistons hissing in turn. Every part
    fits the 0.6 seconds exactly, so it loops clean."""
    sec = 0.6
    x = t(sec)
    whine = np.sin(2 * np.pi * 330 * x) * 0.3 + np.sign(np.sin(2 * np.pi * 165 * x)) * 0.08
    pump = 0.35 + 0.65 * np.sin(2 * np.pi * 5 * x) ** 2
    hiss = loop_noise(sec, lambda f: ((f > 1800) & (f < 7000)) * 1.0) * 0.5
    return whine + hiss * pump


def hum_loop():
    """Juno's DEFT fingers out: one held chord through the chrome, with a singer's vibrato.
    Whole cycles in the second, so it loops clean."""
    sec = 1.0
    x = t(sec)
    vib = np.sin(2 * np.pi * 5 * x)
    tone = sum(a * np.sin(2 * np.pi * f * x + 0.012 * f / 5.0 * vib) for f, a in ((880, 0.5), (1320, 0.25), (1760, 0.15)))
    buzz = np.sign(np.sin(2 * np.pi * 110 * x)) * 0.05
    return tone + buzz


def scrape():
    """Ten DEFT picks across steel: a scale run backwards, one squealing note per point."""
    step = 0.1
    out = np.zeros(int(SR * 1.2))
    for i, s in enumerate((0, 2, 4, 5, 7, 9, 11, 12, 14, 16)):
        f = 1760.0 * 2 ** (-s / 12.0)
        d = step + 0.07
        y = sine(f, d) * 0.6 + np.sign(sine(f * 1.5, d)) * 0.1 + hp(noise(d), 4000) * 0.3
        y = y * env(len(y), 0.004, 0.06)
        k = int(SR * i * step)
        y = y[:len(out) - k]
        out[k:k + len(y)] += y
    return lp(out, 9000) * fade(np.ones(len(out)), 0.005, 0.1)


def laser_loop():
    """Priya's LANCET fingers run up to a cutting beam: a thin whine beating against itself,
    the mains hum under it and a faint sizzle. Whole cycles in the half second, so it loops
    clean."""
    sec = 0.5
    x = t(sec)
    whine = np.sin(2 * np.pi * 1480 * x) * 0.45 + np.sin(2 * np.pi * 1486 * x) * 0.3 + np.sin(2 * np.pi * 2960 * x) * 0.12
    hum = np.sin(2 * np.pi * 120 * x) * 0.18 + np.sign(np.sin(2 * np.pi * 60 * x)) * 0.04
    sizzle = loop_noise(sec, lambda f: ((f > 4000) & (f < 9000)) * 1.0) * 0.18
    return whine + hum + sizzle


def laser_burst():
    """The beam meeting glass or steel: a bright crack, the sizzle of it biting, and the whine
    bending down as it cuts out."""
    sec = 0.8
    crack = hp(noise(0.02), 2500) * env(int(SR * 0.02), 0.0005, 0.005)
    bend = sweep(1900, 1100, 0.5, 0.6) * env(int(SR * 0.5), 0.003, 0.2) * 0.5
    sizzle = hp(noise(sec), 3500) * env(int(SR * sec), 0.01, 0.25) * (0.6 + 0.4 * square(37, sec)) * 0.7
    pops = at(sec, *[(rng.random() * 0.6, lp(noise(0.006), 7000) * 0.7) for _ in range(18)])
    return at(0.9, (0.0, crack * 0.8), (0.0, bend), (0.01, sizzle), (0.03, pops * 0.5))


def chop():
    """Ozzie's cleaver landing: the edge biting in with the hand's weight behind it, a short
    ring off the blade, and the grit of what it split."""
    knock = lp(noise(0.05), 5000) * env(int(SR * 0.05), 0.0005, 0.01)
    thud = sweep(150, 55, 0.2) * env(int(SR * 0.2), 0.001, 0.05)
    ring = sum(sine(f, 0.5) * a for f, a in ((1870, 1.0), (2950, 0.5), (4410, 0.3))) * env(int(SR * 0.5), 0.001, 0.07)
    split = bp(noise(0.12), 1500, 6000) * env(int(SR * 0.12), 0.002, 0.03) * 0.6
    return at(0.6, (0.0, knock), (0.0, thud * 0.9), (0.002, ring * 0.35), (0.005, split))


def arc_loop():
    """Lux's torn-out deck cable, still live: a mains buzz that will not hold steady, and
    spits. Built from parts that fit the half second, so it loops clean."""
    sec = 0.5
    x = t(sec)
    buzz = np.sign(np.sin(2 * np.pi * 120 * x)) * 0.22 + np.sin(2 * np.pi * 240 * x) * 0.2 + np.sin(2 * np.pi * 360 * x + 0.7) * 0.1
    gate = loop_noise(sec, lambda f: ((f > 2) & (f < 30)) * 1.0)
    spit = loop_noise(sec, lambda f: ((f > 2500) & (f < 9500)) * 1.0) * np.clip(gate * 2.5 - 0.6, 0, 1)
    return buzz * (0.6 + 0.4 * np.clip(gate + 0.5, 0, 1)) + spit * 0.8


def zap():
    """The arc finding something to earth through: a sharp crack, a burst of buzz, and the
    crackle dying away."""
    sec = 0.6
    crack = hp(noise(0.015), 3000) * env(int(SR * 0.015), 0.0003, 0.004)
    x = t(0.35)
    buzz = (np.sign(np.sin(2 * np.pi * 180 * x)) * 0.5 + bp(noise(0.35), 1200, 7000) * 0.6) * env(len(x), 0.002, 0.09)
    drop = sweep(2200, 300, 0.25, 0.5) * env(int(SR * 0.25), 0.001, 0.06) * 0.4
    crackle = at(sec, *[(0.05 + rng.random() * 0.45, hp(noise(0.005), 4000) * 0.5 * (1.0 - i / 14.0)) for i in range(14)])
    return at(0.7, (0.0, crack), (0.0, buzz), (0.0, drop), (0.02, crackle))


def baton_hit():
    """Dana's stun baton: a hard rod's crack, and the charge going into whatever it hit."""
    knock = lp(noise(0.03), 4500) * env(int(SR * 0.03), 0.0005, 0.007)
    thud = sweep(240, 90, 0.12) * env(int(SR * 0.12), 0.001, 0.03)
    x = t(0.22)
    bzz = (np.sign(np.sin(2 * np.pi * 95 * x)) * 0.4 + bp(noise(0.22), 900, 6000) * 0.5) * env(len(x), 0.004, 0.08)
    bzz = bzz * (0.55 + 0.45 * square(30, 0.22))
    return at(0.5, (0.0, knock), (0.0, thud * 0.8), (0.015, bzz * 0.7))


def stun_loop():
    """The baton held charged: a tight, even buzz with a tick in it. Whole cycles in the
    0.4 seconds, so it loops clean."""
    sec = 0.4
    x = t(sec)
    buzz = np.sign(np.sin(2 * np.pi * 95 * x)) * 0.18 + np.sin(2 * np.pi * 190 * x) * 0.22 + np.sin(2 * np.pi * 2850 * x) * 0.05
    hiss = loop_noise(sec, lambda f: ((f > 3000) & (f < 8000)) * 1.0) * 0.12
    tick = 0.75 + 0.25 * (np.sin(2 * np.pi * 10 * x) > 0.85)
    return (buzz + hiss) * tick


def piston_loop():
    """Bo's PISTON cocked: the compressor's hum, and the piston chuffing as it holds pressure
    against the catch. Every part fits the 0.8 seconds, so it loops clean."""
    sec = 0.8
    x = t(sec)
    hum = np.sin(2 * np.pi * 55 * x) * 0.35 + np.sign(np.sin(2 * np.pi * 110 * x)) * 0.06
    chuff = loop_noise(sec, lambda f: ((f > 1200) & (f < 6500)) * 1.0) * np.sin(np.pi * x / 0.4) ** 8
    knock = np.sin(2 * np.pi * 40 * x) * np.sin(np.pi * x / 0.4) ** 30 * 0.3
    return hum + chuff * 0.6 + knock


def spike():
    """Bo's spike driven home: the piston's crack, the point going through with a steel
    shriek, then the arm's weight and the vent."""
    crack = hp(noise(0.025), 1800) * env(int(SR * 0.025), 0.0005, 0.005)
    boom = sweep(110, 40, 0.35) * env(int(SR * 0.35), 0.001, 0.1)
    shriek = sweep(4300, 2500, 0.12) * env(int(SR * 0.12), 0.0005, 0.035) * 0.45
    tear = bp(noise(0.08), 2000, 7000) * env(int(SR * 0.08), 0.0005, 0.02) * 0.5
    vent = bp(noise(0.45), 2500, 7000) * env(int(SR * 0.45), 0.04, 0.11) * 0.22
    return at(0.8, (0.0, crack * 0.7), (0.0, boom), (0.003, shriek), (0.003, tear), (0.14, vent))


def tinnitus():
    """What is left in your ears afterwards."""
    sec = 2.8
    x = t(sec)
    ring = (np.sin(2 * np.pi * 3150 * x) + 0.6 * np.sin(2 * np.pi * 3190 * x) + 0.3 * np.sin(2 * np.pi * 6240 * x))
    ring = ring * np.clip(x / 0.04, 0, 1) * np.exp(-x / 1.1)
    rumble = lp(noise(sec), 120) * 3.0 * np.exp(-x / 0.9)
    return fade(ring * 0.5 + rumble, 0.01, 0.4)


def drip():
    a = sweep(1500, 600, 0.03) * env(int(SR * 0.03), 0.001, 0.01)
    b = sweep(700, 1300, 0.05) * env(int(SR * 0.05), 0.002, 0.015) * 0.6
    return at(0.12, (0.0, a), (0.035, b))


def glass_fit():
    """The fitter's arm bonding a fresh layer into the counter frame: servo, slide, seat, latches."""
    sec = 0.34
    x = t(sec)
    swell = np.sin(np.pi * x / sec)
    servo = lp(square(118, sec, 0.35), 900) * swell ** 0.6 * 0.35 + sweep(520, 760, sec) * swell * 0.12
    slide = bp(noise(0.3), 2800, 7000) * np.sin(np.pi * t(0.3) / 0.3) ** 1.5 * 0.3
    seat = sweep(210, 85, 0.12) * env(int(SR * 0.12), 0.001, 0.03)
    seal = lp(noise(0.05), 1500) * env(int(SR * 0.05), 0.001, 0.012) * 0.6
    ring = sum(sine(f, 0.4) * a for f, a in ((2480, 1.0), (3910, 0.45), (6150, 0.2))) * env(int(SR * 0.4), 0.002, 0.1) * 0.3
    latch = at(0.14, *[(i * 0.045, bp(noise(0.012), 1800, 6000) * env(int(SR * 0.012), 0.0005, 0.004)) for i in range(3)])
    return at(1.15, (0.0, servo), (0.26, slide), (0.54, seat), (0.54, seal), (0.55, ring), (0.78, latch * 0.6))


# ------------------------------------------------------------------ results
def cash():
    ching = at(0.7, (0.0, bell(2093, 0.4, 0.14)), (0.09, bell(2637, 0.6, 0.22)))
    coins = at(0.7, *[(0.02 + i * 0.035, sine(3800 + rng.random() * 2600, 0.03) * env(int(SR * 0.03), 0.001, 0.008) * 0.3) for i in range(7)])
    drawer = sweep(180, 90, 0.1) * env(int(SR * 0.1), 0.002, 0.03)
    return mix(drawer * 0.5, ching * 0.6, coins)


def fail():
    sec = 0.6
    x = t(sec)
    f = 196 * (2.0 ** (-0.7 * x / sec))
    ph = 2 * np.pi * np.cumsum(f) / SR
    return lp(np.sign(np.sin(ph)) * 0.6 + np.sin(ph * 0.5), 1100) * fade(np.ones(len(x)), 0.005, 0.2)


def radio():
    """The call box: a squelch burst, then the two rising tones of a line that answered."""
    squelch = bp(noise(0.16), 900, 3400) * env(int(SR * 0.16), 0.002, 0.07)
    a = fade(sine(660, 0.09) + square(660, 0.09) * 0.25, 0.004, 0.02)
    b = fade(sine(990, 0.14) + square(990, 0.14) * 0.25, 0.004, 0.04)
    hiss = bp(noise(0.3), 1200, 3000) * env(int(SR * 0.3), 0.01, 0.12)
    return at(0.75, (0.0, squelch * 0.8), (0.17, a * 0.6), (0.28, b * 0.6), (0.42, hiss * 0.25))


def siren():
    """The crew's wagon pulling up outside: two wails heard through the street door."""
    sec = 1.9
    x = t(sec)
    f = 520 + 260 * (0.5 - 0.5 * np.cos(2 * np.pi * x / 0.95))
    ph = 2 * np.pi * np.cumsum(f) / SR
    tone = np.sin(ph) * 0.7 + np.sign(np.sin(ph)) * 0.18 + np.sin(ph * 2.0) * 0.12
    swell = np.clip(x / 0.5, 0, 1) * np.clip((sec - x) / 0.5, 0, 1)
    return lp(tone, 1500) * (0.35 + 0.65 * swell) * fade(np.ones(len(x)), 0.02, 0.25)


def jingle(notes, dur=0.16, decay=0.28):
    return at(dur * len(notes) + 0.7, *[(i * dur, bell(f, 0.8, decay) * 0.6) for i, f in enumerate(notes)])


def neon_buzz():
    sec = 0.5
    x = t(sec)
    buzz = np.sign(np.sin(2 * np.pi * 100 * x)) * 0.3 + np.sin(2 * np.pi * 200 * x) * 0.3
    flick = (np.sin(2 * np.pi * 9 * x) > -0.3) * (rng.random(len(x)) > 0.02)
    return bp(buzz * flick + noise(sec) * 0.08, 150, 4500) * fade(np.ones(len(x)), 0.005, 0.1)


SOUNDS = {
    "amb_rain": (amb_rain, 0.5), "amb_drone": (amb_drone, 0.5), "scope_hum": (scope_hum, 0.3),
    "door_chime": (door_chime, 0.5), "door_open": (door_open, 0.6), "door_slam": (door_slam, 0.8), "step": (step, 0.5),
    "blip": (blip, 0.45), "blip_glitch": (blip_glitch, 0.4), "blip_narrate": (blip_narrate, 0.2),
    "pencil": (pencil, 0.45), "paper": (paper, 0.4), "stamp": (stamp, 0.9), "click": (click, 0.4), "hover": (hover, 0.15),
    "tool_pick": (tool_pick, 0.4), "tool_put": (tool_put, 0.5), "light_on": (light_on, 0.5),
    "grip_squeeze": (grip_squeeze, 0.45), "grip_release": (grip_release, 0.5), "beep": (beep, 0.3), "beep_low": (beep_low, 0.3),
    "lever": (lever, 0.7), "printer": (printer, 0.4), "tear": (tear, 0.35),
    "shutter_slam": (shutter_slam, 0.95), "shutter_roll": (shutter_roll, 0.55), "bang": (bang, 0.9), "hit": (hit, 0.95),
    "whine": (whine, 0.6), "alarm": (alarm, 0.4), "heartbeat": (heartbeat, 0.9), "sting": (sting, 0.7), "calm": (calm, 0.4),
    "scream": (scream, 0.85), "scream_far": (scream_far, 0.5), "turn_hit": (turn_hit, 0.9),
    "glass_crack": (glass_crack, 0.8), "glass_shatter": (glass_shatter, 0.95), "splat": (splat, 0.8), "crunch": (crunch, 0.9),
    "slash": (slash, 0.9), "saw_loop": (saw_loop, 0.35), "saw_grind": (saw_grind, 0.6), "torch_loop": (torch_loop, 0.4),
    "torch_burst": (torch_burst, 0.75), "tinnitus": (tinnitus, 0.5), "drip": (drip, 0.4),
    "cash": (cash, 0.5), "fail": (fail, 0.5), "neon_buzz": (neon_buzz, 0.3),
    "radio": (radio, 0.5), "siren": (siren, 0.4),
    "jingle_good": (lambda: jingle([523.3, 659.3, 784.0, 1046.5]), 0.5),
    "jingle_bad": (lambda: jingle([392.0, 349.2, 311.1, 233.1], 0.2, 0.35), 0.5),
    "glass_fit": (glass_fit, 0.6),
    "clang": (clang, 0.75), "punch": (punch, 0.9), "servo_loop": (servo_loop, 0.35), "hum_loop": (hum_loop, 0.3),
    "scrape": (scrape, 0.6),
    "laser_loop": (laser_loop, 0.3), "laser_burst": (laser_burst, 0.7), "chop": (chop, 0.85),
    "arc_loop": (arc_loop, 0.3), "zap": (zap, 0.75), "baton_hit": (baton_hit, 0.8), "stun_loop": (stun_loop, 0.25),
    "piston_loop": (piston_loop, 0.35), "spike": (spike, 0.9),
}
# The sounds of the first build share one random stream, in the order above. Every sound added
# since starts from a fresh stream instead: adding one changes no other file, and writing it
# alone gives the same file as a full build. Add new sounds here as well as above.
FRESH = {"radio", "siren", "glass_fit", "clang", "punch", "servo_loop", "hum_loop", "scrape",
         "laser_loop", "laser_burst", "chop", "arc_loop", "zap", "baton_hit", "stun_loop", "piston_loop", "spike"}


def main(only=None):
    """With names on the command line, write only those sounds and print their level."""
    global rng
    total = 0.0
    count = 0
    for name, (fn, gain) in SOUNDS.items():
        if only and name not in only:
            continue
        if name in FRESH:
            rng = np.random.default_rng(SEED)
        x = np.asarray(fn(), dtype=np.float64)
        if not np.all(np.isfinite(x)):
            raise ValueError("%s: the waveform is not finite" % name)
        total += save(name, x, gain)
        count += 1
        if only:
            peak = np.max(np.abs(x))
            rms = np.sqrt(np.mean((x / max(peak, 1e-9)) ** 2))
            print("%-14s %.2f s   rms/peak %.2f" % (name, len(x) / SR, rms))
    print("audio written: %d files, %.1f s" % (count, total))


if __name__ == "__main__":
    import sys
    main(sys.argv[1:] or None)
