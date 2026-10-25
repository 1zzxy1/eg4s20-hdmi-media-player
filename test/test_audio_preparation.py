"""Conservative action onset processing, including the real accepted pack."""
from pathlib import Path
import copy
import hashlib
import json
import struct
import subprocess
import sys
import tempfile
import unittest
import wave

ROOT = Path(__file__).resolve().parents[1]
sys.path.insert(0, str(ROOT / 'script'))
from pack_game_audio import RATE, TRACKS, validate_pack
from prepare_game_audio import ACTION_IDS, GUARD, LIMIT, THRESHOLD, leading_cut, prepare


def pcm(samples):
    return struct.pack('<' + 'h' * len(samples), *samples)


class OnsetTests(unittest.TestCase):
    def test_preserves_preroll_and_retained_samples(self):
        samples = [0] * 200 + [THRESHOLD, -THRESHOLD] * 20 + [7000, -8000] * 120
        raw = pcm(samples)
        cut = leading_cut(raw)
        self.assertEqual(cut, 240 - GUARD)
        self.assertEqual(struct.unpack_from('<h', raw, (cut + GUARD) * 2)[0], 7000)
        self.assertLessEqual(max(abs(x) for x in samples[:cut]), THRESHOLD)

    def test_immediate_negative_full_scale_is_not_silence(self):
        self.assertEqual(leading_cut(pcm([-32768] + [0] * 500)), 0)

    def test_no_onset_short_and_long_quiet_passages_remain(self):
        for samples in ([0] * 2000, [16] * 2000, [0] * 160 + [1000],
                        [0] * (LIMIT + GUARD + 1) + [3000] * 300):
            with self.subTest(length=len(samples)):
                self.assertEqual(leading_cut(pcm(samples)), 0)

    def test_cut_limit_and_invalid_pcm(self):
        self.assertEqual(leading_cut(pcm([0] * (LIMIT + GUARD) + [1000] * 100)), LIMIT)
        for raw in (b'', b'\x00'):
            with self.assertRaises(ValueError):
                leading_cut(raw)


class RealPackTests(unittest.TestCase):
    @classmethod
    def setUpClass(cls):
        cls.directory = ROOT / 'assets/audio'
        cls.pack = (cls.directory / 'AUDIO.PAK').read_bytes()
        cls.manifest = json.loads((cls.directory / 'manifest.json').read_text(encoding='utf-8'))

    def test_actual_waveforms_provenance_and_music_unchanged(self):
        candidate, manifest, tracks, cuts = prepare(self.pack, self.manifest)
        validate_pack(candidate)
        self.assertEqual(manifest['processing']['source_pack_sha256'], hashlib.sha256(self.pack).hexdigest())
        self.assertEqual(manifest['repository'], self.manifest['repository'])
        self.assertEqual(manifest['commit'], self.manifest['commit'])
        self.assertEqual(manifest['rights'], self.manifest['rights'])
        self.assertEqual(len(tracks), 24)
        changed = 0
        for index, ((name, _, _), processed, cut) in enumerate(zip(TRACKS, tracks, cuts)):
            with self.subTest(track=name):
                with wave.open(str(self.directory / f'{index:02}_{name}.wav'), 'rb') as audio:
                    self.assertEqual((audio.getframerate(), audio.getnchannels(), audio.getsampwidth()), (RATE, 1, 2))
                    original = audio.readframes(audio.getnframes())
                # Independent retained-waveform and discarded-level checks.
                self.assertEqual(processed, original[cut * 2:])
                self.assertGreater(len(processed), 0)
                self.assertLessEqual(cut, LIMIT)
                if cut:
                    changed += 1
                    self.assertIn(index, ACTION_IDS)
                    self.assertTrue(all(abs(s[0]) <= THRESHOLD for s in struct.iter_unpack('<h', original[:cut * 2])))
                    first_loud = next(i for i, (s,) in enumerate(struct.iter_unpack('<h', processed)) if abs(s) > THRESHOLD)
                    self.assertGreaterEqual(first_loud, GUARD)
                if index not in ACTION_IDS or index == 15:
                    self.assertEqual(cut, 0)
                    self.assertEqual(processed, original)
                for key in ('source_sha256', 'git_blob_sha1', 'upstream_path'):
                    self.assertEqual(manifest['tracks'][index][key], self.manifest['tracks'][index][key])
                raw_source = (self.directory / 'source' / f'{index:02}_{name}.mp3').read_bytes()
                self.assertEqual(manifest['tracks'][index]['source_sha256'], hashlib.sha256(raw_source).hexdigest())
                self.assertEqual(manifest['tracks'][index]['git_blob_sha1'],
                                 hashlib.sha1(b'blob ' + str(len(raw_source)).encode() + b'\0' + raw_source).hexdigest())
                self.assertEqual(manifest['tracks'][index]['input_pcm_sha256'], hashlib.sha256(original).hexdigest())
        self.assertGreater(changed, 0)
        self.assertEqual(prepare(self.pack, self.manifest)[:2], (candidate, manifest))
        self.assertNotIn('processing', self.manifest)

    def test_reject_corrupt_source_manifest_and_repeat_processing(self):
        for key, value in (('samples', 1), ('pcm_sha256', 'wrong'), ('id', 3), ('name', 'wrong')):
            manifest = copy.deepcopy(self.manifest)
            manifest['tracks'][1][key] = value
            with self.subTest(key=key), self.assertRaisesRegex(ValueError, 'track 1'):
                prepare(self.pack, manifest)
        with self.assertRaises(ValueError):
            prepare(self.pack[:-512], self.manifest)
        candidate, manifest, _, _ = prepare(self.pack, self.manifest)
        with self.assertRaisesRegex(ValueError, 'unprocessed'):
            prepare(candidate, manifest)

    def test_cli_outputs_wavs_and_refuses_overwrite(self):
        with tempfile.TemporaryDirectory(prefix='audio-onset-test-') as directory:
            target = Path(directory) / 'candidate'
            command = [sys.executable, str(ROOT / 'script/prepare_game_audio.py'),
                       '--output-directory', str(target)]
            result = subprocess.run(command, cwd=ROOT, capture_output=True, text=True)
            self.assertEqual(result.returncode, 0, result.stderr)
            candidate, manifest, tracks, _ = prepare(self.pack, self.manifest)
            self.assertEqual((target / 'AUDIO.PAK').read_bytes(), candidate)
            self.assertEqual(json.loads((target / 'manifest.json').read_text()), manifest)
            for index, (name, _, _) in enumerate(TRACKS):
                with wave.open(str(target / f'{index:02}_{name}.wav'), 'rb') as audio:
                    self.assertEqual(audio.readframes(audio.getnframes()), tracks[index])
            result = subprocess.run(command, cwd=ROOT, capture_output=True, text=True)
            self.assertNotEqual(result.returncode, 0)
            self.assertIn('Refusing to overwrite', result.stderr)
            self.assertEqual((target / 'AUDIO.PAK').read_bytes(), candidate)


if __name__ == '__main__':
    unittest.main()
