from pathlib import Path
import subprocess
import json

ROOT = Path(__file__).resolve().parents[1]
TESTS = {
    'audio': ['src/audio/pcm48_tone.v'],
    'audio_controls': ['src/control/audio_controls.v'],
    'axis': ['src/video/video_rgb_to_axis_640x480.v'],
    'commit': ['src/memory/frame_commit_bridge.v'],
    'bmp': ['src/reference/bmp_read.v'],
    'effects': ['src/video/video_effects.v'],
    'frame_write': ['src/memory/frame_fifo_write.v'],
    'transition': ['src/video/transition_control.v','src/memory/frame_commit_bridge.v'],
    'scope': ['src/audio/audio_scope.v'],
    'controls': ['src/control/video_controls.v'],
    'caption_rom': ['src/video/caption_rom.v'],
    'lab_ui': ['src/video/advanced_video.v','src/video/caption_rom.v','src/control/video_controls.v',
        'src/audio/audio_scope.v','src/video/osd_font.v','src/game/game_menu_video.v'],
    'image_cache': ['src/storage/image_cache_controller.v'],
    'loader_cache': ['src/storage/sd_card_bmp.v','src/storage/sd_sector_arbiter.v','src/storage/bmp_sector_player.v','src/storage/image_cache_controller.v'],
    'loader_recovery': ['src/storage/sd_card_bmp.v','src/storage/sd_sector_arbiter.v','src/storage/bmp_sector_player.v','src/storage/image_cache_controller.v'],
    'frame_path': ['src/memory/frame_read_write.v','src/memory/frame_fifo_read.v',
        'src/memory/frame_fifo_write.v','ip/vendor/course/IP/afifo_16_32_256.v','ip/vendor/course/IP/afifo_32_16_256.v',
        'src/video/video_timing_data.v','ip/vendor/course/SD/color_bar.v','ip/vendor/course/SD/video_delay.v'],
}

def main():
    out = ROOT/'build/sim'
    out.mkdir(parents=True, exist_ok=True)
    results=[]
    for name, sources in TESTS.items():
        exe = out/(name+'.vvp')
        compiled=subprocess.run(['iverilog','-g2012','-Wall','-Iip/vendor/course/SD','-s','tb_'+name,'-o',str(exe),
                        *sources,'test/tb_'+name+'.sv'],cwd=ROOT,capture_output=True,text=True)
        (out/(name+'_compile.log')).write_text(compiled.stdout+compiled.stderr)
        compiled.check_returncode()
        # The full-frame FIFO/DMA bench schedules nearly 200 million events.
        # Keep its wall-clock budget separate from the small unit benches.
        timeout=300 if name=='frame_path' else 120
        try:
            result=subprocess.run(['vvp',str(exe)],cwd=ROOT,capture_output=True,text=True,timeout=timeout)
        except subprocess.TimeoutExpired as error:
            def decoded(value):
                return value.decode(errors='replace') if isinstance(value,bytes) else value or ''
            message=f'TIMEOUT {name} after {timeout} seconds'
            (out/(name+'.log')).write_text(decoded(error.stdout)+decoded(error.stderr)+'\n'+message+'\n')
            results.append({'test':name,'passed':False,'error':message})
            (out/'results.json').write_text(json.dumps(results,indent=2))
            raise SystemExit(message) from error
        (out/(name+'.log')).write_text(result.stdout+result.stderr)
        passed=result.returncode==0 and 'PASS ' in result.stdout
        results.append({'test':name,'passed':passed})
        (out/'results.json').write_text(json.dumps(results,indent=2))
        print(result.stdout.strip(),flush=True)
        if not passed:raise SystemExit('FAILED '+name)
    print(f'PASS {len(TESTS)} testbenches')

if __name__ == '__main__': main()
