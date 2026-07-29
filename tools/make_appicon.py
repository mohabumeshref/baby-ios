# -*- coding: utf-8 -*-
"""
Builds the iOS 1024x1024 app icon from the Android adaptive-icon layers.

The Android app has no 1024px source: the largest launcher raster is 192x192,
with adaptive foreground/background layers at 432x432. This composites those
two layers the way Android does and upscales to 1024.

That upscale is a 2.37x stretch, so the result is SOFT. It is good enough to
unblock a TestFlight build - App Store Connect only requires that the slot is
filled - but a real 1024px export from the original artwork should replace it
before App Store submission, where icon quality is actually reviewed.

iOS requires the icon to be fully opaque with no alpha channel; the file is
flattened onto the adaptive background accordingly.
"""

import io
import os
import sys

from PIL import Image

ANDROID = r"D:\Mohammad\BitBucket\baby-tracker-ar-android(github)\app\src\main\res\mipmap-xxxhdpi"
OUT = os.path.join(
    os.path.dirname(os.path.dirname(os.path.abspath(__file__))),
    "BabyTracker", "Assets.xcassets", "AppIcon.appiconset", "AppIcon.png",
)

SIZE = 1024


def main():
    bg_path = os.path.join(ANDROID, "ic_launcher_background.png")
    fg_path = os.path.join(ANDROID, "ic_launcher_foreground.png")

    for p in (bg_path, fg_path):
        if not os.path.exists(p):
            print("missing:", p)
            return 1

    bg = Image.open(bg_path).convert("RGBA")
    fg = Image.open(fg_path).convert("RGBA")

    if fg.size != bg.size:
        fg = fg.resize(bg.size, Image.LANCZOS)

    # Android composites foreground over background at the same extent.
    composed = Image.alpha_composite(bg, fg)

    # Upscale before flattening so the resample works on the full-quality edges.
    composed = composed.resize((SIZE, SIZE), Image.LANCZOS)

    # iOS rejects icons with an alpha channel. Flatten onto opaque white; the
    # background layer already covers the full square, so nothing shows through.
    flat = Image.new("RGB", (SIZE, SIZE), (255, 255, 255))
    flat.paste(composed, mask=composed.split()[3])

    os.makedirs(os.path.dirname(OUT), exist_ok=True)
    flat.save(OUT, "PNG", optimize=True)

    check = Image.open(OUT)
    print("wrote %s" % OUT)
    print("  size : %sx%s" % check.size)
    print("  mode : %s (must be RGB - no alpha)" % check.mode)
    print("  bytes: %d" % os.path.getsize(OUT))
    return 0


if __name__ == "__main__":
    sys.exit(main())
