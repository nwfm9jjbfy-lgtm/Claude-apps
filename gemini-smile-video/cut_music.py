"""把 4分38秒 的原曲剪成约 150.5 秒的配乐，配合分镜的情绪曲线。

128 BPM（一拍 0.469s，一小节 1.875s，8 小节 = 15s）。剪辑点全部取自实测底鼓位置，
都落在乐句的重拍上：前一段的 4 小节 break 结束 → 接下一段过门之后的重拍，听感是连续的。

段落      原曲区间              成片时间          对应画面
1 铺垫    50.18 → 110.21       0     → 60.0    安静 16 小节：标题、7/21 推文、Tibo；30.0s 处 drop → I/O 宣布 3.5 Pro、延期翻页日历
                                                 52.5–60.0 是 4 小节无鼓 break：适合放 Bloomberg 报道、股价转红
2 主体    201.93 → 277.41      60.0  → 135.5   60.0 鼓点回归：7 月推文闪切；
                                                 75.5 起安静桥段（约 30s）：取消传闻 → "注定会失败"；
                                                 105.5 重新爆发：Gemini 4 发布、元素周期表四格点亮
3 尾声    57.68 → 72.68        133.6 → 150.5   一小节交叉淡入，回到开头的安静质感：I think it worked + :) 定格，6s 淡出
"""
import subprocess, json, re
import numpy as np

SR = 44100
SRC = "assets/music/source.mp3"
TMP = "/tmp/claude-0/-home-user-Claude-apps/c90a54e2-9d70-52b3-aa8d-873a25106f2f/scratchpad/music_raw.wav"

raw = subprocess.run(["ffmpeg", "-v", "error", "-i", SRC, "-f", "f32le", "-ac", "2", "-ar", str(SR), "-"],
                     capture_output=True, check=True).stdout
x = np.frombuffer(raw, dtype=np.float32).reshape(-1, 2)

def seg(t0, t1):
    return x[int(round(t0 * SR)):int(round(t1 * SR))].copy()

def join(a, c, xf):
    """等功率交叉淡化：a 的尾部与 c 的头部重叠 xf 秒。"""
    n = int(xf * SR)
    th = np.linspace(0, np.pi / 2, n)[:, None]
    return np.concatenate([a[:-n], a[-n:] * np.cos(th) + c[:n] * np.sin(th), c[n:]])

PRE = 0.012          # 剪在底鼓起音前 12ms，不切到瞬态
XF_CUT = 0.020
XF_OUT = 1.875       # 尾声：一整小节交叉淡化

s1 = seg(50.18 - PRE, 110.21 - PRE + XF_CUT)
s2 = seg(201.93 - PRE, 277.41)
s3 = seg(57.68 - XF_OUT, 57.68 + 15.0)
fade = int(6.0 * SR)
s3[-fade:] *= (np.linspace(1, 0, fade) ** 2)[:, None]
s1[:int(0.01 * SR)] *= np.linspace(0, 1, int(0.01 * SR))[:, None]  # 开头 10ms 防爆音

out = join(join(s1, s2, XF_CUT), s3, XF_OUT)

subprocess.run(["ffmpeg", "-v", "error", "-y", "-f", "f32le", "-ac", "2", "-ar", str(SR), "-i", "-", TMP],
               input=out.astype(np.float32).tobytes(), check=True)
# 两遍 loudnorm：-14 LUFS（B 站/YouTube 常用），真峰值 -1.5 dBTP
probe = subprocess.run(["ffmpeg", "-hide_banner", "-i", TMP, "-af",
                        "loudnorm=I=-14:TP=-1.5:LRA=11:print_format=json", "-f", "null", "-"],
                       capture_output=True, text=True).stderr
m = json.loads(re.search(r"\{[^{}]+\}", probe[probe.rfind("Parsed_loudnorm"):], re.S).group(0))
af = (f"loudnorm=I=-14:TP=-1.5:LRA=11:measured_I={m['input_i']}:measured_TP={m['input_tp']}:"
      f"measured_LRA={m['input_lra']}:measured_thresh={m['input_thresh']}:offset={m['target_offset']}:linear=true")
subprocess.run(["ffmpeg", "-v", "error", "-y", "-i", TMP, "-af", af, "-ar", str(SR),
                "assets/music/music_cut.wav"], check=True)
subprocess.run(["ffmpeg", "-v", "error", "-y", "-i", "assets/music/music_cut.wav", "-b:a", "192k",
                "assets/music/music_cut.m4a"], check=True)

c1 = len(s1) / SR - XF_CUT
c2 = c1 + len(s2) / SR - XF_OUT
print(f"总长 {len(out) / SR:.2f}s | drop {80.18 - 50.18:.2f}s | break {102.71 - 50.18:.2f}s | 鼓点回归 {c1:.2f}s"
      f" | 安静桥段 {c1 + 217.41 - 201.93:.2f}s | 重新爆发 {c1 + 247.41 - 201.93:.2f}s | 尾声淡入 {c2:.2f}s")
