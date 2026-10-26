#!/usr/bin/env python3
"""Draws the app icon (a waveform turning into lines of text) and writes AppIcon.appiconset.

Requires Pillow: pip3 install pillow
Usage: python3 scripts/make-icon.py
"""
import json
from pathlib import Path

from PIL import Image, ImageDraw, ImageFilter

ROOT = Path(__file__).resolve().parent.parent
ICONSET = ROOT / "Transcribe/Resources/Assets.xcassets/AppIcon.appiconset"

SCALE = 4  # draw large, then downsample for smooth edges
S = 1024 * SCALE

TOP = (99, 102, 241)      # indigo
BOTTOM = (124, 58, 237)   # violet
WHITE = (255, 255, 255)


def px(v):
    return int(v * SCALE)


def gradient(size, top, bottom):
    img = Image.new("RGB", (1, size))
    for y in range(size):
        t = y / (size - 1)
        img.putpixel((0, y), tuple(round(a + (b - a) * t) for a, b in zip(top, bottom)))
    return img.resize((size, size))


def draw_icon():
    canvas = Image.new("RGBA", (S, S), (0, 0, 0, 0))

    # macOS icon grid: 824pt rounded square centered in 1024pt, with a soft drop shadow.
    body = (px(100), px(100), px(924), px(924))
    radius = px(185)

    shadow = Image.new("RGBA", (S, S), (0, 0, 0, 0))
    ImageDraw.Draw(shadow).rounded_rectangle(
        (body[0], body[1] + px(12), body[2], body[3] + px(12)), radius, fill=(0, 0, 0, 90)
    )
    canvas.alpha_composite(shadow.filter(ImageFilter.GaussianBlur(px(14))))

    mask = Image.new("L", (S, S), 0)
    ImageDraw.Draw(mask).rounded_rectangle(body, radius, fill=255)
    canvas.paste(gradient(S, TOP, BOTTOM), (0, 0), mask)

    fg = Image.new("RGBA", (S, S), (0, 0, 0, 0))
    d = ImageDraw.Draw(fg)
    center_y = 512

    # Waveform: vertical rounded bars on the left.
    bar_w = 44
    gap = 30
    heights = [120, 250, 380, 260, 170]
    x = 214
    for h in heights:
        d.rounded_rectangle(
            (px(x), px(center_y - h / 2), px(x + bar_w), px(center_y + h / 2)),
            px(bar_w / 2), fill=WHITE + (255,),
        )
        x += bar_w + gap

    # Text lines on the right, as if the sound became written text.
    line_h = 44
    line_gap = 40
    lines = [200, 150, 185, 110]
    left = 634
    total = len(lines) * line_h + (len(lines) - 1) * line_gap
    y = center_y - total / 2
    for w in lines:
        d.rounded_rectangle(
            (px(left), px(y), px(left + w), px(y + line_h)),
            px(line_h / 2), fill=WHITE + (235,),
        )
        y += line_h + line_gap

    canvas.alpha_composite(fg)
    return canvas.resize((1024, 1024), Image.LANCZOS)


def main():
    master = draw_icon()
    images = []
    for size in (16, 32, 128, 256, 512):
        for scale in (1, 2):
            pixels = size * scale
            name = f"icon_{size}x{size}{'@2x' if scale == 2 else ''}.png"
            master.resize((pixels, pixels), Image.LANCZOS).save(ICONSET / name)
            images.append({"filename": name, "idiom": "mac", "scale": f"{scale}x", "size": f"{size}x{size}"})
    with open(ICONSET / "Contents.json", "w") as f:
        json.dump({"images": images, "info": {"author": "xcode", "version": 1}}, f, indent=2)
        f.write("\n")
    print(f"wrote {len(images)} images to {ICONSET.relative_to(ROOT)}")


if __name__ == "__main__":
    main()
