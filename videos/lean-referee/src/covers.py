"""Covers for WeChat Channels: 3:4 profile card, 4:3 share card. python3 covers.py 34|43 out.png"""
import sys
import lib
mode, out = sys.argv[1], sys.argv[2]
lib.W, lib.H = {'34': (1080, 1440), '43': (1440, 1080), '169': (1920, 1080)}[mode]
from lib import *
from PIL import Image
import scenes

W, H = lib.W, lib.H
fr = background(0, lamp=1.3)
s = 1.0

def formulas(x, y0, gap, size, chk_x, s3=0.88):
    for i, tex in enumerate(scenes.FORMULAS):
        m = tex_mask(tex, size if i < 2 else int(size * s3))
        y = y0 + i * gap
        blit(fr, m, x + (int(size * 1.1) if i == 1 else 0), y, GOLD, 0.9, 'lm')
        if i < 2:
            mark(fr, 'check', chk_x, y, int(size * 0.7), 1.0)
        else:
            text(fr, '?', chk_x, y, 'serif', int(size * 1.05), GOLD, 1.0, 'cm', glow=0.5)

def title(cy, size, gap_line):
    rich(fr, [('谁来检查 ', 'serif', INK), ('AI', 'serif', GOLD)], W / 2, cy - size * 1.25, size, 1.0)
    rich(fr, [('有没有“作弊”？', 'serif', INK)], W / 2, cy, size, 1.0)
    hline(fr, W / 2 - size * 3.6, W / 2 + size * 3.6, cy + size * 1.55, GOLD, 0.8, 3)

def status(cy, size):
    mark(fr, 'check', W / 2 - size * 7.3, cy, int(size * 1.2), 1.0)
    text(fr, '机器：通过', W / 2 - size * 1.0, cy, 'sansb', size, GREEN, 1, 'rm')
    text(fr, '人类：审阅中', W / 2 + size * 1.0, cy, 'sansb', size, GOLD, 1, 'lm')

if mode == '34':
    # keep everything inside the central ~80% height (app crops/overlays top & bottom)
    formulas(110, 300, 125, 54, 980, 0.78)
    title(800, 96, 0)
    text(fr, '黎曼猜想 × Lean：数学证明的机器裁判', W / 2, 995, 'serifr', 40, INK, 0.9, 'cm')
    status(1095, 38)
    text(fr, '截至 2026.11.22 · 结论待验证', W / 2, 1170, 'sans', 28, DIM, 1, 'cm')
elif mode == '43':
    # 4:3 share card: the app draws a play button in the centre -> keep the middle band empty
    title(190, 92, 0)
    text(fr, '黎曼猜想 × Lean：数学证明的机器裁判', W / 2, 400, 'serifr', 40, INK, 0.9, 'cm')
    formulas(330, 620, 100, 48, 1110)
    status(915, 36)
    text(fr, '截至 2026.11.22 · 结论待验证', W / 2, 1000, 'sans', 26, DIM, 1, 'cm')

else:
    # Bilibili 16:9; everything that matters stays inside the centred 4:3 (x 240..1680),
    # bottom ~12% kept clear for play count / duration overlays
    import scenes as sc
    for side, x0 in (('l', 40), ('r', 1700)):
        for i in range(22):
            ln = sc.LEAN[(i * 3 + (0 if side == 'l' else 7)) % len(sc.LEAN)]
            text(fr, ln[:26], x0, 60 + i * 44, 'mono', 18, INK, 0.10)
            mark(fr, 'check' if i != 15 else 'cross', x0 - 14 if side == 'l' else x0 - 14, 72 + i * 44, 12, 0.25)
    text(fr, '黎曼猜想 × Lean', W / 2, 150, 'sansb', 40, GOLD, 1, 'cm')
    title(430, 128, 0)
    text(fr, '数学证明的机器裁判', W / 2, 700, 'serifr', 46, INK, 0.9, 'cm')
    status(800, 46)
    text(fr, '截至 2026.11.22 · 结论待验证', W / 2, 880, 'sans', 30, DIM, 1, 'cm')

Image.fromarray(finish(fr, 0)).save(out)
