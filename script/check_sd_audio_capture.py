"""Independently check real WAV/card bytes through the SD-to-HDMI bench.

Playback starts are derived from public sector completions, never DUT RAM,
voice positions, or mixer state. The endpoint does not model SD electrical IO.
"""
from array import array
from pathlib import Path
import argparse
import hashlib
import json
import struct
import sys
import wave

from check_hdmi_audio import check_capture, require
from pack_game_audio import validate_pack

ROOT = Path(__file__).resolve().parents[1]
TRACKS = (0, 1, 2, 12, 15)


def rows(path):
    return [line.split() for line in path.read_text(encoding="ascii").splitlines()]


def compare_pcm(actual, expected):
    require(len(actual) == len(expected), "media PCM sample count mismatch")
    for index, ((cycle, left, right), (expected_cycle, value)) in enumerate(zip(actual, expected)):
        require(cycle == expected_cycle, f"media PCM sample clock mismatch at {index}")
        require(left == right == value,
                f"media PCM mismatch sample={index} got={left:06x}/{right:06x} expected={value:06x}")


def check_media_capture(directory, image_path, audio_directory, tail=1):
    image = image_path.read_bytes()
    manifest = json.loads((audio_directory / "manifest.json").read_text(encoding="utf-8"))
    header = image[512:1024]
    require(header[:8] == b"FPGAUD1!", "card audio directory signature mismatch")
    pak_lba, pak_sectors = struct.unpack_from("<II", header, 16)
    pak = image[pak_lba * 512:(pak_lba + pak_sectors) * 512]
    validate_pack(pak)
    require(header[:16] + header[20:] == pak[:16] + pak[20:512], "card directory/PAK mismatch")
    require(hashlib.sha256(pak).hexdigest() == manifest["sha256"], "card PAK manifest mismatch")
    source = {}
    lbas = {}
    for ident in TRACKS:
        entry = next(track for track in manifest["tracks"] if track["id"] == ident)
        wav_path = audio_directory / f"{ident:02d}_{entry['name']}.wav"
        with wave.open(str(wav_path), "rb") as wav:
            require((wav.getnchannels(), wav.getsampwidth(), wav.getframerate()) == (1, 2, 48000),
                    "reference WAV format mismatch")
            raw = wav.readframes(wav.getnframes())
        offset, count = struct.unpack_from("<II", header, 32 + ident * 16)
        require(len(raw) == count * 2 and hashlib.sha256(raw).hexdigest() == entry["pcm_sha256"],
                f"reference WAV/manifest mismatch: {ident}")
        require(pak[offset * 512:offset * 512 + len(raw)] == raw,
                f"card PCM/reference WAV mismatch: {ident}")
        samples = array("h", raw)
        if sys.byteorder != "little":
            samples.byteswap()
        source[ident] = samples
        lbas[ident] = pak_lba + offset

    ticks = [tuple(map(int, row)) for row in rows(directory / "audio_sd_ticks.txt")]
    pcm = [(int(cycle), int(left, 16), int(right, 16))
           for cycle, left, right in rows(directory / "audio_sd_input.txt")]
    commands = [tuple(map(int, row)) for row in rows(directory / "audio_sd_events.txt")]
    sectors = [(int(cycle), int(lba), client)
               for cycle, lba, client in rows(directory / "audio_sd_sectors.txt")]
    status = rows(directory / "audio_sd_status.txt")
    require(len(status) == 1 and len(status[0]) == 5, "missing SD audio final status")
    underruns, dropped, error, bmp_count, audio_count = map(int, status[0])
    require(len(ticks) == len(pcm) == 4031, "expected five-frame continuous sample clock")
    require(tuple(ident for _, ident in commands) == TRACKS, "missing BGM/four-SFX commands")
    require(all(tick[1] == i for i, tick in enumerate(ticks)), "non-contiguous media tick index")
    require(all(a[0] < b[0] for a, b in zip(sectors, sectors[1:])), "unordered sector completions")
    starts = {}
    for command_cycle, ident in commands:
        require(min(abs(tick[0] - command_cycle) for tick in ticks) > 24,
                f"ambiguous command/sample boundary for track {ident}")
        completion = next((cycle for cycle, lba, client in sectors
                           if client == "A" and lba == lbas[ident] and cycle > command_cycle), None)
        require(completion is not None, f"no first PCM sector for track {ident}")
        # CDC completion arrives in a handful of pixel clocks. This fixture
        # must place every tick >24 clocks away (including the complete
        # five-voice mix window), so neither subcycle CDC timing nor the
        # per-voice scan order can decide any expected sample.
        ready = completion + 4
        require(min(abs(tick[0] - ready) for tick in ticks) > 24,
                f"ambiguous first-sector/sample boundary for track {ident}")
        require(0 < ready - command_cycle < 100000, f"track {ident} startup outside 4 ms bound")
        starts[ident] = ready

    position = {ident: 0 for ident in TRACKS}
    expected = []
    previous = 0
    startup_underruns = 0
    saturation = 0
    phases = {}
    for cycle, index, paused, mute, master, bgm, sfx in ticks:
        # Production registers audio_valid one cycle after the mix tick. It
        # transmits the preceding stable mix; no partially summed sample may
        # escape. The outer mute mux acts immediately between sample strobes.
        expected.append((cycle + 1, 0 if mute else previous))
        total = 0
        for ident in TRACKS:
            if paused:
                continue
            if cycle < starts[ident]:
                command = next(c for c, track in commands if track == ident)
                if cycle > command + 24:
                    startup_underruns += 1
                continue
            if position[ident] < len(source[ident]):
                sample = source[ident][position[ident]]
                level = bgm if ident == 0 else sfx
                total += 0 if level == 0 else sample >> (2 if level == 1 else 1 if level == 2 else 0)
                position[ident] += 1
        total = 0 if master == 0 else total >> (2 if master == 1 else 1 if master == 2 else 0)
        if not mute and not -32768 <= total <= 32767:
            saturation += 1
        previous = 0 if mute else (max(-32768, min(32767, total)) << 8) & 0xffffff
        key = f"pause={paused},mute={mute},levels={master}/{bgm}/{sfx}"
        phases[key] = phases.get(key, 0) + 1
    require(len(phases) == 4 and all(value >= 250 for value in phases.values()),
            "missing sustained normal/volume/pause/mute phases")
    require(underruns == startup_underruns, "unexpected post-start SD audio underrun")
    require(dropped == error == 0, "SD audio error or dropped event")
    require(bmp_count == sum(client == "B" for _, _, client in sectors) >= 20 and
            audio_count == sum(client == "A" for _, _, client in sectors) >= 20,
            "SD client sector completion count mismatch")
    compare_pcm(pcm, expected)
    # A periodic tone cannot expose all of these. Corrupt the real-media
    # capture after it has become audible and require content-check failure.
    index = next(i for i, (_, value) in enumerate(expected) if value != 0 and i > 100)
    negatives = []
    for name, changed in (
        ("changed_sample", pcm[:index] + [(pcm[index][0], pcm[index][1] ^ 256, pcm[index][2] ^ 256)] + pcm[index + 1:]),
        ("dropped_sample", pcm[:index] + pcm[index + 1:]),
        ("duplicated_sample", pcm[:index] + [pcm[index]] + pcm[index:]),
        ("one_sample_late", [(c, pcm[max(0, i - 1)][1], pcm[max(0, i - 1)][2])
                             for i, (c, _, _) in enumerate(pcm)]),
    ):
        try:
            compare_pcm(changed, expected)
        except ValueError as error:
            require("media PCM" in str(error), "wrong media negative failure")
            negatives.append(name)
        else:
            raise ValueError(f"media negative {name} unexpectedly passed")
    hdmi = check_capture(directory / "audio_sd_symbols.txt", directory / "audio_sd_input.txt", tail=tail)
    return {"media_pcm_samples": len(expected), "track_positions": position, "phases": phases,
            "saturated_samples": saturation, "startup_voice_misses": startup_underruns,
            "post_start_underruns": underruns - startup_underruns,
            "first_sector_ready_cycles": starts,
            "bmp_sectors": sum(client == "B" for _, _, client in sectors),
            "audio_sectors": sum(client == "A" for _, _, client in sectors),
            "negative_controls": negatives, "hdmi": hdmi,
            "image_sha256": hashlib.sha256(image).hexdigest(),
            "audio_manifest_sha256": hashlib.sha256((audio_directory / "manifest.json").read_bytes()).hexdigest()}


def main():
    parser = argparse.ArgumentParser(description=__doc__)
    parser.add_argument("directory", type=Path)
    parser.add_argument("--image", type=Path, default=ROOT / "build/media/game-audio-v4.img")
    parser.add_argument("--audio-directory", type=Path, default=ROOT / "assets/audio")
    parser.add_argument("--tail", type=int, default=1)
    args = parser.parse_args()
    print(json.dumps(check_media_capture(args.directory, args.image, args.audio_directory, args.tail), indent=2))


if __name__ == "__main__":
    main()
