from pathlib import Path
import subprocess
import json

ROOT = Path(__file__).resolve().parents[1]
TESTS = {
    'audio': ['rtl/pcm48_tone.v'],
    'axis': ['rtl/reference/video_rgb_to_axis_640x480.v'],
    'commit': ['rtl/frame_commit_bridge.v'],
    'bmp': ['rtl/reference/SD/bmp_read.v'],
    'effects': ['rtl/video_effects.v'],
    'frame_write': ['rtl/reference/SD/frame_fifo_write.v'],
    'transition': ['rtl/transition_control.v','rtl/frame_commit_bridge.v'],
    'scope': ['rtl/audio_scope.v'],
    'controls': ['rtl/video_controls.v'],
    'loader_recovery': ['rtl/reference/SD/sd_card_bmp.v','rtl/bmp_sector_player.v'],
    'frame_path': ['rtl/reference/SD/frame_read_write.v','rtl/reference/SD/frame_fifo_read.v',
        'rtl/reference/SD/frame_fifo_write.v','vendor/course/IP/afifo_16_32_256.v','vendor/course/IP/afifo_32_16_256.v',
        'rtl/reference/SD/video_timing_data.v','vendor/course/SD/color_bar.v','vendor/course/SD/video_delay.v'],
}

def main():
    out = ROOT/'build/sim'
    out.mkdir(parents=True, exist_ok=True)
    results=[]
    for name, sources in TESTS.items():
        exe = out/(name+'.vvp')
        compiled=subprocess.run(['iverilog','-g2012','-Wall','-Ivendor/course/SD','-s','tb_'+name,'-o',str(exe),
                        *sources,'sim/tb_'+name+'.sv'],cwd=ROOT,capture_output=True,text=True)
        (out/(name+'_compile.log')).write_text(compiled.stdout+compiled.stderr)
        compiled.check_returncode()
        result=subprocess.run(['vvp',str(exe)],cwd=ROOT,capture_output=True,text=True,timeout=120)
        (out/(name+'.log')).write_text(result.stdout+result.stderr)
        passed=result.returncode==0 and 'PASS ' in result.stdout
        results.append({'test':name,'passed':passed})
        (out/'results.json').write_text(json.dumps(results,indent=2))
        print(result.stdout.strip(),flush=True)
        if not passed:raise SystemExit('FAILED '+name)
    print(f'PASS {len(TESTS)} testbenches')

if __name__ == '__main__': main()
