# 產生洋流飄帶貼圖：uv run --with pillow Tools/make_textures.py
# 每張 256x2048（K=2 倍解析度，小字才不會糊），上下可無縫重複（v 方向 tiling）。
# 想用真的掃描圖就直接覆蓋 Assets/Resources/Ribbons/*.png。
import math
import os

from PIL import Image, ImageDraw, ImageFont

K = 2
W, H = 128 * K, 1024 * K
OUT = os.path.join(os.path.dirname(__file__), "..", "Assets", "Resources", "Ribbons")
os.makedirs(OUT, exist_ok=True)
FONT = "/System/Library/Fonts/STHeiti Medium.ttc"
BIG = ImageFont.truetype(FONT, 92 * K)
EDGE = 18 * K
TINY = ImageFont.truetype(FONT, 14 * K)   # 邊條「2026 台北 洋流」：比舊版大、解析度兩倍


def center_text(d, text, color, period=256):
    # 直排「洋流」，每 period（原尺寸）重複一次
    for y0 in range(0, H, period * K):
        for k, ch in enumerate(text):
            d.text((W / 2, y0 + (64 + k * 128) * K), ch, font=BIG, fill=color, anchor="mm")


def edge_text(img, text, color):
    # 邊條小字：先橫著寫再轉 90 度貼上；字距固定，剛好整除 H 才能無縫
    strip = Image.new("RGBA", (H, EDGE), (0, 0, 0, 0))
    sd = ImageDraw.Draw(strip)
    step = 128 * K
    for x in range(0, H, step):
        sd.text((x + 6 * K, EDGE / 2), text, font=TINY, fill=color, anchor="lm")
    rot = strip.rotate(90, expand=True)
    img.alpha_composite(rot, (0, 0))
    img.alpha_composite(rot, (W - EDGE, 0))


def classic():
    img = Image.new("RGBA", (W, H), "white")
    d = ImageDraw.Draw(img)
    d.rectangle([0, 0, EDGE, H], fill="#d7262e")
    d.rectangle([W - EDGE, 0, W, H], fill="#d7262e")
    center_text(d, "洋流", "#111111")
    edge_text(img, "2026 台北 洋流", "white")
    return img


def rainbow():
    img = Image.new("RGBA", (W, H), "white")
    d = ImageDraw.Draw(img)
    cols = ["#e53935", "#fb8c00", "#fdd835", "#43a047", "#1e88e5", "#5e35b1"]
    w = 16 * K / len(cols) * 1.5
    for i, c in enumerate(cols):
        d.rectangle([i * w, 0, (i + 1) * w, H], fill=c)
        d.rectangle([W - (i + 1) * w, 0, W - i * w, H], fill=c)
    center_text(d, "洋流", "#111111")
    return img


def tiger():
    img = Image.new("RGBA", (W, H), "#f3e3c3")
    d = ImageDraw.Draw(img)
    s = lambda *v: [x * K for x in v]
    d.rectangle(s(0, 0, 10, 1024), fill="#e2582b")
    d.rectangle(s(118, 0, 128, 1024), fill="#e2582b")
    label = ImageFont.truetype(FONT, 24 * K)
    for y0 in range(0, 1024, 256):
        cy = y0 + 100
        d.ellipse(s(28, cy - 46, 100, cy + 46), fill="#f08a24", outline="#3a2414", width=3 * K)  # 虎頭
        d.ellipse(s(28, cy - 58, 48, cy - 36), fill="#f08a24", outline="#3a2414", width=3 * K)  # 耳
        d.ellipse(s(80, cy - 58, 100, cy - 36), fill="#f08a24", outline="#3a2414", width=3 * K)
        for sx in (40, 56, 72, 88):
            d.line(s(sx, cy - 40, sx + 4, cy - 22), fill="#3a2414", width=4 * K)  # 虎紋
        d.ellipse(s(46, cy - 12, 56, cy - 2), fill="#3a2414")
        d.ellipse(s(72, cy - 12, 82, cy - 2), fill="#3a2414")
        d.ellipse(s(54, cy + 8, 74, cy + 30), fill="#fff4df", outline="#3a2414", width=2 * K)
        d.text((W / 2, (y0 + 200) * K), "TAIPEI", font=label, fill="#c0392b", anchor="mm")
    return img


def navy():
    img = Image.new("RGBA", (W, H), "#1b2a55")
    d = ImageDraw.Draw(img)
    d.rectangle([0, 0, 8 * K, H], fill="#c9a447")
    d.rectangle([W - 8 * K, 0, W, H], fill="#c9a447")
    for y in range(0, 1024, 64):  # 金色波浪紋
        for x in range(8, 120, 2):
            yy = y + 32 + 10 * math.sin(x / 12)
            d.ellipse([(x - 2) * K, (yy - 2) * K, (x + 2) * K, (yy + 2) * K], fill="#c9a447")
    center_text(d, "洋流", "#e8d18a", period=512)
    return img


for name, fn in [("classic", classic), ("rainbow", rainbow), ("tiger", tiger), ("navy", navy)]:
    fn().convert("RGB").save(os.path.join(OUT, name + ".png"))
    print("wrote", name)
