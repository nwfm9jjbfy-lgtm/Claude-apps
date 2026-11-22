"""Shared bar grid for music and picture. Bar k starts at bar(k)."""
BPM = 163.6
BEAT = 60.0 / BPM
BARLEN = 4 * BEAT          # ~1.4667 s
T0 = 2.30                  # bar 0 = first formula line


def bar(k):
    return T0 + k * BARLEN


# scene bounds in bars (bar index where each scene starts)
S_BARS = {
    's0_hook': (None, 7),
    's1_title': (7, 11),
    's2_primes': (11, 21),
    's3_review': (21, 31),
    's4_lean': (31, 48),
    's5_statement': (48, 63),
    's6_status': (63, 87),
    's7_end': (87, 102),
}
END = bar(102)


def span(name):
    a, b = S_BARS[name]
    return (0.0 if a is None else bar(a)), bar(b)
