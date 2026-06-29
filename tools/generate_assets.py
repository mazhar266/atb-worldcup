#!/usr/bin/env python3
"""Generate pixel-art image assets for ATB WorldCup.

Run from the project root with the asset venv activated:
    . .venv-assets/bin/activate
    python tools/generate_assets.py
"""

from __future__ import annotations

import math
import random
from pathlib import Path

from PIL import Image, ImageDraw

ROOT = Path(__file__).resolve().parent.parent
ASSETS = ROOT / "assets"
ASSETS.mkdir(exist_ok=True)


def save(img: Image.Image, name: str) -> None:
    path = ASSETS / name
    img.save(path, "PNG")
    print(f"saved {path.relative_to(ROOT)}")


def make_canvas(size: int, color: tuple[int, int, int, int] = (0, 0, 0, 0)) -> Image.Image:
    return Image.new("RGBA", (size, size), color)


def hex_to_rgba(hex_color: str, alpha: int = 255) -> tuple[int, int, int, int]:
    hex_color = hex_color.lstrip("#")
    return tuple(int(hex_color[i : i + 2], 16) for i in (0, 2, 4)) + (alpha,)


# ──────────────────────────────────────────────────────────────────────────────
# Ball
# ──────────────────────────────────────────────────────────────────────────────

def draw_ball(size: int = 32) -> Image.Image:
    """Classic top-down soccer ball."""
    img = make_canvas(size)
    draw = ImageDraw.Draw(img)
    cx = cy = size // 2
    radius = size // 2 - 2

    # Soft shadow
    shadow_r = radius + 2
    draw.ellipse(
        [cx - shadow_r + 2, cy - shadow_r + 3, cx + shadow_r + 2, cy + shadow_r + 3],
        fill=(0, 0, 0, 80),
    )

    # White ball body
    draw.ellipse(
        [cx - radius, cy - radius, cx + radius, cy + radius],
        fill=(250, 250, 240, 255),
        outline=(40, 40, 40, 255),
        width=2,
    )

    # Black patches (simplified truncated-icosahedron look)
    black = (30, 30, 30, 255)
    patch_r = radius * 0.32
    # Center patch
    draw.regular_polygon((cx, cy, patch_r), n_sides=5, rotation=0, fill=black)
    # Surrounding patches
    for i in range(5):
        angle = math.radians(i * 72 - 18)
        px = cx + math.cos(angle) * radius * 0.58
        py = cy + math.sin(angle) * radius * 0.58
        draw.regular_polygon((px, py, patch_r * 0.85), n_sides=5, rotation=math.degrees(angle) + 90, fill=black)

    return img


# ──────────────────────────────────────────────────────────────────────────────
# Player
# ──────────────────────────────────────────────────────────────────────────────

def draw_player(size: int, jersey: str, shorts: str) -> Image.Image:
    """Top-down player sprite with jersey, shorts and outline."""
    img = make_canvas(size)
    draw = ImageDraw.Draw(img)
    cx = cy = size // 2
    radius = size // 2 - 2

    # Shadow
    draw.ellipse(
        [cx - radius + 3, cy - radius + 4, cx + radius + 3, cy + radius + 4],
        fill=(0, 0, 0, 70),
    )

    # Shorts (slightly larger lower body)
    draw.ellipse(
        [cx - radius, cy - radius + 2, cx + radius, cy + radius],
        fill=hex_to_rgba(shorts),
        outline=(255, 255, 255, 200),
        width=2,
    )

    # Jersey (upper body)
    jersey_r = radius - 2
    draw.ellipse(
        [cx - jersey_r, cy - jersey_r - 1, cx + jersey_r, cy + jersey_r - 3],
        fill=hex_to_rgba(jersey),
        outline=(255, 255, 255, 220),
        width=2,
    )

    return img


def draw_team_sprites(team: str, jersey: str, shorts: str) -> None:
    """Generate three shade variants so substitutions are visible."""
    base = draw_player(32, jersey, shorts)

    # Shade variants for roster slots 1/2/3
    for idx, shade in enumerate([1.0, 0.88, 0.76], start=1):
        tinted = base.copy()
        # Apply a subtle darken overlay to distinguish squad members
        overlay = Image.new("RGBA", tinted.size, (0, 0, 0, int((1 - shade) * 120)))
        tinted = Image.alpha_composite(tinted, overlay)
        save(tinted, f"player_{team}_{idx}.png")


# ──────────────────────────────────────────────────────────────────────────────
# Field
# ──────────────────────────────────────────────────────────────────────────────

def draw_grass(width: int = 700, height: int = 480) -> Image.Image:
    """Tileable-ish grass field with subtle vertical stripes."""
    img = Image.new("RGBA", (width, height), hex_to_rgba("#228B22"))
    draw = ImageDraw.Draw(img)

    # Vertical mowing stripes
    stripe_w = 70
    for x in range(0, width, stripe_w * 2):
        draw.rectangle([x, 0, min(x + stripe_w, width), height], fill=(34, 139, 34, 40))

    # Sparse noise for texture
    random.seed(42)
    for _ in range(3000):
        px = random.randint(0, width - 1)
        py = random.randint(0, height - 1)
        img.putpixel((px, py), (
            40 + random.randint(-10, 10),
            150 + random.randint(-15, 15),
            40 + random.randint(-10, 10),
            30,
        ))

    return img


# ──────────────────────────────────────────────────────────────────────────────
# UI / Title
# ──────────────────────────────────────────────────────────────────────────────

def draw_title() -> Image.Image:
    """Simple title banner with a football pitch stripe motif."""
    width, height = 512, 96
    img = Image.new("RGBA", (width, height), (0, 0, 0, 0))
    draw = ImageDraw.Draw(img)

    # Banner background
    draw.rounded_rectangle([0, 0, width, height], radius=12, fill=(10, 40, 10, 230), outline=(255, 215, 0, 255), width=3)

    # Pitch stripes on banner
    stripe_h = 12
    for y in range(16, height - 16, stripe_h * 2):
        draw.rectangle([16, y, width - 16, y + stripe_h], fill=(34, 139, 34, 120))

    # Title text is rendered by LÖVE; this banner is just a decorative backing.
    return img


def main() -> None:
    save(draw_ball(32), "ball.png")
    draw_team_sprites("red", "#E32626", "#F0F0F0")
    draw_team_sprites("blue", "#2E5BFF", "#F0F0F0")
    save(draw_grass(), "grass.png")
    save(draw_title(), "title.png")
    print("Done.")


if __name__ == "__main__":
    main()
