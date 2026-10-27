"""Independent checks for the GAME BMP atlas and its FAT16 card layout."""

from __future__ import annotations

import hashlib
import io
import struct
import sys
import unittest
from pathlib import Path

from PIL import Image


ROOT = Path(__file__).resolve().parents[1]
sys.path.insert(0, str(ROOT / "script"))
from make_sd_image import CLUSTER_BYTES, DATA_LBA, PARTITION_LBA, FAT_SECTORS, make_image, validate_bmp
from pack_game_assets import (DEFAULT_SOURCE, OPAQUE_PALETTE, PAGE_SIZES,
                              SIGNATURE, TILES, TRANSPARENT, build,
                              read_graphics, source_tiles)


class GameAssetTests(unittest.TestCase):
    @classmethod
    def setUpClass(cls) -> None:
        cls.pages, cls.manifest, cls.header = build(DEFAULT_SOURCE)

    def test_source_crops_match_graphics_index(self) -> None:
        tiles, entries = source_tiles(DEFAULT_SOURCE)
        self.assertEqual(len(tiles), 85)
        self.assertEqual(entries[7]["graphics_type"], "Small_mario")
        self.assertEqual(entries[7]["crop"], [176, 32, 16, 16])
        self.assertEqual(entries[11]["crop"], [0, 4, 16, 16])
        self.assertEqual(entries[78]["graphics_type"], "Mushroom")
        self.assertEqual(entries[78]["crop"], [16, 0, 16, 16])
        self.assertEqual(entries[81]["crop"], [90, 0, 16, 16])
        self.assertEqual(entries[83]["crop"], [360, 4, 16, 16])
        for entry in entries[1:]:
            source = Image.open(DEFAULT_SOURCE / entry["source"]).convert("RGBA")
            x, y, w, h = entry["crop"]
            crop = source.crop((x, y, x + w, y + h))
            if entry.get("sky_transparency"):
                crop.putdata([(r, g, b, 0 if (r, g, b) == (107, 140, 255) else a)
                              for r, g, b, a in crop.getdata()])
            self.assertEqual(hashlib.sha256(crop.tobytes()).hexdigest(), entry["sha256_rgba"])

    def test_fire_palette_matches_source_frames(self) -> None:
        specs = read_graphics(DEFAULT_SOURCE)
        palette = [TRANSPARENT, *OPAQUE_PALETTE]

        def index(pixel: tuple[int, int, int, int]) -> int:
            if pixel[3] < 128:
                return 0
            return min(range(1, len(palette)), key=lambda candidate:
                       sum((channel - target) ** 2
                           for channel, target in zip(pixel[:3], palette[candidate])))

        source = Image.open(specs["Big_mario"][0]).convert("RGBA")
        for frame in (0, 1, 4, 5, 6):
            frames = []
            for name in ("Big_mario", "Fire_mario"):
                _, x, y, width, height, _, _, _, step = specs[name]
                frames.append([index(source.getpixel((x + frame * step + u, y + v)))
                               for v in range(height) for u in range(width)])
            self.assertEqual([{6: 3, 9: 6}.get(color, color) for color in frames[0]],
                             frames[1], f"fire palette frame {frame}")

    def test_bmp_region_palette_and_bottom_up_order(self) -> None:
        self.assertEqual(len(self.pages), 6)
        self.assertEqual(self.manifest["format"], "game-atlas-bmp-v2")
        self.assertEqual("".join(chr(rgb[0]) for rgb in self.manifest["signature"]["rgb"]),
                         "GAME_ATLAS_V2!@#")
        self.assertEqual(self.manifest["preview_pages"][0], "atlas.bmp")
        self.assertEqual(self.manifest["atlas_region"], [0, 0, 128, 256])
        colors = {tuple(rgb) for rgb in self.manifest["palette"]}
        self.assertEqual(tuple(self.manifest["palette"][0]), TRANSPARENT)
        self.assertEqual(len(colors), 16)
        atlas = self.pages[0]
        self.assertEqual(atlas.size, (640, 480))
        self.assertEqual(atlas.getpixel((0, 0)), TRANSPARENT)
        self.assertEqual(atlas.getpixel((0, 16)), TRANSPARENT)
        self.assertEqual(hashlib.sha256(atlas.crop((0, 0, 128, 256)).tobytes()).hexdigest(),
                         "45676da60da3dfb29b4622acc14e06d05fdf803c62182a47dd416f20650f640b")
        self.assertEqual(tuple(atlas.getpixel((x, 0)) for x in range(128, 144)), SIGNATURE)
        for y in range(256):
            for x in range(128):
                self.assertIn(atlas.getpixel((x, y)), colors)
        self.assertEqual(self.manifest["preview_sizes"], [list(size) for size in PAGE_SIZES])
        for page, size in zip(self.pages, PAGE_SIZES):
            with io.BytesIO() as buffer:
                page.save(buffer, format="BMP")
                raw = buffer.getvalue()
            validate_bmp(raw)
            self.assertEqual(page.size, size)
            self.assertEqual(struct.unpack_from("<ii", raw, 18), size)
            w, h = size
            stride = (w * 3 + 3) & ~3
            self.assertEqual(raw[54:57], bytes(reversed(page.getpixel((0, h - 1)))))
            self.assertEqual(raw[54 + (h - 1) * stride:54 + (h - 1) * stride + 3],
                             bytes(reversed(page.getpixel((0, 0)))))
            if page is atlas:
                for x, rgb in enumerate(SIGNATURE, 128):
                    start = 54 + 479 * 1920 + x * 3
                    self.assertEqual(raw[start:start + 3], bytes(reversed(rgb)))

    def test_generated_files_match_source_and_include_real_scaling_inputs(self) -> None:
        import json
        self.assertEqual(json.loads((ROOT / "assets/game/manifest.json").read_text()), self.manifest)
        self.assertEqual((ROOT / "src/game/game_assets.vh").read_text(), self.header)
        for page, name in zip(self.pages, self.manifest["preview_pages"]):
            with Image.open(ROOT / "assets/game" / name) as stored:
                self.assertEqual(stored.size, page.size)
                self.assertEqual(stored.tobytes(), page.tobytes())
        self.assertTrue(any(w < 640 for w, h in PAGE_SIZES))
        self.assertTrue(any(w > 640 for w, h in PAGE_SIZES))
        self.assertTrue(any(w * 3 % 4 for w, h in PAGE_SIZES))

    def test_tile_ids_and_palette_match_rtl_header(self) -> None:
        for tile_id, (name, _, _, _) in enumerate(TILES):
            self.assertIn(f"`define GAME_TILE_{name} 7'd{tile_id}\n", self.header)
        for index, (r, g, b) in enumerate(self.manifest["palette"]):
            self.assertIn(f"`define GAME_PAL_{index} 24'h{r:02x}{g:02x}{b:02x}\n", self.header)
        for index, (r, g, b) in enumerate(SIGNATURE):
            self.assertIn(f"`define GAME_SIG_{index} 24'h{r:02x}{g:02x}{b:02x}\n", self.header)
        self.assertEqual(len(self.manifest["palette"]), 16)

    def test_card_image_has_atlas_first_then_five_debug_pages(self) -> None:
        images = []
        for page in self.pages:
            with io.BytesIO() as buffer:
                page.save(buffer, format="BMP")
                images.append(buffer.getvalue())
        card = make_image(images)
        root = (PARTITION_LBA + 1 + 2 * FAT_SECTORS) * 512
        for index, expected in enumerate(images):
            entry = card[root + 32 * index:root + 32 * (index + 1)]
            self.assertEqual(entry[:11], f"PIC{index+1:05d}BMP".encode())
            cluster, size = struct.unpack_from("<HI", entry, 26)
            start = DATA_LBA * 512 + (cluster - 2) * CLUSTER_BYTES
            self.assertEqual(size, len(expected))
            self.assertEqual(card[start:start + size], expected)
        self.assertEqual(card[root + 6 * 32:root + 6 * 32 + 11], b"FPGAEND BIN")


if __name__ == "__main__":
    unittest.main()
