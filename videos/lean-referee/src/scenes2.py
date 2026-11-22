"""S2–S7. Event times are bar/beat positions so picture hits match the score."""
import numpy as np
from lib import *
from timeline import bar, span, BARLEN, BEAT
from scenes import _formula_block, F_Y, CHK_X


def B(k, beat=0.0):
    return bar(k) + beat * BEAT


def cap(fr, t, k0, k1, s=None, parts=None, size=34):
    caption(fr, t, B(k0), B(k1) - 0.12, s, parts=parts, size=size)


def out_fade(t, t1, d=0.25):
    return 1 - ease_io(prog(t, t1 - d, d))


# ------------------------------------------------------------------ S2 §1 primes & zeros
PRIMES = [2, 3, 5, 7, 11, 13, 17, 19, 23, 29]
ZEROS = [14.13, 21.02, 25.01, 30.42, 32.94, 37.59, 40.92, 43.33, 48.01, 49.77]


def s2_primes(t):
    fr = background(t)
    a0, a1 = span('s2_primes')
    chapter(fr, t, a0, '§1 黎曼猜想')
    # --- number line (bars 11..15)
    nl_a = fade(t, a0, B(15), 0.4, 0.5)
    if nl_a > 0:
        y = 330
        x_of = lambda n: 120 + (n - 1) * (1040 / 29)
        hline(fr, 100, 1180, y, DIM, 0.5 * nl_a, 1)
        for n in range(1, 31):
            x = x_of(n)
            isp = n in PRIMES
            tp = B(11, n / 4) if isp else None
            lit = isp and t >= tp
            col = GOLD if lit else DIM
            a = nl_a * (1.0 if lit else 0.45)
            vline(fr, x, y - 6, y + 6, col, a, 1)
            text(fr, str(n), x, y + 26, 'mono', 18 if lit else 15, col, a, 'cm')
            if lit:
                p = ease(prog(t, tp, 0.25))
                dot(fr, x, y, 5 * p + 1, GOLD, nl_a, glow=0.8 * (1 - prog(t, tp, 0.8)) + 0.2)
    cap(fr, t, 11, 14, parts=[('质数：2、3、5、7、11……', 'sans', GOLD), ('看似毫无规律', 'sans', INK)])
    cap(fr, t, 14, 17, '它们怎么分布，藏在 ζ 函数的零点里')
    # --- critical strip (bars 15..21)
    st_a = fade(t, B(15) - 0.1, 1e9, 0.6, 0) * out_fade(t, a1)
    if st_a > 0:
        xr = lambda re: 760 + re * 110
        yi = lambda im: 560 - im * 9.0
        # axes
        hline(fr, 70, 1000, yi(0), DIM, 0.6 * st_a, 1)
        vline(fr, xr(0), 80, yi(0) + 10, DIM, 0.6 * st_a, 1)
        text(fr, 'Re', 1005, yi(0), 'mono', 16, DIM, st_a, 'lm')
        text(fr, 'Im', xr(0) - 10, 84, 'mono', 16, DIM, st_a, 'rt')
        for re in (-6, -4, -2, 0, 1):
            text(fr, str(re), xr(re), yi(0) + 16, 'mono', 14, DIM, st_a * 0.8, 'ct')
        # strip 0<Re<1
        rect(fr, xr(0), 80, xr(1), yi(0), GOLD, 0.06 * st_a)
        la = st_a * ease(prog(t, B(16), 0.8))
        vline(fr, xr(0.5), 80 + (yi(0) - 80) * (1 - la), yi(0), GOLD, 0.8 * la, 2, dash=7)
        text(fr, 'Re(s) = ½', xr(0.5) + 14, 92, 'mono', 18, GOLD, la, 'lt')
        # nontrivial zeros pop on beats from bar 17
        for i, im in enumerate(ZEROS):
            tz = B(17, i * 0.5)
            if t < tz:
                continue
            p = ease(prog(t, tz, 0.3))
            dot(fr, xr(0.5), yi(im), 5 * p, GOLD, st_a, glow=0.5)
            if i < 3:
                text(fr, f'{0.5}+{im}i', xr(0.5) + 16, yi(im), 'mono', 14, INK, st_a * p * 0.7, 'lm')
        # trivial zeros (gray) at -2,-4,-6
        ta = st_a * ease(prog(t, B(18), 0.5))
        for re in (-2, -4, -6):
            dot(fr, xr(re), yi(0), 5, DIM, ta)
        text(fr, '平凡零点：−2, −4, −6 …（不在讨论范围）', xr(-4), yi(0) - 22, 'sans', 16, DIM, ta, 'cb')
        # verified counter
        va = st_a * ease(prog(t, B(19), 0.5))
        text(fr, '已用计算机验算', 1040, 250, 'sans', 20, INK, va * 0.8, 'lt')
        text(fr, '10¹³ 个零点', 1040, 284, 'sansb', 34, GOLD, va, 'lt')
        text(fr, '全在这条线上', 1040, 336, 'sans', 20, INK, va * 0.8, 'lt')
    cap(fr, t, 17, 19, parts=[('黎曼猜想：', 'sansb', GOLD), ('所有非平凡零点，都在 Re(s) = ½ 这条线上', 'sans', INK)], size=30)
    cap(fr, t, 19, 21.2, parts=[('但验算再多，', 'sans', INK), ('也不等于证明', 'sansb', GOLD)])
    return finish(fr, t)


# ------------------------------------------------------------------ S3 §2 human review
def s3_review(t):
    fr = background(t)
    a0, a1 = span('s3_review')
    chapter(fr, t, a0, '§2 人类审稿')
    # paper stack grows with the clock ticks (2 per beat)
    sa = fade(t, a0, 1e9, 0.4, 0) * out_fade(t, a1)
    n_pages = int(clamp((t - B(22)) / (BEAT / 2), 0, 60))
    for i in range(n_pages):
        y = 520 - i * 5
        x = 230 + ((i * 37) % 11) - 5
        rect(fr, x, y - 120, x + 230, y, hexc('#1A1916'), sa)
        hline(fr, x, x + 230, y - 120, INK, 0.25 * sa, 1)
        vline(fr, x + 230, y - 120, y, INK, 0.12 * sa, 1)
    if n_pages:
        top = 520 - (n_pages - 1) * 5 - 120
        tx = 230 + ((n_pages - 1) * 37 % 11) - 5
        for j in range(6):  # text lines on top sheet
            hline(fr, tx + 20, tx + 200 - (j % 3) * 30, top + 22 + j * 15, DIM, 0.5 * sa, 2)
        text(fr, '250 页论文 + 3 GB 程序与数据', 345, 556, 'sans', 20, INK, sa * ease(prog(t, B(24), 0.5)), 'ct')
    # right: year + referees
    ya = sa * ease(prog(t, B(24), 0.4))
    text(fr, '1998', 640, 150, 'serif', 64, GOLD, ya, 'lt')
    text(fr, '黑尔斯（Thomas Hales）提交开普勒猜想的证明', 640, 240, 'sans', 20, INK, ya * 0.85, 'lt')
    ra = sa * ease(prog(t, B(26), 0.4))
    for i in range(12):
        x = 660 + (i % 6) * 52
        y = 310 + (i // 6) * 52
        dot(fr, x, y, 13, INK, ra * 0.85)
    text(fr, '× 12 位审稿人', 980, 336, 'sans', 22, INK, ra, 'lm')
    # year counter of review: bars 26..29 -> year 1..4
    if t >= B(26):
        yr = int(clamp((t - B(26)) / BARLEN, 0, 3)) + 1
        text(fr, f'审稿第 {yr} 年', 660, 430, 'sansb', 30, INK, ra, 'lt')
    pa = sa * ease(prog(t, B(28), 0.4))
    text(fr, '99%', 900, 470, 'serif', 64, GOLD, pa, 'lt')
    text(fr, '“确定”', 1040, 520, 'sans', 24, INK, pa, 'lb')
    oa = sa * ease(prog(t, B(30), 0.3))
    text(fr, '1%', 1160, 520, 'serif', 40, RED, oa, 'lb')
    cap(fr, t, 21, 24, '人类怎么确认一个证明是对的？靠同行一页页审')
    cap(fr, t, 24, 26, parts=[('真实案例：', 'sansb', GOLD), ('开普勒猜想（最密的堆球方式）', 'sans', INK)])
    cap(fr, t, 26, 28, '12 位审稿人，审了 4 年')
    cap(fr, t, 28, 30, parts=[('结论：', 'sans', INK), ('99% 确定', 'sansb', GOLD), ('，但没法再往前', 'sans', INK)])
    cap(fr, t, 30, 31.2, parts=[('剩下的 ', 'sans', INK), ('1%', 'sansb', RED), (' 怎么办？', 'sans', INK)], size=40)
    return finish(fr, t)


# ------------------------------------------------------------------ S4 §3 Lean
NAT = ['命题：两个偶数相加，还是偶数',
       '设 a = m + m',
       '设 b = n + n',
       'a + b = (m + n) + (m + n)，证毕']
LEAN4 = ['theorem even_add (ha : Even a) (hb : Even b) :',
         '    Even (a + b) := by',
         '  obtain ⟨m, rfl⟩ := ha',
         '  obtain ⟨n, rfl⟩ := hb',
         '  exact ⟨m + n, by ring⟩']
# which code lines go with which natural-language line
PAIR = [(0, [0, 1]), (1, [2]), (2, [3]), (3, [4])]


def _lean_panel(fr, t, alpha, start_bar, skip_line=None, err_t=None, fix_t=None):
    """step i appears at bar start_bar+i, checked on beat 3 (chime)."""
    xL, xR, y0, LH = 90, 640, 170, 44
    rect(fr, 600, 140, 1220, 420, hexc('#121216'), 0.85 * alpha)
    frame_box(fr, 600, 140, 1220, 420, DIM, 0.35 * alpha)
    text(fr, 'Lean 4', 1208, 150, 'mono', 14, DIM, alpha, 'rt')
    row = 0
    for i, (ni, codes) in enumerate(PAIR):
        ts = B(start_bar + i)
        if t < ts:
            break
        p = ease(prog(t, ts, 0.5))
        text(fr, NAT[ni], xL, y0 + ni * 58, 'sansb' if ni == 0 else 'sans', 24 if ni == 0 else 22,
             GOLD if ni == 0 else INK, alpha * p, 'lt', reveal=p)
        for c in codes:
            if c == skip_line and not (fix_t and t >= fix_t):
                continue
            yy = y0 + row * LH
            red = err_t is not None and c == 4 and t >= err_t and not (fix_t and t >= fix_t)
            text(fr, LEAN4[c], xR, yy, 'mono', 19, RED if red else INK, alpha * p, 'lt', reveal=p)
            tc = B(start_bar + i, 3)
            if red:
                rect(fr, 604, yy - 6, 1216, yy + 30, RED, 0.12 * alpha)
                mark(fr, 'cross', 622, yy + 12, 18, alpha)
                ep = ease(prog(t, err_t + 0.1, 0.4))
                text(fr, 'error: unsolved goals  ⊢ Even (m + m + b)', xR, yy + 44, 'mono', 17, RED, alpha * ep, reveal=ep)
            elif t >= tc and not (err_t and c == 4 and t < (fix_t or 1e9) and t >= err_t):
                mark(fr, 'check', 622, yy + 12, 18, alpha, ease(prog(t, tc, 0.2)))
            row += 1
    return row


def s4_lean(t):
    fr = background(t)
    a0, a1 = span('s4_lean')
    chapter(fr, t, a0, '§3 Lean：机器裁判')
    # part A: full proof bars 32..36 ; part B: missing step bars 37..42 ; part C: Flyspeck 43..48
    pa = fade(t, B(32) - 0.2, B(37), 0.4, 0.3)
    if pa > 0:
        _lean_panel(fr, t, pa, 32)
        da = pa * ease(prog(t, B(35, 3) + 0.4, 0.4))
        text(fr, 'No goals — 证明完成', 640, 440, 'monob', 20, GREEN, da, 'lt')
    pb = fade(t, B(37), B(43), 0.4, 0.3)
    if pb > 0:
        _lean_panel(fr, t, pb, 36, skip_line=3, err_t=B(39, 2), fix_t=B(41))
        text(fr, '-- 少写了一步：没有展开 b', 640, 440, 'mono', 17, DIM, pb * ease(prog(t, B(38), 0.4)) * (1 - prog(t, B(41), 0.3)), 'lt')
        if t >= B(41):
            fp = ease(prog(t, B(41), 0.4))
            text(fr, '补上这一步 → 通过', 640, 440, 'monob', 20, GREEN, pb * fp, 'lt')
        illustrative(fr, t, pb, '报错信息为示意')
    pc = fade(t, B(43), 1e9, 0.5, 0) * out_fade(t, a1)
    if pc > 0:
        text(fr, '开普勒猜想后来呢？', W / 2, 170, 'serif', 40, INK, pc, 'cm')
        ya = pc * ease(prog(t, B(44), 0.5))
        text(fr, '2014', W / 2 - 40, 282, 'serif', 72, GOLD, ya, 'rm')
        text(fr, 'Flyspeck 项目', W / 2 + 10, 262, 'sansb', 30, INK, ya, 'lm')
        text(fr, '用 HOL Light 和 Isabelle 完成形式化证明', W / 2 + 10, 304, 'sans', 20, INK, ya * 0.85, 'lm')
        ck = ease(prog(t, B(45, 3), 0.3))
        mark(fr, 'check', W / 2, 410, 64, pc, ck)
        text(fr, '每一步都由机器核对，那 1% 被补上了', W / 2, 470, 'sans', 24, INK, pc * ck, 'cm')
    cap(fr, t, 31, 34, 'Lean：把每一步推理，写成计算机能核对的代码', size=32)
    cap(fr, t, 34, 37, '编译器逐行检查，每一步都要有依据')
    cap(fr, t, 37, 39, '如果漏掉一步呢？')
    cap(fr, t, 39, 41, parts=[('漏一步，', 'sans', INK), ('就报错', 'sansb', RED), ('，不讲情面', 'sans', INK)])
    cap(fr, t, 41, 43, '补上，才能通过')
    cap(fr, t, 46, 48.2, parts=[('机器说「通过」，', 'sans', INK), ('就够了吗？', 'sansb', GOLD)])
    return finish(fr, t)


# ------------------------------------------------------------------ S5 §4 statement
WRONG = ['theorem RH_wrong :', '    ∀ s : ℂ, riemannZeta s = 0 → s.re = 1 / 2']
MATHLIB = ['def RiemannHypothesis : Prop :=',
           '  ∀ (s : ℂ) (_ : riemannZeta s = 0)',
           '    (_ : ¬∃ n : ℕ, s = -2 * (n + 1))',
           '    (_ : s ≠ 1), s.re = 1 / 2']


def s5_statement(t):
    fr = background(t)
    a0, a1 = span('s5_statement')
    chapter(fr, t, a0, '§4 题目写对了吗')
    # part A (48..52): huge proof collapses into one top line "theorem ... : RiemannHypothesis"
    pa = fade(t, a0, B(52), 0.4, 0.4)
    if pa > 0:
        z = ease_io(prog(t, B(48), BARLEN * 2))
        n_lines = 34
        for i in range(n_lines):
            y = 200 + i * (14 - 8 * z) + 30 * z
            a = pa * (0.35 - 0.3 * z)
            w = 300 + (i * 97 % 380)
            hline(fr, 340, 340 + w, y, INK, a, 2)
            mark(fr, 'check', 320, y, 10, a * 1.5)
        ta = pa * ease(prog(t, B(49), 0.5))
        rect(fr, 300, 128, 980, 172, GOLD, 0.08 * ta)
        frame_box(fr, 300, 128, 980, 172, GOLD, 0.7 * ta)
        text(fr, 'theorem riemann_hypothesis : RiemannHypothesis', 640, 150, 'mono', 20, GOLD, ta, 'cm')
        text(fr, '↑ 题目', 990, 150, 'sans', 18, GOLD, ta, 'lm')
        text(fr, '↓ 约 1700 万行证明，全部通过', 640, 470, 'sans', 18, INK, ta * 0.8, 'cm')
    cap(fr, t, 48, 50, '机器的「通过」，只保证一件事：')
    cap(fr, t, 50, 52, parts=[('证出了', 'sans', INK), ('写下的那句话', 'sansb', GOLD)])
    # part B (52..57): a wrongly written statement (illustrative)
    pb = fade(t, B(52), B(57, 2), 0.4, 0.3)
    if pb > 0:
        rect(fr, 220, 200, 1060, 330, hexc('#121216'), 0.85 * pb)
        frame_box(fr, 220, 200, 1060, 330, DIM, 0.35 * pb)
        red = t >= B(56)
        for i, ln in enumerate(WRONG):
            text(fr, ln, 250, 230 + i * 40, 'mono', 21, RED if red else INK, pb, 'lt', reveal=ease(prog(t, B(52, i * 2), 0.6)))
        if red:
            rp = ease(prog(t, B(56), 0.3))
            mark(fr, 'cross', 240, 290, 18, pb * rp)
            text(fr, 'ζ(−2) = 0，但 −2 不在 ½ 这条线上', 640, 380, 'sans', 24, RED, pb * rp, 'cm')
            text(fr, '漏写了「平凡零点除外」，这句话本身就是错的', 640, 420, 'sans', 20, INK, pb * rp * 0.85, 'cm')
        illustrative(fr, t, pb, '写错的题目为示意')
    cap(fr, t, 52, 56, '如果题目本身写错了呢？')
    cap(fr, t, 56, 57.7, parts=[('题目一错，', 'sans', INK), ('证的就不是同一道题', 'sansb', RED)])
    # part C (57.5..63): Mathlib's statement, conditions highlighted; two tools compare
    pc = fade(t, B(57, 2), 1e9, 0.4, 0) * out_fade(t, a1)
    if pc > 0:
        rect(fr, 220, 160, 1060, 340, hexc('#121216'), 0.85 * pc)
        frame_box(fr, 220, 160, 1060, 340, GOLD, 0.45 * pc)
        text(fr, 'Mathlib', 1048, 170, 'mono', 14, GOLD, pc, 'rt')
        for i, ln in enumerate(MATHLIB):
            hl = i in (2, 3) and t >= B(59)
            if hl:
                rect(fr, 236, 190 + i * 36 - 4, 760, 190 + i * 36 + 28, GOLD, 0.10 * pc)
            text(fr, ln, 250, 190 + i * 36, 'mono', 20, GOLD if hl else INK, pc, 'lt', reveal=ease(prog(t, B(57, 2 + i), 0.5)))
        ca = pc * ease(prog(t, B(61), 0.4))
        text(fr, '题目 ⇄ Mathlib 标准写法', 640, 392, 'sans', 22, INK, ca, 'cm')
        text(fr, '两个独立工具核对：comparator · con-leche', 640, 430, 'mono', 17, DIM, ca, 'cm')
        mark(fr, 'check', 640, 480, 30, pc, ease(prog(t, B(61, 3), 0.3)))
    cap(fr, t, 57.5, 61, '所以要单独查：证的是不是公认的那道题', size=32)
    cap(fr, t, 61, 63.2, '这周社区查的，正是这一步')
    return finish(fr, t)


# ------------------------------------------------------------------ S6 §5 status
CARDS = [
    (64, '11.20', ['Anthropic 数学家', 'Levent Alpöge 宣布：', '与 Claude 合作证明了黎曼猜想'],
     ['约 1700 万行 Lean 代码', '文字版超 25 万页，未公开']),
    (69, '11.21', ['Lean FRO 与 Mathlib', '联合声明：代码通过检查', '证的正是 Mathlib 里的黎曼猜想'],
     ['机器这一关：过了']),
    (74, '11.22', ['克雷数学研究所官网：', '黎曼猜想仍标注 Unsolved'],
     ['数学界的正式认可：还没有']),
]


def s6_status(t):
    fr = background(t)
    a0, a1 = span('s6_status')
    chapter(fr, t, a0, '§5 这周的真实状况')
    # timeline phase (bars 63..79)
    ta = fade(t, a0, B(79), 0.4, 0.4)
    if ta > 0:
        lp_ = ease_io(prog(t, B(63), BARLEN))
        hline(fr, 140, 140 + 1000 * lp_, 200, DIM, 0.6 * ta, 2)
        for i, (k, date, lines, sub) in enumerate(CARDS):
            if t < B(k):
                continue
            p = ease(prog(t, B(k), 0.5))
            x = 140 + i * 360
            dot(fr, x + 8, 200, 7, GOLD, ta * p, glow=0.4)
            text(fr, date, x, 222, 'monob', 30, GOLD, ta * p, 'lt')
            for j, ln in enumerate(lines):
                text(fr, ln, x, 280 + j * 34, 'sans', 19, INK, ta * p, 'lt', reveal=ease(prog(t, B(k) + 0.2 + j * 0.3, 0.6)))
            sp = ease(prog(t, B(k + 2), 0.5))
            col = GREEN if i == 1 else (DIM if i == 0 else RED)
            for j, sl in enumerate(sub):
                text(fr, sl, x, 400 + j * 28, 'sans', 17, col, ta * sp, 'lt')
    cap(fr, t, 63, 69, '这周发生了什么？')
    cap(fr, t, 69, 74, parts=[('机器裁判：', 'sans', INK), ('逐行检查通过，题目也核对过了', 'sansb', GREEN)], size=32)
    cap(fr, t, 74, 79, parts=[('但「通过」', 'sans', INK), ('≠', 'sansb', GOLD), (' 数学界已经接受', 'sans', INK)])
    # verdict phase (bars 79..87)
    va = fade(t, B(79), 1e9, 0.4, 0) * out_fade(t, a1, 0.6)
    if va > 0:
        for i, (who, verdict, col, sub, kk) in enumerate([
                ('机器', '✓ 通过', GREEN, '每一步都核对过，题目写对了', 79),
                ('人类', '审阅中…', GOLD, '还要读懂：它为什么成立', 81)]):
            p = ease(prog(t, B(kk), 0.5))
            x = 340 + i * 600
            frame_box(fr, x - 230, 150, x + 230, 470, col, 0.45 * va * p)
            text(fr, who, x, 200, 'serif', 34, INK, va * p, 'cm')
            if i == 0:
                mark(fr, 'check', x - 70, 300, 46, va * p, ease(prog(t, B(kk) + 0.3, 0.3)))
                text(fr, '通过', x + 30, 300, 'serif', 46, col, va * p, 'cm')
            else:
                dots = '.' * (1 + int((t - B(kk)) / BEAT) % 3) if t >= B(kk) else ''
                text(fr, '审阅中' + dots, x - 80, 300, 'serif', 46, col, va * p, 'lm')
            text(fr, sub, x, 400, 'sans', 20, INK, va * p * 0.85, 'cm')
    cap(fr, t, 79, 83, '这次，证明由人和 AI 合写，由机器来验')
    cap(fr, t, 83, 87, parts=[('数学家还要回答：', 'sans', INK), ('它为什么对', 'sansb', GOLD)])
    return finish(fr, t)


# ------------------------------------------------------------------ S7 ending
def s7_end(t):
    fr = background(t)
    a0, a1 = span('s7_end')
    fa = ease(prog(t, a0, 0.8))
    # formulas fully written, "?" still there; replaced by a cursor near the end
    dim = fa * (1 - 0.55 * ease(prog(t, B(91), 1.0)))
    _formula_block(fr, 100.0, dim, active_glow=False, show_q=False)
    qa = dim * (1 - ease(prog(t, B(97), 0.6)))
    if qa > 0:
        text(fr, '?', CHK_X, F_Y[2], 'serif', 52, GOLD, qa, 'cm', glow=0.3)
    if t >= B(97):
        on = 1.0 if ((t - B(97)) / BEAT) % 2 < 1.2 else 0.15
        rect(fr, CHK_X - 2, F_Y[2] - 26, CHK_X + 2, F_Y[2] + 26, GOLD, dim * on * ease(prog(t, B(97), 0.5)))
    ma = fade(t, B(91), 1e9, 0.6, 0)
    rich(fr, [('「能被检验」', 'serif', GOLD), ('，比', 'serif', INK), ('「说得漂亮」', 'serif', INK), ('更重要', 'serif', INK)],
         W / 2, 560 - 8 * (1 - ma), 44, ma)
    cap(fr, t, 87, 91, 'AI 写出一个证明，可能越来越容易')
    na = fade(t, B(97), 1e9, 0.6, 0)
    text(fr, '截至 2026.11.22　结论待数学界审阅', W / 2, 655, 'sans', 18, DIM, na, 'cm')
    black = ease_io(prog(t, B(100, 2), BARLEN * 1.5))
    return finish(fr, t, black)


SCENES = [
    ('s2_primes', *span('s2_primes'), s2_primes),
    ('s3_review', *span('s3_review'), s3_review),
    ('s4_lean', *span('s4_lean'), s4_lean),
    ('s5_statement', *span('s5_statement'), s5_statement),
    ('s6_status', *span('s6_status'), s6_status),
    ('s7_end', *span('s7_end'), s7_end),
]
