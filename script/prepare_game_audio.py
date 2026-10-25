"""Build an opt-in action-SFX onset candidate from the accepted PCM pack.

Only low-level leading samples are removed. Retained audio, tails, music and
scripted jingles are byte-identical; this does not reduce SD/player latency.
No network, converter, FPGA or disk device is used.
"""
from pathlib import Path
import argparse
import copy
import hashlib
import json
import struct
import sys
import wave

from pack_game_audio import RATE, TRACKS, make_pack, validate_pack

ROOT = Path(__file__).resolve().parents[1]
ACTION_IDS = frozenset((1, 2, 3, 7, 8, 9, 10, 11, 12, 14, 15, 16, 17, 18, 23))
THRESHOLD = 64  # About -54 dBFS, not digital silence.
GUARD = RATE * 2 // 1000
LIMIT = RATE * 12 // 1000


def sha(data):
    return hashlib.sha256(data).hexdigest()


def leading_cut(pcm):
    """Keep 2ms before the first >64 sample; never cut long quiet passages."""
    if not pcm or len(pcm) % 2:
        raise ValueError('Expected nonempty s16le PCM')
    if len(pcm) // 2 <= GUARD * 2:
        return 0
    for index, (sample,) in enumerate(struct.iter_unpack('<h', pcm[:(LIMIT + GUARD + 1) * 2])):
        if abs(sample) > THRESHOLD:
            return max(0, min(index - GUARD, LIMIT))
    # An onset outside this short window may be intentional phrasing.
    return 0


def prepare(pack, manifest):
    validate_pack(pack)
    if manifest.get('sha256') != sha(pack) or manifest.get('processing'):
        raise ValueError('Expected an unprocessed pack matching its manifest')
    records = manifest.get('tracks', [])
    if len(records) != len(TRACKS):
        raise ValueError('Expected 24 source tracks')
    tracks, cuts = [], []
    result = copy.deepcopy(manifest)
    for index, ((name, _, _), record) in enumerate(zip(TRACKS, records)):
        sector, count = struct.unpack_from('<II', pack, 32 + index * 16)
        pcm = pack[sector * 512:sector * 512 + count * 2]
        if (record.get('id') != index or record.get('name') != name or
                record.get('samples') != count or record.get('pcm_sha256') != sha(pcm)):
            raise ValueError(f'Source PCM/manifest mismatch at track {index}')
        cut = leading_cut(pcm) if index in ACTION_IDS else 0
        processed = pcm[cut * 2:]
        tracks.append(processed)
        cuts.append(cut)
        result['tracks'][index].update({
            'input_pcm_sha256': sha(pcm), 'input_samples': count,
            'leading_samples_removed': cut,
            'pcm_sha256': sha(processed), 'samples': len(processed) // 2,
            'seconds': round(len(processed) / (2 * RATE), 4)})
    candidate = make_pack(tracks)
    validate_pack(candidate)
    result['sha256'] = sha(candidate)
    result['processing'] = {
        'method': 'action-leading-low-level-v1', 'source_pack_sha256': sha(pack),
        'action_ids': sorted(ACTION_IDS), 'threshold_abs_s16': THRESHOLD,
        'guard_samples': GUARD, 'max_cut_samples': LIMIT,
        'tail_processing': 'none', 'retained_waveform': 'byte-identical',
        'status': 'candidate; board audition pending'}
    return candidate, result, tracks, cuts


def main():
    parser = argparse.ArgumentParser(description=__doc__)
    parser.add_argument('--input-directory', type=Path, default=ROOT / 'assets/audio')
    parser.add_argument('--output-directory', type=Path,
                        default=ROOT / 'build/media/audio-lowlatency')
    args = parser.parse_args()
    try:
        if args.output_directory.exists():
            raise ValueError('Refusing to overwrite an existing output directory')
        pack = (args.input_directory / 'AUDIO.PAK').read_bytes()
        manifest = json.loads((args.input_directory / 'manifest.json').read_text(encoding='utf-8'))
        candidate, result, tracks, cuts = prepare(pack, manifest)
        # A separate, new directory also prevents modifying the accepted pack.
        args.output_directory.mkdir(parents=True, exist_ok=False)
        (args.output_directory / 'AUDIO.PAK').write_bytes(candidate)
        (args.output_directory / 'manifest.json').write_text(
            json.dumps(result, indent=2) + '\n', encoding='utf-8')
        for index, ((name, _, _), pcm, cut) in enumerate(zip(TRACKS, tracks, cuts)):
            with wave.open(str(args.output_directory / f'{index:02}_{name}.wav'), 'wb') as audio:
                audio.setparams((1, 2, RATE, 0, 'NONE', 'not compressed'))
                audio.writeframes(pcm)
            print(f'{index:02} {name}: leading cut {cut} samples ({cut * 1000 / RATE:.3f} ms)')
        print(f'Created candidate {args.output_directory}: {len(candidate)} bytes; '
              f'{sum(cut > 0 for cut in cuts)} tracks shortened. Board audition pending.')
    except (OSError, ValueError, KeyError, TypeError, AttributeError, struct.error) as error:
        print(f'FAIL audio preparation: {error}', file=sys.stderr)
        return 1
    return 0


if __name__ == '__main__':
    sys.exit(main())
