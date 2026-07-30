#!/usr/bin/env python3
"""
Compose App Store screenshots from raw simulator captures.

Output is 1320x2868 - Apple's 6.9" iPhone slot, which it scales down for every
smaller iPhone, so this one size covers the whole iPhone range.

Each frame is a caption band over the device shot on the app's warm gradient.
The raw capture is scaled DOWN into the frame, so a capture from a smaller
simulator still yields a crisp 6.9" asset.

Arabic is shaped through HarfBuzz and rasterised with FreeType (see
arabic_text.py) rather than Pillow's plain text path, because Cairo does its
letter joining with OpenType GSUB and has no legacy presentation-form glyphs
for the reshaper approach to hit.

Usage:
    python tools/store_screenshots.py <shots_dir> <out_dir> [--lang ar|en]
"""

import argparse
import os
import sys

sys.path.insert(0, os.path.dirname(os.path.abspath(__file__)))

from PIL import Image, ImageDraw, ImageFilter, ImageFont

from arabic_text import ShapedFont

CANVAS = (1320, 2868)

# Warm & Refined, matching the app.
BG_TOP = (255, 233, 215)
BG_BOTTOM = (244, 240, 236)
INK = (58, 42, 32)
BRAND = (194, 94, 40)

FONT_DIR = os.path.join(
    os.path.dirname(os.path.dirname(os.path.abspath(__file__))),
    "BabyTracker", "Resources",
)

# caption, sub-caption, source file stem
FRAMES = {
    "ar": [
        ("مهارات كل شهر", "تابعي ما يتقنه طفلك، مهارة بمهارة", "01-home"),
        ("أسبوعاً بأسبوع", "كيف ينمو طفلك، ولماذا", "02-weeks"),
        ("مجتمع الأمهات", "اسألي، شاركي، وأجيبي", "03-community"),
        ("ابدئي بتاريخ الميلاد", "وكل شيء يُحسب تلقائياً", "00-onboarding"),
    ],
    "en": [
        ("Milestones by month", "Check off what your baby can do", "01-home"),
        ("Week by week", "How your baby grows, and why", "02-weeks"),
        ("A parents' community", "Ask, share, and answer", "03-community"),
        ("Start with a birth date", "Everything else is worked out", "00-onboarding"),
    ],
}


def font(name, size):
    path = os.path.join(FONT_DIR, name)
    if not os.path.exists(path):
        sys.exit("missing font: " + path)
    return ShapedFont(path, size)


def gradient(size):
    top, bottom = Image.new("RGB", (1, 2)), None
    top.putpixel((0, 0), BG_TOP)
    top.putpixel((0, 1), BG_BOTTOM)
    return top.resize(size, Image.BICUBIC)


def rounded(img, radius):
    mask = Image.new("L", img.size, 0)
    ImageDraw.Draw(mask).rounded_rectangle(
        [(0, 0), (img.size[0] - 1, img.size[1] - 1)], radius=radius, fill=255
    )
    out = img.convert("RGBA")
    out.putalpha(mask)
    return out


def centered(image, y, text, fnt, fill, width, lang):
    """`y` is the top of the line; the shaper draws from a baseline."""
    rtl = lang == "ar"
    kwargs = (
        {"direction": "rtl", "script": "Arab", "language": "ar"}
        if rtl
        else {"direction": "ltr", "script": "Latn", "language": "en"}
    )
    text_width = fnt.measure(text, **kwargs)
    x = (width - text_width) / 2
    fnt.draw(image, (x, y + fnt.ascent()), text, fill + (255,), **kwargs)
    return fnt.size


def compose(src_path, caption, sub, lang, out_path):
    canvas = gradient(CANVAS).convert("RGBA")

    title_font = font("Cairo-Bold.ttf", 76)
    sub_font = font("Cairo-Regular.ttf", 44)

    top = 132
    h = centered(canvas, top, caption, title_font, INK, CANVAS[0], lang)
    centered(canvas, top + h + 72, sub, sub_font, BRAND, CANVAS[0], lang)

    # Device shot, scaled to leave the caption band clear.
    shot = Image.open(src_path).convert("RGB")
    target_w = int(CANVAS[0] * 0.82)
    target_h = int(shot.size[1] * (target_w / shot.size[0]))

    max_h = CANVAS[1] - 520
    if target_h > max_h:
        target_h = max_h
        target_w = int(shot.size[0] * (target_h / shot.size[1]))

    shot = shot.resize((target_w, target_h), Image.LANCZOS)
    shot = rounded(shot, 56)

    x = (CANVAS[0] - target_w) // 2
    y = 470

    shadow = Image.new("RGBA", CANVAS, (0, 0, 0, 0))
    ImageDraw.Draw(shadow).rounded_rectangle(
        [(x, y + 16), (x + target_w, y + target_h + 16)], radius=56, fill=(120, 70, 40, 70)
    )
    canvas = Image.alpha_composite(
        canvas, shadow.filter(ImageFilter.GaussianBlur(26))
    )
    canvas.paste(shot, (x, y), shot)

    canvas.convert("RGB").save(out_path, "PNG", optimize=True)
    print("wrote {}  {}x{}".format(os.path.basename(out_path), *CANVAS))


def main():
    ap = argparse.ArgumentParser()
    ap.add_argument("shots_dir")
    ap.add_argument("out_dir")
    ap.add_argument("--lang", default="ar", choices=["ar", "en"])
    args = ap.parse_args()

    os.makedirs(args.out_dir, exist_ok=True)

    for index, (caption, sub, stem) in enumerate(FRAMES[args.lang], start=1):
        src = os.path.join(args.shots_dir, "{}-{}.png".format(stem, args.lang))
        if not os.path.exists(src):
            print("skip (missing): " + src)
            continue
        out = os.path.join(args.out_dir, "{}-{:02d}-{}.png".format(args.lang, index, stem))
        compose(src, caption, sub, args.lang, out)


if __name__ == "__main__":
    main()
