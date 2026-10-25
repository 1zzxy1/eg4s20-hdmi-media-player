"""Deployment compatibility faults: stale builds and playable-but-silent cards."""
from pathlib import Path
import copy
import hashlib
import json
import struct
import subprocess
import sys
import tempfile
import unittest

ROOT = Path(__file__).resolve().parents[1]
sys.path.insert(0, str(ROOT / 'script'))
from check_deployment import check_build, check_media
from make_sd_image import make_image
from pack_game_audio import make_pack
from build_td_gui import sync_project_sources


class GuiProjectTests(unittest.TestCase):
    def test_reactivated_ip_clears_stale_auto_exclusion(self):
        with tempfile.TemporaryDirectory(prefix='td-project-') as directory:
            project=Path(directory)/'media_player.al'
            project.write_text('<Project><Source_Files><Verilog>'
                '<File Path="core.v"><FileInfo><Attr Name="AutoExcluded" Val="true"/>'
                '<Attr Name="UsedInSyn" Val="true"/></FileInfo></File>'
                '<File Path="other.v"><FileInfo><Attr Name="AutoExcluded" Val="true"/>'
                '</FileInfo></File></Verilog></Source_Files>'
                '<Runs><Run Name="phy_1"/></Runs></Project>',encoding='utf-8')
            sync_project_sources(project,Path(directory)/'stage',[Path('core.v')])
            import xml.etree.ElementTree as ET
            saved=ET.parse(project)
            nodes=saved.findall('Source_Files/Verilog/File')
            self.assertIsNone(nodes[0].find('FileInfo/Attr[@Name="AutoExcluded"]'))
            self.assertEqual(nodes[0].find('FileInfo/Attr[@Name="UsedInSyn"]').get('Val'),'true')
            self.assertIsNotNone(nodes[1].find('FileInfo/Attr[@Name="AutoExcluded"]'))
            self.assertEqual(saved.find('Runs/Run').get('Name'),'phy_1')
            once=project.read_bytes()
            sync_project_sources(project,Path(directory)/'stage',[Path('core.v')])
            self.assertEqual(once,project.read_bytes())

    def test_missing_hdmi_sources_persist_without_losing_settings(self):
        with tempfile.TemporaryDirectory(prefix='td-project-') as directory:
            project=Path(directory)/'media_player.al'
            project.write_text('<Project><Source_Files><Verilog>'
                '<File Path="old.v"><FileInfo><Attr Name="UsedInP&R" Val="true"/>'
                '</FileInfo></File></Verilog></Source_Files>'
                '<HardWare><Device>EG4S20BG256</Device></HardWare>'
                '<Runs><Run Name="phy_1"/></Runs></Project>',encoding='utf-8')
            files=[Path(n) for n in ('old.v','game_hdmi_tx.v','game_hdmi_channel.v','game_hdmi_terc.v')]
            sync_project_sources(project,Path(directory)/'stage',files)
            once=project.read_bytes()
            sync_project_sources(project,Path(directory)/'stage',files)
            self.assertEqual(once,project.read_bytes())
            import xml.etree.ElementTree as ET
            saved=ET.parse(project)
            self.assertEqual(len(saved.findall('Source_Files/Verilog/File')),4)
            self.assertEqual(saved.findtext('HardWare/Device'),'EG4S20BG256')
            self.assertEqual(saved.find('Runs/Run').attrib['Name'],'phy_1')


def sha(data):
    return hashlib.sha256(data).hexdigest()


class BuildPairTests(unittest.TestCase):
    def setUp(self):
        self.temp = tempfile.TemporaryDirectory(prefix='build-pair-test-')
        self.addCleanup(self.temp.cleanup)
        self.stage = Path(self.temp.name) / 'stage'
        self.stage.mkdir()
        source = self.stage / 'design.v'
        source.write_bytes(b'module design; endmodule\n')
        self.expected = {source.name: sha(source.read_bytes())}
        self.bit = Path(self.temp.name) / 'design.bit'
        self.bit.write_bytes(b'accepted-test-bitstream')
        self.receipt = {'passed': True, 'native_gui_flow': True,
                        'timing_ns': {'SWNS': 1.0, 'HWNS': 0.01},
                        'sha256': sha(self.bit.read_bytes()),
                        'staged_source_sha256': self.expected.copy()}

    def check(self, receipt=None, expected=None):
        return check_build(self.receipt if receipt is None else receipt,
                           self.bit, self.stage, self.expected if expected is None else expected)

    def test_accepted_pair(self):
        self.assertEqual(self.check()['staged_files'], 1)

    def test_changed_or_added_source_requires_rebuild(self):
        for expected in ({'design.v': sha(b'new design')},
                         {**self.expected, 'extra.v': sha(b'extra')}, {}):
            with self.subTest(expected=expected), self.assertRaises(ValueError):
                self.check(expected=expected)

    def test_changed_missing_or_extra_gui_staging(self):
        source = self.stage / 'design.v'
        for action in ('changed', 'missing', 'extra'):
            with self.subTest(action=action):
                source.write_bytes(b'module design; endmodule\n')
                extra = self.stage / 'unexpected.v'
                if action == 'changed':
                    source.write_bytes(b'outdated GUI design')
                elif action == 'missing':
                    source.unlink()
                else:
                    extra.write_bytes(b'extra')
                with self.assertRaisesRegex(ValueError, 'GUI staging'):
                    self.check()

    def test_replaced_bitstream(self):
        self.bit.write_bytes(b'old-build-bitstream')
        with self.assertRaisesRegex(ValueError, 'Bitstream differs'):
            self.check()

    def test_failed_and_negative_build_receipts(self):
        for changes in ({'passed': False}, {'negative_control': True},
                        {'native_gui_flow': False}, {'staged_source_sha256': None}):
            with self.subTest(changes=changes), self.assertRaises(ValueError):
                self.check(receipt={**self.receipt, **changes})

    def test_missing_negative_and_nonfinite_timing(self):
        for name in ('SWNS', 'HWNS'):
            for value in (None, -0.001, float('nan'), float('inf'), True):
                receipt = copy.deepcopy(self.receipt)
                receipt['timing_ns'][name] = value
                with self.subTest(name=name, value=value), self.assertRaisesRegex(ValueError, 'timing'):
                    self.check(receipt=receipt)


class MediaPairTests(unittest.TestCase):
    def setUp(self):
        self.temp = tempfile.TemporaryDirectory(prefix='media-pair-test-')
        self.addCleanup(self.temp.cleanup)
        directory = Path(self.temp.name)
        self.game, self.audio = directory / 'game', directory / 'audio'
        self.game.mkdir()
        self.audio.mkdir()
        # Use the actual native atlas; no upstream repository or image library
        # is needed to validate the deployed BMP bytes against the RTL header.
        self.atlas = (ROOT / 'assets/game/atlas.bmp').read_bytes()
        self.header = (ROOT / 'src/game/game_assets.vh').read_text(encoding='ascii')
        (self.game / 'atlas.bmp').write_bytes(self.atlas)
        (self.game / 'manifest.json').write_text(json.dumps({'preview_pages': ['atlas.bmp']}))
        tracks = [struct.pack('<h', 123 + i) * (257 + i) for i in range(24)]
        self.pack = make_pack(tracks)
        (self.audio / 'AUDIO.PAK').write_bytes(self.pack)
        self.audio_manifest = {'sha256': sha(self.pack),
                               'tracks': [{'id': i, 'samples': len(pcm) // 2,
                                           'pcm_sha256': sha(pcm)} for i, pcm in enumerate(tracks)]}
        (self.audio / 'manifest.json').write_text(json.dumps(self.audio_manifest))
        self.image = directory / 'game.img'
        self.image.write_bytes(make_image([self.atlas], self.pack))

    def check(self):
        return check_media(self.image, self.game, self.audio, self.header)

    def test_current_native_atlas_and_audio(self):
        result = self.check()
        self.assertEqual(result['audio_tracks'], 24)
        self.assertEqual(result['images'], [{'file': 'atlas.bmp', 'size': [640, 480]}])

    def test_old_card_without_audio_is_rejected(self):
        self.image.write_bytes(make_image([self.atlas]))
        with self.assertRaisesRegex(ValueError, 'TF image does not match'):
            self.check()

    def test_corrupt_audio_directory_pcm_and_image_size(self):
        for fault in ('directory', 'pcm', 'truncated', 'trailing'):
            image = make_image([self.atlas], self.pack)
            if fault == 'directory':
                image[512 + 16] ^= 1
            elif fault == 'pcm':
                audio_lba = struct.unpack_from('<I', image, 512 + 16)[0]
                image[(audio_lba + 1) * 512] ^= 1
            elif fault == 'truncated':
                del image[-512:]
            else:
                image.extend(bytes(512))
            self.image.write_bytes(image)
            with self.subTest(fault=fault), self.assertRaisesRegex(ValueError, 'TF image does not match'):
                self.check()

    def test_bad_first_atlas_signature_and_palette(self):
        for x, color, error in ((128, b'\x00\x00\x00', 'signature'),
                                 (0, b'\x01\x02\x03', 'palette')):
            atlas = bytearray(self.atlas)
            offset = struct.unpack_from('<I', atlas, 10)[0] + 479 * 1920 + x * 3
            atlas[offset:offset + 3] = color
            (self.game / 'atlas.bmp').write_bytes(atlas)
            # Rebuild the card too: semantic atlas validation must catch a
            # self-consistent but unbootable pair, not just a hash mismatch.
            self.image.write_bytes(make_image([atlas], self.pack))
            with self.subTest(error=error), self.assertRaisesRegex(ValueError, error):
                self.check()

    def test_audio_track_manifest_mismatch(self):
        manifest = copy.deepcopy(self.audio_manifest)
        manifest['tracks'][7]['pcm_sha256'] = sha(b'wrong PCM')
        (self.audio / 'manifest.json').write_text(json.dumps(manifest))
        with self.assertRaisesRegex(ValueError, 'Audio track 7'):
            self.check()

    def test_cli_failure_is_nonzero_and_has_no_success(self):
        result = subprocess.run([sys.executable, str(ROOT / 'script/check_deployment.py'),
                                 '--image', str(Path(self.temp.name) / 'missing.img'), '--json'],
                                cwd=ROOT, capture_output=True, text=True)
        self.assertNotEqual(result.returncode, 0)
        response = json.loads(result.stdout)
        self.assertFalse(response['passed'])
        self.assertIn('regular .img file', response['error'])


if __name__ == '__main__':
    unittest.main()
