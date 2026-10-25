"""Convert Mario-master sprite crops into BMP pages for the existing TF loader.

The first image is a 640x480 RGB BMP. Its top-left 128x256 pixels hold
128 16x16 tiles in row-major order; magenta is transparent (palette index 0).
This tool reads source art but never modifies it or writes a physical card.
"""

from __future__ import annotations

import argparse
import hashlib
import json
import re
from pathlib import Path

from PIL import Image, ImageDraw


ROOT = Path(__file__).resolve().parents[1]
DEFAULT_SOURCE = ROOT.parent / "Mario-master"
TILE_SIZE = 16
TILE_COLUMNS = 8
TILE_COUNT = 128
TRANSPARENT = (255, 0, 255)
SIGNATURE = tuple((ord(char), 0xA5, ord(char) ^ 0x5A) for char in "GAME_ATLAS_V2!@#")
LEVEL_SKY = (107, 140, 255)
OPAQUE_PALETTE = [
    (0, 0, 0), (254, 254, 254), (247, 214, 181),
    (227, 157, 37), (231, 90, 16), (177, 52, 37),
    (156, 74, 0), (82, 33, 0), (106, 107, 4),
    (0, 173, 0), (16, 148, 0), (140, 214, 0),
    (173, 173, 173), (99, 99, 99), (57, 189, 255),
]
PAGE_SIZES = [(640, 480), (320, 240), (800, 600), (641, 479), (640, 480), (960, 720)]
INK, CYAN, GOLD = (246, 246, 240), (120, 203, 217), (246, 192, 87)


def pixel_text(page: Image.Image, xy: tuple[int, int], text: str,
               color: tuple[int, int, int] = INK, scale: int = 2) -> None:
    # Reuse the same original bitmap alphabet as the FPGA OSD, not a host font.
    font = dict(re.findall(r'"(.)":glyph=56\'h([0-9a-f]{14})',
                          (ROOT / "src/video/osd_font.v").read_text(encoding="ascii")))
    x0, y0 = xy
    if x0 + (len(text) * 6 - 1) * scale > page.width or y0 + 7 * scale > page.height:
        raise ValueError(f"Text outside page: {text}")
    draw = ImageDraw.Draw(page)
    for index, char in enumerate(text):
        if char == " ":
            continue
        if char not in font:
            raise ValueError(f"Unsupported OSD character: {char}")
        glyph = bytes.fromhex(font[char])
        for row, bits in enumerate(glyph):
            for col in range(5):
                if bits & (1 << (4 - col)):
                    x, y = x0 + (index * 6 + col) * scale, y0 + row * scale
                    draw.rectangle((x, y, x + scale - 1, y + scale - 1), fill=color)

# Names are consumed by the game RTL. The source frame positions come from
# graphics.txt, rather than from hand-copied pixel coordinates.
TILES = [
    ("EMPTY", None, 0, 0),
    ("GROUND", "Brick", 0, 0),
    ("BRICK", "Brick", 0, 1),
    ("QUESTION", "Question_Block", 0, 0),
    ("USED", "Question_Block", 0, 2),
    ("COIN", "Coin", 0, 0),
    ("FLAG", "Flag", 0, 0),
    ("PLAYER_IDLE", "Small_mario", 0, 6),
    ("PLAYER_RUN0", "Small_mario", 0, 0),
    ("PLAYER_RUN1", "Small_mario", 0, 1),
    ("PLAYER_JUMP", "Small_mario", 0, 4),
    ("ENEMY0", "Chestnut", 0, 0),
    ("ENEMY1", "Chestnut", 0, 1),
    ("AVATAR0", "Small_mario", 0, 6),
    ("AVATAR1", "Small_mario", 0, 0),
    ("AVATAR2", "Small_mario", 0, 1),
    ("AVATAR3", "Small_mario", 0, 2),
    ("AVATAR4", "Small_mario", 0, 3),
    ("AVATAR5", "Small_mario", 0, 4),
    ("AVATAR6", "Small_mario", 0, 5),
    ("AVATAR7", "Small_mario", 0, 7),
    ("PIPE_TL", "raw:tile_set.png", 128, 0),
    ("PIPE_TR", "raw:tile_set.png", 128, 16),
    ("PIPE_BL", "raw:tile_set.png", 144, 0),
    ("PIPE_BR", "raw:tile_set.png", 144, 16),
    ("STONE", "raw:tile_set.png", 64, 16),
    ("MUSHROOM", "Mushroom", 0, 0),
    ("BIG_IDLE_TOP", "Big_mario/TOP", 0, 6),
    ("BIG_IDLE_BOTTOM", "Big_mario/BOTTOM", 0, 6),
    ("BIG_RUN0_TOP", "Big_mario/TOP", 0, 0),
    ("BIG_RUN0_BOTTOM", "Big_mario/BOTTOM", 0, 0),
    ("BIG_RUN1_TOP", "Big_mario/TOP", 0, 1),
    ("BIG_RUN1_BOTTOM", "Big_mario/BOTTOM", 0, 1),
    ("BIG_JUMP_TOP", "Big_mario/TOP", 0, 4),
    ("BIG_JUMP_BOTTOM", "Big_mario/BOTTOM", 0, 4),
    ("BIG_CROUCH_TOP", "Big_mario/TOP", 0, 5),
    ("BIG_CROUCH_BOTTOM", "Big_mario/BOTTOM", 0, 5),
]
TILES += [(f"CASTLE_{row}{col}", "raw:level_1.png", 120 + row * 16, 3232 + col * 16)
          for row in range(5) for col in range(5)]
TILES += [(f"BUSH_{side}", "raw:level_1.png", 176, 2672 + col * 16)
          for col, side in enumerate(("L", "R"))]
TILES += [(f"CLOUD_{row}{col}", "raw:level_1.png", 16 + row * 16, 2608 + col * 16)
          for row in range(2) for col in range(2)]
TILES += [(f"HILL_{row}{col}", "raw:level_1.png", 160 + row * 16, 3072 + col * 16)
          for row in range(2) for col in range(4)]
TILES += [("FLAG_POLE_TOP", "Pole/TOP", 0, 0),
          ("FLAG_POLE_BODY", "Pole/BOTTOM", 0, 0)]
TILES += [("ONEUP", "Mushroom", 0, 1),
          ("STAR", "Star", 0, 0),
          ("FLOWER", "Flower", 0, 0),
          ("KOOPA_TOP", "Tortoise/TOP", 0, 0),
          ("KOOPA_BOTTOM", "Tortoise/BOTTOM", 0, 0),
          ("SHELL", "raw:smb_enemies_sheet.png", 4, 360),
          ("FIREBALL", "Mario_fire", 0, 0)]


def read_graphics(source: Path) -> dict[str, tuple[Path, int, int, int, int, int, int, int, int]]:
    specs = {}
    for line_no, line in enumerate((source / "graphics.txt").read_text(encoding="utf-8").splitlines(), 1):
        fields = line.split()
        if len(fields) != 10:
            raise ValueError(f"graphics.txt:{line_no}: expected 10 fields")
        path = source / fields[0]
        nums = tuple(map(int, fields[1:9]))
        name = fields[9]
        if name in specs or not path.is_file():
            raise ValueError(f"graphics.txt:{line_no}: duplicate type or missing image: {name}")
        specs[name] = (path, *nums)
    return specs


def source_tiles(source: Path) -> tuple[list[Image.Image], list[dict]]:
    specs = read_graphics(source)
    images: dict[Path, Image.Image] = {}
    tiles: list[Image.Image] = []
    manifest = []
    for tile_id, (name, group, row, col) in enumerate(TILES):
        if group is None:
            tiles.append(Image.new("RGBA", (TILE_SIZE, TILE_SIZE)))
            manifest.append({"id": tile_id, "name": name, "source": None})
            continue
        if group.startswith("raw:"):
            path = source / "resources/graphics" / group[4:]
            left, top, w, h = col, row, TILE_SIZE, TILE_SIZE
            mask_sky = path.name == "level_1.png"
            graphic_type = None
        else:
            graphic_type, _, half = group.partition("/")
            path, x, y, w, h, rows, row_step, cols, col_step = specs[graphic_type]
            if not (0 <= row < rows and 0 <= col < cols):
                raise ValueError(f"{name}: frame outside graphics.txt range")
            left, top = x + col * col_step, y + row * row_step
            if half:
                if half not in ("TOP", "BOTTOM") or w > TILE_SIZE or h not in (24, 32):
                    raise ValueError(f"{name}: expected a <=16x24 or 16x32 source frame")
                if h == 32:
                    top += 0 if half == "TOP" else TILE_SIZE
                    h = TILE_SIZE
                elif half == "BOTTOM":
                    top += TILE_SIZE
                    h = h - TILE_SIZE
                else:
                    h = TILE_SIZE
            if w > TILE_SIZE or h > TILE_SIZE:
                raise ValueError(f"{name}: frame exceeds {TILE_SIZE}x{TILE_SIZE}; split before use")
            mask_sky = False
        if path not in images:
            images[path] = Image.open(path).convert("RGBA")
        if left < 0 or top < 0 or left + w > images[path].width or top + h > images[path].height:
            raise ValueError(f"{name}: crop outside {path}")
        crop = images[path].crop((left, top, left + w, top + h))
        if mask_sky:
            crop.putdata([(r, g, b, 0 if (r, g, b) == LEVEL_SKY else a)
                          for r, g, b, a in crop.getdata()])
        tile = Image.new("RGBA", (TILE_SIZE, TILE_SIZE))
        tile.paste(crop, (0, TILE_SIZE - h))
        tiles.append(tile)
        manifest.append({
            "id": tile_id,
            "name": name,
            "source": path.relative_to(source).as_posix(),
            "graphics_type": graphic_type,
            "frame": [row, col],
            "crop": [left, top, w, h],
            "sha256_rgba": hashlib.sha256(crop.tobytes()).hexdigest(),
            "sky_transparency": mask_sky,
        })
    return tiles, manifest


def quantize_tiles(tiles: list[Image.Image]) -> tuple[Image.Image, list[tuple[int, int, int]]]:
    if len(tiles) > TILE_COUNT:
        raise ValueError("More than 128 tiles")
    sheet = Image.new("RGBA", (TILE_COLUMNS * TILE_SIZE, TILE_COUNT // TILE_COLUMNS * TILE_SIZE))
    for tile_id, tile in enumerate(tiles):
        sheet.paste(tile, ((tile_id % TILE_COLUMNS) * TILE_SIZE, (tile_id // TILE_COLUMNS) * TILE_SIZE))
    palette = [TRANSPARENT] + OPAQUE_PALETTE
    nearest: dict[tuple[int, int, int], int] = {}
    pixels = []
    for r, g, b, alpha in sheet.getdata():
        if alpha < 128:
            pixels.append(0)
        else:
            color = (r, g, b)
            if color not in nearest:
                nearest[color] = min(range(1, len(palette)), key=lambda index:
                                     sum((channel - match) ** 2
                                         for channel, match in zip(color, palette[index])))
            pixels.append(nearest[color])
    out = Image.new("RGB", sheet.size)
    out.putdata([palette[index] for index in pixels])
    return out, palette


def render_page(sheet: Image.Image, title: str, ids: list[int],
                size: tuple[int, int], number: int) -> Image.Image:
    page = Image.new("RGB", (640, 480), (20, 26, 39))
    draw = ImageDraw.Draw(page)
    draw.rectangle((8, 8, 631, 471), outline=CYAN, width=2)
    pixel_text(page, (24, 24), title, scale=3)
    pixel_text(page, (24, 56), f"0{number}/06  BMP {size[0]}X{size[1]} - HDMI 640X480", CYAN)
    draw.line((24, 84, 615, 84), fill=CYAN, width=2)
    columns = 4
    step_x, step_y = 148, 104
    for item, tile_id in enumerate(ids):
        crop = sheet.crop(((tile_id % TILE_COLUMNS) * TILE_SIZE,
                           (tile_id // TILE_COLUMNS) * TILE_SIZE,
                           (tile_id % TILE_COLUMNS + 1) * TILE_SIZE,
                           (tile_id // TILE_COLUMNS + 1) * TILE_SIZE))
        transparent = Image.new("L", crop.size, 255)
        transparent.putdata([0 if rgb == TRANSPARENT else 255 for rgb in crop.getdata()])
        x, y = 24 + item % columns * step_x, 98 + item // columns * step_y
        draw.rectangle((x, y, x + 139, y + 95), fill=(32, 43, 62), outline=(57, 75, 96))
        preview = crop.resize((64, 64), Image.Resampling.NEAREST)
        mask = transparent.resize(preview.size, Image.Resampling.NEAREST)
        page.paste(preview, (x + 8, y + 8), mask)
        pixel_text(page, (x + 96, y + 16), f"{tile_id:02d}", GOLD)
        pixel_text(page, (x + 6, y + 80), TILES[tile_id][0].replace("_", " ")[:11])
    pixel_text(page, (24, 422), "KEY2/3 PAGE  KEY4 AUTO / HOLD FULL", GOLD)
    pixel_text(page, (24, 448), "KEY1 MENU  DISPLAY FOR FX / OSD", CYAN)
    # The card carries actual mixed-size BMPs; the hardware performs the final
    # nearest-neighbour conversion. Never shrink or relabel the first atlas.
    return page.resize(size, Image.Resampling.NEAREST)


def build(source: Path) -> tuple[list[Image.Image], dict, str]:
    tiles, tile_manifest = source_tiles(source)
    sheet, palette = quantize_tiles(tiles)
    atlas = Image.new("RGB", (640, 480), (20, 26, 39))
    atlas.paste(sheet, (0, 0))
    for x, pixel in enumerate(SIGNATURE, 128):
        atlas.putpixel((x, 0), pixel)
    draw = ImageDraw.Draw(atlas)
    draw.rectangle((152, 24, 615, 248), outline=CYAN, width=2)
    pixel_text(atlas, (176, 44), "PIXEL QUEST", scale=4)
    pixel_text(atlas, (176, 92), "ASSET LAB / 01 OF 06", CYAN, scale=3)
    pixel_text(atlas, (176, 140), "85 ACTIVE / 128 TILE SLOTS", GOLD)
    pixel_text(atlas, (176, 170), "16 COLORS / 16X16 PIXELS", CYAN)
    pixel_text(atlas, (176, 210), "NATIVE BMP 640X480", scale=2)
    pixel_text(atlas, (24, 284), "ONE FPGA - TWO WAYS TO EXPLORE", CYAN, scale=3)
    for x, label, detail in [(24, "TF BMP", "READ"), (176, "SDRAM", "CACHE"),
                             (328, "TILES", "PLAY"), (480, "HDMI", "SHOW")]:
        draw.rectangle((x, 332, x + 135, 398), fill=(32, 43, 62), outline=CYAN)
        pixel_text(atlas, (x + 12, 344), label, GOLD)
        pixel_text(atlas, (x + 12, 374), detail)
    pixel_text(atlas, (24, 422), "KEY1 MENU - DEBUG FOR TF PREVIEW", GOLD)
    pixel_text(atlas, (24, 448), "KEY2/3 PAGE  KEY4 AUTO / HOLD FULL", CYAN)
    pages = [atlas,
             render_page(sheet, "PLAYER / ANIMATION", list(range(7, 11)) + list(range(27, 35)), PAGE_SIZES[1], 2),
             render_page(sheet, "WORLD / TERRAIN", list(range(21, 27)) + list(range(62, 68)), PAGE_SIZES[2], 3),
             render_page(sheet, "ENEMY / ITEMS", [11, 12, 5, 78, 79, 80, 81, 82, 83, 84], PAGE_SIZES[3], 4),
             render_page(sheet, "SELECT AVATAR", list(range(13, 21)), PAGE_SIZES[4], 5),
             render_page(sheet, "GAME MATERIAL INDEX", list(range(37, 45)) + list(range(68, 72)), PAGE_SIZES[5], 6)]
    manifest = {
        "format": "game-atlas-bmp-v2", "tile_size": TILE_SIZE,
        "atlas_columns": TILE_COLUMNS, "atlas_rows": TILE_COUNT // TILE_COLUMNS,
        "atlas_region": [0, 0, 128, 256],
        "bmp_size": [640, 480], "transparent_rgb": list(TRANSPARENT),
        "signature": {"x": 128, "y": 0, "rgb": [list(rgb) for rgb in SIGNATURE]},
        "palette": [list(color) for color in palette], "tiles": tile_manifest,
        "preview_pages": ["atlas.bmp"] + [f"preview_{i}.bmp" for i in range(1, 6)],
        "preview_sizes": [list(size) for size in PAGE_SIZES],
        "preview_font_source": "src/video/osd_font.v",
        "source_project": "Mario-master",
        "source_license": "GPL-3.0 for source code; original art provenance requires review before public redistribution",
    }
    header = ["// Generated by script/pack_game_assets.py; do not edit.",
              "`ifndef GAME_ASSETS_VH", "`define GAME_ASSETS_VH"]
    header += [f"`define GAME_TILE_{name} 7'd{index}" for index, (name, _, _, _) in enumerate(TILES)]
    header += [f"`define GAME_PAL_{i} 24'h{r:02x}{g:02x}{b:02x}"
               for i, (r, g, b) in enumerate(palette)]
    header += [f"`define GAME_SIG_{i} 24'h{r:02x}{g:02x}{b:02x}"
               for i, (r, g, b) in enumerate(SIGNATURE)]
    header += ["`endif", ""]
    return pages, manifest, "\n".join(header)


def main() -> None:
    parser = argparse.ArgumentParser(description=__doc__)
    parser.add_argument("--source", type=Path, default=DEFAULT_SOURCE)
    parser.add_argument("--out", type=Path, default=ROOT / "assets/game")
    args = parser.parse_args()
    pages, manifest, header = build(args.source)
    args.out.mkdir(parents=True, exist_ok=True)
    for name, page in zip(manifest["preview_pages"], pages):
        page.save(args.out / name, format="BMP")
    (args.out / "manifest.json").write_text(json.dumps(manifest, indent=2) + "\n", encoding="utf-8")
    rtl_header = ROOT / "src/game/game_assets.vh"
    rtl_header.parent.mkdir(parents=True, exist_ok=True)
    rtl_header.write_text(header, encoding="ascii")
    print(f"Generated {len(pages)} BMP pages, {len(TILES)} active tiles, and {rtl_header}")


if __name__ == "__main__":
    main()
