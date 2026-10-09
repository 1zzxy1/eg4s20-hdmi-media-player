from pathlib import Path
import subprocess

ROOT = Path(__file__).resolve().parents[1]
TESTS = {
    'audio': ['rtl/pcm48_tone.v'],
    'axis': ['rtl/reference/video_rgb_to_axis_640x480.v'],
    'commit': ['rtl/frame_commit_bridge.v'],
    'bmp': ['rtl/reference/SD/bmp_read.v'],
    'effects': ['rtl/video_effects.v'],
    'frame_write': ['rtl/reference/SD/frame_fifo_write.v'],
}

def main():
    out = ROOT/'build/sim'
    out.mkdir(parents=True, exist_ok=True)
    for name, sources in TESTS.items():
        exe = out/(name+'.vvp')
        subprocess.run(['iverilog','-g2012','-Wall','-s','tb_'+name,'-o',str(exe),
                        *sources,'sim/tb_'+name+'.sv'],cwd=ROOT,check=True)
        subprocess.run(['vvp',str(exe)],cwd=ROOT,check=True,timeout=60)
    print(f'PASS {len(TESTS)} testbenches')

if __name__ == '__main__': main()
