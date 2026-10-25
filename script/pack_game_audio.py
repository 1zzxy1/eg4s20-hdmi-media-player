"""Fetch pinned reference sounds and build a sector-aligned s16le PCM pack.

No device is opened. MIT code licensing does not establish rights to game audio.
The manifest retains upstream paths, commit, Git blob SHA, and content hashes.
"""
from pathlib import Path
import argparse
import base64
import hashlib
import json
import struct
import subprocess
import urllib.parse
import urllib.request
import wave

ROOT = Path(__file__).resolve().parents[1]
REPO = 'umaim/Mario'
COMMIT = '980c275358704a49f868567aeec5bdfb347c4781'
MAGIC = b'FPGAUD1!'
RATE = 48000
TRACKS = [
    ('overworld', 'Themes', 'Overworld'),
    ('jump_small', 'Sounds', 'Jump Small'), ('coin', 'Sounds', 'Coin'),
    ('stomp_kick', 'Sounds', 'Kick'), ('death', 'Sounds', 'Player Dies'),
    ('start_pause', 'Sounds', 'Pause'), ('clear', 'Sounds', 'Level Complete'),
    ('powerup', 'Sounds', 'Powerup'), ('bump', 'Sounds', 'Bump'),
    ('hurt', 'Sounds', 'Power Down'), ('flagpole', 'Sounds', 'Flagpole'),
    ('one_up', 'Sounds', 'Gain Life'), ('fireball', 'Sounds', 'Fireball'),
    ('star', 'Themes', 'Star'), ('powerup_appears', 'Sounds', 'Powerup Appears'),
    ('break_block', 'Sounds', 'Break Block'), ('jump_super', 'Sounds', 'Jump Super'),
    ('pipe', 'Sounds', 'Pipe'), ('firework', 'Sounds', 'Firework'),
    ('hurry', 'Sounds', 'Hurry'), ('game_over', 'Sounds', 'Game Over'),
    ('underground', 'Themes', 'Underworld'), ('stage_clear', 'Sounds', 'Stage Clear'),
    ('vine', 'Sounds', 'Vine Emerging'),
]


def make_pack(tracks):
    if len(tracks) != 24:
        raise ValueError('Requires exactly 24 indexed tracks')
    header = bytearray(512)
    header[:8] = MAGIC
    struct.pack_into('<IHH', header, 8, RATE, 24, 1)
    body = bytearray()
    for index, pcm in enumerate(tracks):
        if not pcm or len(pcm) % 2 or len(pcm) // 2 >= 1 << 24:
            raise ValueError('Invalid PCM length')
        offset = 1 + len(body) // 512
        struct.pack_into('<IIHHI', header, 32 + index * 16,
                         offset, len(pcm) // 2, int(index == 0), index, 0)
        body.extend(pcm)
        body.extend(bytes((-len(body)) % 512))
    struct.pack_into('<I', header, 20, 1 + len(body) // 512)
    return bytes(header + body)


def validate_pack(data):
    if len(data) < 512 or len(data) % 512 or data[:8] != MAGIC:
        raise ValueError('Invalid audio pack header')
    if struct.unpack_from('<IHH', data, 8) != (RATE, 24, 1):
        raise ValueError('Unsupported rate/count/version')
    if struct.unpack_from('<I', data, 20)[0] != len(data) // 512:
        raise ValueError('Audio pack size mismatch')
    end = 512
    for index in range(24):
        offset, count, flags, ident, reserved = struct.unpack_from('<IIHHI', data, 32 + index * 16)
        if offset * 512 != end or not 0 < count < 1 << 24 or flags != int(index == 0) or ident != index or reserved:
            raise ValueError('Invalid track descriptor')
        end = ((offset * 512 + count * 2 + 511) // 512) * 512
        if end > len(data):
            raise ValueError('Track outside pack')
    if end != len(data):
        raise ValueError('Trailing audio data')


def api(path):
    request = urllib.request.Request('https://api.github.com/' + path, headers={
        'User-Agent': 'FPGA-Pixel-Quest-assets', 'Accept': 'application/vnd.github+json'})
    with urllib.request.urlopen(request, timeout=45) as response:
        return json.load(response)


def main():
    parser = argparse.ArgumentParser(description=__doc__)
    parser.add_argument('--fetch', action='store_true', help='Fetch pinned reference audio through GitHub API')
    parser.add_argument('--ffmpeg', type=Path, required=True)
    parser.add_argument('--directory', type=Path, default=ROOT / 'assets/audio')
    args = parser.parse_args()
    directory = args.directory
    if (directory / 'AUDIO.PAK').exists():
        raise SystemExit('Refusing to overwrite existing pack; choose a new directory')
    directory.mkdir(parents=True, exist_ok=True)
    original = directory / 'source'
    original.mkdir(exist_ok=True)
    tracks, records = [], []
    for index, (name, group, upstream) in enumerate(TRACKS):
        path = f'Source/Sounds/{group}/mp3/{upstream}.mp3'
        local = original / f'{index:02}_{name}.mp3'
        blob_sha = None
        if args.fetch and not local.exists():
            response = api(f'repos/{REPO}/contents/{urllib.parse.quote(path)}?ref={COMMIT}')
            blob_sha = response['sha']
            payload = base64.b64decode(response['content'])
            if hashlib.sha1(b'blob ' + str(len(payload)).encode() + b'\0' + payload).hexdigest() != blob_sha:
                raise ValueError('Git blob hash mismatch')
            local.write_bytes(payload)
        if not local.exists():
            raise SystemExit(f'Missing {local}; use --fetch or provide source files')
        wav = directory / f'{index:02}_{name}.wav'
        if not wav.exists():
            subprocess.run([str(args.ffmpeg.resolve()), '-nostdin', '-v', 'error', '-n', '-i', str(local),
                            '-ar', str(RATE), '-ac', '1', '-c:a', 'pcm_s16le', str(wav)], check=True)
        with wave.open(str(wav), 'rb') as audio:
            if (audio.getframerate(), audio.getnchannels(), audio.getsampwidth()) != (RATE, 1, 2):
                raise ValueError('Conversion format mismatch')
            pcm = audio.readframes(audio.getnframes())
        tracks.append(pcm)
        raw = local.read_bytes()
        records.append({'id': index, 'name': name, 'upstream_path': path,
                        'git_blob_sha1': blob_sha or hashlib.sha1(b'blob ' + str(len(raw)).encode() + b'\0' + raw).hexdigest(),
                        'source_sha256': hashlib.sha256(raw).hexdigest(),
                        'pcm_sha256': hashlib.sha256(pcm).hexdigest(), 'samples': len(pcm)//2,
                        'seconds': round(len(pcm)/(2*RATE), 4)})
        print(f'{index:02} {name}: {len(pcm)//2} samples', flush=True)
    pack = make_pack(tracks)
    validate_pack(pack)
    (directory / 'AUDIO.PAK').write_bytes(pack)
    (directory / 'manifest.json').write_text(json.dumps({
        'repository': f'https://github.com/{REPO}', 'commit': COMMIT,
        'format': 's16le-mono-48000-sector-v1', 'sha256': hashlib.sha256(pack).hexdigest(),
        'rights': 'Upstream code is MIT; rights to Nintendo-derived audio are not established. Review before public distribution.',
        'tracks': records}, indent=2), encoding='utf-8')
    print(f'Created {directory / "AUDIO.PAK"}: {len(pack)} bytes. No SD device accessed.')


if __name__ == '__main__':
    main()
