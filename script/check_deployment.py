"""Check the current game bitstream/media pair without accessing a device.

This is a compatibility check, not a substitute for simulation or board tests.
Expected staging is generated in a temporary directory using the build flow.
"""
from pathlib import Path
import argparse
import hashlib
import json
import math
import re
import struct
import sys
import tempfile

from build_td import ROOT, stage_sources
from make_sd_image import make_image, validate_bmp
from pack_game_audio import validate_pack


def require(condition, message):
    if not condition:
        raise ValueError(message)


def file_hash(path):
    require(path.is_file(), f'Missing regular file: {path}')
    digest = hashlib.sha256()
    with path.open('rb') as stream:
        for block in iter(lambda: stream.read(1024 * 1024), b''):
            digest.update(block)
    return digest.hexdigest()


def expected_staging():
    # Reuse feature selection and the 40MHz SDRAM-header transformation. Never
    # refresh the real staging here: that would hide an outdated GUI project.
    with tempfile.TemporaryDirectory(prefix='pixel-quest-check-') as directory:
        stage = Path(directory)
        stage_sources(stage)
        return {p.name: file_hash(p) for p in stage.iterdir() if p.is_file()}


def check_build(receipt, bitstream, stage, expected):
    require(isinstance(receipt, dict), 'Invalid TD receipt')
    require(receipt.get('passed') is True and receipt.get('native_gui_flow') is True
            and not receipt.get('negative_control'),
            'No accepted native TD build; run python script/build_td_gui.py')
    timing = receipt.get('timing_ns', {})
    require(isinstance(timing, dict), 'Invalid TD timing record')
    for name in ('SWNS', 'HWNS'):
        value = timing.get(name)
        require(type(value) in (int, float) and math.isfinite(value) and value >= 0,
                f'Missing or failing TD timing: {name}')
    recorded = receipt.get('staged_source_sha256')
    require(isinstance(recorded, dict) and bool(expected), 'Missing TD source hashes')
    require(recorded.keys() == expected.keys(),
            'TD source set differs from current design; rebuild the project')
    changed = sorted(name for name in expected if expected[name] != recorded[name])
    require(not changed, 'Bitstream is stale for current sources: ' + ', '.join(changed))
    require(stage.is_dir(), f'Missing GUI staging: {stage}')
    staged = {p.name: file_hash(p) for p in stage.iterdir() if p.is_file()}
    require(staged == recorded, 'GUI staging differs from accepted TD build; rebuild the project')
    digest = file_hash(bitstream)
    require(bitstream.stat().st_size > 0 and digest == receipt.get('sha256'),
            'Bitstream differs from accepted TD build')
    return {'bitstream': str(bitstream.resolve()), 'sha256': digest,
            'staged_files': len(expected), 'timing_ns': timing}


def check_atlas(data, header):
    validate_bmp(data)
    width, height = struct.unpack_from('<ii', data, 18)
    require((width, height) == (640, 480), 'First BMP must be the native 640x480 game atlas')
    offset = struct.unpack_from('<I', data, 10)[0]
    stride = (width * 3 + 3) & ~3
    definitions = dict(re.findall(r"`define (GAME_(?:SIG|PAL)_\d+) 24'h([0-9a-fA-F]{6})", header))

    def rgb(x, y):
        start = offset + (height - 1 - y) * stride + x * 3
        return bytes(data[start:start + 3][::-1])

    for index in range(16):
        key = f'GAME_SIG_{index}'
        require(key in definitions and rgb(128 + index, 0).hex() == definitions[key].lower(),
                f'First BMP has wrong game atlas signature at pixel {index}')
    palette = set()
    for index in range(16):
        key = f'GAME_PAL_{index}'
        require(key in definitions, f'Missing RTL palette entry: {key}')
        palette.add(bytes.fromhex(definitions[key]))
    require(all(rgb(x, y) in palette for y in range(256) for x in range(128)),
            'Game atlas contains colors outside the current RTL palette')


def check_media(image, game_dir, audio_dir, header):
    require(image.suffix.lower() == '.img' and image.is_file(),
            'Media input must be a regular .img file, not a device or drive')
    manifest = json.loads((game_dir / 'manifest.json').read_text(encoding='utf-8'))
    require(isinstance(manifest, dict), 'Invalid game manifest')
    pages = manifest.get('preview_pages')
    require(isinstance(pages, list) and 1 <= len(pages) <= 64,
            'Missing game preview page list')
    require(all(isinstance(name, str) and Path(name).name == name and
                '/' not in name and '\\' not in name and name.lower().endswith('.bmp')
                for name in pages), 'Invalid game preview filename')
    images = [(game_dir / name).read_bytes() for name in pages]
    check_atlas(images[0], header)
    pack = (audio_dir / 'AUDIO.PAK').read_bytes()
    validate_pack(pack)
    audio_manifest = json.loads((audio_dir / 'manifest.json').read_text(encoding='utf-8'))
    require(isinstance(audio_manifest, dict), 'Invalid audio manifest')
    require(hashlib.sha256(pack).hexdigest() == audio_manifest.get('sha256'),
            'AUDIO.PAK differs from audio source manifest')
    tracks = audio_manifest.get('tracks', [])
    require(isinstance(tracks, list) and len(tracks) == 24 and
            all(isinstance(track, dict) for track in tracks),
            'Audio manifest must describe 24 tracks')
    for index, track in enumerate(tracks):
        sector, samples = struct.unpack_from('<II', pack, 32 + index * 16)
        pcm = pack[sector * 512:sector * 512 + samples * 2]
        require(track.get('id') == index and track.get('samples') == samples and
                track.get('pcm_sha256') == hashlib.sha256(pcm).hexdigest(),
                f'Audio track {index} differs from audio source manifest')
    expected = make_image(images, audio_pack=pack)
    expected_hash = hashlib.sha256(expected).hexdigest()
    require(image.stat().st_size == len(expected) and file_hash(image) == expected_hash,
            'TF image does not match current game BMPs/audio/layout; regenerate with make_sd_image.py')
    return {'image': str(image.resolve()), 'sha256': expected_hash, 'bytes': len(expected),
            'images': [{'file': name, 'size': list(struct.unpack_from('<ii', data, 18))}
                       for name, data in zip(pages, images)],
            'audio_tracks': len(tracks),
            'audio_lba': struct.unpack_from('<I', expected, 512 + 16)[0]}


def main():
    parser = argparse.ArgumentParser(description=__doc__)
    parser.add_argument('--image', type=Path, default=ROOT / 'build/media/game-audio-v4.img',
                        help='Current game image to check (ordinary file only)')
    parser.add_argument('--audio-directory', type=Path, default=ROOT / 'assets/audio',
                        help='Audio pack/manifest paired with the image (default: accepted original)')
    parser.add_argument('--json', action='store_true', help='Print a machine-readable result')
    parser.add_argument('--video-diagnostic', action='store_true', help='Check isolated video-only build; no media required')
    parser.add_argument('--video-svga', action='store_true', help='Check 800x600 DVI probe; no media required')
    args = parser.parse_args()
    if args.video_svga and args.video_diagnostic: parser.error('Choose one diagnostic target')
    try:
        if args.video_diagnostic or args.video_svga:
            directory = ROOT / ('build/video_svga' if args.video_svga else 'build/video_diagnostic')
            receipt = json.loads((directory / 'verification.json').read_text(encoding='utf-8'))
            require(receipt.get('top') == ('video_svga_top' if args.video_svga else 'video_diagnostic_top'), 'Receipt is not the selected video diagnostic')
            build = check_build(receipt, directory / 'media_player_Runs/phy_1/media_player.bit',
                                ROOT / ('build/staging/video_svga' if args.video_svga else 'build/staging/video_diagnostic'), expected_staging())
            if args.json:
                print(json.dumps({'passed': True, 'build': build, 'media': None,
                                  'scope': 'Video diagnostic files only; no device accessed'}, indent=2))
            else:
                print(f'PASS video diagnostic / current sources: {build["staged_files"]} staged files')
                print(f'  BIT SHA256: {build["sha256"]}')
                print('No TF card required. Physical display acceptance is separate.')
            return 0
        require(args.image.suffix.lower() == '.img' and args.image.is_file(),
                'Media input must be a regular .img file, not a device or drive')
        receipt = json.loads((ROOT / 'prj/verification.json').read_text(encoding='utf-8'))
        build = check_build(receipt, ROOT / 'prj/media_player_Runs/phy_1/media_player.bit',
                            ROOT / 'build/staging/gui', expected_staging())
        media = check_media(args.image, ROOT / 'assets/game', args.audio_directory,
                            (ROOT / 'src/game/game_assets.vh').read_text(encoding='ascii'))
    except (OSError, ValueError, KeyError, TypeError, AssertionError, struct.error) as error:
        if args.json:
            print(json.dumps({'passed': False, 'error': str(error)}))
        else:
            print(f'FAIL deployment compatibility: {error}', file=sys.stderr)
        return 1
    if args.json:
        print(json.dumps({'passed': True, 'build': build, 'media': media,
                          'scope': 'Current source/bitstream/media compatibility only; no board or device accessed'},
                         indent=2))
    else:
        print(f'PASS current sources / accepted TD bitstream: {build["staged_files"]} staged files')
        print(f'  BIT SHA256: {build["sha256"]}')
        print(f'PASS TF image: {len(media["images"])} BMPs, {media["audio_tracks"]} audio tracks, audio LBA {media["audio_lba"]}')
        print(f'  IMG SHA256: {media["sha256"]}')
        print('Compatibility only; simulation/board acceptance is separate. No card or FPGA was accessed.')
    return 0


if __name__ == '__main__':
    sys.exit(main())
