"""Check both board diagnostic transports against an independent frame image."""
from pathlib import Path
import hashlib
import json
import subprocess
from PIL import Image

ROOT = Path(__file__).resolve().parents[1]
GLYPHS = dict(zip('0123456789', [
    '0e11131519110e','040c040404040e','0e11010204081f','1e01010601011e','02060a121f0202',
    '1f101e0101110e','0608101e11110e','1f010204080808','0e11110e11110e','0e11110f01020c']))
GLYPHS.update(dict(zip('ABDEFGHILMNOPRTUVX', [
    '0e11111f111111','1e11111e11111e','1e11111111111e','1f10101e10101f','1f10101e101010',
    '0e11101711110f','1111111f111111','0e04040404040e','1010101010101f','111b1515111111',
    '11191513111111','0e11111111110e','1e11111e101010','1e11111e141211','1f040404040404',
    '1111111111110e','11111111110a04','11110a040a1111'])))


def reference(dvi):
    colors = [0x603030,0x604020,0x606020,0x306030,0x206060,0x203060,0x403060,0x603060,0x604040,0x505050]
    image = Image.new('RGB', (640, 480))
    for y in range(480):
        for x in range(640):
            value = colors[x//64]
            if x%64 == 0 or y in (120,240,360): value=0x909090
            if 432 <= y < 464: value=((x%256)<<16)|((y%256)<<8)|0xa1|((x//256)<<3)|((y//256)<<2)
            image.putpixel((x,y), ((value>>16)&255,(value>>8)&255,value&255))
    def text(x,y,letters,scale,cell):
        for index,letter in enumerate(letters):
            bitmap=bytes.fromhex(GLYPHS.get(letter,'00'*7))
            for dy in range(7*scale):
                for dx in range(cell):
                    on=dx//scale<5 and bitmap[dy//scale]&(1<<(4-dx//scale))
                    image.putpixel((x+index*cell+dx,y+dy),(255,255,255) if on else (16,16,24))
    for strip in range(10):text(strip*64+20,32,str(strip),4,20)
    text(192,208,('B PURE DVI' if dvi else 'A VENDOR HDMI').ljust(16),2,16)
    text(192,240,'640 X 480'.ljust(16),2,16)
    text(16,400,'LEFT 000',2,16);text(480,400,'RIGHT 639',2,16)
    image.paste((255,0,0),(0,0,8,480));image.paste((0,255,0),(632,0,640,480))
    image.paste((0,0,255),(0,0,640,8));image.paste((255,255,0),(0,472,640,480))
    return image


def main():
    out=ROOT/'build/video_diagnostic_sim';out.mkdir(parents=True,exist_ok=True)
    (out/'result.json').unlink(missing_ok=True)
    exe=Path('D:/2_hardware/ModelSim/win64')
    def run(tool,args,label,timeout=240):
        result=subprocess.run([str(exe/tool),*args],cwd=out,capture_output=True,text=True,timeout=timeout)
        log=result.stdout+result.stderr;(out/(label+'.log')).write_text(log,encoding='utf-8')
        print(log[-1200:],flush=True)
        assert result.returncode==0,label
        return log
    sources=['src/diagnostic/video_diagnostic.v','src/diagnostic/video_diagnostic_pattern.v',
        'src/video/osd_font.v','src/video/game_hdmi_output.v','src/video/video_rgb_to_axis_640x480.v',
        'src/video/game_hdmi_channel.v','src/video/game_hdmi_terc.v','ip/vendor/course/startup_pulse.v',
        'ip/vendor/course/hdmi1.4b_transmitter_core/hdmi_1_4b_transmitter_core_wrapper.enc.v',
        'ip/vendor/course/hdmi_phy_warpper.v','ip/vendor/course/lane_lvds_10_1.v',
        'test/hdmi_serial_capture.sv','test/tb_video_diagnostic.sv']
    control_sources=['ip/clock/video_pll.v','src/common/game_boot_reset.v','src/common/reset_sync.v',
        'src/diagnostic/video_diagnostic_top.v','test/tb_video_diagnostic_controls.sv']
    run('vlib.exe',['work'],'library')
    lib=Path('E:/1_software/TD/sim_release/eg4')
    run('vlog.exe',[
        *map(str,lib.glob('eg_logic*.v')),str(lib/'eg_phy_glbl.v'),str(lib/'eg_phy_pll.v'),
        *[str(ROOT/p) for p in sources+control_sources]],'compile')
    results=[]
    for dvi in (0,1):
        name='dvi' if dvi else 'hdmi';golden=reference(dvi)
        (out/(name+'.hex')).write_text(''.join('%02x%02x%02x\n'%pixel for pixel in golden.getdata()),encoding='ascii')
        log=run('vsim.exe',['-c','-onfinish','exit','work.tb_video_diagnostic','work.glbl',f'-gDVI={dvi}',
            '+GOLDEN='+name+'.hex','+PPM='+name+'.ppm','+SERIAL_CAPTURE='+name+'_serial.txt','-do','run -all; quit -f'],name)
        assert 'PASS video diagnostic' in log,name
        actual=Image.open(out/(name+'.ppm')).convert('RGB')
        assert actual.size==golden.size and actual.tobytes()==golden.tobytes(),name+' captured frame'
        actual.save(out/(name+'.png'));results.append({'mode':name,'passed':True})
    log=run('vsim.exe',['-c','-onfinish','exit','work.tb_video_diagnostic','work.glbl','-gCORRUPT=1',
        '+GOLDEN=hdmi.hex','+PPM=negative.ppm','+SERIAL_CAPTURE=negative_serial.txt','-do','run -all; quit -f'],'negative')
    assert 'diagnostic pixel mismatch' in log and 'PASS video diagnostic' not in log,'corrupt RGB not detected'
    log=run('vsim.exe',['-c','-onfinish','exit','work.tb_video_diagnostic_controls','work.glbl',
        '-do','run -all; quit -f'],'controls')
    assert 'PASS diagnostic board controls:' in log and '** Fatal:' not in log,'board controls failed'
    models=[*lib.glob('eg_logic*.v'),lib/'eg_phy_glbl.v',lib/'eg_phy_pll.v']
    (out/'result.json').write_text(json.dumps({'passed':True,'cases':results,'corrupt_rgb':'detected','board_controls':'pass',
        'source_hashes':{name:hashlib.sha256((ROOT/name).read_bytes()).hexdigest()
            for name in sources+control_sources+['script/test_video_diagnostic.py']},
        'vendor_models':{str(p):hashlib.sha256(p.read_bytes()).hexdigest() for p in models},
        'limits':'digital raster/transport/functional serializer; controls use a functional PLL with explicit simulation startup reset, no physical monitor or analog timing'},indent=2))
    print('PASS HDMI/DVI pixels, sync, serialization, board controls; corrupt RGB rejected')


if __name__=='__main__':main()
