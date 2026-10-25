"""Check board pin coverage and unchanged vendor source hashes."""
from pathlib import Path
import hashlib
import json
import re
import argparse

ROOT = Path(__file__).resolve().parents[1]

def main():
    parser=argparse.ArgumentParser()
    parser.add_argument('--video-diagnostic',action='store_true')
    args=parser.parse_args()
    top='src/diagnostic/video_diagnostic_top.v' if args.video_diagnostic else 'src/media_player_top.v'
    header=(ROOT/top).read_text().split(');',1)[0].split('(',1)[1]
    ports=[]
    width=None
    for part in header.split(','):
        part=part.strip()
        if re.match(r'(input|output|inout)\b',part):
            m=re.fullmatch(r'(?:input|output|inout)\s+wire\s*(?:\[([^]]+)\]\s*)?(\w+)',part)
            assert m,part
            width,name=m.groups()
        else:
            assert re.fullmatch(r'\w+',part),part
            name=part
        if width:
            high,low=map(int,width.split(':'))
            ports.extend(f'{name}[{i}]' for i in range(low,high+1))
        else:ports.append(name)
    adc=(ROOT/'prj/constraints/hx4s20c.adc').read_text()
    bound=re.findall(r'set_pin_assignment\s+\{([^}]+)\}',adc)
    locations=re.findall(r'LOCATION = ([A-Z]+\d+)',adc)
    assert set(ports)==set(bound),(set(ports)-set(bound),set(bound)-set(ports))
    assert len(locations)==len(set(locations))==len(ports)
    for row in json.loads((ROOT/'doc/reference_manifest.json').read_text(encoding='utf-8')):
        if not row['editable']:
            data=(ROOT/row['destination']).read_bytes()
            digest=hashlib.sha256(data).hexdigest()
            # Git checkout may normalize CRLF. Accept newline normalization only.
            if digest!=row['source_sha256']:
                normalized=data.replace(b'\r\n',b'\n')
                assert any(hashlib.sha256(value).hexdigest()==row['source_sha256'] for value in
                           [normalized,normalized.replace(b'\n',b'\r\n')]),row['destination']
    # A console add_files call must not hide an incomplete saved GUI project.
    project=(ROOT/('build/video_diagnostic/media_player.al' if args.video_diagnostic else 'prj/media_player.al')).read_text(encoding='utf-8')
    registered={Path(p.replace('\\','/')).name for p in re.findall(r'<File Path="([^"]+)"',project)}
    required={p.name for directory in ('src','ip') for p in (ROOT/directory).rglob('*.v')}
    assert required<=registered,('RTL missing from saved TD project',sorted(required-registered))
    print(f'PASS {len(ports)} pin assignments, no duplicate locations, vendor provenance')
    print(f'PASS {len(required)} RTL files persisted in the GUI project')

if __name__=='__main__':main()
