"""Fail-closed software acceptance suite. Hardware/analog validation is separate."""
from pathlib import Path
import hashlib
import json
import subprocess
import sys
import time

ROOT = Path(__file__).resolve().parents[1]
INPUT_DIRECTORIES = ('src', 'ip', 'test', 'script', 'prj/constraints', 'assets')
STEPS = [
    ('verification', ['../test/test_verification.py']),
    ('pins', ['check_project.py']), ('media', ['../test/test_media_image.py']),
    ('unit', ['test.py']), ('bmp', ['test_advanced.py']),
    ('game_assets', ['../test/test_game_assets.py']),
    ('deployment', ['../test/test_deployment.py']),
    ('audio_preparation', ['../test/test_audio_preparation.py']),
    ('level', ['pack_level_1_1.py', '--check']), ('game', ['test_game.py']),
    ('video', ['test_video.py']), ('sdram', ['test_vendor.py']),
    ('bmp_sdram', ['test_vendor.py', '--bmp']), ('hdmi', ['test_hdmi_vendor.py']),
]


def source_hashes(root):
    return {
        path.relative_to(root).as_posix(): hashlib.sha256(path.read_bytes()).hexdigest()
        for directory in INPUT_DIRECTORIES
        for path in sorted((root / directory).rglob('*'))
        if path.is_file() and '__pycache__' not in path.parts
    }


def write_json(path, value):
    # Publish a whole JSON document, including when a previous run was killed.
    temporary = path.with_suffix(path.suffix + '.tmp')
    temporary.write_text(json.dumps(value, indent=2), encoding='utf-8')
    temporary.replace(path)


def run_suites(root, steps):
    out = root / 'build/verification'
    out.mkdir(parents=True, exist_ok=True)
    snapshot = out / 'source_hashes.json'
    receipt = {'passed': False, 'state': 'running',
               'suites': [name for name, _ in steps], 'started_unix': time.time()}
    write_json(out / 'run.json', receipt)
    snapshot.unlink(missing_ok=True)
    results = []
    write_json(out / 'results.json', results)
    try:
        if not steps or len(set(receipt['suites'])) != len(steps):
            raise ValueError('Acceptance suites must be nonempty and unique')
        before = source_hashes(root)
        if not before:
            raise ValueError('No verification inputs found')
        for name, args in steps:
            start = time.monotonic()
            with (out / (name + '.log')).open('w', encoding='utf-8') as log:
                process = subprocess.run(
                    [sys.executable, '-u', str(root / 'script' / args[0]), *args[1:]],
                    cwd=root, stdout=log, stderr=subprocess.STDOUT)
            results.append({'suite': name, 'passed': process.returncode == 0,
                            'seconds': round(time.monotonic() - start, 2)})
            write_json(out / 'results.json', results)
            print(name, 'PASS' if process.returncode == 0 else 'FAIL', flush=True)
            if process.returncode:
                raise RuntimeError('Failed ' + name + '; see ' + str(out / (name + '.log')))
        after = source_hashes(root)
        changed = sorted(name for name in before.keys() | after.keys()
                         if before.get(name) != after.get(name))
        if changed:
            raise RuntimeError('Verification inputs changed during run; rerun all suites: '
                               + ', '.join(changed))
        write_json(snapshot, before)
        receipt.update(passed=True, state='passed',
                       source_hashes_sha256=hashlib.sha256(snapshot.read_bytes()).hexdigest())
        write_json(out / 'run.json', receipt)
    except BaseException as error:
        snapshot.unlink(missing_ok=True)
        receipt.update(passed=False,
                       state='interrupted' if isinstance(error, KeyboardInterrupt) else 'failed',
                       error=str(error) or type(error).__name__)
        write_json(out / 'run.json', receipt)
        raise
    print('PASS all configured software suites; no claim of analog PHY or hardware validation')


def main():
    try:
        run_suites(ROOT, STEPS)
    except (OSError, ValueError, RuntimeError) as error:
        raise SystemExit(str(error)) from error


if __name__ == '__main__':
    main()
