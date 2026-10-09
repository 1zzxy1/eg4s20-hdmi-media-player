"""Build all feature profiles serially and retain measured, comparable reports."""
from pathlib import Path
import subprocess,json,re,sys
ROOT=Path(__file__).resolve().parents[1]
def main():
    rows=[]
    for name in ['base','text','transition','scale','color','scope','all']:
        out=ROOT/('build/td' if name=='all' else 'build/td_'+name)
        out.mkdir(parents=True,exist_ok=True)
        with (out/'driver.log').open('w') as f:
            r=subprocess.run([sys.executable,'scripts/build_td.py','--stage','route','--profile',name],cwd=ROOT,stdout=f,stderr=subprocess.STDOUT)
        row={'profile':name,'build_exit':r.returncode}
        # Never report artifacts left over from an earlier successful build.
        area=(out/'media_player_phy.area').read_text() if r.returncode==0 and (out/'media_player_phy.area').exists() else ''
        timing=(out/'media_player_phy.ts').read_text() if r.returncode==0 and (out/'media_player_phy.ts').exists() else ''
        for key in ['lut','reg','bram','dsp','pll','gclk']:
            m=re.search(r'^#'+key+r'\s+(\d+)\s+out of\s+(\d+)',area,re.M)
            if m:row[key]=int(m[1])
        for key in ['SWNS','HWNS']:
            m=re.search(key+r':\s*([-\d.]+)',timing)
            if m:row[key]=float(m[1])
        row['timing_pass']=r.returncode==0 and row.get('SWNS',-1)>=0 and row.get('HWNS',-1)>=0
        rows.append(row)
        (ROOT/'build/profile_matrix.json').write_text(json.dumps(rows,indent=2))
        print(json.dumps(row),flush=True)
    if not rows[-1]['timing_pass']:raise SystemExit('All-features timing is not closed')
if __name__=='__main__':main()
