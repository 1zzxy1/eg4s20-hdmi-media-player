"""Reproducible TD build; generated files stay in ignored build/td."""
from pathlib import Path
import argparse
import os
import re
import shutil
import subprocess
import xml.etree.ElementTree as ET

ROOT = Path(__file__).resolve().parents[1]

def main():
    parser = argparse.ArgumentParser()
    parser.add_argument('--stage', choices=['elaborate', 'synthesis', 'route', 'bitstream'], default='synthesis')
    parser.add_argument('--td', default=os.environ.get('TD_CONSOLE', 'E:/1_software/TD/bin/td_commands_prompt.exe'))
    parser.add_argument('--profile', choices=['all','base','text','transition','scale','color','scope'], default='all')
    args = parser.parse_args()
    out = ROOT / ('build/td' if args.profile=='all' else 'build/td_'+args.profile)
    out.mkdir(parents=True, exist_ok=True)
    files = sorted(list((ROOT/'rtl').rglob('*.v')) + list((ROOT/'vendor').rglob('*.v')))
    names = set()
    for f in files:
        if f.name in names: raise ValueError('Duplicate staged filename: '+f.name)
        names.add(f.name)
        shutil.copyfile(f, out/f.name)
    features=['TEXT','TRANSITION','SCALE','COLOR','SCOPE']
    (out/'feature_config.vh').write_text('\n'.join(
        f'`define FEATURE_{name} {int(args.profile=="all" or args.profile==name.lower())}' for name in features)+'\n')
    # The encrypted controller uses this header to derive refresh intervals.
    # Keep vendor copy unchanged and explicitly select the actual 40MHz clock.
    header = out/'global_def.v'
    original=header.read_text()
    assert original.count('1000000000/125000000')==1, 'Refresh clock definition changed'
    header.write_text(original.replace('1000000000/125000000', '1000000000/40000000'))
    project = ET.Element('Project', Version='3', Minor='2', Path=out.as_posix())
    ET.SubElement(project, 'Name').text = 'media_player'
    hw = ET.SubElement(project, 'HardWare')
    for key, val in [('Family','EG4'), ('Device','EG4S20BG256'), ('Speed','')]:
        ET.SubElement(hw,key).text = val
    sources = ET.SubElement(ET.SubElement(project,'Source_Files'),'Verilog')
    for index, f in enumerate(files):
        node = ET.SubElement(sources,'File',Path=f.name)
        info = ET.SubElement(node,'FileInfo')
        for name, val in [('UsedInSyn','true'),('UsedInP&R','true'),('BelongTo','design_1'),('CompileOrder',str(index+1))]:
            ET.SubElement(info,'Attr',Name=name,Val=val)
    fs = ET.SubElement(project,'FileSets')
    ET.SubElement(fs,'FileSet',Name='design_1',Type='DesignFiles')
    top = ET.SubElement(project,'TOP_MODULE')
    ET.SubElement(top,'MODULE').text = 'media_player_top'
    ET.SubElement(top,'CREATEINDEX').text = 'user'
    ET.indent(project)
    for suffix in ['prj','al']:
        ET.ElementTree(project).write(out/f'media_player.{suffix}',encoding='utf-8',xml_declaration=True)
    for f in (ROOT/'constraints').glob('*'):
        if f.suffix in ['.adc','.sdc']: shutil.copyfile(f,out/f.name)
    commands = ['open_project media_player.prj', 'import_device eagle_s20.db -package EG4S20BG256',
                'elaborate -top media_player_top', 'read_adc hx4s20c.adc',
                'read_sdc media_player.sdc', 'export_db media_player_elaborate.db']
    if args.stage != 'elaborate':
        commands += ['optimize_rtl', 'report_area -file media_player_rtl.area',
                     'optimize_gate -maparea media_player_gate.area', 'legalize_phy_inst',
                     'update_timing', 'report_timing_summary -file media_player_gate.timing',
                     'export_db media_player_gate.db']
    if args.stage in ['route', 'bitstream']:
        commands += ['place', 'route', 'report_area -io_info -file media_player_phy.area',
                     'update_timing -mode final', 'report_timing_summary -file media_player_pr.timing',
                     'report_timing_status -file media_player_phy.ts',
                     'export_db media_player_pr.db']
    if args.stage == 'bitstream':
        commands += ['set fp [open media_player_pr.timing r]', 'set timing [read $fp]', 'close $fp',
                     'if {![regexp {SWNS: ([-0-9.]+)ns} $timing -> sw] || ![regexp {HWNS: ([-0-9.]+)ns} $timing -> hw]} {error "Timing report unavailable"}',
                     'if {$sw < 0 || $hw < 0} {error "Timing closure required: setup=$sw hold=$hw"}',
                     'bitgen -bit media_player.bit']
    script = 'if {[catch {\n'+ '\n'.join(commands)+'\n} reason]} {puts "BUILD_FAILED: $reason"; exit 1}\nputs "BUILD_OK"\nexit\n'
    (out/'build.tcl').write_text(script,encoding='utf-8')
    with (out/'console.log').open('wb') as log:
        result = subprocess.run([args.td],input=b'source build.tcl\n',cwd=out,stdout=log,stderr=subprocess.STDOUT,timeout=1800)
    text = (out/'console.log').read_text(errors='replace')
    print(text[-6000:])
    critical = [line for line in text.splitlines() if 'CRITICAL-WARNING' in line]
    # The macro is a package SDRAM, not a fabric cell with a user LOC. TD moves
    # its placeholder during ECO; final route DRC and bitgen validate placement.
    # Its forwarded clock reaches one package pin over local routing. Do not
    # waive an ordinary logic clock, extra clock sink, or any timing violation.
    known = [line for line in critical if
             ('PHY-7002 ' in line and 'Instance u_sdram/sdram location ' in line) or
             ('PHY-5079 ' in line and 'Marked 1 clock net(s)' in line and
              re.search(r'mem_shift\s*\|[^\n]*0/1[^\n]*u_sdram/u2_ram/SDRAM_CLK', text))]
    unexpected = [line for line in critical if line not in known]
    if known:
        print('REVIEWED PACKAGE-IP WARNINGS (hardware validation pending):')
        print('\n'.join(known))
    if result.returncode or 'BUILD_OK' not in text or 'BUILD_FAILED:' in text or unexpected:
        raise SystemExit('TD build failed; see build/td/console.log')
    print('TD '+args.stage+' passed; reports in build/td')

if __name__ == '__main__': main()
