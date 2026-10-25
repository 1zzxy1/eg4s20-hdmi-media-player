"""Check FAT16 layout and scanner bounds for generated media images."""
from pathlib import Path
import subprocess
import struct
import sys
import tempfile
import unittest

sys.path.insert(0, str(Path(__file__).resolve().parents[1] / 'script'))
from make_sd_image import (CLUSTER_BYTES, DATA_LBA, END_MARKER, FAT_SECTORS,
                           PARTITION_LBA, ROOT_SECTORS, SCAN_LIMIT_BYTES,
                           VOLUME_SECTORS, demo_bmp, make_image)
from pack_game_audio import make_pack, validate_pack


def small_bmp():
    pixels = b'\x12\x34\x56\x00'
    return (struct.pack('<2sIHHI', b'BM', 58, 0, 0, 54) +
            struct.pack('<IiiHHIIiiII', 40, 1, 1, 1, 24, 0, len(pixels),
                        0, 0, 0, 0) + pixels)


class MediaImageTest(unittest.TestCase):
    def test_audio_directory_fat_and_pcm(self):
        tracks = [struct.pack('<h', index * 123 - 1000) * (257 + index) for index in range(24)]
        pack = make_pack(tracks)
        validate_pack(pack)
        image = make_image([small_bmp()], audio_pack=pack)
        root = (PARTITION_LBA + 1 + 2 * FAT_SECTORS) * 512
        marker = image[root + 32:root + 64]
        entry = image[root + 64:root + 96]
        self.assertEqual(marker[:11], b'FPGAEND BIN')
        self.assertEqual(entry[:11], b'AUDIO   PAK')
        cluster, size = struct.unpack_from('<HI', entry, 26)
        start = DATA_LBA * 512 + (cluster - 2) * CLUSTER_BYTES
        self.assertEqual(image[start:start + size], pack)
        directory = image[512:1024]
        expected = bytearray(pack[:512])
        struct.pack_into('<I', expected, 16, start // 512)
        self.assertEqual(directory, expected)
        fat_start = (PARTITION_LBA + 1) * 512
        count = (len(pack) + CLUSTER_BYTES - 1) // CLUSTER_BYTES
        for offset in range(count):
            self.assertEqual(struct.unpack_from('<H', image, fat_start + 2 * (cluster + offset))[0],
                             0xffff if offset == count - 1 else cluster + offset + 1)
        for index, pcm in enumerate(tracks):
            sector, samples, loop, ident, reserved = struct.unpack_from('<IIHHI', directory, 32 + index * 16)
            self.assertEqual((samples, loop, ident, reserved), (len(pcm) // 2, int(index == 0), index, 0))
            self.assertEqual(image[start + sector * 512:start + sector * 512 + len(pcm)], pcm)
        self.assertEqual(image[root + 96], 0)

    def test_reject_bad_audio_and_capacity(self):
        pack = make_pack([b'\x01\x02'] * 24)
        for offset, value in [(0, 0), (8, 0), (12, 23), (20, 0), (32, 0), (36, 0), (42, 99)]:
            bad = bytearray(pack)
            bad[offset] = value
            with self.subTest(offset=offset), self.assertRaises(ValueError):
                make_image([small_bmp()], audio_pack=bad)
        with self.assertRaises(ValueError):
            validate_pack(pack + bytes(512))
        with self.assertRaises(ValueError):
            make_pack([b'\x00'] * 24)
        # Four maximum-length PCM tracks already exceed the bounded image.
        large = make_pack([bytes((1 << 24) * 2 - 2)] * 4 + [b'\x00\x00'] * 20)
        with self.assertRaisesRegex(ValueError, 'Audio exceeds'):
            make_image([small_bmp()], audio_pack=large)

    def test_64_images_and_end_marker(self):
        bmp = small_bmp()
        image = make_image([bmp] * 64)
        self.assertEqual(len(image), (PARTITION_LBA + VOLUME_SECTORS) * 512)
        self.assertEqual(image[510:512], b'\x55\xaa')
        self.assertEqual(image[450], 6)
        self.assertEqual(struct.unpack_from('<II', image, 454),
                         (PARTITION_LBA, VOLUME_SECTORS))
        boot = PARTITION_LBA * 512
        self.assertEqual(image[boot + 510:boot + 512], b'\x55\xaa')
        self.assertEqual(struct.unpack_from('<H', image, boot + 11)[0], 512)
        self.assertEqual(image[boot + 13], CLUSTER_BYTES // 512)
        self.assertEqual(struct.unpack_from('<H', image, boot + 17)[0], 512)

        fat_lba = PARTITION_LBA + 1
        fat = image[fat_lba * 512:(fat_lba + FAT_SECTORS) * 512]
        self.assertEqual(fat, image[(fat_lba + FAT_SECTORS) * 512:
                                    (fat_lba + 2 * FAT_SECTORS) * 512])
        root = (fat_lba + 2 * FAT_SECTORS) * 512
        self.assertEqual(root + ROOT_SECTORS * 512, DATA_LBA * 512)
        for index in range(64):
            entry = image[root + index * 32:root + (index + 1) * 32]
            self.assertEqual(entry[:11], f'PIC{index + 1:05d}BMP'.encode())
            cluster, size = struct.unpack_from('<HI', entry, 26)
            self.assertEqual((cluster, size), (index + 2, len(bmp)))
            self.assertEqual(struct.unpack_from('<H', fat, cluster * 2)[0], 0xffff)
            start = DATA_LBA * 512 + (cluster - 2) * CLUSTER_BYTES
            self.assertEqual(image[start:start + size], bmp)

        entry = image[root + 64 * 32:root + 65 * 32]
        self.assertEqual(entry[:11], b'FPGAEND BIN')
        self.assertEqual(entry[11], 0x20)
        marker_cluster, marker_size = struct.unpack_from('<HI', entry, 26)
        self.assertEqual((marker_cluster, marker_size), (66, 16))
        self.assertEqual(struct.unpack_from('<H', fat, marker_cluster * 2)[0], 0xffff)
        marker_start = DATA_LBA * 512 + (marker_cluster - 2) * CLUSTER_BYTES
        self.assertEqual(image[marker_start:marker_start + marker_size], END_MARKER)
        self.assertEqual(image[marker_start + marker_size:marker_start + CLUSTER_BYTES],
                         bytes(CLUSTER_BYTES - marker_size))
        self.assertLessEqual(marker_start + CLUSTER_BYTES, SCAN_LIMIT_BYTES)
        self.assertEqual(image[root + 65 * 32], 0)

    def test_demo_dimensions_repeat(self):
        for index, size in [(0, (640, 480)), (1, (320, 240)),
                            (2, (800, 600)), (3, (641, 479)),
                            (4, (640, 480)), (5, (320, 240))]:
            self.assertEqual(struct.unpack_from('<ii', demo_bmp(index), 18), size)

    def test_large_images_respect_scan_window(self):
        large = demo_bmp(0, native=True)
        # Maximum legal dimensions make the capacity boundary deterministic.
        header = bytearray(large[:54])
        width, height = 1920, 1440
        size = 54 + width * height * 3
        struct.pack_into('<I', header, 2, size)
        struct.pack_into('<ii', header, 18, width, height)
        struct.pack_into('<I', header, 34, size - 54)
        large = bytes(header) + bytes(size - 54)
        image = make_image([large] * 7)
        self.assertEqual(len(image), (PARTITION_LBA + VOLUME_SECTORS) * 512)
        fat = image[(PARTITION_LBA + 1) * 512:
                    (PARTITION_LBA + 1 + FAT_SECTORS) * 512]
        root = (PARTITION_LBA + 1 + 2 * FAT_SECTORS) * 512
        next_cluster = 2
        clusters_per_bmp = (size + CLUSTER_BYTES - 1) // CLUSTER_BYTES
        for index in range(7):
            entry = image[root + index * 32:root + (index + 1) * 32]
            cluster, file_size = struct.unpack_from('<HI', entry, 26)
            self.assertEqual((cluster, file_size), (next_cluster, size))
            for offset in range(clusters_per_bmp - 1):
                self.assertEqual(struct.unpack_from('<H', fat, (cluster + offset) * 2)[0],
                                 cluster + offset + 1)
            self.assertEqual(struct.unpack_from('<H', fat,
                                                (cluster + clusters_per_bmp - 1) * 2)[0],
                             0xffff)
            next_cluster += clusters_per_bmp
        marker = image[root + 7 * 32:root + 8 * 32]
        self.assertEqual(struct.unpack_from('<HI', marker, 26), (next_cluster, 16))
        marker_start = DATA_LBA * 512 + (next_cluster - 2) * CLUSTER_BYTES
        self.assertEqual(image[marker_start:marker_start + 16], END_MARKER)
        with self.assertRaisesRegex(ValueError, 'scanner/card data range|end marker'):
            make_image([large] * 8)

    def test_reject_invalid_counts(self):
        bmp = small_bmp()
        for count in (0, 65):
            with self.subTest(count=count), self.assertRaisesRegex(ValueError, '1..64'):
                make_image([bmp] * count)
            with self.subTest(cli_count=count), tempfile.TemporaryDirectory() as directory:
                output = Path(directory) / 'invalid.img'
                result = subprocess.run([sys.executable,
                                         str(Path(__file__).resolve().parents[1] /
                                             'script' / 'make_sd_image.py'),
                                         str(output), '--count', str(count)],
                                        capture_output=True, text=True)
                self.assertNotEqual(result.returncode, 0)
                self.assertIn('Count must be 1..64', result.stderr)
                self.assertFalse(output.exists())

    def test_end_marker_after_cluster_aligned_bmp(self):
        bmp = bytearray(small_bmp())
        offset = CLUSTER_BYTES - 4
        struct.pack_into('<I', bmp, 2, CLUSTER_BYTES)
        struct.pack_into('<I', bmp, 10, offset)
        bmp = bytes(bmp[:54]) + bytes(offset - 54) + bytes(bmp[54:])
        image = make_image([bmp])
        root = (PARTITION_LBA + 1 + 2 * FAT_SECTORS) * 512
        self.assertEqual(struct.unpack_from('<HI', image, root + 32 + 26), (3, 16))
        self.assertEqual(image[DATA_LBA * 512 + CLUSTER_BYTES:
                               DATA_LBA * 512 + CLUSTER_BYTES + 16], END_MARKER)


if __name__ == '__main__':
    unittest.main()
