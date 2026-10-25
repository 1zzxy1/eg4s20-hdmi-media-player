"""Restore missing unmodified vendor sources using the tracked provenance map."""
from pathlib import Path
import hashlib
import json
import shutil

ROOT = Path(__file__).resolve().parents[1]


def main():
    entries = json.loads((ROOT / 'doc/reference_manifest.json').read_text(encoding='utf-8'))
    # Edited derivatives must be restored from Git, not replaced by old examples.
    missing = [e['destination'] for e in entries
               if e['editable'] and not (ROOT / e['destination']).is_file()]
    if missing:
        raise SystemExit('Restore edited project sources from Git: ' + ', '.join(missing))
    restored = 0
    for entry in entries:
        dst = ROOT / entry['destination']
        if dst.exists():
            continue
        src = ROOT.parent / entry['source']
        if hashlib.sha256(src.read_bytes()).hexdigest() != entry['source_sha256']:
            raise SystemExit('Reference source hash mismatch: ' + str(src))
        dst.parent.mkdir(parents=True, exist_ok=True)
        shutil.copyfile(src, dst)
        restored += 1
    print(f'Reference files available: {len(entries)}; restored {restored}; existing files preserved')


if __name__ == '__main__':
    main()
