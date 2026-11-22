"""Scenes: each takes global time t and returns uint8 HxWx3."""
import numpy as np
from lib import *

# ------------------------------------------------------------------ S0 hook
FORMULAS = [
    r'$\zeta(s)=\sum_{n=1}^{\infty}\,\frac{1}{n^{s}}$',
    r'$=\prod_{p\ \mathrm{prime}}\frac{1}{1-p^{-s}}$',
    r'$\zeta(\rho)=0,\ \ 0<\mathrm{Re}\,\rho<1\ \ \Longrightarrow\ \ \mathrm{Re}\,\rho=\frac{1}{2}$',
]
F_T = [2.30, 3.92, 5.43]       # each line starts on a downbeat
F_Y = [175, 315, 450]
F_X = 220
CHK_X = 1070

LEAN = [
    'theorem zeta_ne_zero_of_one_lt_re (hs : 1 < s.re) : riemannZeta s ≠ 0 := by',
    '  simpa using riemannZeta_eulerProduct hs',
    'lemma xi_functional_eq (s : ℂ) : completedZeta (1 - s) = completedZeta s := by',
    '  rw [completedZeta_one_sub]',
    'lemma zero_free_strip (hσ : σ₀ ≤ s.re) : riemannZeta s ≠ 0 := by',
    '  refine ne_of_gt (norm_pos_iff.mpr ?_)',
    '  exact (vonMangoldt_bound hσ).trans_lt hlt',
    'theorem explicit_formula (x : ℝ) (hx : 2 ≤ x) :',
    '    ψ x = x - ∑ ρ in zeros, x ^ ρ / ρ - log (2 * π) := by',
    '  have h₁ := perron_integral hx',
    '  linarith [h₁, residue_sum_eq hx]',
    'lemma hadamard_product (s : ℂ) : xi s = xi 0 * ∏\' ρ, (1 - s / ρ) := by',
    '  exact entire_order_one_product xi_entire xi_growth',
    'lemma zero_density (T : ℝ) : N(σ, T) ≤ C * T ^ (3 * (1 - σ)) := by',
    '  calc N(σ, T) ≤ ∑ k in range K, M k := count_le_sum',
    '    _ ≤ C * T ^ (3 * (1 - σ)) := by gcongr; exact mean_value hT',
    'lemma critical_line_zero (ρ : ℂ) (hρ : riemannZeta ρ = 0) :',
    '    ρ.re = 1 / 2 := by',
    '  nlinarith [sq_nonneg (ρ.re - 1 / 2), mollifier_pos hρ]',
    'theorem prime_count_error (x : ℝ) : |π x - li x| ≤ C * √x * log x := by',
]
RED_IDX = 18   # the line that stops on the scan line

def _formula_block(fr, t, dim=1.0, active_glow=True, q_t=6.92, show_q=True):
    for i, (tex, t0, y) in enumerate(zip(FORMULAS, F_T, F_Y)):
        if t < t0:
            continue
        m = tex_mask(tex, 50 if i < 2 else 44)
        rv = ease(prog(t, t0, 0.9))
        x = F_X + (56 if i == 1 else 0)
        if active_glow and i < 2 and t < F_T[i + 1]:
            g, pad = glow_of(m, 9)
            blit(fr, g, x - pad, y - pad, GOLD, 0.45 * dim, 'lm', rv, additive=True)
        blit(fr, m, x, y, GOLD, dim, 'lm', rv)
        if i < 2:
            tc = F_T[i + 1]
            if t >= tc:
                mark(fr, 'check', CHK_X, y, 34, dim, ease(prog(t, tc, 0.25)))
    if show_q and t >= q_t:
        p = ease(prog(t, q_t, 0.4))
        pulse = 0.75 + 0.25 * np.cos((t - q_t) * 2 * np.pi * 161.5 / 60 / 2)
        text(fr, '?', CHK_X, F_Y[2], 'serif', 52, GOLD, dim * p * pulse, 'cm', glow=0.4)



def s0_hook(t):
    fr = background(t)
    LINE_H = 26
    scan_y = 360
    code_a = ease(prog(t, 9.96, 0.35))
    # formulas: dim out when the code pours in
    dim = 1 - 0.9 * code_a
    _formula_block(fr, t, dim, show_q=True)
    if t < 2.6:  # blinking cursor before the first line is written
        on = 1.0 if (t * 2.2) % 1 < 0.6 else 0.15
        rect(fr, F_X, F_Y[0] - 26, F_X + 4, F_Y[0] + 26, GOLD, on * ease(prog(t, 0.3, 0.4)) * (1 - prog(t, 2.3, 0.3)))
    # caption
    caption(fr, t, 2.30, 5.30, '1859 年，黎曼写下一个猜想')
    caption(fr, t, 5.43, 8.30, '167 年，没人证明它')
    caption(fr, t, 8.43, 11.30, None, parts=[('这周，它可能被 ', 'sans', INK), ('AI', 'sansb', GOLD), (' 啃下来了', 'sans', INK)])
    caption(fr, t, 11.40, 12.86 + 0.3, None, parts=[('但', 'sans', INK), ('先别信', 'sansb', RED)], size=40)
    if code_a <= 0:
        return finish(fr, t)
    # ---------- code waterfall ----------
    # lines enter from below and scroll up; decelerate so that RED line rests on scan line
    p = prog(t, 9.96, 11.40 - 9.96)
    end_off = 250 + RED_IDX * LINE_H - scan_y          # base_y + idx*LH - off == scan_y
    start_off = end_off - 1800
    off = start_off + (end_off - start_off) * ease(p) if t < 11.40 else end_off
    # repeat the listing upward so the screen is full while scrolling
    stopped = t >= 11.40
    for k in range(-80, 22):
        idx = k % len(LEAN)
        y = 250 + k * LINE_H - off
        if k > RED_IDX:
            y += 30 * ease(prog(t, 11.45, 0.3))
        if y < -30 or y > H - 110:
            continue
        is_red = k == RED_IDX and stopped
        edge = clamp(min((y + 30) / 120, (H - 110 - y) / 90))
        a = code_a * 0.55 * edge
        col = INK
        if is_red:
            a = code_a
            rp = ease(prog(t, 11.40, 0.2))
            rect(fr, 150, y - 2, 1130, y + 22, RED, 0.16 * rp)
            col = RED
        text(fr, LEAN[idx], 190, y, 'mono', 15, col, a)
        # passed the scan line -> check
        if y < scan_y - 4 and not is_red:
            mark(fr, 'check', 165, y + 10, 14, a * 1.2)
        if is_red:
            mark(fr, 'cross', 165, y + 10, 16, code_a)
            ep = ease(prog(t, 11.55, 0.35))
            text(fr, 'error: unsolved goals  ⊢ ρ.re = 1 / 2', 190, y + 28, 'mono', 15, RED, ep, reveal=ep)
    # scan line
    hline(fr, 150, 1130, scan_y + 25, GOLD, 0.25 * code_a, 1)
    illustrative(fr, t, code_a, '代码为示意')
    return finish(fr, t)


# ------------------------------------------------------------------ S1 title
def s1_title(t):
    T0 = 12.86
    fr = background(t, lamp=1.3)
    lt = t - T0
    a = ease(prog(lt, 0.05, 0.6))
    dy = 10 * (1 - a)
    rich(fr, [('谁来检查 ', 'serif', INK), ('AI', 'serif', GOLD), (' 有没有“作弊”？', 'serif', INK)],
         W / 2, 262 + dy, 60, a)
    lp = ease_io(prog(lt, 0.55, 0.9))
    hline(fr, W / 2 - 330 * lp, W / 2 + 330 * lp, 372, GOLD, 0.8, 2)
    sa = ease(prog(lt, 1.44, 0.5))
    text(fr, '数学证明的机器裁判', W / 2, 420 + 6 * (1 - sa), 'serifr', 32, INK, 0.9 * sa, 'cm')
    na = ease(prog(lt, 2.91, 0.5))
    text(fr, '-- 截至 2026.11.22 · 结论待数学界审阅', W / 2, 500, 'mono', 18, DIM, na, 'cm',
         reveal=ease(prog(lt, 2.91, 0.8)))
    return finish(fr, t)


SCENES = [
    ('s0_hook', 0.0, 12.86, s0_hook),
    ('s1_title', 12.86, 18.69, s1_title),
]
