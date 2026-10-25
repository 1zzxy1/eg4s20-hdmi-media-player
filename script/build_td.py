"""Reproducible TD build; generated files stay in ignored build/td."""
from pathlib import Path
import argparse
import os
import re
import shutil
import subprocess
import xml.etree.ElementTree as ET

ROOT = Path(__file__).resolve().parents[1]

def stage_sources(out, profile='all'):
    """Share identical source, feature and SDRAM refresh settings across flows."""
    out.mkdir(parents=True, exist_ok=True)
    files = sorted(list((ROOT/'src').rglob('*.v')) + list((ROOT/'ip').rglob('*.v')))
    names = set()
    for f in files:
        if f.name in names: raise ValueError('Duplicate staged filename: '+f.name)
        names.add(f.name)
        shutil.copyfile(f, out/f.name)
    for f in (ROOT/'src').rglob('*.vh'):
        if f.name != 'feature_config.vh':
            if f.name in names: raise ValueError('Duplicate staged header: '+f.name)
            names.add(f.name)
            shutil.copyfile(f,out/f.name)
    features=['TEXT','TRANSITION','SCALE','COLOR','SCOPE']
    (out/'feature_config.vh').write_text('\n'.join(
        f'`define FEATURE_{name} {int(profile=="all" or profile==name.lower())}' for name in features)+'\n')
    # The encrypted controller uses this header to derive refresh intervals.
    # Keep vendor copy unchanged and explicitly select the actual 40MHz clock.
    header = out/'global_def.v'
    original=header.read_text()
    assert original.count('1000000000/125000000')==1, 'Refresh clock definition changed'
    header.write_text(original.replace('1000000000/125000000', '1000000000/40000000'))
    for f in (ROOT/'prj/constraints').glob('*'):
        if f.suffix in ['.adc','.sdc']: shutil.copyfile(f,out/f.name)
    return files

def main():
    parser = argparse.ArgumentParser()
    parser.add_argument('--stage', choices=['elaborate', 'synthesis', 'route', 'bitstream'], default='synthesis')
    parser.add_argument('--td', default=os.environ.get('TD_CONSOLE', 'E:/1_software/TD/bin/td_commands_prompt.exe'))
    parser.add_argument('--profile', choices=['all','base','text','transition','scale','color','scope'], default='all')
    args = parser.parse_args()
    out = ROOT / ('build/td' if args.profile=='all' else 'build/td_'+args.profile)
    files = stage_sources(out, args.profile)
    project = ET.Element('Project', Version='3', Minor='2', Path=out.as_posix())
    ET.SubElement(project, 'Project_Created_Time')
    ET.SubElement(project, 'TD_Encoding').text = 'GB2312'
    ET.SubElement(project, 'TD_Version').text = '6.2.168116'
    ET.SubElement(project, 'Name').text = 'media_player'
    hw = ET.SubElement(project, 'HardWare')
    for key, val in [('Family','EG4'), ('Device','EG4S20BG256'), ('Speed','')]:
        ET.SubElement(hw,key).text = val
    source_files = ET.SubElement(project,'Source_Files')
    sources = ET.SubElement(source_files,'Verilog')
    for index, f in enumerate(files):
        node = ET.SubElement(sources,'File',Path=f.name)
        info = ET.SubElement(node,'FileInfo')
        for name, val in [('UsedInSyn','true'),('UsedInP&R','true'),('BelongTo','design_1'),('CompileOrder',str(index+1))]:
            ET.SubElement(info,'Attr',Name=name,Val=val)
    # Register constraints for TD GUI runs as well as the explicit Tcl flow.
    for order, (kind, filename) in enumerate([
            ('SDC_FILE','media_player.sdc'), ('ADC_FILE','hx4s20c.adc')], start=1):
        node = ET.SubElement(ET.SubElement(source_files,kind),'File',Path=filename)
        info = ET.SubElement(node,'FileInfo')
        for name, val in [('UsedInSyn','true'),('UsedInP&R','true'),
                          ('BelongTo','constraint_1'),('CompileOrder',str(order))]:
            ET.SubElement(info,'Attr',Name=name,Val=val)
    fs = ET.SubElement(project,'FileSets')
    ET.SubElement(fs,'FileSet',Name='design_1',Type='DesignFiles')
    ET.SubElement(fs,'FileSet',Name='constraint_1',Type='ConstrainFiles')
    top = ET.SubElement(project,'TOP_MODULE')
    ET.SubElement(top,'MODULE').text = 'media_player_top'
    ET.SubElement(top,'CREATEINDEX').text = 'user'
    for tag in ['Property','Device_Settings','Configurations']:
        ET.SubElement(project,tag)
    runs = ET.SubElement(project,'Runs')
    for name, kind, strategy in [('syn_1','Synthesis','Default_Synthesis_Strategy'),
                                 ('phy_1','PhysicalDesign','Default_PhysicalDesign_Strategy')]:
        attrs = dict(Name=name,Type=kind,ConstraintSet='constraint_1',Description='',Active='true')
        if kind=='PhysicalDesign': attrs['SynRun']='syn_1'
        run = ET.SubElement(runs,'Run',**attrs)
        ET.SubElement(run,'Strategy',Name=strategy)
        ET.SubElement(run,'UserParams')
    ET.SubElement(project,'Project_Settings')
    ET.indent(project)
    for suffix in ['prj','al']:
        ET.ElementTree(project).write(out/f'media_player.{suffix}',encoding='utf-8',xml_declaration=True)
    commands = ['open_project media_player.prj', 'import_device eagle_s20.db -package EG4S20BG256',
                'elaborate -top media_player_top', 'read_adc hx4s20c.adc',
                'read_sdc media_player.sdc', 'export_db media_player_elaborate.db']
    if args.stage != 'elaborate':
        commands += ['optimize_rtl', 'report_area -file media_player_rtl.area',
                     'optimize_gate -maparea media_player_gate.area', 'legalize_phy_inst',
                     'update_timing', 'report_timing_summary -file media_player_gate.timing',
                     'export_db media_player_gate.db']
    if args.stage in ['route', 'bitstream']:
        commands += ['set_param place fix_hold high', 'set_param route hold_fix_iteration 10',
                     'place', 'route', 'report_area -io_info -file media_player_phy.area',
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
    # TD console rewrites .al while loading .prj and drops constraint file-list
    # entries. Restore the complete GUI project after the verified batch run.
    ET.ElementTree(project).write(out/'media_player.al',encoding='utf-8',xml_declaration=True)
    print('TD '+args.stage+' passed; reports in build/td')

if __name__ == '__main__': main()
