"""Decode captured digital TMDS data islands; never accesses hardware.

Wire layout references: HDMI 1.4 sections 5.2.3, 5.3.3, 5.3.4 and
hdl-util/hdmi commit 83b1c9543a91b776671a44e68e130f81cae437b7.
This is an independent receiver-side checker, not imported transmitter RTL.
"""
from collections import Counter
from dataclasses import dataclass
from dataclasses import replace
from pathlib import Path
import argparse
import json


TERC4 = (0x29c, 0x263, 0x2e4, 0x2e2, 0x171, 0x11e, 0x18e, 0x13c,
         0x2cc, 0x139, 0x19c, 0x2c6, 0x28e, 0x271, 0x163, 0x2c3)
NIBBLE = {code: value for value, code in enumerate(TERC4)}
CONTROL = {0x354, 0x0ab, 0x154, 0x2ab}


@dataclass(frozen=True)
class Packet:
    cycle: int
    header: bytes
    sub: tuple[bytes, ...]
    symbols: tuple = ()


def require(condition, message):
    if not condition:
        raise ValueError(message)


def ecc(data):
    """LSB-first polynomial remainder for G(x)=x^8+x^7+x^6+1."""
    remainder = 0
    for byte in data:
        for bit in range(8):
            feedback = (remainder ^ (byte >> bit)) & 1
            remainder >>= 1
            if feedback:
                remainder ^= 0x83
    return remainder


def decode_packet(symbols):
    require(len(symbols) == 32, "data island packet length is not 32")
    header = 0
    sub = [0] * 4
    for index, (cycle, lanes) in enumerate(symbols):
        require(all(lane in NIBBLE for lane in lanes), f"invalid TERC4 at {cycle}")
        a, b, c = (NIBBLE[lane] for lane in lanes)
        header |= ((a >> 2) & 1) << index
        for slot in range(4):
            sub[slot] |= ((b >> slot) & 1) << (2 * index)
            sub[slot] |= ((c >> slot) & 1) << (2 * index + 1)
    blocks = [header.to_bytes(4, "little"), *(word.to_bytes(8, "little") for word in sub)]
    for index, block in enumerate(blocks):
        require(ecc(block[:-1]) == block[-1],
                f"BCH mismatch cycle={symbols[0][0]} block={index}")
    return Packet(symbols[0][0], blocks[0][:3], tuple(block[:7] for block in blocks[1:]), tuple(symbols))


def read_packets(path):
    """Find islands by eight preamble clocks and two leading/trailing guards.

    A TERC4-looking video pixel alone can never open a data island.
    Captures may end between islands, but never in a guard or packet.
    """
    preamble = 0
    phase = "idle"
    payload = []
    last_cycle = None
    with Path(path).open(encoding="ascii") as stream:
        for line in stream:
            fields = line.split()
            require(len(fields) == 4, "malformed TMDS trace row")
            cycle = int(fields[0])
            lanes = tuple(int(field, 16) for field in fields[1:])
            require(last_cycle is None or cycle == last_cycle + 1, "non-contiguous TMDS trace")
            last_cycle = cycle
            guard = lanes[0] in TERC4[12:] and lanes[1:] == (0x133, 0x133)
            if phase == "idle":
                if lanes[0] in CONTROL and lanes[1:] == (0x0ab, 0x0ab):
                    preamble += 1
                else:
                    if preamble >= 8:
                        require(guard, f"missing leading island guard at {cycle}")
                        phase = "lead"
                    preamble = 0
            elif phase == "lead":
                require(guard, f"missing second leading guard at {cycle}")
                phase = "data"
            elif phase == "data":
                if guard:
                    require(not payload, f"partial data island packet at {cycle}")
                    phase = "trail"
                else:
                    require(all(lane in NIBBLE for lane in lanes), f"invalid island symbol at {cycle}")
                    payload.append((cycle, lanes))
                    if len(payload) == 32:
                        yield decode_packet(payload)
                        payload = []
            else:
                require(guard, f"missing second trailing guard at {cycle}")
                phase = "idle"
    require(phase == "idle", "truncated data island capture")


def audit_packets(packets, pcm, minimum_samples=3000, tail=1):
    """Require FIFO-exact stereo PCM and independently verify ACR on the wire."""
    require(len(pcm) >= minimum_samples, "too few input PCM samples")
    intervals = Counter(pcm[i][0] - pcm[i-1][0] for i in range(1, len(pcm)))
    require(set(intervals) == {520, 521}, "input cadence is not 48 kHz at 25 MHz")
    require(all(abs((sample[0]-pcm[0][0])*48000-index*25000000) < 48000
                for index, sample in enumerate(pcm)), "input 48 kHz cadence drifts")
    counts = Counter()
    matched = 0
    delays = []
    status = None
    status_bits = 0
    status_blocks = 0
    for packet in packets:
        kind, hb1, hb2 = packet.header
        counts[kind] += 1
        if kind == 1:
            require(all(block == packet.sub[0] for block in packet.sub), "ACR replicas differ")
            b = packet.sub[0]
            cts = (b[1] << 16) | (b[2] << 8) | b[3]
            n = (b[4] << 16) | (b[5] << 8) | b[6]
            require(b[0] == 0 and n == 6144 and cts == 25000,
                    f"ACR rate mismatch: N={n} CTS={cts}")
        elif kind == 2:
            require(hb1 & 0xf0 == 0 and hb2 & 0x0f == 0, "unsupported audio layout/header")
            for slot, block in enumerate(packet.sub):
                if not (hb1 >> slot) & 1:
                    continue
                left = int.from_bytes(block[:3], "little")
                right = int.from_bytes(block[3:6], "little")
                flags = block[6]
                require(flags & 0x33 == 0, "invalid PCM validity/user flags")
                require((left.bit_count() + (flags & 0xf).bit_count()) % 2 == 0 and
                        (right.bit_count() + (flags >> 4).bit_count()) % 2 == 0,
                        f"IEC parity mismatch sample={matched}")
                require(matched < len(pcm), "extra output PCM sample")
                cycle, expected_l, expected_r = pcm[matched]
                require((left, right) == (expected_l, expected_r),
                        f"PCM mismatch sample={matched} got={left:06x}/{right:06x} "
                        f"expected={expected_l:06x}/{expected_r:06x}")
                if (hb2 >> (slot + 4)) & 1:
                    if status is not None:
                        require(status_bits == 192, "IEC channel-status block period mismatch")
                        require(all(word & 3 == 0 and (word >> 24) & 15 == 2 and
                                    (word >> 32) & 15 == 11 for word in status),
                                "IEC channel-status format is not consumer 48 kHz 24-bit LPCM")
                        status_blocks += 1
                    status = [0, 0]
                    status_bits = 0
                if status is not None:
                    require(status_bits < 192, "missing IEC block-start marker")
                    status[0] |= ((flags >> 2) & 1) << status_bits
                    status[1] |= ((flags >> 6) & 1) << status_bits
                    status_bits += 1
                delay = packet.cycle - cycle
                require(0 <= delay <= 5000, f"PCM scheduling delay outside bound: {delay}")
                delays.append(delay)
                matched += 1
        elif kind in (0x82, 0x84):
            data = b"".join(packet.sub)
            require(hb2 <= 27 and (sum(packet.header) + sum(data[:hb2 + 1])) % 256 == 0,
                    f"InfoFrame checksum mismatch type={kind:02x}")
            if kind == 0x84:
                require(hb1 == 1 and hb2 == 10 and data[1] & 7 == 1 and
                        (data[1] >> 4) in (0, 1) and (data[2] >> 2) & 7 in (0, 3),
                        "audio InfoFrame is not stereo LPCM/stream-defined 48 kHz")
                if tail == 3:
                    require(data[1:3] == b"\x11\x0f", "direct audio format must be explicit 48 kHz 24-bit LPCM")
            elif tail == 3:
                require(hb1 == 2 and hb2 == 13 and data[1:6] == b"\x02\x10\x00\x01\x00",
                        "direct AVI must declare RGB underscan 4:3 VIC 1 without repetition")
        elif kind == 3:
            require(packet.sub[0][0] == 0x10, "GCP must clear AVMUTE")
            if tail == 1:
                require(all(block == b"\x10\x04\x00\x00\x00\x00\x00" for block in packet.sub),
                        "vendor GCP must repeat explicit 24-bit depth in all subpackets")
    require(matched >= minimum_samples, f"too few decoded PCM samples: {matched}")
    # Five exact rasters leave 1 sample in the vendor queue or 3 samples in
    # the direct transmitter's four-sample group. Never accept an arbitrary tail.
    require(len(pcm) - matched == tail, "unexpected unsent PCM tail for five-frame capture")
    require(counts[1] >= 50 and counts[0x84] >= 2, "missing repeated ACR/audio InfoFrame")
    require(counts[3] >= 2 and counts[0x82] >= 2, "missing repeated Clear_AVMUTE/AVI packets")
    require(status_blocks >= 10, "too few complete IEC channel-status blocks")
    return {"packets": {f"{key:02x}": value for key, value in sorted(counts.items())},
            "input_samples": len(pcm), "decoded_samples": matched,
            "pending_tail_samples": len(pcm) - matched,
            "cadence_clocks": dict(intervals), "acr_n": 6144, "acr_cts": 25000,
            "sample_rate_hz": 48000, "channel_status_blocks": status_blocks,
            "delay_pixel_clocks": [min(delays), max(delays)]}


def negative_controls(packets, pcm, tail=1):
    """Corrupt real captured packets; each failure must name the intended check."""
    detected = []

    def rejects(name, operation, expected):
        try:
            operation()
        except ValueError as error:
            require(expected in str(error), f"negative {name} failed for wrong reason: {error}")
            detected.append(name)
        else:
            raise ValueError(f"negative {name} unexpectedly passed")

    audio_index = next(i for i, packet in enumerate(packets) if packet.header[0] == 2)
    packet = packets[audio_index]
    raw = list(packet.symbols)
    cycle, lanes = raw[0]
    raw[0] = (cycle, (lanes[0], TERC4[NIBBLE[lanes[1]] ^ 1], lanes[2]))
    rejects("bch_bit_flip", lambda: decode_packet(raw), "BCH mismatch")
    raw[0] = (cycle, (lanes[0], 0, lanes[2]))
    rejects("invalid_terc4", lambda: decode_packet(raw), "invalid TERC4")

    def corrupt(name, index, changed, expected):
        modified = packets.copy()
        modified[index] = changed
        rejects(name, lambda: audit_packets(modified, pcm, tail=tail), expected)

    # Recompute IEC parity after changing data so that payload checks, rather
    # than the easier parity check, must detect a transport error.
    def sample_block(block, left, right):
        flags = block[6] & 0x77
        flags |= ((left.bit_count() + (flags & 7).bit_count()) % 2) << 3
        flags |= ((right.bit_count() + (flags >> 4).bit_count()) % 2) << 7
        return left.to_bytes(3, "little") + right.to_bytes(3, "little") + bytes([flags])

    left = int.from_bytes(packet.sub[0][:3], "little")
    right = int.from_bytes(packet.sub[0][3:6], "little")
    changed = sample_block(packet.sub[0], left ^ 1, right)
    corrupt("pcm_payload", audio_index, replace(packet, sub=(changed, *packet.sub[1:])), "PCM mismatch")
    require(left != right, "stereo negative control needs asymmetric challenge")
    changed = sample_block(packet.sub[0], right, left)
    corrupt("stereo_swap", audio_index, replace(packet, sub=(changed, *packet.sub[1:])), "PCM mismatch")
    changed = packet.sub[0][:6] + bytes([packet.sub[0][6] ^ 8])
    corrupt("iec_parity", audio_index, replace(packet, sub=(changed, *packet.sub[1:])), "IEC parity")
    modified = packets.copy()
    del modified[audio_index]
    rejects("dropped_sample", lambda: audit_packets(modified, pcm, tail=tail), "PCM mismatch")
    modified = packets.copy()
    modified.insert(audio_index, packet)
    rejects("duplicated_sample", lambda: audit_packets(modified, pcm, tail=tail), "PCM mismatch")
    index = next(i for i, p in enumerate(packets) if p.header[0] == 1)
    p = packets[index]
    block = p.sub[0][:6] + bytes([p.sub[0][6] ^ 1])
    corrupt("acr_rate", index, replace(p, sub=(block,) * 4), "ACR rate mismatch")
    index = next(i for i, p in enumerate(packets) if p.header[0] == 0x84)
    p = packets[index]
    block = bytes([p.sub[0][0] ^ 1]) + p.sub[0][1:]
    corrupt("infoframe_checksum", index, replace(p, sub=(block, *p.sub[1:])), "InfoFrame checksum")
    modified = [p for p in packets if p.header[0] != 1]
    rejects("missing_acr", lambda: audit_packets(modified, pcm, tail=tail), "missing repeated ACR")
    audio = [i for i, p in enumerate(packets) if p.header[0] == 2]
    boundary = next(i for i, index in enumerate(audio) if packets[index].header[2] & 0x10)
    slots = packets[audio[boundary]].header[1].bit_count()
    index = audio[boundary + 24 // slots]
    p = packets[index]
    # Change the sampling-frequency status bit, then repair sample parity.
    block = p.sub[0][:6] + bytes([p.sub[0][6] ^ 4])
    block = sample_block(block, int.from_bytes(block[:3], "little"), int.from_bytes(block[3:6], "little"))
    corrupt("channel_status_rate", index, replace(p, sub=(block, *p.sub[1:])), "channel-status format")
    index = audio[boundary + 1]
    p = packets[index]
    corrupt("block_start_period", index, replace(p, header=p.header[:2] + bytes([0x10])), "block period")
    drifting = [(pcm[0][0] + i*521 - i//20, left, right) for i, (_, left, right) in enumerate(pcm)]
    rejects("sample_clock_drift", lambda: audit_packets(packets, drifting, tail=tail), "cadence drifts")
    return detected


def check_capture(symbols_path, pcm_path, negatives=False, tone=False, tail=1):
    pcm = []
    for line in Path(pcm_path).read_text(encoding="ascii").splitlines():
        cycle, left, right = line.split()
        pcm.append((int(cycle), int(left, 16), int(right, 16)))
    packets = list(read_packets(symbols_path))
    result = audit_packets(packets, pcm, tail=tail)
    if tone:
        require(all(left == right == (0x100000 if index % 48 < 24 else 0xf00000)
                    for index, (_, left, right) in enumerate(pcm)), "test tone is not stereo 1 kHz")
        result["test_tone_hz"] = 1000
    if negatives:
        result["negative_controls"] = negative_controls(packets, pcm, tail=tail)
    return result


def main():
    parser = argparse.ArgumentParser(description=__doc__)
    parser.add_argument("symbols", type=Path)
    parser.add_argument("pcm", type=Path)
    parser.add_argument("--negative-controls", action="store_true")
    parser.add_argument("--tone", action="store_true")
    parser.add_argument("--tail", type=int, default=1)
    args = parser.parse_args()
    print(json.dumps(check_capture(args.symbols, args.pcm, args.negative_controls, args.tone, args.tail), indent=2))


if __name__ == "__main__":
    main()
