#!/usr/bin/env python3
"""Generate the gray-box textures under assets/textures/.

Placeholder art, generated so it is reproducible and reviewable as a diff.
Real art will replace these files in place; nothing in code assumes they are
generated. Run: python3 tools/gen_textures.py
"""
from pathlib import Path
from PIL import Image, ImageDraw

OUT = Path(__file__).resolve().parent.parent / "assets" / "textures"
SIZE = 512


def hull_panels() -> Image.Image:
    """Panelled hull plating: readable at a glance, obvious that it is a placeholder."""
    img = Image.new("RGB", (SIZE, SIZE), (74, 82, 92))
    d = ImageDraw.Draw(img)
    step = SIZE // 8
    for gy in range(8):
        for gx in range(8):
            shade = 8 if (gx + gy) % 2 == 0 else -8
            x0, y0 = gx * step, gy * step
            d.rectangle([x0 + 2, y0 + 2, x0 + step - 3, y0 + step - 3],
                        fill=(74 + shade, 82 + shade, 92 + shade))
    # Sparse hazard stripes: enough that rotation reads without lighting cues,
    # sparse enough that the silhouette still does the talking.
    for i in range(0, SIZE * 2, 128):
        d.line([(i, 0), (i - SIZE, SIZE)], fill=(150, 118, 48), width=5)
    # Orientation marks: bright at the top edge, dim at the bottom.
    d.rectangle([0, 0, SIZE - 1, 10], fill=(210, 226, 240))
    d.rectangle([0, SIZE - 11, SIZE - 1, SIZE - 1], fill=(28, 32, 38))
    return img


def main() -> None:
    OUT.mkdir(parents=True, exist_ok=True)
    path = OUT / "hull_panels.png"
    hull_panels().save(path, optimize=True)
    print(f"wrote {path} ({path.stat().st_size} bytes)")


if __name__ == "__main__":
    main()
