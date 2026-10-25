"""Validate the fixed SVGA probe through functional PLL and serializer pins.

This checks digital output correctness; physical horizontal-wrap acceptance
remains the human observation recorded by test_video_board.ps1.
"""
from pathlib import Path
import hashlib
import json
import subprocess
from PIL import Image
from test_video_diagnostic import GLYPHS

ROOT = Path(__file__).resolve().parents[1]


def reference():
    glyphs = {**GLYPHS, 'C': '0e11101010110e', 'S': '0f10100e01011e'}
    colors = [0x603030, 0x604020, 0x606020, 0x306030, 0x206060,
              0x203060, 0x403060, 0x603060, 0x604040, 0x505050]
    image = Image.new('RGB', (800, 600))
    for y in range(600):
        for x in range(800):
            value = colors[x//80]
            if x % 80 == 0 or y in (150, 300, 450): value = 0x909090
            if 540 <= y < 580:
                value = ((x % 256) << 16) | ((y % 256) << 8) | 0xa1 | ((x//256) << 3) | (((y//256) % 2) << 2)
            image.putpixel((x, y), ((value >> 16) & 255, (value >> 8) & 255, value & 255))

    def text(x, y, letters, scale, cell):
        for index, letter in enumerate(letters):
            bitmap = bytes.fromhex(glyphs.get(letter, '00'*7))
            for dy in range(7*scale):
                for dx in range(cell):
                    on = dx//scale < 5 and bitmap[dy//scale] & (1 << (4-dx//scale))
                    image.putpixel((x+index*cell+dx, y+dy), (255, 255, 255) if on else (16, 16, 24))
    for strip in range(10): text(strip*80+28, 40, str(strip), 4, 20)
    text(272, 260, 'C SVGA DVI'.ljust(16), 2, 16)
    text(272, 292, '800 X 600'.ljust(16), 2, 16)
    text(16, 500, 'LEFT 000', 2, 16)
    text(640, 500, 'RIGHT 799', 2, 16)
    image.paste((255, 0, 0), (0, 0, 8, 600)); image.paste((0, 255, 0), (792, 0, 800, 600))
    image.paste((0, 0, 255), (0, 0, 800, 8)); image.paste((255, 255, 0), (0, 592, 800, 600))
    return image


def main():
    out = ROOT/'build/video_svga_sim'; out.mkdir(parents=True, exist_ok=True)
    (out/'result.json').unlink(missing_ok=True)
    exe = Path('D:/2_hardware/ModelSim/win64')

    def run(tool, args, label):
        result = subprocess.run([str(exe/tool), *args], cwd=out, capture_output=True, text=True, timeout=300)
        log = result.stdout + result.stderr
        (out/(label+'.log')).write_text(log, encoding='utf-8')
        print(log[-1800:], flush=True)
        assert result.returncode == 0, label
        return log

    lib = Path('E:/1_software/TD/sim_release/eg4')
    models = [*lib.glob('eg_logic*.v'), lib/'eg_phy_glbl.v', lib/'eg_phy_pll.v']
    sources = ['src/diagnostic/video_svga_top.v', 'src/diagnostic/video_svga_pattern.v',
               'ip/clock/video_svga_pll.v', 'src/common/game_boot_reset.v', 'src/common/reset_sync.v',
               'src/video/osd_font.v', 'src/video/game_hdmi_channel.v', 'src/video/game_hdmi_terc.v',
               'ip/vendor/course/hdmi_phy_warpper.v', 'ip/vendor/course/lane_lvds_10_1.v',
               'test/hdmi_serial_capture.sv', 'test/tb_video_svga.sv']
    tracked = sources + ['script/test_video_svga.py', 'script/test_video_diagnostic.py']
    source_hashes = {p: hashlib.sha256((ROOT/p).read_bytes()).hexdigest() for p in tracked}
    run('vlib.exe', ['work'], 'library')
    run('vlog.exe', [*map(str, models), *[str(ROOT/p) for p in sources]], 'compile')
    golden = reference()
    golden.save(out/'expected.png')
    (out/'golden.hex').write_text(''.join('%02x%02x%02x\n' % p for p in golden.getdata()), encoding='ascii')
    for corrupt in (0, 1):
        name = 'negative' if corrupt else 'svga'
        log = run('vsim.exe', ['-c', '-onfinish', 'exit', 'work.tb_video_svga', 'work.glbl',
                  f'-gCORRUPT={corrupt}', '+GOLDEN=golden.hex', '+PPM='+name+'.ppm',
                  '+SERIAL_CAPTURE='+name+'_serial.txt', '-do', 'run -all; quit -f'], name)
        if corrupt:
            assert 'SVGA pixel mismatch' in log and 'PASS SVGA:' not in log, 'corrupt video undetected'
        else:
            assert 'PASS SVGA:' in log and '** Fatal:' not in log, 'SVGA pin/clock/frame check failed'
            actual = Image.open(out/'svga.ppm').convert('RGB')
            assert actual.size == golden.size and actual.tobytes() == golden.tobytes(), 'captured frame mismatch'
            actual.save(out/'svga.png')
    assert source_hashes == {p: hashlib.sha256((ROOT/p).read_bytes()).hexdigest() for p in tracked}, 'sources changed during simulation; rerun'
    (out/'result.json').write_text(json.dumps({
        'passed': True, 'pin_decoded_pixels': 960000, 'frames': 2, 'corrupt_rgb': 'detected',
        'source_hashes': source_hashes,
        'vendor_models': {str(p): hashlib.sha256(p.read_bytes()).hexdigest() for p in models},
        'limits': 'Functional PLL startup reset is forced in simulation. No physical monitor/analog capture; board verdict remains pending.'
    }, indent=2))
    print('PASS SVGA pixels from serializer pins, PLL frequencies, timing, KEY4; corrupt RGB rejected')


if __name__ == '__main__': main()
