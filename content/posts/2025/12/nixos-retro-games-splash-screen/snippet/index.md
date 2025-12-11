+++
date = '2025-12-09T00:13:46+01:00'
title = "Animating NixOS Retro Games Splash Screen"
[build]
    render = 'always'
    list = 'never'
+++
```python
from PIL import Image, ImageDraw
import os

from config import *

SCREEN_BOX = [
    (413, 221), (413, 207),
    (641, 207), (641, 221),
    (655, 221), (655, 369),
    (641, 369), (641, 383),
    (413, 383), (413, 369),
    (399, 369), (399, 221)
]

FLICKER_SCREEN_BOX = [
    (399, 207), (399, 193),
    (655, 193), (655, 207),
    (669, 207), (669, 383),
    (655, 383), (655, 397),
    (399, 397), (399, 383),
    (385, 383), (385, 207)
]

BLUE_NORMAL = (56, 183, 245)
BLUE_FLASH = (82, 201, 255)
BLUE_DARK = (0, 10, 30)

BLINK_DOT = (696, 548, 15)
BLINK_COLOR = (82, 201, 255)

BLINK_PERIOD = 8
BLINK_DUTY = 0.4
BLINK_PHASE = 0

# ------------------------


def ensure_clear_dir(path):
    if not os.path.exists(path):
        os.makedirs(path)

    files = sorted(os.listdir(OUTPUT_DIR))
    for f in files:
        if f.endswith(".png"):
            os.unlink(os.path.join(OUTPUT_DIR, f))


def _polygon_centroid(points):
    pts = [tuple(map(float, p)) for p in points]
    A = 0.0
    Cx = 0.0
    Cy = 0.0
    for i in range(len(pts)):
        x1, y1 = pts[i]
        x2, y2 = pts[(i + 1) % len(pts)]
        cross = x1 * y2 - x2 * y1
        A += cross
        Cx += (x1 + x2) * cross
        Cy += (y1 + y2) * cross
    A *= 0.5

    Cx = Cx / (6 * A)
    Cy = Cy / (6 * A)
    return int(round(Cx)), int(round(Cy))


def draw_center_glow(base_img, screen_shape, radius, color):
    cx, cy = _polygon_centroid(screen_shape)

    glow_overlay = Image.new("RGBA", base_img.size, (0, 0, 0, 0))
    go = ImageDraw.Draw(glow_overlay)

    for r in range(radius, 0, -1):
        alpha = int(255 * (r / radius))
        go.ellipse((cx - r, cy - r, cx + r, cy + r), fill=color + (alpha,))

    mask = Image.new("L", base_img.size, 0)
    m = ImageDraw.Draw(mask)
    m.polygon(screen_shape, fill=255)

    clipped_glow = Image.composite(glow_overlay, Image.new("RGBA", base_img.size, (0, 0, 0, 0)), mask)
    base_img.alpha_composite(clipped_glow)


def fill_screen(img, screen_shape, color):
    overlay = Image.new("RGBA", img.size, (0, 0, 0, 0))
    d = ImageDraw.Draw(overlay)
    d.polygon(screen_shape, fill=color + (255,))
    img.alpha_composite(overlay)


def save_frame(img, idx):
    img = img.resize((400, 400), Image.Resampling.LANCZOS)
    img.save(f"{OUTPUT_DIR}/frame_{idx}.png")


def blink_cycle(frame_idx, period=BLINK_PERIOD, duty=BLINK_DUTY, phase=BLINK_PHASE):
    if period <= 0:
        return True
    t = (frame_idx - phase) % period
    on_frames = int(round(period * duty))
    return t < on_frames


def draw_blink_dot(img, on):
    if not on:
        return
    x, y, s = BLINK_DOT
    overlay = Image.new("RGBA", img.size, (0, 0, 0, 0))
    d = ImageDraw.Draw(overlay)
    d.rectangle((x, y, x + s, y + s), fill=BLINK_COLOR + (255,))
    img.alpha_composite(overlay)


def apply_global_effects(img, frame_idx):
    # Put all persistent per-frame overlays here (e.g., blinking LED)
    draw_blink_dot(img, blink_cycle(frame_idx))


def main():
    ensure_clear_dir(OUTPUT_DIR)
    base = Image.open(SOURCE_IMAGE).convert("RGBA")

    frame = 0

    # --------------------
    # PHASE 1: DARKNESS (3 frames)
    # --------------------
    for _ in range(3):
        img = Image.new("RGBA", base.size, (14, 22, 36))
        save_frame(img, frame)
        frame += 1

    # --------------------
    # PHASE 2: CRT IGNITION
    # --------------------
    # Frame 4: monitor but dark screen
    img = base.copy()
    fill_screen(img, FLICKER_SCREEN_BOX, BLUE_DARK)
    save_frame(img, frame)
    frame += 1

    # Frame 5: small glow
    img = base.copy()
    fill_screen(img, FLICKER_SCREEN_BOX, BLUE_DARK)
    draw_center_glow(img, SCREEN_BOX, radius=6, color=BLUE_FLASH)
    apply_global_effects(img, frame)
    save_frame(img, frame)
    frame += 1

    # Frame 6: bigger glow
    img = base.copy()
    fill_screen(img, FLICKER_SCREEN_BOX, BLUE_DARK)
    draw_center_glow(img, SCREEN_BOX, radius=20, color=BLUE_FLASH)
    apply_global_effects(img, frame)
    save_frame(img, frame)
    frame += 1

    # --------------------
    # PHASE 3: FULL LIGHT + FLICKER
    # --------------------
    # Frame 7 – bright fill
    img = base.copy()
    fill_screen(img, SCREEN_BOX, BLUE_FLASH)
    apply_global_effects(img, frame)
    save_frame(img, frame)
    frame += 1

    # Frame 8 – normal
    img = base.copy()
    fill_screen(img, SCREEN_BOX, BLUE_NORMAL)
    apply_global_effects(img, frame)
    save_frame(img, frame)
    frame += 1

    # Frame 9 – flicker
    img = base.copy()
    fill_screen(img, SCREEN_BOX, BLUE_FLASH)
    apply_global_effects(img, frame)
    save_frame(img, frame)
    frame += 1

    # --------------------
    # PHASE 4: LED LOOP (15 frames)
    # --------------------
    for i in range(15):
        img = base.copy()
        apply_global_effects(img, frame)
        save_frame(img, frame)
        frame += 1

    print("Done. Frames saved to:", OUTPUT_DIR)

if __name__ == "__main__":
    main()
```