"""English on-screen text. Keys are the exact Chinese strings used in the scenes."""
import re

EN = {
    # S0 / S1
    '1859 年，黎曼写下一个猜想': 'In 1859, Riemann wrote down a conjecture',
    '167 年，没人证明它': 'For 167 years, no one has proved it',
    '这周，它可能被 ': 'This week, ',
    ' 啃下来了': ' may have cracked it',
    '但': 'But ',
    '先别信': "don't believe it yet",
    '代码为示意': 'illustrative code',
    '谁来检查 ': 'Who checks whether ',
    ' 有没有“作弊”？': ' is cheating?',
    '数学证明的机器裁判': 'Machine referees for mathematical proof',
    '-- 截至 2026.11.22 · 结论待数学界审阅': '-- as of 2026-11-22 · not yet accepted by mathematicians',
    # S2
    '§1 黎曼猜想': '§1 The Riemann Hypothesis',
    '质数：2、3、5、7、11……': 'Primes: 2, 3, 5, 7, 11 … ',
    '看似毫无规律': 'no obvious pattern',
    '它们怎么分布，藏在 ζ 函数的零点里': 'How they are spread out is encoded in the zeros of ζ',
    '平凡零点：−2, −4, −6 …（不在讨论范围）': 'trivial zeros −2, −4, −6 … (excluded)',
    '已用计算机验算': 'Checked by computer:',
    '10¹³ 个零点': '10¹³ zeros',
    '全在这条线上': 'all on this line',
    '黎曼猜想：': 'Riemann Hypothesis (RH): ',
    '所有非平凡零点，都在 Re(s) = ½ 这条线上': 'every nontrivial zero lies on Re(s) = ½',
    '但验算再多，': 'But no amount of checking ',
    '也不等于证明': 'is a proof',
    # S3
    '§2 人类审稿': '§2 Human review',
    '250 页论文 + 3 GB 程序与数据': '250 pages + 3 GB of code and data',
    '黑尔斯（Thomas Hales）提交开普勒猜想的证明': 'Thomas Hales submits a proof of the Kepler conjecture',
    '× 12 位审稿人': '× 12 referees',
    '“确定”': '"certain"',
    '人类怎么确认一个证明是对的？靠同行一页页审': 'How do we know a proof is right? Peers check it page by page',
    '真实案例：': 'A real case: ',
    '开普勒猜想（最密的堆球方式）': 'the Kepler conjecture (densest sphere packing)',
    '12 位审稿人，审了 4 年': '12 referees, 4 years of review',
    '结论：': 'Verdict: ',
    '99% 确定': '99% certain',
    '，但没法再往前': ', and no further',
    '剩下的 ': 'What about the last ',
    ' 怎么办？': '?',
    # S4
    '命题：两个偶数相加，还是偶数': 'Claim: even + even is even',
    '设 a = m + m': 'Let a = m + m',
    '设 b = n + n': 'Let b = n + n',
    'a + b = (m + n) + (m + n)，证毕': 'a + b = (m + n) + (m + n). Done.',
    '§3 Lean：机器裁判': '§3 Lean, the machine referee',
    'No goals — 证明完成': 'No goals — proof complete',
    '-- 少写了一步：没有展开 b': '-- one step missing: b is never unpacked',
    '补上这一步 → 通过': 'add it back → passes',
    '报错信息为示意': 'illustrative error message',
    '开普勒猜想后来呢？': 'And the Kepler conjecture?',
    'Flyspeck 项目': 'The Flyspeck project',
    '用 HOL Light 和 Isabelle 完成形式化证明': 'formal proof completed in HOL Light and Isabelle',
    '每一步都由机器核对，那 1% 被补上了': 'Every step machine-checked. The missing 1%, closed.',
    'Lean：把每一步推理，写成计算机能核对的代码': 'Lean: write every step of reasoning as code a computer can check',
    '编译器逐行检查，每一步都要有依据': 'It checks line by line. Every step needs a justification',
    '如果漏掉一步呢？': 'What if a step is missing?',
    '漏一步，': 'Skip a step ',
    '就报错': 'and it fails',
    '，不讲情面': ', no exceptions',
    '补上，才能通过': 'Fill the gap, and only then it passes',
    '机器说「通过」，': 'The machine says "passed." ',
    '就够了吗？': 'Is that enough?',
    # S5
    '§4 题目写对了吗': '§4 Is the statement right?',
    '↑ 题目': '↑ the statement',
    '↓ 约 1700 万行证明，全部通过': '↓ ~17 million lines of proof, all passing',
    '机器的「通过」，只保证一件事：': 'A machine "pass" guarantees one thing:',
    '证出了': 'it proved ',
    '写下的那句话': 'exactly the sentence that was written',
    'ζ(−2) = 0，但 −2 不在 ½ 这条线上': 'ζ(−2) = 0, but −2 is not on the ½ line',
    '漏写了「平凡零点除外」，这句话本身就是错的': 'It forgot "except the trivial zeros," so the statement itself is false',
    '写错的题目为示意': 'illustrative wrong statement',
    '如果题目本身写错了呢？': 'What if the statement itself is wrong?',
    '题目一错，': 'Get the statement wrong ',
    '证的就不是同一道题': 'and you have proved a different problem',
    '题目 ⇄ Mathlib 标准写法': "statement ⇄ Mathlib's standard definition",
    '两个独立工具核对：comparator · con-leche': 'checked by two independent tools: comparator · con-leche',
    '所以要单独查：证的是不是公认的那道题': 'So check separately: is it the agreed-upon problem?',
    '这周社区查的，正是这一步': 'That is exactly what the community checked this week',
    # S6
    '§5 这周的真实状况': '§5 Where things stand',
    'Anthropic 数学家': 'Anthropic mathematician',
    'Levent Alpöge 宣布：': 'Levent Alpöge announces',
    '与 Claude 合作证明了黎曼猜想': 'a proof of RH, made with Claude',
    '约 1700 万行 Lean 代码': '~17 million lines of Lean',
    '文字版超 25 万页，未公开': '250,000+ page write-up, unreleased',
    'Lean FRO 与 Mathlib': 'Lean FRO & Mathlib',
    '联合声明：代码通过检查': 'joint statement: the code checks',
    '证的正是 Mathlib 里的黎曼猜想': "and proves Mathlib's RH statement",
    '机器这一关：过了': 'Machine check: passed',
    '克雷数学研究所官网：': 'Clay Mathematics Institute:',
    '黎曼猜想仍标注 Unsolved': 'RH still listed as "Unsolved"',
    '数学界的正式认可：还没有': 'Formal acceptance: not yet',
    '这周发生了什么？': 'What happened this week?',
    '机器裁判：': 'Machine referee: ',
    '逐行检查通过，题目也核对过了': 'every line passes, statement verified',
    '但「通过」': 'But "passed" ',
    ' 数学界已经接受': ' accepted by mathematicians',
    '机器': 'Machine',
    '人类': 'Humans',
    '通过': 'Passed',
    '✓ 通过': '✓ Passed',
    '每一步都核对过，题目写对了': 'Every step checked, statement correct',
    '还要读懂：它为什么成立': 'Still to understand: why it holds',
    '这次，证明由人和 AI 合写，由机器来验': 'This time, a human and an AI wrote it, and a machine checked it',
    '数学家还要回答：': 'Mathematicians still have to answer: ',
    '它为什么对': 'why is it true?',
    # S7
    '「能被检验」': 'Being checkable',
    '，比': ' matters more than ',
    '「说得漂亮」': 'sounding convincing',
    '更重要': '',
    'AI 写出一个证明，可能越来越容易': 'Getting a proof out of AI may keep getting easier',
    '截至 2026.11.22　结论待数学界审阅': 'As of Nov 22, 2026 · awaiting review by mathematicians',
    '示意': 'illustrative',
    '审阅中…': 'Reviewing…',
    # covers
    '黎曼猜想 × Lean': 'Riemann Hypothesis × Lean',
    '有没有“作弊”？': 'is cheating?',
    '机器：通过': 'Machine: passed',
    '人类：审阅中': 'Humans: reviewing',
    '截至 2026.11.22 · 结论待验证': 'As of Nov 22, 2026 · not yet confirmed',
    '黎曼猜想 × Lean：数学证明的机器裁判': 'Riemann Hypothesis × Lean: machine referees for proof',
}

PATTERNS = [
    (re.compile(r'^审稿第 (\d+) 年$'), r'Year \1 of review'),
    (re.compile(r'^审阅中(\.*)$'), r'Reviewing\1'),
]
CJK = re.compile(r'[一-鿿　-〿＀-￯]')


def tr(s):
    if s in EN:
        return EN[s]
    if s.startswith('-- ') and s[3:] in EN:
        return '-- ' + EN[s[3:]]
    for pat, rep in PATTERNS:
        if pat.match(s):
            return pat.sub(rep, s)
    if CJK.search(s):
        raise KeyError(f'untranslated: {s!r}')
    return s
