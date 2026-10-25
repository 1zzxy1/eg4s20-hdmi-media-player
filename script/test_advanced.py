"""Independent golden-image verification; no encrypted-IP replacement is implied."""
from pathlib import Path
import subprocess,struct,json,time,argparse
ROOT=Path(__file__).resolve().parents[1]
OUT=ROOT/'build/advanced_sim'

def bmp(w,h,offset=54):
    stride=(w*3+3)&~3
    pixels=bytearray()
    for y in range(h):
        for x in range(w):pixels.extend(((x*7+y*11)&255,(x*3+y*17)&255,(x*19+y*5)&255))
        pixels.extend(b'\xa5'*(stride-w*3))
    header=struct.pack('<2sIHHI',b'BM',offset+len(pixels),0,0,offset)+struct.pack('<IiiHHIIiiII',40,w,h,1,24,0,len(pixels),0,0,0,0)
    return header+bytes(offset-54)+pixels

def golden_bmp(data,w,h,ow,oh):
    # Independent random access definition, no RTL accumulator algorithm.
    offset=struct.unpack_from('<I',data,10)[0];stride=(w*3+3)&~3
    rows=[]
    for y in range(oh):
        for x in range(ow):
            pos=offset+(y*h//oh)*stride+(x*w//ow)*3
            b,g,r=data[pos:pos+3];rows.append(f'{r:02x}{g:02x}{b:02x}\n')
    return ''.join(rows)

def run_case(w,h,ow=32,oh=24,offset=54,bad=False,short=False,silent=False,negative=False,corruption='',scaling=True):
    name=f'bmp_{w}_{h}_{ow}_{oh}_{offset}_{int(bad)}{int(short)}{int(silent)}{int(negative)}_{corruption}_{int(scaling)}'
    data=bmp(w,h,offset);gold=golden_bmp(data,w,h,ow,oh)
    if bad:data=data[:28]+b'\x10\x00'+data[30:]
    if corruption:
        changes={'width_zero':(18,0),'height_negative':(22,0xffffffff),'width_over':(18,1921),
                 'compression':(30,1),'offset_small':(10,40),'length_short':(2,55),'dib':(14,125)}
        at,value=changes[corruption];data=bytearray(data);struct.pack_into('<I',data,at,value);data=bytes(data)
        bad=True
    if not scaling and (w,h)!=(ow,oh):bad=True
    data+=bytes((-len(data))%512)
    image=OUT/(name+'.hex');expected=OUT/(name+'.rgb');exe=OUT/(name+'.vvp')
    image.write_text(''.join(f'{b:02x}\n' for b in data));expected.write_text(gold)
    cmd=['iverilog','-g2012','-s','tb_scaled_bmp',f'-Ptb_scaled_bmp.W={ow}',f'-Ptb_scaled_bmp.H={oh}',
         f'-Ptb_scaled_bmp.FILE_BYTES={len(data)}',f'-Ptb_scaled_bmp.SCALING={int(scaling)}','-o',str(exe),'src/storage/bmp_sector_player.v','test/tb_scaled_bmp.sv']
    subprocess.run(cmd,cwd=ROOT,check=True,capture_output=True)
    result=subprocess.run(['vvp',str(exe),f'+IMAGE={image.as_posix()}',f'+GOLDEN={expected.as_posix()}',
        f'+BAD={int(bad)}',f'+SHORT={int(short)}',f'+SILENT={int(silent)}',f'+NEGATIVE={int(negative)}'],
        cwd=ROOT,text=True,capture_output=True,timeout=180)
    (OUT/(name+'.log')).write_text(result.stdout+result.stderr)
    if negative:
        assert result.returncode!=0 and 'pixel ' in result.stdout,'Negative control failed to detect corrupt pixel'
    else: assert result.returncode==0 and 'PASS scaled' in result.stdout,result.stdout+result.stderr
    print(('PASS detector rejected corruption' if negative else result.stdout.strip()),name)
    return {'case':name,'passed':True,'negative_control':negative}

def run_asset(path):
    """Compare every output pixel of the actual demo BMP, not a synthetic image."""
    from PIL import Image
    data=path.read_bytes();w,h=struct.unpack_from('<ii',data,18)
    golden=golden_bmp(data,w,h,640,480)
    name='asset_'+path.stem
    data+=bytes((-len(data))%512)
    image=OUT/(name+'.hex');expected=OUT/(name+'.rgb');exe=OUT/(name+'.vvp')
    image.write_text(''.join(f'{b:02x}\n' for b in data));expected.write_text(golden)
    subprocess.run(['iverilog','-g2012','-s','tb_scaled_bmp','-Ptb_scaled_bmp.W=640',
        '-Ptb_scaled_bmp.H=480',f'-Ptb_scaled_bmp.FILE_BYTES={len(data)}','-o',str(exe),
        'src/storage/bmp_sector_player.v','test/tb_scaled_bmp.sv'],cwd=ROOT,check=True,capture_output=True)
    result=subprocess.run(['vvp',str(exe),f'+IMAGE={image.as_posix()}',f'+GOLDEN={expected.as_posix()}'],
        cwd=ROOT,text=True,capture_output=True,timeout=180)
    (OUT/(name+'.log')).write_text(result.stdout+result.stderr)
    assert result.returncode==0 and 'PASS scaled' in result.stdout,result.stdout+result.stderr
    # Golden pixels are in the loader's bottom-up DMA order; show them upright.
    Image.frombytes('RGB',(640,480),bytes.fromhex(golden)).transpose(Image.Transpose.FLIP_TOP_BOTTOM).save(OUT/(name+'.png'))
    print(result.stdout.strip(),name,flush=True)
    return {'case':name,'input_size':[w,h],'output_pixels':640*480,'passed':True}

def main():
    OUT.mkdir(parents=True,exist_ok=True)
    cases=[(1,1),(3,2),(319,241),(641,479),(800,600),(1920,1440)]
    results=[]
    for w,h in cases:results.append(run_case(w,h))
    results.append(run_case(3,2,640,480))
    results.append(run_case(640,480,640,480))
    results.append(run_case(7,5,offset=510))
    for flag in ['bad','short','silent','negative']:results.append(run_case(3,2,**{flag:True}))
    for corruption in ['width_zero','height_negative','width_over','compression','offset_small','length_short','dib']:
        results.append(run_case(3,2,corruption=corruption))
    results.append(run_case(3,2,scaling=False));results.append(run_case(32,24,scaling=False))
    results.append(run_case(640,480,short=2))
    for path in [ROOT/'assets/game/atlas.bmp',*sorted((ROOT/'assets/game').glob('preview_*.bmp'))]:
        results.append(run_asset(path))
    (OUT/'bmp_results.json').write_text(json.dumps(results,indent=2))
    print(f'PASS {len(results)} scaled BMP cases (sector-interface model, not SD SPI/IP verification)')
if __name__=='__main__':main()
