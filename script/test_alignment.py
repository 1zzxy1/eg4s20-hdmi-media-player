"""Receiver-shift model against the real game raster, plus board controls."""
from pathlib import Path
import subprocess

ROOT = Path(__file__).resolve().parents[1]


def main():
    out = ROOT / 'build/alignment_sim'
    out.mkdir(parents=True, exist_ok=True)
    sources = sorted((ROOT / 'src/game').glob('*.v')) + [ROOT / 'src/video/osd_font.v']
    for name, actual, sink, negative in [
        ('tb_game_alignment', 0, 128, True),
        ('tb_game_alignment', 128, 128, False),
        ('tb_game_alignment', 0, 0, False),
        ('tb_game_alignment', 1, 1, False),
        ('tb_game_alignment', 639, 639, False),
        ('tb_game_alignment_controls', 0, 0, False),
    ]:
        label = f'{name}_{actual}_{sink}'
        exe = out / (label + '.vvp')
        params = [] if name.endswith('controls') else [
            f'-P{name}.ACTUAL_OFFSET={actual}', f'-P{name}.SINK_SHIFT={sink}']
        p = subprocess.run(['iverilog', '-g2012', '-Isrc/game', '-s', name,
                            *params, '-o', str(exe), *map(str, sources),
                            str(ROOT / 'test' / (name + '.sv'))], cwd=ROOT,
                           capture_output=True, text=True)
        (out / (label + '_compile.log')).write_text(p.stdout + p.stderr)
        p.check_returncode()
        p = subprocess.run(['vvp', str(exe)], cwd=ROOT, capture_output=True,
                           text=True, timeout=180)
        (out / (label + '.log')).write_text(p.stdout + p.stderr)
        print(p.stdout.strip(), flush=True)
        if negative:
            assert p.returncode != 0 and 'Wrapped pixel' in p.stdout, 'Negative control did not fail'
            print('PASS negative control: uncompensated sink wraps the actual raster', flush=True)
        else:
            assert p.returncode == 0 and 'PASS' in p.stdout, p.stderr


if __name__ == '__main__':
    main()
