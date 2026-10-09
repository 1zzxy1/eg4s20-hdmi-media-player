"""Protected HDMI + vendor RAM/FIFO simulation, using installed ModelSim."""
from pathlib import Path
import subprocess,json
ROOT=Path(__file__).resolve().parents[1]
def main():
    out=ROOT/'build/hdmi_sim';out.mkdir(parents=True,exist_ok=True)
    exe=Path('D:/2_hardware/ModelSim/win64')
    def run(name,args,timeout=240):
        p=subprocess.run([str(exe/name),*args],cwd=out,capture_output=True,text=True,timeout=timeout)
        (out/(name+'.log')).write_text(p.stdout+p.stderr,encoding='utf-8')
        print((p.stdout+p.stderr)[-2000:],flush=True)
        assert p.returncode==0,name+' failed'
        return p.stdout+p.stderr
    run('vlib.exe',['work'])
    names=['rtl/advanced_video.v','rtl/video_controls.v','rtl/audio_scope.v','rtl/osd_font.v','rtl/pcm48_tone.v',
        'rtl/reference/SD/video_timing_data.v','vendor/course/SD/color_bar.v',
        'rtl/reference/video_rgb_to_axis_640x480.v',
        'vendor/course/hdmi1.4b_transmitter_core/hdmi_1_4b_transmitter_core_wrapper.enc.v','sim/tb_hdmi_vendor.sv']
    lib=Path('E:/1_software/TD/sim_release/eg4')
    run('vlog.exe',['+incdir+'+(ROOT/'vendor/course/SD').as_posix(),
        *[str(ROOT/n) for n in names],*[str(p) for p in lib.glob('eg_logic*.v')],str(lib/'eg_phy_glbl.v')])
    log=run('vsim.exe',['-c','-onfinish','exit','work.tb_hdmi_vendor','-do','run -all; quit -f'])
    assert 'PASS vendor HDMI:' in log,'No positive HDMI receipt'
    (out/'result.json').write_text(json.dumps({'protected_hdmi':'pass','limits':'digital symbol/interface test, no analog PHY or audio packet decoder'}))
if __name__=='__main__':main()
