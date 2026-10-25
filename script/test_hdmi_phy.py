"""Exercise the unmodified HDMI serializer with the actual vendor ODDR model."""
from pathlib import Path
import hashlib
import json
import subprocess

ROOT = Path(__file__).resolve().parents[1]


def main():
    out = ROOT / 'build/hdmi_phy_sim'
    out.mkdir(parents=True, exist_ok=True)
    receipt = out / 'result.json'
    receipt.unlink(missing_ok=True)
    exe = Path('D:/2_hardware/ModelSim/win64')
    library = Path('E:/1_software/TD/sim_release/eg4')
    sources = [ROOT / name for name in (
        'ip/vendor/course/hdmi_phy_warpper.v',
        'ip/vendor/course/lane_lvds_10_1.v', 'test/tb_hdmi_phy.sv',
        'script/test_hdmi_phy.py', 'ip/clock/video_pll.v')]
    models = [library / name for name in (
        'eg_logic_io.v', 'eg_logic_clk.v', 'eg_phy_pll.v', 'eg_phy_glbl.v')]

    def run(tool, args, label):
        process = subprocess.run([str(exe / tool), *args], cwd=out,
                                 capture_output=True, text=True, timeout=60)
        log = process.stdout + process.stderr
        (out / (label + '.log')).write_text(log, encoding='utf-8')
        if process.returncode:
            raise RuntimeError(label + ' failed:\n' + log[-3000:])
        return log

    run('vlib.exe', ['work'], 'vlib')
    run('vlog.exe', [*map(str, models), *map(str, sources[:2]), str(sources[4])], 'vlog')
    run('vlog.exe', ['-sv', str(sources[2])], 'vlog_bench')
    cases = []
    for phase in (0, 1000, 3500):
        log = run('vsim.exe', ['-c', '-onfinish', 'exit',
                  'work.tb_hdmi_phy', 'work.glbl', '-gPHASE_PS=' + str(phase),
                  '-do', 'run -all; quit -f'], 'phase_' + str(phase))
        if 'PASS HDMI PHY:' not in log or '** Fatal:' in log:
            raise RuntimeError('No positive PHY receipt:\n' + log[-3000:])
        line = next(line for line in log.splitlines() if 'PASS HDMI PHY:' in line)
        print(line, flush=True)
        cases.append({'phase_ps': phase, 'resets': 2, 'result': 'pass'})
    for edge in (0, 1):
        log = run('vsim.exe', ['-c', '-onfinish', 'exit',
                  'work.tb_hdmi_phy', 'work.glbl', '-gUSE_PLL=1',
                  '-gTX_POSEDGE=' + str(edge),
                  '-do', 'run -all; quit -f'], 'pll_edge_' + str(edge))
        if 'PASS HDMI PHY: pll=1' not in log or '** Fatal:' in log:
            raise RuntimeError('PLL-to-PHY regression failed:\n' + log[-3000:])
        print(next(line for line in log.splitlines() if 'PASS HDMI PHY:' in line), flush=True)
        cases.append({'clock': 'vendor_video_pll_model', 'tx_posedge': bool(edge),
                      'resets': 2, 'result': 'pass'})
    for fault in (1, 2):
        log = run('vsim.exe', ['-c', '-onfinish', 'exit',
                  'work.tb_hdmi_phy', 'work.glbl', '-gFAULT=' + str(fault),
                  '-do', 'run -all; quit -f'], 'negative_' + str(fault))
        if 'PHY acquisition mismatch' not in log or 'PASS HDMI PHY:' in log:
            raise RuntimeError('PHY negative control did not detect injected fault')
    receipt.write_text(json.dumps({
        'serializer': 'pass', 'cases': cases,
        'negative_controls': ['reversed_lane_bits', 'swapped_lanes'],
        'source_hashes': {p.relative_to(ROOT).as_posix(): hashlib.sha256(p.read_bytes()).hexdigest()
                          for p in sources},
        'vendor_models': {str(p): hashlib.sha256(p.read_bytes()).hexdigest() for p in models},
        'limits': 'synthetic parallel words, ideal phase cases and vendor functional PLL model; no routed delays, analog IO, board or display'
    }, indent=2), encoding='utf-8')
    print('PASS HDMI PHY negative controls: reversed bits and swapped lanes', flush=True)


if __name__ == '__main__':
    main()
