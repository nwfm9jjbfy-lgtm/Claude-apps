"""Deterministic frame helpers: every frame depends only on t."""
import functools, io
import numpy as np
import cv2
from PIL import Image, ImageDraw, ImageFont

W, H, FPS = 1280, 720, 30
import os as _os
LANG = _os.environ.get('VIDEO_LANG', 'zh')
if LANG == 'en':
    from i18n_en import tr
else:
    tr = lambda s: s

def hexc(h):
    h = h.lstrip('#')
    return np.array([int(h[i:i + 2], 16) for i in (0, 2, 4)], np.float32) / 255.0

BG = hexc('#0B0B0E')
INK = hexc('#EDE6D6')
GOLD = hexc('#D4A84B')
GREEN = hexc('#5FB37A')
RED = hexc('#D9534F')
DIM = hexc('#8A8478')

FONTS = {
    'serif': ('/usr/share/fonts/opentype/noto/NotoSerifCJK-Bold.ttc', 2),
    'serifr': ('/usr/share/fonts/opentype/noto/NotoSerifCJK-Regular.ttc', 2),
    'sans': ('/usr/share/fonts/opentype/noto/NotoSansCJK-Regular.ttc', 2),
    'sansb': ('/usr/share/fonts/opentype/noto/NotoSansCJK-Bold.ttc', 2),
    'mono': ('/usr/share/fonts/truetype/jetbrains-mono/JetBrainsMono-Regular.ttf', 0),
    'monob': ('/usr/share/fonts/truetype/jetbrains-mono/JetBrainsMono-Bold.ttf', 0),
}

@functools.lru_cache(None)
def font(kind, size):
    p, i = FONTS[kind]
    return ImageFont.truetype(p, size, index=i)

# ---------- easing ----------
def clamp(x, a=0.0, b=1.0):
    return max(a, min(b, x))

def prog(t, t0, dur):
    return clamp((t - t0) / dur) if dur > 0 else float(t >= t0)

def ease(p):  # cubic out
    return 1 - (1 - p) ** 3

def ease_io(p):
    return 3 * p * p - 2 * p * p * p

def fade(t, t0, t1, fin=0.35, fout=0.3):
    """opacity window [t0,t1] with fade in / out"""
    if t < t0 or t > t1:
        return 0.0
    a = ease(prog(t, t0, fin))
    if fout > 0:
        a *= 1 - ease_io(prog(t, t1 - fout, fout))
    return a

# ---------- sprites (RGBA float arrays, straight alpha) ----------
FALLBACK = {'mono': ['dmono', 'sans'], 'monob': ['dmono', 'sansb'], 'serif': ['dserif'], 'serifr': ['dserif'],
            'sans': ['dsans'], 'sansb': ['dsans']}
FONTS.update({'dmono': ('/usr/share/fonts/truetype/dejavu/DejaVuSansMono.ttf', 0),
              'dsans': ('/usr/share/fonts/truetype/dejavu/DejaVuSans.ttf', 0),
              'dserif': ('/usr/share/fonts/truetype/dejavu/DejaVuSerif.ttf', 0)})

@functools.lru_cache(None)
def _cmap(kind):
    from fontTools.ttLib import TTFont
    p, i = FONTS[kind]
    f = TTFont(p, fontNumber=i, lazy=True)
    return set(f.getBestCmap().keys())

def _runs(s, kind):
    chain = [kind] + FALLBACK.get(kind, [])
    runs = []
    for ch in s:
        k = next((c for c in chain if ord(ch) in _cmap(c) or ch == ' '), chain[-1])
        if runs and runs[-1][1] == k:
            runs[-1][0] += ch
        else:
            runs.append([ch, k])
    return runs

@functools.lru_cache(512)
def _text_mask(s, kind, size):
    runs = _runs(s, kind)
    if len(runs) > 1:
        ms = [_single_mask(r, k, size) for r, k in runs]
        asc = max(font(k, size).getmetrics()[0] for _, k in runs)
        h = max(m.shape[0] + asc - font(k, size).getmetrics()[0] for m, (_, k) in zip(ms, runs))
        out = np.zeros((h, sum(m.shape[1] - 4 for m in ms) + 4), np.float32)
        x = 0
        for m, (_, k) in zip(ms, runs):
            dy = asc - font(k, size).getmetrics()[0]
            out[dy:dy + m.shape[0], x:x + m.shape[1]] = np.maximum(out[dy:dy + m.shape[0], x:x + m.shape[1]], m)
            x += m.shape[1] - 4
        return out
    return _single_mask(s, runs[0][1] if runs else kind, size)

def _single_mask(s, kind, size):
    f = font(kind, size)
    l, tp, r, b = f.getbbox(s)
    asc, desc = f.getmetrics()
    w = max(1, r - min(0, l)) + 4
    h = asc + desc + 4
    im = Image.new('L', (w, h), 0)
    ImageDraw.Draw(im).text((2 - min(0, l), 2), s, font=f, fill=255)
    return np.asarray(im, np.float32) / 255.0

def text_mask(s, kind='sans', size=28):
    return _text_mask(s, kind, size)

def rich_mask(parts, size, gap=0):
    """parts: list of (text, kind, color). returns (mask_list, offsets, total_w, h)"""
    ms = [text_mask(p[0], p[1], size) for p in parts]
    h = max(m.shape[0] for m in ms)
    xs, x = [], 0
    for m in ms:
        xs.append(x)
        x += m.shape[1] - 4 + gap
    return ms, xs, x + 4, h

@functools.lru_cache(128)
def _tex_mask(tex, size):
    import matplotlib
    matplotlib.use('Agg')
    import matplotlib.pyplot as plt
    matplotlib.rcParams['mathtext.fontset'] = 'stix'
    fig = plt.figure(figsize=(0.01, 0.01), dpi=100)
    fig.text(0, 0, tex, fontsize=size * 0.72, color='white')
    buf = io.BytesIO()
    fig.savefig(buf, dpi=100, transparent=True, bbox_inches='tight', pad_inches=0.06)
    plt.close(fig)
    buf.seek(0)
    a = np.asarray(Image.open(buf).convert('RGBA'), np.float32)[..., 3] / 255.0
    return a

def tex_mask(tex, size=48):
    return _tex_mask(tex, size)

@functools.lru_cache(256)
def _glow(key_id, sigma):
    m = _GLOW_SRC[key_id]
    pad = int(sigma * 3)
    g = np.pad(m, pad)
    g = cv2.GaussianBlur(g, (0, 0), sigma)
    return g, pad

_GLOW_SRC = {}

def glow_of(mask, sigma=10):
    k = (id(mask), mask.shape)
    _GLOW_SRC[k] = mask
    return _glow(k, sigma)

# ---------- compositing ----------
def blit(fr, mask, x, y, color, alpha=1.0, anchor='lt', reveal=1.0, additive=False):
    """Composite a coverage mask tinted `color` at (x,y). anchor: l/c/r + t/m/b.
    reveal: left-to-right wipe fraction."""
    if alpha <= 0.002 or reveal <= 0:
        return
    h, w = mask.shape
    if anchor[0] == 'c':
        x -= w / 2
    elif anchor[0] == 'r':
        x -= w
    if anchor[1] == 'm':
        y -= h / 2
    elif anchor[1] == 'b':
        y -= h
    x, y = int(round(x)), int(round(y))
    m = mask
    if reveal < 1:
        rw = int(w * reveal)
        if rw <= 0:
            return
        m = mask[:, :rw].copy()
        soft = min(24, rw)
        m[:, rw - soft:] *= np.linspace(1, 0, soft)[None, :]
    hh, ww = m.shape
    x0, y0 = max(0, x), max(0, y)
    x1, y1 = min(W, x + ww), min(H, y + hh)
    if x1 <= x0 or y1 <= y0:
        return
    a = m[y0 - y:y1 - y, x0 - x:x1 - x, None] * alpha
    reg = fr[y0:y1, x0:x1]
    c = np.asarray(color, np.float32)
    if additive:
        reg += a * c
    else:
        reg *= (1 - a)
        reg += a * c

def text(fr, s, x, y, kind='sans', size=28, color=INK, alpha=1.0, anchor='lt', reveal=1.0, glow=0.0, maxw=None):
    s = tr(s)
    if not s:
        return (0, 0)
    m = text_mask(s, kind, size)
    while maxw and m.shape[1] > maxw and size > 12:
        size -= 1
        m = text_mask(s, kind, size)
    if glow > 0:
        g, pad = glow_of(m, 8)
        gx = x - pad if anchor[0] == 'l' else x
        gy = y - pad if anchor[1] == 't' else y
        blit(fr, g, gx, gy, color, alpha * glow, anchor, reveal, additive=True)
    blit(fr, m, x, y, color, alpha, anchor, reveal)
    return m.shape

def rich(fr, parts, x, y, size, alpha=1.0, anchor='c', reveal=1.0, maxw=None):
    """parts: [(text, kind, color)] laid out on one line; anchor horizontal c/l."""
    parts = [(tr(p[0]), p[1], p[2]) for p in parts]
    parts = [p for p in parts if p[0]]
    maxw = maxw or (W - 100)
    ms, xs, tw, h = rich_mask(parts, size)
    while tw > maxw and size > 12:
        size -= 1
        ms, xs, tw, h = rich_mask(parts, size)
    if anchor == 'c':
        x -= tw / 2
    for (s, k, col), m, ox in zip(parts, ms, xs):
        r = clamp((reveal * tw - ox) / max(1, m.shape[1]))
        blit(fr, m, x + ox, y + (h - m.shape[0]), col, alpha, 'lt', r)
    return tw, h

def rect(fr, x0, y0, x1, y1, color, alpha=1.0):
    x0, y0, x1, y1 = [int(round(v)) for v in (x0, y0, x1, y1)]
    x0, y0, x1, y1 = max(0, x0), max(0, y0), min(W, x1), min(H, y1)
    if x1 <= x0 or y1 <= y0 or alpha <= 0:
        return
    reg = fr[y0:y1, x0:x1]
    reg *= (1 - alpha)
    reg += alpha * np.asarray(color, np.float32)

def hline(fr, x0, x1, y, color, alpha=1.0, th=2):
    rect(fr, x0, y - th / 2, x1, y + th / 2, color, alpha)

@functools.lru_cache(8)
def _check_mask(size, kind):
    s = size
    im = Image.new('L', (s * 4, s * 4), 0)
    d = ImageDraw.Draw(im)
    if kind == 'check':
        d.line([(0.6 * s, 2.1 * s), (1.5 * s, 3.0 * s), (3.4 * s, 0.9 * s)], fill=255, width=int(s * 0.42), joint='curve')
    else:
        d.line([(0.8 * s, 0.8 * s), (3.2 * s, 3.2 * s)], fill=255, width=int(s * 0.42))
        d.line([(3.2 * s, 0.8 * s), (0.8 * s, 3.2 * s)], fill=255, width=int(s * 0.42))
    im = im.resize((s, s), Image.LANCZOS)
    return np.asarray(im, np.float32) / 255.0

def mark(fr, kind, x, y, size, alpha=1.0, pop=1.0):
    """green check or red cross centered at x,y; pop: 0..1 wipe-in"""
    col = GREEN if kind == 'check' else RED
    m = _check_mask(size, kind)
    blit(fr, m, x, y, col, alpha, 'cm', reveal=pop)

# ---------- background ----------
@functools.lru_cache(1)
def _bg():
    yy, xx = np.mgrid[0:H, 0:W].astype(np.float32)
    # vignette
    d = np.sqrt(((xx - W / 2) / (W * 0.62)) ** 2 + ((yy - H / 2) / (H * 0.70)) ** 2)
    vig = np.clip(1 - 0.55 * d ** 2, 0.35, 1)
    # desk lamp from top
    lamp = np.exp(-(((xx - W / 2) / (W * 0.33)) ** 2 + ((yy + 120) / (H * 0.55)) ** 2))
    img = BG[None, None, :] * vig[..., None] + hexc('#3A2E18')[None, None, :] * lamp[..., None] * 0.55
    return img.astype(np.float32)

@functools.lru_cache(1)
def _grain():
    rng = np.random.default_rng(1859)
    return [(rng.standard_normal((H, W)).astype(np.float32) * (1.6 / 255)) for _ in range(4)]

def background(t, lamp=1.0):
    fr = _bg().copy()
    if lamp != 1.0:
        fr = BG[None, None, :] + (fr - BG[None, None, :]) * lamp
    return fr

def finish(fr, t, black=0.0):
    n = int(round(t * FPS))
    fr += _grain()[(n // 3) % 4][..., None]
    if black > 0:
        fr *= (1 - black)
    return (np.clip(fr, 0, 1) * 255 + 0.5).astype(np.uint8)

# ---------- recurring UI ----------
def chapter(fr, t, t0, label):
    a = fade(t, t0 + 0.1, 1e9, 0.5, 0) * 0.75
    text(fr, f'-- {label}', 56, 40, 'mono', 20, GOLD, a, reveal=ease(prog(t, t0 + 0.1, 0.6)))

def caption(fr, t, t0, t1, s, color=INK, size=34, y=640, kind='sans', parts=None):
    a = fade(t, t0, t1, 0.3, 0.25)
    if a <= 0:
        return
    dy = 8 * (1 - ease(prog(t, t0, 0.4)))
    if parts:
        rich(fr, parts, W / 2, y - 24 + dy, size, a)
    else:
        text(fr, s, W / 2, y + dy, kind, size, color, a, 'cm', maxw=W - 100)

def illustrative(fr, t, a=1.0, label='示意'):
    text(fr, label, W - 40, H - 28, 'sans', 16, DIM, 0.8 * a, 'rb')


@functools.lru_cache(64)
def disc(r):
    s = int(np.ceil(r * 2 + 4))
    yy, xx = np.mgrid[0:s, 0:s].astype(np.float32) - (s - 1) / 2
    return np.clip(r + 0.5 - np.sqrt(xx ** 2 + yy ** 2), 0, 1)


def dot(fr, x, y, r, color, alpha=1.0, glow=0.0):
    if glow > 0:
        g, pad = glow_of(disc(r), max(3, r))
        blit(fr, g, x, y, color, alpha * glow, 'cm', additive=True)
    blit(fr, disc(r), x, y, color, alpha, 'cm')


def vline(fr, x, y0, y1, color, alpha=1.0, th=2, dash=0):
    if dash <= 0:
        rect(fr, x - th / 2, y0, x + th / 2, y1, color, alpha)
        return
    y = y0
    while y < y1:
        rect(fr, x - th / 2, y, x + th / 2, min(y1, y + dash), color, alpha)
        y += dash * 2


def frame_box(fr, x0, y0, x1, y1, color, alpha=1.0, th=1):
    hline(fr, x0, x1, y0, color, alpha, th)
    hline(fr, x0, x1, y1, color, alpha, th)
    vline(fr, x0, y0, y1, color, alpha, th)
    vline(fr, x1, y0, y1, color, alpha, th)
