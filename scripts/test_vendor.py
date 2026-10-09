"""Use installed ModelSim to compile/run real protected RTL; never decrypt or replace it."""
from pathlib import Path
import subprocess,argparse,shutil,json
ROOT=Path(__file__).resolve().parents[1]
def main():
    p=argparse.ArgumentParser()
    p.add_argument('--modelsim',default='D:/2_hardware/ModelSim/win64')
    p.add_argument('--td',default='E:/1_software/TD')
    p.add_argument('--bmp',action='store_true')
    a=p.parse_args();exe=Path(a.modelsim);out=ROOT/('build/vendor_bmp_sim' if a.bmp else 'build/vendor_sim');out.mkdir(parents=True,exist_ok=True)
    # Build-local header selects the same 40 MHz refresh interval as synthesis.
    text=(ROOT/'vendor/course/include/global_def.v').read_text()
    (out/'global_def.v').write_text(text.replace('1000000000/125000000','1000000000/40000000'))
    def command(name,args,timeout=240):
        r=subprocess.run([str(exe/name),*args],cwd=out,capture_output=True,text=True,timeout=timeout)
        (out/(name+'.log')).write_text(r.stdout+r.stderr,encoding='utf-8')
        print((r.stdout+r.stderr)[-2500:],flush=True)
        if r.returncode:raise SystemExit(name+' failed: '+str(r.returncode))
        return r.stdout+r.stderr
    command('vlib.exe',['work'])
    paths=[
      'rtl/reference/SD/frame_read_write.v','rtl/reference/SD/frame_fifo_read.v','rtl/reference/SD/frame_fifo_write.v',
      'vendor/course/IP/afifo_16_32_256.v','vendor/course/IP/afifo_32_16_256.v',
      'rtl/reference/SD/video_timing_data.v','vendor/course/SD/color_bar.v','vendor/course/SD/video_delay.v',
      'vendor/course/include/sdr_as_ram.enc.v','vendor/course/include/sdr_wrrd.enc.v',
      'rtl/reference/include/sdr_init_ref.enc.v','rtl/reference/SD/sdram.v','rtl/bmp_sector_player.v','sim/tb_frame_path.sv']
    command('vlog.exe',['-sv','+define+REAL_SDRAM'+('+BMP_SOURCE' if a.bmp else ''),'+incdir+.',
        '+incdir+'+(ROOT/'vendor/course/SD').as_posix(),*[str(ROOT/x) for x in paths],
        str(ROOT/'sim/sdram_array_model.sv')])
    log=command('vsim.exe',['-c','-onfinish','exit','work.tb_frame_path','-do','onbreak {quit -code 2 -f}; run -all; quit -f'])
    if 'PASS frame path with vendor encrypted SDRAM controller' not in log:raise SystemExit('No positive test receipt')
    (out/'result.json').write_text(json.dumps({'vendor_controller_frame_test':'pass',
        'device_array':'self-authored functional JEDEC model; not vendor or timing sign-off'}))
if __name__=='__main__':main()
