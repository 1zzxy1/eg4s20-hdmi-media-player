"""Fail-closed software acceptance suite. Hardware/analog validation is separate."""
from pathlib import Path
import subprocess,sys,json,hashlib,time
ROOT=Path(__file__).resolve().parents[1]
def main():
    out=ROOT/'build/verification';out.mkdir(parents=True,exist_ok=True)
    steps=[('pins',['check_project.py']),('unit',['test.py']),('bmp',['test_advanced.py']),
           ('video',['test_video.py']),('sdram',['test_vendor.py']),
           ('bmp_sdram',['test_vendor.py','--bmp']),('hdmi',['test_hdmi_vendor.py'])]
    results=[]
    for name,args in steps:
        start=time.monotonic()
        with (out/(name+'.log')).open('w',encoding='utf-8') as log:
            r=subprocess.run([sys.executable,'-u','scripts/'+args[0],*args[1:]],cwd=ROOT,stdout=log,stderr=subprocess.STDOUT)
        results.append({'suite':name,'passed':r.returncode==0,'seconds':round(time.monotonic()-start,2)})
        (out/'results.json').write_text(json.dumps(results,indent=2))
        print(name,'PASS' if r.returncode==0 else 'FAIL',flush=True)
        if r.returncode:raise SystemExit('Failed '+name+'; see '+str(out/(name+'.log')))
    hashes={p.relative_to(ROOT).as_posix():hashlib.sha256(p.read_bytes()).hexdigest()
            for directory in ['rtl','vendor','sim','scripts','constraints'] for p in (ROOT/directory).rglob('*')
            if p.is_file() and '__pycache__' not in p.parts}
    (out/'source_hashes.json').write_text(json.dumps(hashes,indent=2))
    print('PASS all configured software suites; no claim of analog PHY or hardware validation')
if __name__=='__main__':main()
