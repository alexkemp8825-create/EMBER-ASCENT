#!/usr/bin/env python3
"""Validate sliced zombie parts and the registered variant table."""

from __future__ import annotations

import re
import sys
from pathlib import Path

from PIL import Image

ROOT = Path("/workspace")
PARTS = ROOT / "assets" / "zombies" / "parts"
LIBRARY = ROOT / "scripts" / "zombies" / "ZombieVisualLibrary.gd"

REQUIRED = ["head", "body", "left_hand", "right_hand", "left_foot", "right_foot"]
VARIANTS = ["office", "punk", "nurse", "forest", "pirate", "chef", "builder", "sleeping"]


def fail(message: str) -> None:
    print(f"FAIL: {message}")
    raise SystemExit(1)


def main() -> None:
    if not LIBRARY.exists():
        fail("ZombieVisualLibrary.gd is missing")
    library_text = LIBRARY.read_text(encoding="utf-8")
    for variant_id in VARIANTS:
        if f'"{variant_id}"' not in library_text:
            fail(f"{variant_id} is not registered")
        folder = PARTS / variant_id
        if not folder.is_dir():
            fail(f"missing parts folder {folder}")
        for part in REQUIRED:
            png = folder / f"{part}.png"
            if not png.exists():
                fail(f"missing {png}")
            image = Image.open(png)
            if image.size[0] < 8 or image.size[1] < 8:
                fail(f"{png} is too small: {image.size}")
            extrema = image.convert("RGBA").getextrema()
            if extrema[3][1] == 0:
                fail(f"{png} is fully transparent")
            path = f"res://assets/zombies/parts/{variant_id}/{part}.png"
            if path not in library_text:
                fail(f"{path} is not referenced by the library")

    # Hands should stay detached squares, not full torso strips.
    for variant_id in VARIANTS:
        for hand in ("left_hand", "right_hand"):
            image = Image.open(PARTS / variant_id / f"{hand}.png")
            w, h = image.size
            if w > 140 or h > 140:
                fail(f"{variant_id} {hand} looks like a torso strip: {image.size}")
            if max(w, h) / max(1, min(w, h)) > 2.2:
                fail(f"{variant_id} {hand} is not square enough: {image.size}")

    spawn_weights = re.findall(r'"spawn_weight":\s*([0-9.]+)', library_text)
    if len(spawn_weights) < 8:
        fail("expected spawn_weight on every variant")
    if any(float(value) <= 0 for value in spawn_weights):
        fail("spawn weights must be positive")

    print("OK: 8 variants, required parts, library paths, spawn weights")


if __name__ == "__main__":
    main()
