"""Original score, synthesized with numpy. Deterministic (fixed seeds).
Key: D minor. Grid from timeline.py. Writes audio/score_raw.wav."""
import os
import numpy as np
import soundfile as sf
from scipy.signal import butter, sosfilt, fftconvolve
from timeline import bar, BEAT, BARLEN, END, S_BARS

SR = 48000
ROOT = os.path.dirname(os.path.dirname(os.path.abspath(__file__)))
DUR = END + 3.0
N = int(DUR * SR)
dry = np.zeros((2, N), np.float32)
send = np.zeros((2, N), np.float32)   # reverb send
rng = np.random.default_rng(1859)


def hz(m):
    return 440.0 * 2 ** ((m - 69) / 12)


def tt(n):
    return np.arange(n) / SR


def env(n, a=0.005, d=0.2, s=0.0, r=0.05, hold=None):
    """ADSR; hold = seconds before release (default: whole length minus release)."""
    t = tt(n)
    L = n / SR
    hold = L - r if hold is None else hold
    e = np.where(t < a, t / max(a, 1e-4), s + (1 - s) * np.exp(-(t - a) / max(d, 1e-4)))
    rel = np.clip(1 - (t - hold) / max(r, 1e-4), 0, 1)
    return (e * np.where(t > hold, rel, 1)).astype(np.float32)


def lp(x, fc, order=2):
    fc = min(fc, SR * 0.45)
    return sosfilt(butter(order, fc, 'low', fs=SR, output='sos'), x).astype(np.float32)


def hp(x, fc, order=2):
    return sosfilt(butter(order, fc, 'high', fs=SR, output='sos'), x).astype(np.float32)


def bp(x, lo, hi):
    return sosfilt(butter(2, [lo, hi], 'band', fs=SR, output='sos'), x).astype(np.float32)


def add(sig, t0, gain=1.0, pan=0.0, rev=0.0):
    i = int(round(t0 * SR))
    if i >= N:
        return
    sig = sig[:N - i] * gain
    l, r = np.cos((pan + 1) * np.pi / 4), np.sin((pan + 1) * np.pi / 4)
    dry[0, i:i + len(sig)] += sig * l * 1.414
    dry[1, i:i + len(sig)] += sig * r * 1.414
    if rev:
        send[0, i:i + len(sig)] += sig * l * rev
        send[1, i:i + len(sig)] += sig * r * rev


def saw(f, n, phase=0.0):
    t = tt(n)
    return (2 * ((f * t + phase) % 1) - 1).astype(np.float32)


# ---------------- instruments ----------------
def pad(notes, t0, dur, gain=0.10, cutoff=1400, rev=0.5, attack=0.8):
    n = int((dur + 1.2) * SR)
    x = np.zeros(n, np.float32)
    for m in notes:
        for det in (-0.09, 0.0, 0.085):
            x += saw(hz(m + det), n, rng.random())
    x = lp(x, cutoff, 2) / (3 * len(notes)) * 2.2
    x *= env(n, attack, 10, 1.0, 1.2, hold=dur)
    add(x, t0, gain, -0.25, rev)
    add(np.roll(x, 380), t0, gain, 0.25, rev)


def bass(m, t0, dur, gain=0.22):
    n = int((dur + 0.05) * SR)
    t = tt(n)
    f = hz(m)
    x = np.sin(2 * np.pi * f * t) + 0.5 * lp(saw(f, n), 420)
    x = np.tanh(1.6 * x) * env(n, 0.006, 0.35, 0.55, 0.05)
    add(x.astype(np.float32), t0, gain)


def pluck(m, t0, gain=0.16, pan=0.0, rev=0.35, bright=1.0, decay=0.9):
    """FM bell-pluck"""
    n = int((decay * 2.5) * SR)
    t = tt(n)
    f = hz(m)
    I = 2.2 * bright * np.exp(-t / 0.25)
    x = np.sin(2 * np.pi * f * t + I * np.sin(2 * np.pi * f * 2.0 * t))
    x += 0.25 * np.sin(2 * np.pi * f * 4.01 * t) * np.exp(-t / 0.12)
    x = (x * np.exp(-t / decay) * np.minimum(1, t / 0.002)).astype(np.float32)
    add(x, t0, gain, pan, rev)


def arp_note(m, t0, cutoff, gain=0.07, pan=0.0, rev=0.25):
    n = int(0.22 * SR)
    f = hz(m)
    x = 0.6 * saw(f, n) + 0.4 * np.sign(np.sin(2 * np.pi * f * 0.5 * tt(n)))
    x = lp(x.astype(np.float32), cutoff, 2) * env(n, 0.003, 0.07, 0.0, 0.02)
    add(x, t0, gain, pan, rev)


def kick(t0, gain=0.55):
    n = int(0.45 * SR)
    t = tt(n)
    f = 44 + 90 * np.exp(-t / 0.035)
    ph = 2 * np.pi * np.cumsum(f) / SR
    x = np.sin(ph) * np.exp(-t / 0.16)
    x += 0.15 * hp(rng.standard_normal(n).astype(np.float32), 3000) * np.exp(-t / 0.004)
    add(np.tanh(1.3 * x).astype(np.float32), t0, gain)


def clap(t0, gain=0.16, rev=0.3):
    n = int(0.3 * SR)
    t = tt(n)
    x = bp(rng.standard_normal(n).astype(np.float32), 900, 4500)
    e = np.exp(-t / 0.09)
    for d in (0.0, 0.011, 0.022):
        e += 0.6 * np.exp(-np.maximum(t - d, 0) / 0.006) * (t >= d)
    add((x * e * 0.5).astype(np.float32), t0, gain, 0.05, rev)


def tick(t0, gain=0.06, pan=0.3, length=0.025):
    n = int(0.06 * SR)
    t = tt(n)
    x = hp(rng.standard_normal(n).astype(np.float32), 7000) * np.exp(-t / length)
    add(x, t0, gain, pan, 0.05)


def boom(t0, gain=0.6, rev=0.6):
    n = int(3.0 * SR)
    t = tt(n)
    f = 38 + 30 * np.exp(-t / 0.2)
    x = np.sin(2 * np.pi * np.cumsum(f) / SR) * np.exp(-t / 1.1)
    x += 0.3 * lp(rng.standard_normal(n).astype(np.float32), 600) * np.exp(-t / 0.5)
    add(x.astype(np.float32), t0, gain, 0, rev)


def riser(t0, t1, gain=0.12):
    n = int((t1 - t0) * SR)
    t = tt(n) / (t1 - t0)
    x = rng.standard_normal(n).astype(np.float32)
    out = np.zeros(n, np.float32)
    seg = SR // 20
    for i in range(0, n, seg):
        c = 400 + 7000 * t[i] ** 2
        out[i:i + seg] = bp(x[i:i + seg], c * 0.7, min(c * 1.4, 20000))
    out *= (t ** 2).astype(np.float32)
    add(out, t0, gain, 0, 0.4)


def error_stab(t0, gain=0.22):
    """minor-2nd cluster: the 'red line'"""
    n = int(1.6 * SR)
    t = tt(n)
    x = np.zeros(n)
    for m in (38, 39, 50, 51, 62):
        x += lp(saw(hz(m), n), 1800) * 0.3
    x = np.tanh(1.5 * x) * np.exp(-t / 0.45) * np.minimum(1, t / 0.003)
    add(x.astype(np.float32), t0, gain, 0, 0.5)
    boom(t0, 0.35, 0.3)


def check_chime(t0, gain=0.07, pan=0.4):
    pluck(86, t0, gain, pan, 0.3, 0.6, 0.35)
    pluck(93, t0 + BEAT / 2, gain * 0.8, pan, 0.3, 0.6, 0.45)


# ---------------- harmony ----------------
# chords as (bass midi, pad notes, arp notes)
Dm = (38, [62, 65, 69], [62, 65, 69, 74])
Bb = (34, [62, 65, 70], [58, 62, 65, 70])
F = (41, [60, 65, 69], [60, 65, 69, 72])
C = (36, [60, 64, 67], [60, 64, 67, 72])
Gm = (43, [62, 67, 70], [62, 67, 70, 74])
A = (33, [61, 64, 69], [61, 64, 69, 73])
LOOP = [Dm, Bb, F, C]
TENSE = [Dm, Gm, Bb, A]


def bars(a, b):
    return range(a, b)


def chord_at(k, prog_):
    return prog_[k % 4]


def section_pulse(a, b, prog_, kick_on=True, clap_on=False, arp=True, arp_cut=(900, 2600), bass_on=True,
                  ticks=0, pad_gain=0.09, chimes=False):
    for k in bars(a, b):
        t = bar(k)
        root, pn, an = chord_at(k, prog_)
        pad(pn, t, BARLEN, pad_gain, 1300)
        if bass_on:
            for e in range(8):           # 8th notes, octave pump
                bass(root + (12 if e % 4 == 3 else 0), t + e * BEAT / 2, BEAT / 2 * 0.9)
        if kick_on:
            kick(t)
            kick(t + 2 * BEAT, 0.45)
        if clap_on:
            clap(t + BEAT)
            clap(t + 3 * BEAT)
        if arp:
            p = (k - a) / max(1, b - a)
            cut = arp_cut[0] + (arp_cut[1] - arp_cut[0]) * p
            for s in range(16):
                m = an[(s * 3) % 4] + (12 if s % 8 == 7 else 0)
                arp_note(m, t + s * BEAT / 4, cut, 0.055 if s % 4 else 0.075, pan=0.35 * np.sin(s * 0.8))
        if ticks:
            for s in range(4 * ticks):
                tick(t + s * BEAT / ticks, 0.05 if s % ticks else 0.07)
        if chimes:
            check_chime(t + 3 * BEAT)


def melody(notes, start_bar, gain=0.13, pan=-0.2):
    """notes: list of (beat_offset, midi, decay)"""
    for off, m, d in notes:
        pluck(m, bar(start_bar) + off * BEAT, gain, pan, 0.45, 1.0, d)


# ================= arrangement =================
# --- pre-roll 0 .. 2.30: low drone swell + cursor ticks
pad([38, 45], 0.0, bar(7) - 0.0, 0.07, 500, 0.4, attack=2.0)
for i in range(3):
    tick(0.55 + i * 0.6, 0.03, 0.0, 0.01)

# --- hook (bars 0..7): each formula line = a bell note; the "?" = unresolved 2nd
pluck(62, bar(0), 0.18, -0.2, 0.6)           # line 1
pluck(69, bar(1), 0.18, 0.0, 0.6)            # line 2
check_chime(bar(1) - 0.02, 0.05)
pluck(65, bar(2), 0.18, 0.2, 0.6)            # line 3
check_chime(bar(2) - 0.02, 0.05)
pluck(76, bar(3), 0.12, 0.3, 0.7, decay=1.4)  # "?" (E over Dm: unresolved)
pluck(77, bar(3) + BEAT * 1.5, 0.08, 0.3, 0.7, decay=1.4)
for k in (3, 4):
    for s in range(8):
        tick(bar(k) + s * BEAT / 2, 0.035, 0.25)
bass(26, bar(4), BARLEN * 2, 0.18)
riser(bar(4), bar(5), 0.08)
# code waterfall (bar 5): fast 16th arp, rising filter, then error at bar 6
for s in range(16):
    arp_note([62, 65, 69, 74][s % 4] + 12 * (s // 8), bar(5) + s * BEAT / 4, 1200 + s * 250, 0.07, pan=0.4 * np.sin(s))
    tick(bar(5) + s * BEAT / 4, 0.03, -0.3)
kick(bar(5), 0.5)
error_stab(bar(6))

# --- title (bars 7..11)
boom(bar(7), 0.7)
pad([50, 57, 62, 65], bar(7), 4 * BARLEN, 0.11, 1600, 0.7, attack=0.3)
melody([(0, 74, 1.4), (4, 72, 1.0), (6, 69, 1.0), (8, 70, 1.6), (12, 69, 2.0)], 7, 0.12)

# --- §1 primes (11..21): pulse enters, light
section_pulse(11, 15, LOOP, kick_on=False, clap_on=False, arp=True, arp_cut=(600, 900), bass_on=False, ticks=0, pad_gain=0.07)
section_pulse(15, 21, LOOP, kick_on=True, clap_on=False, arp=True, arp_cut=(900, 1600), ticks=0, pad_gain=0.07)
# prime "pings" on primes 2,3,5,7,11,13 (beats from bar 11)
for i, pnum in enumerate([2, 3, 5, 7, 11, 13, 17, 19, 23]):
    pluck([74, 77, 81, 84, 86, 88, 89, 91, 93][i], bar(11) + pnum * BEAT / 4 + 0.0, 0.06, 0.5 - 0.1 * i, 0.4, 0.8, 0.5)

# --- §2 review (21..31): clock ticks = years passing; drop out on bar 30
section_pulse(21, 30, LOOP, kick_on=True, clap_on=True, arp=True, arp_cut=(1200, 2400), ticks=2)
pad([38, 45, 53], bar(30), BARLEN, 0.08, 700)
riser(bar(29) + BARLEN / 2, bar(31), 0.14)

# --- §3 Lean (31..48): full; chime each bar = the check marks
boom(bar(31), 0.5, 0.4)
section_pulse(31, 48, LOOP, kick_on=True, clap_on=True, arp=True, arp_cut=(2000, 4200), ticks=4,
              pad_gain=0.10, chimes=True)
error_stab(bar(39) + 2 * BEAT, 0.14)                 # the line that goes red mid-scene
melody([(0, 74, 0.6), (2, 77, 0.6), (3, 76, 0.5), (4, 74, 1.2), (8, 72, 0.6), (10, 70, 0.6), (11, 69, 1.6)], 41, 0.10, 0.25)
melody([(0, 74, 0.6), (2, 77, 0.6), (3, 79, 0.5), (4, 81, 1.2), (8, 79, 0.6), (10, 77, 0.6), (11, 76, 1.6)], 45, 0.10, 0.25)

# --- §4 statement (48..63): kick out, tense harmony, filtered arp; "?" bells
section_pulse(48, 63, TENSE, kick_on=False, clap_on=False, arp=True, arp_cut=(700, 1200), bass_on=False,
              ticks=1, pad_gain=0.08)
for k in range(48, 63, 2):
    bass(chord_at(k, TENSE)[0], bar(k), BARLEN * 1.9, 0.2)
for k in (51, 55, 59):
    pluck(76, bar(k) + 2 * BEAT, 0.08, 0.3, 0.7, decay=1.4)
error_stab(bar(56), 0.12)                             # wrong statement goes red
riser(bar(61), bar(63), 0.13)

# --- §5 status (63..87): back to full, lifts an octave for the last 8 bars
boom(bar(63), 0.55, 0.5)
section_pulse(63, 79, LOOP, kick_on=True, clap_on=True, arp=True, arp_cut=(1800, 3200), ticks=2)
section_pulse(79, 86, LOOP, kick_on=True, clap_on=True, arp=True, arp_cut=(3200, 5000), ticks=4, chimes=True)
melody([(0, 81, 0.8), (2, 79, 0.6), (4, 77, 1.0), (8, 76, 0.6), (10, 74, 0.6), (12, 76, 1.6)], 79, 0.10)
melody([(0, 81, 0.8), (2, 79, 0.6), (4, 77, 1.0), (8, 79, 0.6), (10, 81, 0.6), (12, 86, 2.0)], 83, 0.10)
pad([38, 45, 50], bar(86), BARLEN, 0.08, 700)          # one-bar breath before the ending

# --- ending (87..102): back to the hook bells, slow, resolves on D
boom(bar(87), 0.5, 0.7)
for k in range(87, 101, 2):
    root, pn, an = chord_at((k - 87) // 2, [Dm, Bb, F, A])
    pad(pn, bar(k), 2 * BARLEN, 0.09, 1100, 0.7)
    bass(root, bar(k), 2 * BARLEN * 0.95, 0.16)
melody([(0, 62, 1.2), (4, 69, 1.2), (8, 65, 1.2), (12, 76, 1.8)], 87, 0.14)
melody([(0, 62, 1.2), (4, 69, 1.2), (8, 65, 1.2), (12, 74, 3.0)], 95, 0.14)   # "?" (76) resolves to D (74)
pad([50, 57, 62, 65, 69], bar(101), 2.5, 0.10, 900, 0.8, attack=0.2)
bass(26, bar(101), 2.5, 0.2)

# ---------------- mix ----------------
ir_n = int(2.4 * SR)
ti = tt(ir_n)
ir = [lp(rng.standard_normal(ir_n).astype(np.float32), 5000) * np.exp(-ti / 0.55).astype(np.float32) for _ in range(2)]
wet = np.stack([fftconvolve(send[c], ir[c])[:N] for c in range(2)]) * 0.12
mix = dry + wet.astype(np.float32)
# section level automation (dB) -> clear dynamic arc
pts = [(0, -2), (bar(7) - 0.05, -2), (bar(7), -5.5), (bar(11) - 0.05, -5.5), (bar(11), -8), (bar(15), -6), (bar(21), -4.5), (bar(30), -4), (bar(31), 0),
       (bar(48), -7), (bar(61), -5), (bar(63), -1), (bar(79), 0), (bar(87), -4), (END + 3, -6)]
tx = np.array([p[0] for p in pts]); gx = np.array([p[1] for p in pts])
g = 10 ** (np.interp(np.arange(N) / SR, tx, gx) / 20)
k = int(0.08 * SR); g = np.convolve(g, np.ones(k) / k, 'same')
mix *= g[None, :].astype(np.float32)
mix = hp(mix[0], 28), hp(mix[1], 28)
mix = np.stack(mix)
# fade the tail
tail = int(2.5 * SR)
mix[:, -tail:] *= np.linspace(1, 0, tail) ** 2
print('pre-master peak', float(np.abs(mix).max()))
mix = mix / np.percentile(np.abs(mix), 99.95) * 0.5
mix = np.tanh(mix * 1.2) / 1.2
os.makedirs(os.path.join(ROOT, 'audio'), exist_ok=True)
sf.write(os.path.join(ROOT, 'audio', 'score_raw.wav'), mix.T, SR, subtype='PCM_24')
print('wrote score', DUR)
