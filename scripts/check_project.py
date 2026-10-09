"""Check board pin coverage and unchanged vendor source hashes."""
from pathlib import Path
import hashlib
import json
import re

ROOT = Path(__file__).resolve().parents[1]

def main():
    header=(ROOT/'rtl/media_player_top.v').read_text().split(');',1)[0].split('(',1)[1]
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
    adc=(ROOT/'constraints/hx4s20c.adc').read_text()
    bound=re.findall(r'set_pin_assignment\s+\{([^}]+)\}',adc)
    locations=re.findall(r'LOCATION = ([A-Z]+\d+)',adc)
    assert set(ports)==set(bound),(set(ports)-set(bound),set(bound)-set(ports))
    assert len(locations)==len(set(locations))==len(ports)
    for row in json.loads((ROOT/'reference_manifest.json').read_text(encoding='utf-8')):
        if not row['editable']:
            data=(ROOT/row['destination']).read_bytes()
            digest=hashlib.sha256(data).hexdigest()
            # Git checkout may normalize CRLF. Accept newline normalization only.
            if digest!=row['source_sha256']:
                normalized=data.replace(b'\r\n',b'\n')
                assert any(hashlib.sha256(value).hexdigest()==row['source_sha256'] for value in
                           [normalized,normalized.replace(b'\n',b'\r\n')]),row['destination']
    print(f'PASS {len(ports)} pin assignments, no duplicate locations, vendor provenance')

if __name__=='__main__':main()
