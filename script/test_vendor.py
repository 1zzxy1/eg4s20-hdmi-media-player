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
    text=(ROOT/'ip/vendor/course/include/global_def.v').read_text()
    (out/'global_def.v').write_text(text.replace('1000000000/125000000','1000000000/40000000'))
    def command(name,args,timeout=240):
        r=subprocess.run([str(exe/name),*args],cwd=out,capture_output=True,text=True,timeout=timeout)
        (out/(name+'.log')).write_text(r.stdout+r.stderr,encoding='utf-8')
        print((r.stdout+r.stderr)[-2500:],flush=True)
        if r.returncode:raise SystemExit(name+' failed: '+str(r.returncode))
        return r.stdout+r.stderr
    command('vlib.exe',['work'])
    paths=[
      'src/memory/frame_read_write.v','src/memory/frame_fifo_read.v','src/memory/frame_fifo_write.v',
      'ip/vendor/course/IP/afifo_16_32_256.v','ip/vendor/course/IP/afifo_32_16_256.v',
      'src/video/video_timing_data.v','ip/vendor/course/SD/color_bar.v','ip/vendor/course/SD/video_delay.v',
      'ip/vendor/course/include/sdr_as_ram.enc.v','ip/vendor/course/include/sdr_wrrd.enc.v',
      'ip/sdram/sdr_init_ref.enc.v','src/memory/sdram.v','src/storage/bmp_sector_player.v','test/tb_frame_path.sv']
    command('vlog.exe',['-sv','+define+REAL_SDRAM'+('+BMP_SOURCE' if a.bmp else ''),'+incdir+.',
        '+incdir+'+(ROOT/'ip/vendor/course/SD').as_posix(),*[str(ROOT/x) for x in paths],
        str(ROOT/'test/sdram_array_model.sv')])
    log=command('vsim.exe',['-c','-onfinish','exit','work.tb_frame_path','-do','onbreak {quit -code 2 -f}; run -all; quit -f'])
    if 'PASS frame path with vendor encrypted SDRAM controller' not in log:raise SystemExit('No positive test receipt')
    (out/'result.json').write_text(json.dumps({'vendor_controller_frame_test':'pass',
        'device_array':'self-authored functional JEDEC model; not vendor or timing sign-off'}))
if __name__=='__main__':main()
