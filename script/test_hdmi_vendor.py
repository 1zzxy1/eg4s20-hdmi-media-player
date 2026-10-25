"""Deployed vendor HDMI backend (or --direct comparison) and PHY simulation."""
from pathlib import Path
import argparse,subprocess,json,hashlib,sys
ROOT=Path(__file__).resolve().parents[1]
def main():
    parser=argparse.ArgumentParser(description=__doc__)
    backends=parser.add_mutually_exclusive_group()
    backends.add_argument('--direct',dest='direct',action='store_true',help='Test the retained direct packetizer')
    backends.add_argument('--vendor',dest='direct',action='store_false',help='Test the deployed vendor core (default)')
    parser.set_defaults(direct=False)
    args=parser.parse_args()
    direct=int(args.direct)
    tail='3' if direct else '1'
    backend='direct' if direct else 'vendor'
    out=ROOT/('build/hdmi_sim' if direct else 'build/hdmi_vendor_sim');out.mkdir(parents=True,exist_ok=True)
    # A failed rerun must not leave an older successful receipt behind.
    (out/'result.json').unlink(missing_ok=True)
    exe=Path('D:/2_hardware/ModelSim/win64')
    def run(name,args,timeout=240,label=None):
        p=subprocess.run([str(exe/name),*args],cwd=out,capture_output=True,text=True,timeout=timeout)
        (out/((label or name)+'.log')).write_text(p.stdout+p.stderr,encoding='utf-8')
        print((p.stdout+p.stderr)[-2000:],flush=True)
        assert p.returncode==0,name+' failed'
        return p.stdout+p.stderr
    run('vlib.exe',['work'])
    names=['src/video/advanced_video.v','src/control/video_controls.v','src/audio/audio_scope.v','src/video/osd_font.v','src/audio/pcm48_tone.v',
        'src/video/video_timing_data.v','ip/vendor/course/SD/color_bar.v','ip/vendor/course/SD/video_delay.v',
        'src/video/video_rgb_to_axis_640x480.v','ip/vendor/course/startup_pulse.v',
        'src/video/game_hdmi_output.v','src/video/game_hdmi_tx.v','src/video/game_hdmi_channel.v','src/video/game_hdmi_terc.v',
        'ip/vendor/course/hdmi1.4b_transmitter_core/hdmi_1_4b_transmitter_core_wrapper.enc.v',
        'ip/vendor/course/hdmi_phy_warpper.v','ip/vendor/course/lane_lvds_10_1.v','test/tb_hdmi_vendor.sv']
    game_names=['src/game/game_video.v','src/game/game_scene_text.v','src/game/game_hud_decimal.v',
        'src/game/game_reward_fx.v','src/game/game_menu_video.v',
        'src/game/game_alignment_pattern.v','test/tb_hdmi_game_pipeline.sv']
    media_names=['src/audio/sd_pcm_player.v','src/audio/audio_sector_bridge.v',
        'src/storage/sd_sector_arbiter.v','test/tb_hdmi_sd_audio.sv']
    lib=Path('E:/1_software/TD/sim_release/eg4')
    run('vlog.exe',['+incdir+'+(ROOT/'ip/vendor/course/SD').as_posix(),
        *[str(ROOT/n) for n in names],*[str(p) for p in lib.glob('eg_logic*.v')],str(lib/'eg_phy_glbl.v')])
    # Protected vendor RTL uses Verilog identifiers reserved in SystemVerilog.
    run('vlog.exe',['-sv','+incdir+'+(ROOT/'src/game').as_posix(),
        *[str(ROOT/n) for n in game_names+media_names+['test/hdmi_serial_capture.sv']]],label='vlog_game')
    log=run('vsim.exe',['-c','-onfinish','exit','work.tb_hdmi_vendor','work.glbl','-gDIRECT='+str(direct),
        '-gEDID_START='+str(1-direct),
        '+SERIAL_CAPTURE=audio_tone_serial.txt','-do','run -all; quit -f'])
    assert 'PASS vendor HDMI:' in log,'No positive HDMI receipt'
    assert 'PASS HDMI serial pins: words=2099981' in log,'No complete HDMI serial receipt'
    # Decode the selected transmitter's data islands, including IEC 60958
    # audio samples.  This is receiver-side evidence for the 48 kHz baseline.
    audio_results={}
    def decode_audio(label,options):
        captures=[out/(label+'_symbols.txt'),out/(label+'_input.txt')]
        result=subprocess.run([sys.executable,str(ROOT/'script/check_hdmi_audio.py'),
            *map(str,captures),'--tail',tail,*options],cwd=ROOT,capture_output=True,text=True,timeout=30)
        (out/(label+'_decode.log')).write_text(result.stdout+result.stderr,encoding='utf-8')
        assert result.returncode==0,'HDMI audio data-island decode failed: '+result.stderr[-1000:]
        audio_results[label]=json.loads(result.stdout)
        audio_results[label]['capture_sha256']={p.name:hashlib.sha256(p.read_bytes()).hexdigest() for p in captures}
        print('PASS '+label+': '+str(audio_results[label]['decoded_samples'])+' decoded PCM samples',flush=True)
    decode_audio('audio_tone',['--tone'])
    # An asymmetric, changing stereo stream catches channel swaps, stale FIFO
    # data, and duplicated samples that a periodic square wave could hide.
    log=run('vsim.exe',['-c','-onfinish','exit','work.tb_hdmi_vendor','work.glbl','-gDIRECT='+str(direct),'-gAUDIO_PATTERN=1',
        '-gEDID_START='+str(1-direct),
        '+SERIAL_CAPTURE=audio_stereo_serial.txt',
        '-do','run -all; quit -f'],label='audio_stereo')
    assert 'PASS vendor HDMI:' in log,'No positive stereo HDMI receipt'
    assert 'PASS HDMI serial pins: words=2099981' in log,'No complete stereo serial receipt'
    decode_audio('audio_stereo',['--negative-controls'])
    serial_results={}
    def decode_serial(label,options):
        capture=out/(label+'_serial.txt')
        # Independently verify the entire recovered trace, including blanking,
        # video, guards and data islands, not just the decoded audio packets.
        expected_cycle=20
        with capture.open(encoding='ascii') as serial, (out/(label+'_symbols.txt')).open(encoding='ascii') as parallel:
            reference=next(parallel)
            while int(reference.split(' ',1)[0])<expected_cycle:
                reference=next(parallel)
            for line in serial:
                assert int(line.split(' ',1)[0])==expected_cycle,'Serial capture cycle gap'
                assert line==reference,'Serial capture differs from parallel symbols'
                expected_cycle+=1
                reference=next(parallel,'')
        assert expected_cycle==2100001,'Incomplete serialized symbol trace'
        result=subprocess.run([sys.executable,str(ROOT/'script/check_hdmi_audio.py'),
            str(capture),str(out/(label+'_input.txt')),'--tail',tail,*options],cwd=ROOT,
            capture_output=True,text=True,timeout=30)
        (out/(label+'_serial_decode.log')).write_text(result.stdout+result.stderr,encoding='utf-8')
        assert result.returncode==0,'Serialized HDMI audio decode failed: '+result.stderr[-1000:]
        serial_results[label]=json.loads(result.stdout)
        serial_results[label]['symbol_words']=2099981
        serial_results[label]['capture_sha256']=hashlib.sha256(capture.read_bytes()).hexdigest()
        print('PASS '+label+' serial pins: '+str(serial_results[label]['decoded_samples'])+' decoded PCM samples',flush=True)
    decode_serial('audio_tone',['--tone'])
    decode_serial('audio_stereo',[])
    result=subprocess.run([sys.executable,str(ROOT/'script/test_hdmi_phy.py')],cwd=ROOT,
        capture_output=True,text=True,timeout=90)
    (out/'serializer_cases.log').write_text(result.stdout+result.stderr,encoding='utf-8')
    assert result.returncode==0,'Serializer phase/reset regression failed: '+result.stderr[-1000:]
    serializer_cases=json.loads((ROOT/'build/hdmi_phy_sim/result.json').read_text(encoding='utf-8'))
    image=ROOT/'build/media/game-audio-v4.img'
    log=run('vsim.exe',['-c','-onfinish','exit','work.tb_hdmi_sd_audio','work.glbl','-gDIRECT='+str(direct),
        '+IMAGE='+image.as_posix(),'+SERIAL_CAPTURE=audio_sd_serial.txt','-do','run -all; quit -f'],label='audio_sd')
    assert 'PASS SD HDMI audio:' in log,'No positive SD-to-HDMI receipt'
    assert 'PASS HDMI serial pins: words=2099981' in log,'No complete SD audio serial receipt'
    result=subprocess.run([sys.executable,str(ROOT/'script/check_sd_audio_capture.py'),str(out),'--tail',tail],
        cwd=ROOT,capture_output=True,text=True,timeout=40)
    (out/'audio_sd_decode.log').write_text(result.stdout+result.stderr,encoding='utf-8')
    assert result.returncode==0,'SD-to-HDMI reference decode failed: '+result.stderr[-2000:]
    media_result=json.loads(result.stdout)
    media_result['capture_sha256']={p.name:hashlib.sha256(p.read_bytes()).hexdigest()
        for p in out.glob('audio_sd_*.txt')}
    print('PASS actual media SD-to-HDMI: '+str(media_result['media_pcm_samples'])+' reference samples',flush=True)
    decode_serial('audio_sd',[])
    for calibration in (0,1):
        log=run('vsim.exe',['-c','-onfinish','exit','work.tb_hdmi_game_pipeline','-gDIRECT='+str(direct),
            '-gCALIBRATION='+str(calibration),'-gSTABILITY='+str(1-calibration),
            '-do','run -all; quit -f'],label='pipeline_'+str(calibration))
        assert 'PASS HDMI game pipeline:' in log,'No positive game pipeline receipt'
    log=run('vsim.exe',['-c','-onfinish','exit','work.tb_hdmi_game_pipeline','-gDIRECT='+str(direct),
        '-gGAMEPLAY=1','-do','run -all; quit -f'],label='pipeline_hud')
    assert 'PASS HDMI game pipeline: calibration=0 gameplay=1' in log,'No positive gameplay HUD receipt'
    log=run('vsim.exe',['-c','-onfinish','exit','work.tb_hdmi_game_pipeline','-gDIRECT='+str(direct),
        '-gGAMEPLAY=1','-gALIGN_ENABLE=1','-gALIGN_OFFSET=128',
        '-do','run -all; quit -f'],label='pipeline_aligned')
    assert 'PASS HDMI game pipeline: calibration=0 gameplay=1' in log,'No aligned game HDMI receipt'
    log=run('vsim.exe',['-c','-onfinish','exit','work.tb_hdmi_game_pipeline','-gDIRECT='+str(direct),
        '-gINJECT_SHIFT=1','-do','run -all; quit -f'],label='pipeline_negative')
    assert 'pipeline pixel mismatch calibration=0 x=0 y=0' in log,'Pixel shift negative control was not detected at the left edge'
    assert 'PASS HDMI game pipeline:' not in log,'Negative control unexpectedly passed'
    # The vendor core regenerates sync from SOF/rows. These two injected
    # source-sync faults apply only to the direct pass-through backend.
    if direct:
        check_direct_sync(run)
    (out/'result.json').write_text(json.dumps({'backend':backend,'hdmi':'pass','game_pipeline':'pass',
        'calibration_edges':'pass','gameplay_hud':'pass','manual_alignment_128':'pass','pixel_shift_negative':'detected',
        'sync_shift_negative':'detected' if direct else 'not applicable: regenerated sync',
        'island_sync_negative':'detected' if direct else 'not applicable: protected core',
        'audio_data_islands':audio_results,
        'serial_pin_audio':serial_results,'serializer_cases':serializer_cases,
        'sd_audio_pipeline':media_result,
        'source_hashes':{name:hashlib.sha256((ROOT/name).read_bytes()).hexdigest()
            for name in names+game_names+media_names+['src/game/game_assets.vh','script/test_hdmi_vendor.py',
                'test/hdmi_serial_capture.sv','test/tb_hdmi_phy.sv','script/test_hdmi_phy.py',
                'script/check_hdmi_audio.py','script/check_sd_audio_capture.py','script/pack_game_audio.py']},
        'edid_startup':'DDC activity without a responding sink' if not direct else 'not applicable',
        'limits':'digital video/audio and card-image byte endpoint; no SD command/electrical IO, game-event generation, analog PHY, responding EDID sink, physical sink or complete HDMI conformance'}))

def check_direct_sync(run):
    log=run('vsim.exe',['-c','-onfinish','exit','work.tb_hdmi_game_pipeline','-gDIRECT=1',
        '-gINJECT_HS_SHIFT=1','-do','run -all; quit -f'],label='pipeline_sync_negative')
    assert 'HDMI horizontal back porch' in log,'Horizontal sync shift was not detected'
    assert 'PASS HDMI game pipeline:' not in log,'Sync negative control unexpectedly passed'
    log=run('vsim.exe',['-c','-onfinish','exit','work.tb_hdmi_game_pipeline','-gDIRECT=1',
        '-gINJECT_ISLAND_SYNC=1','-do','run -all; quit -f'],label='pipeline_island_sync_negative')
    assert 'HDMI blanking sync mismatch' in log,'Island-only sync corruption was not detected'
    assert 'PASS HDMI game pipeline:' not in log,'Island sync negative control unexpectedly passed'
if __name__=='__main__':main()
