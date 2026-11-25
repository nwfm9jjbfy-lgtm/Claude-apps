"""15 秒样片：标题卡 → 7/21 预训练推文 → Tibo 回复 + Logan 回复。
确定性逐帧渲染（PIL），原始帧经管道送入 ffmpeg。"""
import subprocess, math
from PIL import Image, ImageDraw, ImageFont, ImageFilter

W, H, FPS = 1280, 720, 30
BG = (11, 11, 11)
GOLD = (242, 181, 58)
RED = (229, 72, 59)
WHITE = (240, 234, 222)
GREY = (150, 145, 138)
FONT = "/usr/share/fonts/truetype/wqy/wqy-zenhei.ttc"

def font(size):
    return ImageFont.truetype(FONT, size)

def ease(t):  # easeOutCubic, clamp 0..1
    t = max(0.0, min(1.0, t))
    return 1 - (1 - t) ** 3

def rounded(img, r=22):
    mask = Image.new("L", img.size, 0)
    ImageDraw.Draw(mask).rounded_rectangle([0, 0, *img.size], r, fill=255)
    out = Image.new("RGBA", img.size)
    out.paste(img, (0, 0), mask)
    return out

# ---------- 素材 ----------
thread = Image.open("assets/tweets/2026-07-21_pretraining_thread.jpg").convert("RGB")
main_tweet = rounded(thread.crop((0, 0, 1206, 660)))
tibo = rounded(thread.crop((0, 1275, 1206, 1610)))
logan_reply = rounded(thread.crop((0, 1610, 1206, 1988)))

# 背景：暗角 + 巨大年份水印，预先画好
base = Image.new("RGB", (W, H), BG)
wm = ImageDraw.Draw(base)
wm.text((W - 40, H + 40), "2026", font=font(380), fill=(24, 24, 24), anchor="rd")
vig = Image.new("L", (W, H), 0)
ImageDraw.Draw(vig).ellipse([-260, -220, W + 260, H + 220], fill=255)
vig = vig.filter(ImageFilter.GaussianBlur(160))
base = Image.composite(base, Image.new("RGB", (W, H), (0, 0, 0)), vig)

# 飘落的灰色方块（确定性）
squares = [((i * 197) % W, (i * 89) % H, 6 + (i * 7) % 18, 10 + (i * 13) % 22) for i in range(26)]

def background(t):
    img = base.copy()
    ov = Image.new("RGBA", (W, H), (0, 0, 0, 0))
    d = ImageDraw.Draw(ov)
    for x, y, s, sp in squares:
        yy = (y + t * sp) % (H + 40) - 20
        d.rectangle([x, yy, x + s, yy + s], fill=(120, 120, 120, 28))
    img.paste(ov, (0, 0), ov)
    return img

def paste_alpha(img, layer, xy, alpha):
    if alpha <= 0:
        return
    l = layer.copy()
    a = l.split()[3].point(lambda v: int(v * alpha))
    l.putalpha(a)
    img.paste(l, xy, l)

def text_alpha(img, xy, s, f, color, alpha, anchor="mm"):
    if alpha <= 0:
        return
    ov = Image.new("RGBA", img.size, (0, 0, 0, 0))
    ImageDraw.Draw(ov).text(xy, s, font=f, fill=(*color, int(255 * alpha)), anchor=anchor)
    img.paste(ov, (0, 0), ov)

def subtitle(img, zh, en, alpha):
    """底部双语字幕：中文大字 + 英文原文小字。"""
    text_alpha(img, (W // 2, H - 78), zh, font(32), WHITE, alpha)
    text_alpha(img, (W // 2, H - 38), en, font(18), GREY, alpha)

def date_chip(img, s, alpha):
    if alpha <= 0:
        return
    ov = Image.new("RGBA", img.size, (0, 0, 0, 0))
    d = ImageDraw.Draw(ov)
    d.rectangle([48, 40, 56, 78], fill=(*RED, int(255 * alpha)))
    d.text((70, 59), s, font=font(30), fill=(*WHITE, int(255 * alpha)), anchor="lm")
    img.paste(ov, (0, 0), ov)

def scaled(layer, s):
    return layer.resize((int(layer.width * s), int(layer.height * s)), Image.LANCZOS)

# ---------- 镜头 ----------
def shot_title(t):  # 0–3s
    img = background(t)
    a = ease(t / 0.8) * (1 - ease((t - 2.6) / 0.4))
    text_alpha(img, (W // 2, 300), ":)", font(170), GOLD, a)
    text_alpha(img, (W // 2, 450), "微 笑", font(64), WHITE, ease((t - 0.6) / 0.8) * (1 - ease((t - 2.6) / 0.4)))
    text_alpha(img, (W // 2, 510), "S   M   I   L   E", font(20), GREY, ease((t - 1.0) / 0.8) * (1 - ease((t - 2.6) / 0.4)))
    return img

def shot_tweet(t):  # 3–9.5s，本地 t 0–6.5
    img = background(t + 3)
    fade = ease(t / 0.6) * (1 - ease((t - 6.1) / 0.4))
    date_chip(img, "2026.07.21", fade)
    text_alpha(img, (W - 48, 59), "此时，Gemini 3.5 Pro 据报道已多次延期", font(20), RED, fade * ease((t - 0.8) / 0.6), anchor="rm")
    s = 0.60 + 0.03 * (t / 6.5)  # 慢推
    card = scaled(main_tweet, s)
    paste_alpha(img, card, ((W - card.width) // 2, 118 + int(20 * (1 - ease(t / 0.8)))), fade)
    # :) 金色弹出
    pop = ease((t - 2.2) / 0.5) * (1 - ease((t - 6.1) / 0.4))
    text_alpha(img, (W // 2 + card.width // 2 + 70, 330), ":)", font(int(40 + 30 * pop)), GOLD, pop)
    subtitle(img, "我们已经启动了迄今最雄心勃勃的一次预训练——为了 Gemini 4，进展令人兴奋 :)",
             "We have started our most ambitious pre-training run yet, for Gemini 4, and are excited by the progress :)",
             ease((t - 0.8) / 0.5) * (1 - ease((t - 6.1) / 0.4)))
    return img

def shot_reply(t):  # 9.5–15s，本地 t 0–5.5
    img = background(t + 9.5)
    out = 1 - ease((t - 5.0) / 0.5)
    s = 0.58
    a1 = ease(t / 0.5) * out
    c1 = scaled(tibo, s)
    paste_alpha(img, c1, ((W - c1.width) // 2, 110 - int(16 * (1 - a1))), a1)
    a2 = ease((t - 2.4) / 0.5) * out
    c2 = scaled(logan_reply, s)
    paste_alpha(img, c2, ((W - c2.width) // 2, 110 + c1.height + 14 + int(20 * (1 - a2))), a2)
    if t < 2.4:
        subtitle(img, "希望它也有跑完的那一天！", "Hope it finishes one day too!", ease((t - 0.4) / 0.4))
    else:
        subtitle(img, "谢谢 Tibo！TPU 和预训练团队正在火力全开！", "Ty Tibo! TPU's and Pre-training team are cooking!",
                 ease((t - 2.6) / 0.4) * out)
    return img

DUR = 15.0
def frame(t):
    if t < 3.0:
        return shot_title(t)
    if t < 9.5:
        return shot_tweet(t - 3.0)
    return shot_reply(t - 9.5)

if __name__ == "__main__":
    import sys
    out = sys.argv[1] if len(sys.argv) > 1 else "sample.mp4"
    p = subprocess.Popen(["ffmpeg", "-y", "-loglevel", "error", "-f", "rawvideo", "-pix_fmt", "rgb24",
                          "-s", f"{W}x{H}", "-r", str(FPS), "-i", "-",
                          "-c:v", "libx264", "-pix_fmt", "yuv420p", "-crf", "18", "-preset", "medium", out],
                         stdin=subprocess.PIPE)
    for i in range(int(DUR * FPS)):
        p.stdin.write(frame(i / FPS).tobytes())
    p.stdin.close()
    p.wait()
