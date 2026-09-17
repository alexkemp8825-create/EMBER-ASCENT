#!/usr/bin/env python3
"""Slice modular zombie parts from the provided reference sheets."""

from __future__ import annotations

import json
import shutil
from collections import deque
from pathlib import Path

import numpy as np
from PIL import Image

WORKSPACE = Path("/workspace")
SHEET1 = Path(
    "/home/ubuntu/.cursor/projects/workspace/assets/"
    "4d4f990d817d72de9a97afb6ae6ce563bffd75b9aa9f478445e10da48717bee0.png"
)
SHEET2 = Path(
    "/home/ubuntu/.cursor/projects/workspace/assets/"
    "8b5ebfe06cb23357ad1d4259bfed8937718086308982d529e450e5685d0cc551.png"
)

OUT_ROOT = WORKSPACE / "assets" / "zombies"
SOURCE_DIR = OUT_ROOT / "source"
PARTS_DIR = OUT_ROOT / "parts"
PREVIEW_DIR = OUT_ROOT / "previews"

# Sheet-space split between floating head and body.
# Sheet 1 hands start ~501; sheet 2 hands start ~528.
VARIANTS = [
    {
        "id": "office",
        "display_name": "Office",
        "sheet": 1,
        "col": (37, 447),
        "head_body_split_y": 498,
        "hand_band": (501, 576),
        "has_detached_hands": True,
        "accessory_cut_y": None,
        "keep_hat_on_head": True,
    },
    {
        "id": "punk",
        "display_name": "Punk",
        "sheet": 1,
        "col": (485, 883),
        "head_body_split_y": 498,
        "hand_band": (501, 576),
        "has_detached_hands": True,
        "accessory_cut_y": None,
        "keep_hat_on_head": True,
    },
    {
        "id": "nurse",
        "display_name": "Nurse",
        "sheet": 1,
        "col": (906, 1296),
        "head_body_split_y": 498,
        "hand_band": (501, 576),
        "has_detached_hands": True,
        "accessory_cut_y": None,
        "keep_hat_on_head": True,
    },
    {
        "id": "forest",
        "display_name": "Forest",
        "sheet": 1,
        "col": (1337, 1738),
        "head_body_split_y": 498,
        "hand_band": (501, 576),
        "has_detached_hands": True,
        "accessory_cut_y": None,
        "keep_hat_on_head": True,
    },
    {
        "id": "pirate",
        "display_name": "Pirate",
        "sheet": 2,
        "col": (40, 463),
        "head_body_split_y": 518,
        "hand_band": (528, 607),
        "has_detached_hands": False,
        "accessory_cut_y": None,
        "keep_hat_on_head": True,
    },
    {
        "id": "chef",
        "display_name": "Chef",
        "sheet": 2,
        "col": (483, 869),
        "head_body_split_y": 518,
        "hand_band": (528, 607),
        "has_detached_hands": False,
        "accessory_cut_y": None,
        "keep_hat_on_head": True,
    },
    {
        "id": "builder",
        "display_name": "Builder",
        "sheet": 2,
        "col": (889, 1273),
        "head_body_split_y": 518,
        "hand_band": (528, 607),
        "has_detached_hands": False,
        "accessory_cut_y": None,
        "keep_hat_on_head": True,
    },
    {
        "id": "sleeping",
        "display_name": "Sleeping",
        "sheet": 2,
        "col": (1293, 1734),
        "head_body_split_y": 518,
        "hand_band": (528, 607),
        "has_detached_hands": False,
        "accessory_cut_y": None,
        "keep_hat_on_head": True,
    },
]


def load_rgba(path: Path) -> np.ndarray:
    return np.array(Image.open(path).convert("RGBA"))


def tight_bbox(mask: np.ndarray) -> tuple[int, int, int, int] | None:
    rows = np.any(mask, axis=1)
    cols = np.any(mask, axis=0)
    if not rows.any() or not cols.any():
        return None
    y0, y1 = np.where(rows)[0][[0, -1]]
    x0, x1 = np.where(cols)[0][[0, -1]]
    return int(x0), int(y0), int(x1), int(y1)


def crop_masked(arr: np.ndarray, mask: np.ndarray, pad: int = 1) -> tuple[Image.Image, dict]:
    bbox = tight_bbox(mask)
    if bbox is None:
        empty = Image.new("RGBA", (1, 1), (0, 0, 0, 0))
        return empty, {"bbox": None, "center": None, "size": [1, 1]}
    x0, y0, x1, y1 = bbox
    x0 = max(0, x0 - pad)
    y0 = max(0, y0 - pad)
    x1 = min(arr.shape[1] - 1, x1 + pad)
    y1 = min(arr.shape[0] - 1, y1 + pad)
    out = np.zeros((y1 - y0 + 1, x1 - x0 + 1, 4), dtype=np.uint8)
    local = mask[y0 : y1 + 1, x0 : x1 + 1]
    out[local] = arr[y0 : y1 + 1, x0 : x1 + 1][local]
    image = Image.fromarray(out, "RGBA")
    return image, {
        "bbox": [x0, y0, x1, y1],
        "center": [(x0 + x1) / 2.0, (y0 + y1) / 2.0],
        "size": [image.size[0], image.size[1]],
    }


def _dilate(mask: np.ndarray, radius: int) -> np.ndarray:
    if radius <= 0 or not mask.any():
        return mask
    h, w = mask.shape
    out = mask.copy()
    ys, xs = np.where(mask)
    for r in range(1, radius + 1):
        for dy in range(-r, r + 1):
            for dx in range(-r, r + 1):
                if dy * dy + dx * dx > r * r:
                    continue
                ny = ys + dy
                nx = xs + dx
                valid = (ny >= 0) & (ny < h) & (nx >= 0) & (nx < w)
                out[ny[valid], nx[valid]] = True
    return out


def _is_mint_skin(rgb: np.ndarray) -> np.ndarray:
    r = rgb[:, :, 0]
    g = rgb[:, :, 1]
    b = rgb[:, :, 2]
    # Mint/green zombie skin only — exclude blue pajamas and white cloth.
    return (
        (g > 175)
        & (r > 120)
        & (b > 140)
        & ((g.astype(np.int16) - r.astype(np.int16)) > 18)
        & (g + 5 >= b)
    )


def _extract_mint_hand(
    sheet: np.ndarray,
    body_head: np.ndarray,
    y0: int,
    y1: int,
    x0: int,
    x1: int,
) -> np.ndarray:
    region = np.zeros_like(body_head)
    x0 = max(0, x0)
    x1 = min(sheet.shape[1] - 1, x1)
    region[y0 : y1 + 1, x0 : x1 + 1] = body_head[y0 : y1 + 1, x0 : x1 + 1]
    rgb = sheet[:, :, :3].astype(np.int16)
    mint = region & _is_mint_skin(rgb)
    if not mint.any():
        return np.zeros_like(body_head)
    comps = connected_components(mint)
    core = max(comps, key=lambda comp: int(comp.sum()))
    padded = _dilate(core, 16)
    return padded & (sheet[:, :, 3] > 20)


def _keep_largest_component(mask: np.ndarray) -> np.ndarray:
    comps = connected_components(mask)
    if not comps:
        return mask
    return max(comps, key=lambda comp: int(comp.sum()))


def _clip_body_shoulders(body_mask: np.ndarray, hand_y0: int, hand_y1: int, x0: int, x1: int) -> np.ndarray:
    probe_y = min(body_mask.shape[0] - 1, hand_y1 + 12)
    xs = np.where(body_mask[probe_y, x0 : x1 + 1])[0]
    if len(xs) == 0:
        return body_mask
    torso_left = x0 + int(xs[0]) - 6
    torso_right = x0 + int(xs[-1]) + 6
    cleaned = body_mask.copy()
    band = cleaned[hand_y0 : hand_y1 + 1, :]
    band[:, : max(0, torso_left)] = False
    band[:, min(cleaned.shape[1], torso_right + 1) :] = False
    cleaned[hand_y0 : hand_y1 + 1, :] = band
    return cleaned


def _edge_seed(mask: np.ndarray, from_left: bool) -> tuple[int, int] | None:
    ys, xs = np.where(mask)
    if len(xs) == 0:
        return None
    pick = int(xs.argmin() if from_left else xs.argmax())
    return int(ys[pick]), int(xs[pick])


def find_face_pivot(head_img: Image.Image) -> list[float]:
    """Estimate the face/eye center inside a head texture."""
    arr = np.array(head_img)
    if arr.size == 0:
        return [head_img.size[0] / 2.0, head_img.size[1] / 2.0]
    rgb = arr[:, :, :3].astype(np.int16)
    alpha = arr[:, :, 3]
    # Eyes are near-black squares on mint skin.
    darkness = rgb.mean(axis=2)
    eye = (alpha > 80) & (darkness < 55) & (rgb[:, :, 0] < 70)
    bbox = tight_bbox(eye)
    if bbox is None:
        opaque = tight_bbox(alpha > 80)
        if opaque is None:
            return [head_img.size[0] / 2.0, head_img.size[1] * 0.62]
        x0, y0, x1, y1 = opaque
        return [(x0 + x1) / 2.0, y0 + (y1 - y0) * 0.62]
    x0, y0, x1, y1 = bbox
    return [(x0 + x1) / 2.0, (y0 + y1) / 2.0]


def flood_from(mask: np.ndarray, seeds: list[tuple[int, int]]) -> np.ndarray:
    h, w = mask.shape
    out = np.zeros_like(mask, dtype=bool)
    q = deque()
    for y, x in seeds:
        if 0 <= y < h and 0 <= x < w and mask[y, x] and not out[y, x]:
            out[y, x] = True
            q.append((y, x))
    while q:
        y, x = q.popleft()
        for ny, nx in ((y - 1, x), (y + 1, x), (y, x - 1), (y, x + 1)):
            if 0 <= ny < h and 0 <= nx < w and mask[ny, nx] and not out[ny, nx]:
                out[ny, nx] = True
                q.append((ny, nx))
    return out


def connected_components(mask: np.ndarray) -> list[np.ndarray]:
    h, w = mask.shape
    visited = np.zeros_like(mask, dtype=bool)
    comps: list[np.ndarray] = []
    for y in range(h):
        xs = np.where(mask[y] & ~visited[y])[0]
        for x in xs:
            if visited[y, x]:
                continue
            comp = flood_from(mask, [(y, int(x))])
            visited |= comp
            comps.append(comp)
    return comps


def write_png(image: Image.Image, path: Path) -> None:
    path.parent.mkdir(parents=True, exist_ok=True)
    image.save(path)
    write_import(path)


def write_import(png_path: Path) -> None:
    rel = png_path.as_posix()
    import_path = png_path.with_suffix(".png.import")
    import_path.write_text(
        "\n".join(
            [
                "[remap]",
                "",
                'importer="texture"',
                'type="CompressedTexture2D"',
                "",
                "[deps]",
                "",
                f'source_file="res://{png_path.relative_to(WORKSPACE).as_posix()}"',
                "",
                "[params]",
                "",
                "compress/mode=0",
                "mipmaps/generate=false",
                "process/fix_alpha_border=false",
                "process/premult_alpha=false",
                "detect_3d/compress_to=0",
                "",
            ]
        )
        + "\n",
        encoding="utf-8",
    )


def extract_variant(sheet: np.ndarray, spec: dict) -> dict:
    x0, x1 = spec["col"]
    split_y = spec["head_body_split_y"]
    hand_y0, hand_y1 = spec["hand_band"]
    opaque = sheet[:, :, 3] > 24

    col_mask = np.zeros_like(opaque, dtype=bool)
    col_mask[:, x0 : x1 + 1] = opaque[:, x0 : x1 + 1]

    comps = connected_components(col_mask)
    comps.sort(key=lambda m: tight_bbox(m)[2] - tight_bbox(m)[0] + tight_bbox(m)[3] - tight_bbox(m)[1], reverse=True)

    feet = []
    hands = []
    body_head = None
    for comp in comps:
        bbox = tight_bbox(comp)
        if bbox is None:
            continue
        cx = (bbox[0] + bbox[2]) / 2.0
        cy = (bbox[1] + bbox[3]) / 2.0
        w = bbox[2] - bbox[0] + 1
        h = bbox[3] - bbox[1] + 1
        area = int(comp.sum())
        if cy > 700 and area < 12000:
            feet.append((cx, comp))
        elif spec["has_detached_hands"] and hand_y0 - 10 <= cy <= hand_y1 + 10 and area < 12000:
            hands.append((cx, comp))
        elif area > 20000:
            body_head = comp

    if body_head is None:
        raise RuntimeError(f"No torso/head component for {spec['id']}")

    feet.sort(key=lambda item: item[0])
    hands.sort(key=lambda item: item[0])

    if not spec["has_detached_hands"] or len(hands) < 2:
        # Sheet 2 hands are visually detached squares but anti-aliased
        # fringes can bridge them to the torso. Isolate with side windows
        # so the shirt stays on the body sprite.
        left_hand = _extract_mint_hand(sheet, body_head, hand_y0, hand_y1, x0, x0 + 130)
        right_hand = _extract_mint_hand(sheet, body_head, hand_y0, hand_y1, x1 - 130, x1)
        body_head = body_head & ~left_hand & ~right_hand
        body_head = _clip_body_shoulders(body_head, split_y, hand_y1, x0, x1)
        hands = [(0.0, left_hand), (1.0, right_hand)]

    if len(feet) < 2:
        raise RuntimeError(f"Expected 2 feet for {spec['id']}, got {len(feet)}")
    if len(hands) < 2:
        raise RuntimeError(f"Expected 2 hands for {spec['id']}, got {len(hands)}")

    head_mask = body_head.copy()
    head_mask[split_y:, :] = False
    body_mask = body_head.copy()
    body_mask[:split_y, :] = False
    body_mask = _keep_largest_component(body_mask)
    head_mask = _keep_largest_component(head_mask)

    accessory_mask = np.zeros_like(head_mask)
    if spec["accessory_cut_y"] is not None and not spec["keep_hat_on_head"]:
        cut = spec["accessory_cut_y"]
        accessory_mask[:cut, :] = head_mask[:cut, :]
        # Keep a little skull overlap so the hat still sits on the head outline.
        keep_from = max(0, cut - 6)
        head_mask[:keep_from, :] = False
        # Remove accessory-only pixels that are clearly above the skull.
        head_mask[:cut, :] = head_mask[:cut, :] & ~accessory_mask[:cut, :]
        # Restore a thin contact band so the head is not decapitated.
        head_mask[keep_from:cut, :] = body_head[keep_from:cut, :]

    parts = {
        "head": crop_masked(sheet, head_mask),
        "body": crop_masked(sheet, body_mask),
        "left_hand": crop_masked(sheet, hands[0][1]),
        "right_hand": crop_masked(sheet, hands[1][1]),
        "left_foot": crop_masked(sheet, feet[0][1]),
        "right_foot": crop_masked(sheet, feet[1][1]),
    }
    if accessory_mask.any():
        parts["accessory"] = crop_masked(sheet, accessory_mask)
    else:
        parts["accessory"] = (Image.new("RGBA", (1, 1), (0, 0, 0, 0)), {"bbox": None, "center": None, "size": [1, 1]})

    return parts


def assemble_preview(parts: dict, canvas_size=(360, 520)) -> Image.Image:
    canvas = Image.new("RGBA", canvas_size, (255, 255, 255, 255))
    # Place using original sheet centers, normalized to body/feet.
    centers = {}
    for name, (_img, meta) in parts.items():
        if meta["center"] is not None:
            centers[name] = meta["center"]
    if "body" not in centers:
        return canvas
    origin_x = centers["body"][0]
    origin_y = centers.get("left_foot", centers["body"])[1] + 40
    scale = 0.55
    cx, cy = canvas_size[0] // 2, int(canvas_size[1] * 0.78)
    order = ["body", "left_foot", "right_foot", "left_hand", "right_hand", "head", "accessory"]
    for name in order:
        img, meta = parts[name]
        if meta["center"] is None or img.size == (1, 1):
            continue
        px = cx + int((meta["center"][0] - origin_x) * scale) - img.size[0] // 2
        py = cy + int((meta["center"][1] - origin_y) * scale) - img.size[1] // 2
        # Scale part for preview readability
        preview_img = img.resize(
            (max(1, int(img.size[0] * scale)), max(1, int(img.size[1] * scale))),
            Image.Resampling.NEAREST,
        )
        px = cx + int((meta["center"][0] - origin_x) * scale) - preview_img.size[0] // 2
        py = cy + int((meta["center"][1] - origin_y) * scale) - preview_img.size[1] // 2
        canvas.alpha_composite(preview_img, (px, py))
    return canvas


def assemble_shared_skeleton(parts: dict, office: dict, face_pivot, office_face) -> Image.Image:
    canvas = Image.new("RGBA", (360, 520), (255, 255, 255, 255))
    scale = 0.55
    body_c = office["body"][1]["center"]
    origin_x, origin_y = body_c[0], office["left_foot"][1]["center"][1] + 40
    cx, cy = 180, int(520 * 0.78)
    order = ["body", "left_foot", "right_foot", "left_hand", "right_hand", "head", "accessory"]
    for name in order:
        img, meta = parts[name]
        if meta["center"] is None or img.size == (1, 1):
            continue
        office_meta = office[name][1]
        if office_meta["center"] is None:
            slot = meta["center"]
        else:
            slot = office_meta["center"]
        preview_img = img.resize(
            (max(1, int(img.size[0] * scale)), max(1, int(img.size[1] * scale))),
            Image.Resampling.NEAREST,
        )
        if name == "head":
            # Place so the face pivot lands on the office face location.
            office_head_tl = (
                office["head"][1]["bbox"][0],
                office["head"][1]["bbox"][1],
            )
            office_face_sheet = (
                office_head_tl[0] + office_face[0],
                office_head_tl[1] + office_face[1],
            )
            px = cx + int((office_face_sheet[0] - origin_x) * scale) - int(face_pivot[0] * scale)
            py = cy + int((office_face_sheet[1] - origin_y) * scale) - int(face_pivot[1] * scale)
        elif name == "accessory":
            # Parent to head: sit above the shared face.
            office_head_tl = (
                office["head"][1]["bbox"][0],
                office["head"][1]["bbox"][1],
            )
            office_face_sheet = (
                office_head_tl[0] + office_face[0],
                office_head_tl[1] + office_face[1],
            )
            px = cx + int((office_face_sheet[0] - origin_x) * scale) - preview_img.size[0] // 2
            py = cy + int((office_face_sheet[1] - origin_y) * scale) - preview_img.size[1] + 8
        else:
            px = cx + int((slot[0] - origin_x) * scale) - preview_img.size[0] // 2
            py = cy + int((slot[1] - origin_y) * scale) - preview_img.size[1] // 2
        canvas.alpha_composite(preview_img, (px, py))
    return canvas


def compute_offsets(parts: dict, office_parts: dict) -> dict:
    """Offsets so this variant's face/body land on the office skeleton."""
    def center(p, key):
        return p[key][1]["center"]

    offsets = {
        "head_offset": [0, 0],
        "head_scale": [1.0, 1.0],
        "accessory_offset": [0, 0],
        "body_offset": [0, 0],
        "left_hand_offset": [0, 0],
        "right_hand_offset": [0, 0],
        "left_foot_offset": [0, 0],
        "right_foot_offset": [0, 0],
    }
    if office_parts is None:
        return offsets
    for key, field in (
        ("head", "head_offset"),
        ("body", "body_offset"),
        ("left_hand", "left_hand_offset"),
        ("right_hand", "right_hand_offset"),
        ("left_foot", "left_foot_offset"),
        ("right_foot", "right_foot_offset"),
        ("accessory", "accessory_offset"),
    ):
        a = center(parts, key) if parts[key][1]["center"] else None
        b = center(office_parts, key) if office_parts[key][1]["center"] else None
        if a and b:
            # Difference relative to body, then vs office's relative placement.
            a_body = center(parts, "body")
            b_body = center(office_parts, "body")
            rel_a = [a[0] - a_body[0], a[1] - a_body[1]]
            rel_b = [b[0] - b_body[0], b[1] - b_body[1]]
            # Convert sheet pixels into Visual-node pixels (sprites are stored 1:1,
            # then the whole Visual node is scaled). Only keep an offset when the
            # part's natural center would miss the shared skeleton slot.
            delta = [rel_a[0] - rel_b[0], rel_a[1] - rel_b[1]]
            if abs(delta[0]) >= 8 or abs(delta[1]) >= 8:
                offsets[field] = [round(delta[0], 1), round(delta[1], 1)]
    return offsets


def main() -> None:
    PARTS_DIR.mkdir(parents=True, exist_ok=True)
    PREVIEW_DIR.mkdir(parents=True, exist_ok=True)
    SOURCE_DIR.mkdir(parents=True, exist_ok=True)

    shutil.copy2(SHEET1, SOURCE_DIR / "sheet_office_punk_nurse_forest.png")
    shutil.copy2(SHEET2, SOURCE_DIR / "sheet_pirate_chef_builder_sleeping.png")
    write_import(SOURCE_DIR / "sheet_office_punk_nurse_forest.png")
    write_import(SOURCE_DIR / "sheet_pirate_chef_builder_sleeping.png")

    sheets = {1: load_rgba(SHEET1), 2: load_rgba(SHEET2)}
    extracted = {}
    metrics = {}
    for spec in VARIANTS:
        parts = extract_variant(sheets[spec["sheet"]], spec)
        extracted[spec["id"]] = parts
        dest = PARTS_DIR / spec["id"]
        if dest.exists():
            shutil.rmtree(dest)
        dest.mkdir(parents=True, exist_ok=True)
        part_meta = {}
        for name, (img, meta) in parts.items():
            if name == "accessory" and meta["bbox"] is None:
                continue
            write_png(img, dest / f"{name}.png")
            part_meta[name] = meta
        head_img = parts["head"][0]
        metrics[spec["id"]] = {
            "display_name": spec["display_name"],
            "parts": part_meta,
            "head_pivot": find_face_pivot(head_img),
        }

    office = extracted["office"]
    for spec in VARIANTS:
        metrics[spec["id"]]["offsets"] = compute_offsets(extracted[spec["id"]], office)

    # Shared skeleton positions from the office variant, origin at body center.
    body_c = office["body"][1]["center"]
    skeleton = {}
    for name in ("head", "body", "left_hand", "right_hand", "left_foot", "right_foot"):
        c = office[name][1]["center"]
        skeleton[name] = [round(c[0] - body_c[0], 1), round(c[1] - body_c[1], 1)]
    metrics["_skeleton"] = skeleton

    (OUT_ROOT / "variant_metrics.json").write_text(json.dumps(metrics, indent=2), encoding="utf-8")

    # Individual and lineup previews
    thumbs = []
    for spec in VARIANTS:
        preview = assemble_preview(extracted[spec["id"]])
        preview.save(PREVIEW_DIR / f"{spec['id']}.png")
        thumbs.append(preview)
    lineup = Image.new("RGBA", (360 * 4, 520 * 2), (255, 255, 255, 255))
    for i, thumb in enumerate(thumbs):
        lineup.paste(thumb, ((i % 4) * 360, (i // 4) * 520))
    lineup.save(PREVIEW_DIR / "lineup.png")

    # Shared-skeleton preview: every variant uses office node positions,
    # head placed by face pivot (what the Godot controller will do).
    shared = Image.new("RGBA", (360 * 4, 520 * 2), (255, 255, 255, 255))
    office_face = metrics["office"]["head_pivot"]
    office_head_center = office["head"][1]["center"]
    for i, spec in enumerate(VARIANTS):
        cell = assemble_shared_skeleton(
            extracted[spec["id"]],
            office,
            metrics[spec["id"]]["head_pivot"],
            office_face,
        )
        shared.paste(cell, ((i % 4) * 360, (i // 4) * 520))
    shared.save(PREVIEW_DIR / "shared_skeleton_lineup.png")
    print("sliced", list(extracted))
    print("skeleton", skeleton)


if __name__ == "__main__":
    main()
