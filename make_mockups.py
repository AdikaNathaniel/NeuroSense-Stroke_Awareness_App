from PIL import Image, ImageDraw, ImageFont, ImageFilter
import os, math

INPUT_DIR  = r"C:\NeuroSense-Stroke_Awareness_App-stroke-neuro\NeuroSense-Stroke_Awareness_App-stroke-neuro\images-mobile"
OUTPUT_DIR = INPUT_DIR  # overwrite in-place

# Title for each screenshot
TITLES = {
    "1.jpg": "Ask NeuroSense AI Anything",
    "2.jpg": "Track Your Stroke Risk Over Time",
    "3.jpg": "Join NeuroSense in Seconds",
    "4.jpg": "Available in Multiple Languages",
    "5.jpg": "Secure & Private Access",
    "6.jpg": "Assess Your Stroke Risk Instantly",
}

# NeuroSense brand colours
BG_TOP    = (13,  71, 161)   # deep blue  #0D47A1
BG_BOTTOM = (21, 101, 192)   # mid blue   #1565C0
BEZEL     = (28,  28,  30)   # near-black
BEZEL_IN  = (18,  18,  20)
SCREEN_BG = (255, 255, 255)

# Canvas / phone dimensions
CANVAS_W  = 540
CANVAS_H  = 960
TITLE_H   = 90          # space at top for title text
PHONE_W   = 340
PHONE_H   = 700
PHONE_X   = (CANVAS_W - PHONE_W) // 2
PHONE_Y   = TITLE_H + 20
RADIUS    = 42           # bezel corner radius
BEZEL_T   = 14          # bezel thickness
NOTCH_W   = 80
NOTCH_H   = 24
NOTCH_R   = 12


def gradient_bg(w, h, top, bottom):
    img = Image.new("RGB", (w, h))
    draw = ImageDraw.Draw(img)
    for y in range(h):
        t   = y / h
        r   = int(top[0] + (bottom[0] - top[0]) * t)
        g   = int(top[1] + (bottom[1] - top[1]) * t)
        b   = int(top[2] + (bottom[2] - top[2]) * t)
        draw.line([(0, y), (w, y)], fill=(r, g, b))
    return img


def rounded_rect_mask(w, h, r):
    mask = Image.new("L", (w, h), 0)
    d    = ImageDraw.Draw(mask)
    d.rounded_rectangle([0, 0, w - 1, h - 1], radius=r, fill=255)
    return mask


def add_phone_frame(canvas, screenshot, px, py, pw, ph):
    draw = ImageDraw.Draw(canvas)

    # ── outer bezel (dark shell) ──────────────────────────────────────────────
    draw.rounded_rectangle(
        [px, py, px + pw, py + ph],
        radius=RADIUS, fill=BEZEL
    )

    # ── side button details ───────────────────────────────────────────────────
    btn_x = px + pw
    # volume up / down (right side)
    for by in [py + 120, py + 175]:
        draw.rounded_rectangle([btn_x - 3, by, btn_x + 6, by + 38],
                               radius=3, fill=(50, 50, 52))
    # power button (left side)
    draw.rounded_rectangle([px - 6, py + 150, px + 3, py + 210],
                           radius=3, fill=(50, 50, 52))

    # ── screen area ───────────────────────────────────────────────────────────
    sx = px + BEZEL_T
    sy = py + BEZEL_T
    sw = pw - BEZEL_T * 2
    sh = ph - BEZEL_T * 2
    sr = RADIUS - BEZEL_T + 2

    screen_mask = rounded_rect_mask(sw, sh, sr)

    # Resize screenshot to fill screen
    shot = screenshot.resize((sw, sh), Image.LANCZOS)
    canvas.paste(shot, (sx, sy), screen_mask)

    # ── dark overlay frame inside screen (inner bezel illusion) ──────────────
    inner = Image.new("RGBA", (sw, sh), (0, 0, 0, 0))
    id_   = ImageDraw.Draw(inner)
    id_.rounded_rectangle([0, 0, sw - 1, sh - 1], radius=sr,
                          outline=(0, 0, 0, 120), width=2)
    canvas.paste(inner, (sx, sy), inner)



def pick_font(size):
    candidates = [
        "C:/Windows/Fonts/arialbd.ttf",
        "C:/Windows/Fonts/arial.ttf",
        "C:/Windows/Fonts/calibrib.ttf",
        "C:/Windows/Fonts/segoeui.ttf",
    ]
    for path in candidates:
        if os.path.exists(path):
            return ImageFont.truetype(path, size)
    return ImageFont.load_default()


def make_mockup(src_path, title, out_path):
    screenshot = Image.open(src_path).convert("RGB")

    # Canvas with gradient background
    canvas = gradient_bg(CANVAS_W, CANVAS_H, BG_TOP, BG_BOTTOM)

    # Phone frame + screenshot
    add_phone_frame(canvas, screenshot, PHONE_X, PHONE_Y, PHONE_W, PHONE_H)

    # Title text
    draw  = ImageDraw.Draw(canvas)
    font  = pick_font(28)
    bbox  = draw.textbbox((0, 0), title, font=font)
    tw    = bbox[2] - bbox[0]
    tx    = (CANVAS_W - tw) // 2
    ty    = (TITLE_H - (bbox[3] - bbox[1])) // 2

    # Shadow
    draw.text((tx + 2, ty + 2), title, font=font, fill=(0, 0, 0, 120))
    # White text
    draw.text((tx, ty), title, font=font, fill=(255, 255, 255))

    # Subtle bottom label
    font_sm = pick_font(16)
    label   = "NeuroSense — Stroke Awareness"
    bb2     = draw.textbbox((0, 0), label, font=font_sm)
    lx      = (CANVAS_W - (bb2[2] - bb2[0])) // 2
    ly      = CANVAS_H - 30
    draw.text((lx, ly), label, font=font_sm, fill=(180, 210, 255))

    canvas.save(out_path, quality=95)
    print(f"Saved: {os.path.basename(out_path)}")


# ── Run ───────────────────────────────────────────────────────────────────────
if __name__ == '__main__':
    for fname, title in TITLES.items():
        src = os.path.join(INPUT_DIR, fname)
        if os.path.exists(src):
            make_mockup(src, title, os.path.join(OUTPUT_DIR, fname))
        else:
            print(f"Missing: {fname}")
    print("\nAll done.")
