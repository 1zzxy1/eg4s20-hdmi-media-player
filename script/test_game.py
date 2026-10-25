"""Self-checking game RTL tests; fail on missing benches or nonzero simulation."""
from pathlib import Path
import json
import subprocess

ROOT = Path(__file__).resolve().parents[1]


def main():
    out = ROOT / 'build/game_sim'
    out.mkdir(parents=True, exist_ok=True)
    benches = sorted((ROOT / 'test').glob('tb_game_*.sv'))
    assert benches, 'No game testbenches'
    sources = sorted((ROOT / 'src/game').glob('*.v'))
    sources += sorted((ROOT / 'src/audio').glob('*.v'))
    sources += [ROOT / p for p in ['src/storage/sd_sector_arbiter.v',
        'src/storage/game_asset_loader.v', 'src/storage/bmp_sector_player.v',
        'src/storage/game_score_flash.v', 'src/control/game_inputs.v',
        'src/control/game_debug_controls.v',
        'src/control/menu_media_controls.v',
        'src/common/game_boot_reset.v', 'src/video/osd_font.v']]
    results = []
    for bench in benches:
        name = bench.stem
        exe = out / (name + '.vvp')
        compiled = subprocess.run(['iverilog', '-g2012', '-Wall', '-Isrc/game',
            '-s', name, '-o', str(exe), *map(str, sources), str(bench)],
            cwd=ROOT, capture_output=True, text=True)
        (out / (name + '_compile.log')).write_text(compiled.stdout + compiled.stderr)
        compiled.check_returncode()
        # Twenty full rasters took over 300 s on the validation host (16
        # completed before timeout). Keep the full coverage and a finite
        # headroom budget; all other benches retain 180 s.
        timeout = 600 if name == 'tb_game_scene' else 180
        try:
            sim = subprocess.run(['vvp', str(exe)], cwd=ROOT, capture_output=True,
                                 text=True, timeout=timeout)
        except subprocess.TimeoutExpired as error:
            def decoded(value):
                return value.decode(errors='replace') if isinstance(value, bytes) else value or ''
            message = f'TIMEOUT {name} after {timeout} seconds'
            (out / (name + '.log')).write_text(
                decoded(error.stdout) + decoded(error.stderr) + '\n' + message + '\n')
            results.append({'test': name, 'passed': False, 'error': message})
            (out / 'results.json').write_text(json.dumps(results, indent=2))
            raise SystemExit(message) from error
        (out / (name + '.log')).write_text(sim.stdout + sim.stderr)
        passed = sim.returncode == 0 and 'PASS' in sim.stdout
        results.append({'test': name, 'passed': passed})
        (out / 'results.json').write_text(json.dumps(results, indent=2))
        print(sim.stdout.strip(), flush=True)
        if not passed:
            raise SystemExit('Failed ' + name + ': ' + sim.stderr)
    print(f'PASS {len(results)} game testbenches')


if __name__ == '__main__':
    main()
