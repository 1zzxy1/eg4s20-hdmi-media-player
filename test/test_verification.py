"""Exercise acceptance receipts with real child processes and changing inputs."""
from pathlib import Path
import hashlib
import json
import sys
import tempfile
import unittest
from unittest.mock import patch

ROOT = Path(__file__).resolve().parents[1]
sys.path.insert(0, str(ROOT / 'script'))
from verify import run_suites, source_hashes


class VerificationTests(unittest.TestCase):
    def setUp(self):
        self.temp = tempfile.TemporaryDirectory(prefix='verification-test-')
        self.addCleanup(self.temp.cleanup)
        self.root = Path(self.temp.name)
        for directory in ('src', 'script', 'assets', 'build/verification'):
            (self.root / directory).mkdir(parents=True)
        self.source = self.root / 'src/design.v'
        self.source.write_text('module design; endmodule\n', encoding='ascii')
        self.asset = self.root / 'assets/audio.pcm'
        self.asset.write_bytes(b'\x00\x01')
        self.out = self.root / 'build/verification'
        self.script('pass.py', "print('PASS child')")

    def script(self, name, body):
        (self.root / 'script' / name).write_text(body, encoding='utf-8')
        return name

    def read(self, name):
        return json.loads((self.out / name).read_text(encoding='utf-8'))

    def seed_success(self):
        for name, value in (('run.json', {'passed': True, 'state': 'passed'}),
                            ('results.json', [{'suite': 'old', 'passed': True}]),
                            ('source_hashes.json', {'old.v': 'obsolete'})):
            (self.out / name).write_text(json.dumps(value), encoding='utf-8')

    def assert_rejected(self):
        self.assertFalse(self.read('run.json')['passed'])
        self.assertFalse((self.out / 'source_hashes.json').exists())

    def test_success_binds_current_inputs_and_complete_suite_list(self):
        (self.root / 'script/__pycache__').mkdir()
        (self.root / 'script/__pycache__/ignored.pyc').write_bytes(b'cache')
        run_suites(self.root, [('first', ['pass.py']), ('second', ['pass.py'])])
        receipt = self.read('run.json')
        self.assertTrue(receipt['passed'])
        self.assertEqual(receipt['state'], 'passed')
        self.assertEqual(receipt['suites'], ['first', 'second'])
        self.assertEqual([item['suite'] for item in self.read('results.json')], receipt['suites'])
        self.assertEqual(self.read('source_hashes.json'), source_hashes(self.root))
        self.assertIn('assets/audio.pcm', self.read('source_hashes.json'))
        self.assertNotIn('script/__pycache__/ignored.pyc', self.read('source_hashes.json'))
        self.assertEqual(receipt['source_hashes_sha256'], hashlib.sha256(
            (self.out / 'source_hashes.json').read_bytes()).hexdigest())

    def test_old_success_is_invalid_before_first_child_starts(self):
        self.seed_success()
        name = self.script('inspect.py', '''from pathlib import Path
import json
out = Path('build/verification')
assert json.loads((out / 'run.json').read_text())['state'] == 'running'
assert not json.loads((out / 'run.json').read_text())['passed']
assert json.loads((out / 'results.json').read_text()) == []
assert not (out / 'source_hashes.json').exists()
''')
        run_suites(self.root, [('inspect', [name])])
        self.assertTrue(self.read('run.json')['passed'])

    def test_nonzero_child_stops_remaining_suites_and_removes_old_success(self):
        self.seed_success()
        name = self.script('fail.py', 'raise SystemExit(7)')
        later = self.script('later.py', "from pathlib import Path; Path('unexpected').touch()")
        with self.assertRaisesRegex(RuntimeError, 'Failed broken'):
            run_suites(self.root, [('broken', [name]), ('later', [later])])
        self.assert_rejected()
        self.assertEqual(self.read('run.json')['state'], 'failed')
        self.assertEqual(len(self.read('results.json')), 1)
        self.assertFalse(self.read('results.json')[0]['passed'])
        self.assertFalse((self.root / 'unexpected').exists())

    def test_input_changes_reject_otherwise_successful_children(self):
        for action in ("Path('src/design.v').write_text('changed')",
                       "Path('src/added.v').write_text('added')",
                       "Path('src/design.v').unlink()",
                       "Path('assets/audio.pcm').write_bytes(b'changed')"):
            with self.subTest(action=action):
                self.seed_success()
                self.source.write_text('module design; endmodule\n', encoding='ascii')
                (self.root / 'src/added.v').unlink(missing_ok=True)
                name = self.script('mutate.py', 'from pathlib import Path\n' + action)
                with self.assertRaisesRegex(RuntimeError, 'inputs changed during run'):
                    run_suites(self.root, [('mutate', [name])])
                self.assert_rejected()
                self.assertTrue(self.read('results.json')[0]['passed'])

    def test_interrupt_invalidates_success_and_records_incomplete_run(self):
        self.seed_success()
        with patch('verify.subprocess.run', side_effect=KeyboardInterrupt):
            with self.assertRaises(KeyboardInterrupt):
                run_suites(self.root, [('interrupt', ['pass.py'])])
        self.assert_rejected()
        self.assertEqual(self.read('run.json')['state'], 'interrupted')
        self.assertEqual(self.read('results.json'), [])

    def test_launch_failure_invalidates_success(self):
        self.seed_success()
        with patch('verify.subprocess.run', side_effect=FileNotFoundError('interpreter missing')):
            with self.assertRaises(FileNotFoundError):
                run_suites(self.root, [('missing', ['pass.py'])])
        self.assert_rejected()
        self.assertEqual(self.read('run.json')['state'], 'failed')

    def test_empty_or_duplicate_suites_cannot_publish_success(self):
        for steps in ([], [('same', ['pass.py']), ('same', ['pass.py'])]):
            with self.subTest(steps=steps):
                self.seed_success()
                with self.assertRaisesRegex(ValueError, 'nonempty and unique'):
                    run_suites(self.root, steps)
                self.assert_rejected()


if __name__ == '__main__':
    unittest.main()
