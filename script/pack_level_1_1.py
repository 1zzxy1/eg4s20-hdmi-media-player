"""Decode the documented SMB1 Area6 object stream into a shared tile RAM image.

Only the ground area is decoded. No ROM image, CPU code or emulator is used.
Source: Xkeeper0/smb1 commit 1cc3c92cbbe8cda44903657f3da332688e806a89,
src/levels/objects.asm L_GroundArea6. Object semantics were cross-checked
against DecodeAreaData, GetPipeHeight and StaircaseObject in src/prg.asm.
Enemy entries come from src/levels/enemies.asm E_GroundArea6; page control,
group expansion and initial Y follow ProcessEnemyData, HandleGroupEnemies
and CheckpointEnemyID in the same src/prg.asm.
"""
from pathlib import Path
import argparse
import hashlib
import json

ROOT = Path(__file__).resolve().parents[1]
SOURCE = 'https://github.com/Xkeeper0/smb1/blob/1cc3c92cbbe8cda44903657f3da332688e806a89/src/levels/objects.asm'
ENEMY_SOURCE = 'https://github.com/Xkeeper0/smb1/blob/1cc3c92cbbe8cda44903657f3da332688e806a89/src/levels/enemies.asm'
OBJECTS = bytes.fromhex('''
50 21 07 81 47 24 57 00 63 01 77 01 c9 71 68 f2 e7 73 97 fb
06 83 5c 01 d7 22 e7 00 03 a7 6c 02 b3 22 e3 01 e7 07 47 a0
57 06 a7 01 d3 00 d7 01 07 81 67 20 93 22 03 a3 1c 61 17 21
6f 33 c7 63 d8 62 e9 61 fa 60 4f b3 87 63 9c 01 b7 63 c8 62
d9 61 ea 60 39 f1 87 21 a7 01 b7 20 39 f1 5f 38 6d c1 af 26 fd
''')
ENEMIES = bytes.fromhex('''
1e c2 00 6b 06 8b 86 63 b7 0f 05 03 06 23 06 4b b7 bb 00
5b b7 fb 37 3b b7 0f 0b 1b 37 ff
''')
AIR,GROUND,BRICK,Q_COIN,Q_POWER,USED,STONE,PIPE_TL,PIPE_TR,PIPE_BL,PIPE_BR,HIDDEN_1UP,BRICK_COIN,BRICK_STAR,BRICK_POWER = range(15)


def decode_enemies():
    """Expand Area6's normal-mode Goomba groups and single enemy objects."""
    result=[]
    page=0
    i=0
    while ENEMIES[i] != 0xff:
        a,b=ENEMIES[i:i+2]
        if b & 0x80:
            page += 1
        row=a & 15
        if row == 14:
            i += 3
            continue
        if row == 15:
            page=b & 0x3f
            i += 2
            continue
        x=page*256+(a >> 4)*16
        code=b & 0x3f
        if 0x37 <= code <= 0x3e:
            # HandleGroupEnemies: low bit selects 2/3 members, spacing is $18.
            count=3 if (code-0x37) & 1 else 2
            kind=1 if code >= 0x3b else 0
            y=(0x70 if (code-0x37) & 2 else 0xb0)+8
        else:
            assert code in (0,6), (i,a,b)
            count=1
            kind=0 if code == 6 else 1
            y=row*16+8
        for member in range(count):
            result.append({'x':x+member*24,'y':y,'kind':kind,
                           'source_offset':i,'raw':f'{a:02x} {b:02x}',
                           'page':page,'group_member':member})
        i += 2
    assert len(result)==17
    assert [(e['x'],e['y'],e['kind']) for e in result] == [
        (352,184,0),(640,184,0),(864,184,0),(888,184,0),
        (1280,56,0),(1312,56,0),(1600,184,0),(1624,184,0),
        (1712,184,1),(1872,184,0),(1896,184,0),(2032,184,0),
        (2056,184,0),(2096,184,0),(2120,184,0),(2832,184,0),
        (2856,184,0)]
    return result

def decode():
    cells = [0] * 4096
    objects = []
    def rect(x,y,w,h,kind):
        assert 0 <= x < 256 and 0 <= y < 16 and x+w <= 256 and y+h <= 16
        for row in range(y,y+h):
            for col in range(x,x+w):
                cells[row*256+col] = kind
    rect(0,13,212,2,GROUND)
    page=0
    flag=None
    castle=None
    for i in range(2,len(OBJECTS)-1,2):
        a,b=OBJECTS[i:i+2]
        if b&128: page+=1
        row=a&15
        x=page*16+(a>>4)
        typ=(b&127)>>4
        arg=b&15
        record={'offset':i,'raw':f'{a:02x} {b:02x}','x':x,'row':row,'type':typ,'arg':arg}
        objects.append(record)
        if row<12:
            y=row+2
            if typ==0:
                kinds={0:Q_POWER,1:Q_COIN,3:HIDDEN_1UP,4:BRICK_POWER,6:BRICK_STAR,7:BRICK_COIN}
                if arg not in kinds: raise ValueError(record)
                rect(x,y,1,1,kinds[arg])
            elif typ==2: rect(x,y,arg+1,1,BRICK)
            elif typ==6: rect(x,y,1,arg+1,STONE)
            elif typ==7:
                height=(arg&7)+1
                rect(x,y,1,1,PIPE_TL);rect(x+1,y,1,1,PIPE_TR)
                rect(x,y+1,1,height-1,PIPE_BL);rect(x+1,y+1,1,height-1,PIPE_BR)
            else: raise ValueError(record)
        elif row==12:
            if typ==0: rect(x,10,arg+1,5,AIR)
            elif typ==6: rect(x,5,arg+1,1,Q_COIN)
            else: raise ValueError(record)
        elif row==15:
            if typ==3:
                for dx in range(arg+1):
                    height=min(dx+1,8)
                    rect(x+dx,13-height,1,height,STONE)
            elif typ==2: castle=x
            else: raise ValueError(record)
        elif row==13 and (b&127)==0x41:
            flag=x
            rect(x,12,1,1,STONE)
        else: raise ValueError(record)
    assert flag==198 and castle==202
    return cells, {'format':'smb1-ground-area6-v1','source':SOURCE,
        'source_object_sha256':hashlib.sha256(OBJECTS).hexdigest(),
        'width_tiles':212,'height_tiles':15,'flag_x':flag*16,
        'castle_x':castle*16,'castle_door_x':(castle+2)*16,
        'objects':objects,'cells_sha256':hashlib.sha256(bytes(cells)).hexdigest(),
        'limitations':['Underground bonus room is excluded.',
            'Decorative background is rendered separately.',
            'Normal gameplay recreation; not a cycle-accurate NES implementation.']}

def outputs():
    cells,manifest=decode()
    enemies=decode_enemies()
    manifest['enemy_source']=ENEMY_SOURCE
    manifest['source_enemy_sha256']=hashlib.sha256(ENEMIES).hexdigest()
    manifest['enemies']=enemies
    init=['// Generated by script/pack_level_1_1.py. ROM initialization, no reset muxes.']
    init.extend(f'level_rom[{i}]=8\'d{v};' for i,v in enumerate(cells))
    spawn=['// Generated by script/pack_level_1_1.py from E_GroundArea6.',
           f'`define GAME_ENEMY_COUNT {len(enemies)}']
    for name,width,default in [('x',12,4095),('y',9,0),('kind',2,0)]:
        spawn.extend([f'function [{width-1}:0] spawn_{name};',
                      '    input [4:0] n;',
                      '    begin',
                      '        case(n)'])
        spawn.extend(f"            5'd{i}:spawn_{name}={width}'d{e[name]};"
                     for i,e in enumerate(enemies))
        spawn.extend([f"            default:spawn_{name}={width}'d{default};",
                      '        endcase',
                      '    end',
                      'endfunction'])
    return {'src/game/game_level_init.vh':'\n'.join(init)+'\n',
            'src/game/game_enemy_spawns.vh':'\n'.join(spawn)+'\n',
            'assets/game/level_1_1.json':json.dumps(manifest,indent=2)+'\n'}

def main():
    p=argparse.ArgumentParser(description=__doc__);p.add_argument('--check',action='store_true');args=p.parse_args()
    for name,content in outputs().items():
        path=ROOT/name
        if args.check:
            assert path.read_text(encoding='utf-8')==content, f'Stale generated file: {name}'
        else:
            path.parent.mkdir(parents=True,exist_ok=True)
            path.write_text(content,encoding='utf-8')
    print('PASS documented Area6 decode: 212 columns, 3 pits, 6 pipes, 17 enemies, flag 198, castle 202')

if __name__=='__main__':main()
