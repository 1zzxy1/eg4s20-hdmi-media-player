"""Create and exercise the real TD project/RUN flow, including constraint lists.

This uses native create_project/add_files/launch_runs, not the batch .prj flow.
The negative control must reproduce BIT-8123 when constraints are absent.
"""
from pathlib import Path
import argparse, hashlib, json, os, re, shutil, subprocess, sys, time
import xml.etree.ElementTree as ET
from build_td import ROOT, stage_sources

def sync_project_sources(project, stage, files):
    """Persist staged RTL in the GUI project, preserving device/run settings."""
    # TD writes a bare ampersand in UsedInP&R attribute values.
    # Normalize it only for XML parsing; preserve all project settings.
    tree=ET.ElementTree(ET.fromstring(re.sub(r'&(?!#?\w+;)', '&amp;',
                                            project.read_text(encoding='utf-8'))))
    sources=tree.find('Source_Files/Verilog')
    if sources is None:
        raise ValueError('TD project has no Verilog source set')
    existing={Path(node.attrib['Path']).name:node for node in sources.findall('File')}
    for order, source in enumerate(files,1):
        if source.name in existing:
            # TD caches unused modules across runs. A newly instantiated IP
            # must be reanalysed rather than silently retained as a black box.
            info=existing[source.name].find('FileInfo')
            if info is not None:
                for attr in list(info):
                    if attr.get('Name')=='AutoExcluded':
                        info.remove(attr)
            continue
        relative=os.path.relpath(stage/source.name,project.parent).replace('\\','/')
        node=ET.SubElement(sources,'File',Path=relative)
        info=ET.SubElement(node,'FileInfo')
        for name,value in [('UsedInSyn','true'),('UsedInP&R','true'),
                           ('BelongTo','design_1'),('CompileOrder',str(order))]:
            ET.SubElement(info,'Attr',Name=name,Val=value)
    tree.write(project,encoding='UTF-8',xml_declaration=True)
    actual={Path(n.attrib['Path']).name for n in ET.parse(project).findall('Source_Files/Verilog/File')}
    assert {f.name for f in files}<=actual,'Saved GUI project is missing RTL'

def read_timing(path):
    timing=path.read_text()
    return {key:float(re.search(key+r':\s*([-\d.]+)ns',timing)[1]) for key in ['SWNS','HWNS']}

def repair_hold(td, phy):
    """Run TD's routed ECO hold repair and regenerate the actual bitstream."""
    before=read_timing(phy/'media_player_phy.ts')
    if before['HWNS']>=0:
        return None
    # Preserve the native result for audit; never accept a repaired report with
    # the original bitstream. A failed repair leaves verification failed.
    for name in ['media_player_phy.ts','media_player_pr.timing','media_player_phy.area']:
        shutil.copyfile(phy/name,phy/(name+'.pre_hold'))
    commands=['import_device eagle_s20.db -package EG4S20BG256',
              'import_db media_player_pr.db','fix_hold -eco',
              'update_timing -mode final',
              'report_timing_status -file media_player_phy.ts',
              'report_timing_summary -file media_player_pr.timing',
              'report_timing_exception -file media_player_exception.timing',
              'report_area -io_info -file media_player_phy.area',
              'export_db media_player_pr.db','bitgen -bit media_player.bit']
    script='if {[catch {\n'+'\n'.join(commands)+'\n} error]} {puts "HOLD_REPAIR_FAILED:$error"; exit 1}\nputs "HOLD_REPAIR_FINISHED"\nexit\n'
    (phy/'repair_hold.tcl').write_text(script,encoding='utf-8')
    started=time.time()
    with (phy/'repair_hold.log').open('wb') as log:
        run=subprocess.run([td],input=b'source repair_hold.tcl\n',cwd=phy,
                           stdout=log,stderr=subprocess.STDOUT,timeout=600)
    output=(phy/'repair_hold.log').read_text(errors='replace')
    assert run.returncode==0 and 'HOLD_REPAIR_FINISHED' in output,'Post-route hold repair failed'
    assert not any(' ERROR:' in line or 'CRITICAL-WARNING' in line for line in output.splitlines()),'Review hold repair log'
    assert (phy/'media_player.bit').stat().st_mtime>=started,'Hold repair did not regenerate bitstream'
    after=read_timing(phy/'media_player_phy.ts')
    assert all(v>=0 for v in after.values()),after
    return {'command':'fix_hold -eco','before_ns':before,'after_ns':after,
            'regenerated_bitstream':True,'log':str(phy/'repair_hold.log')}

def main():
    parser=argparse.ArgumentParser()
    parser.add_argument('--td',default=os.environ.get('TD_CONSOLE','E:/1_software/TD/bin/td_commands_prompt.exe'))
    parser.add_argument('--negative-control',action='store_true')
    parser.add_argument('--video-diagnostic',action='store_true',help='Build isolated video-only HDMI/DVI board diagnostic')
    parser.add_argument('--video-svga',action='store_true',help='Build independent 800x600 DVI compatibility probe')
    args=parser.parse_args()
    if args.video_svga and (args.video_diagnostic or args.negative_control):
        parser.error('SVGA, A/B diagnostic and negative control are separate builds')
    if args.video_diagnostic and args.negative_control:
        parser.error('Diagnostic and missing-constraint negative control are separate builds')
    out=ROOT/('build/video_svga' if args.video_svga else 'build/video_diagnostic' if args.video_diagnostic else 'build/td_gui_no_constraints' if args.negative_control else 'prj')
    stage=ROOT/('build/staging/video_svga' if args.video_svga else 'build/staging/video_diagnostic' if args.video_diagnostic else 'build/staging/negative' if args.negative_control else 'build/staging/gui')
    top='video_svga_top' if args.video_svga else 'video_diagnostic_top' if args.video_diagnostic else 'media_player_top'
    sdc='video_svga.sdc' if args.video_svga else 'video_diagnostic.sdc' if args.video_diagnostic else 'media_player.sdc'
    out.mkdir(parents=True,exist_ok=True)
    files=stage_sources(stage)
    (out/'verification.json').write_text(json.dumps({'passed':False,'state':'running'}))
    project=out/'media_player.al'
    if project.exists():
        sync_project_sources(project,stage,files)
    # create_project initializes the device implicitly; reopening an existing
    # project must do so explicitly before launching native project runs.
    commands=['import_device eagle_s20.db -package EG4S20BG256']
    if not project.exists():
        commands.append('create_project media_player {'+out.as_posix()+'} -family EG4 -device EG4S20BG256')
    commands+=['open_project {'+project.as_posix()+'}', 'top_module '+top,
               'add_include_dir {'+stage.as_posix()+'}',
               'set_param place effort high -run phy_1',
               'set_param place fix_hold high -run phy_1',
               'set_param route hold_fix_iteration 10 -run phy_1']
    commands += ['add_files {'+(stage/f.name).as_posix()+'}' for f in files]
    if not args.negative_control:
        commands += ['add_files {'+(stage/n).as_posix()+'}' for n in ['hx4s20c.adc',sdc]]
    # These are disposable generated runs, not source files. Remove their old
    # result markers so a repeat cannot reuse a failed/stale GUI database.
    commands+=['reset_runs syn_1 -f','launch_runs {syn_1 phy_1}',
               'wait_run syn_1 -quiet','wait_run phy_1 -quiet','close_project']
    script='if {[catch {\n'+'\n'.join(commands)+'\n} error]} {puts "GUI_RUN_FAILED:$error"; exit 1}\nputs "GUI_RUN_FINISHED"\nexit\n'
    (out/'run_gui.tcl').write_text(script,encoding='utf-8')
    started=time.time()
    with (out/'driver.log').open('wb') as log:
        run=subprocess.run([args.td],input=b'source run_gui.tcl\n',cwd=out,stdout=log,stderr=subprocess.STDOUT,timeout=1800)
    syn=out/'media_player_Runs/syn_1';phy=out/'media_player_Runs/phy_1'
    driver=(out/'driver.log').read_text(errors='replace')
    if (run.returncode or 'GUI_RUN_FINISHED' not in driver) and not args.negative_control:
        raise SystemExit('Native project flow failed: '+str(out/'driver.log'))
    synlog=(syn/'run.log').read_text(errors='replace');phylog=(phy/'run.log').read_text(errors='replace')
    assert (phy/'run.log').stat().st_mtime>=started,'Stale physical run log'
    settings=(syn/'settings.cfg').read_text()
    if args.negative_control:
        assert ('GUI_RUN_FAILED:' in driver and run.returncode==1) or ('GUI_RUN_FINISHED' in driver and run.returncode==0),'Aborted negative control'
        assert 'set ADCList {}' in settings and 'set SDCList {}' in settings
        assert (syn/'.opt_gate.end.f').exists(),'Negative control did not reach physical flow'
        assert 'BIT-8123 ERROR:' in phylog,'Negative control failed to detect missing IO constraints'
        (out/'verification.json').write_text(json.dumps({'passed':True,'negative_control':True,'expected_error':'BIT-8123'},indent=2))
        print('PASS negative control: real GUI RUN reproduces BIT-8123 without constraints')
        return
    assert 'hx4s20c.adc' in settings and sdc in settings,'GUI did not propagate constraints'
    assert 'read_adc' in synlog and 'read_sdc' in synlog,'GUI synthesis did not read constraints'
    errors=[l for l in (synlog+phylog).splitlines() if ' ERROR:' in l]
    assert not errors,errors
    critical=[l for l in (synlog+phylog).splitlines() if 'CRITICAL-WARNING' in l]
    known=[l for l in critical if
           ('PHY-7002 ' in l and 'Instance u_sdram/sdram location ' in l) or
           ('PHY-5079 ' in l and 'Marked 1 clock net(s)' in l and
            re.search(r'mem_shift\s*\|[^\n]*0/1[^\n]*u_sdram/u2_ram/SDRAM_CLK',phylog))]
    assert len(known)==len(critical),[l for l in critical if l not in known]
    assert (phy/'.bitgen.end.f').exists() and (phy/'media_player.bit').exists(),'No successful GUI bitgen receipt'
    hold_repair=repair_hold(args.td,phy)
    wns=read_timing(phy/'media_player_phy.ts')
    assert all(v>=0 for v in wns.values()),wns
    area=(phy/'media_player_phy.area').read_text()
    pins=re.findall(r'set_pin_assignment\s+\{([^}]+)\}\s+\{LOCATION\s*=\s*(\w+)',(ROOT/'prj/constraints/hx4s20c.adc').read_text())
    # TD's IO report is a placement check in addition to mere settings inclusion.
    for port,loc in pins:
        assert re.search(r'^\s*'+re.escape(port)+r'\s+(?:INPUT|OUTPUT|INOUT)\s+'+re.escape(loc)+r'\s',area,re.M),('IO location mismatch',port,loc)
    receipt={'passed':True,'project':str(project),'top':top,'bitstream':str(phy/'media_player.bit'),
             'sha256':hashlib.sha256((phy/'media_player.bit').read_bytes()).hexdigest(),
             'pins_checked':len(pins),'timing_ns':wns,'native_gui_flow':True,
             'post_route_hold_repair':hold_repair,'reviewed_warnings':known,
             'staged_source_sha256':{p.name:hashlib.sha256(p.read_bytes()).hexdigest()
                                     for p in stage.iterdir() if p.is_file()}}
    (out/'verification.json').write_text(json.dumps(receipt,indent=2))
    print(json.dumps(receipt,indent=2))
    print('PASS native GUI RUN: constraints consumed, pins placed, bitstream generated, timing closed')

if __name__=='__main__':
    try:
        main()
    except (Exception, SystemExit) as error:
        # A failed flow must not leave a misleading "running" receipt or allow
        # an old bitstream to be mistaken for an accepted current build.
        receipt_dir=ROOT/('build/video_svga' if '--video-svga' in sys.argv else 'build/video_diagnostic' if '--video-diagnostic' in sys.argv else 'build/td_gui_no_constraints' if '--negative-control' in sys.argv else 'prj')
        if receipt_dir.exists():
            (receipt_dir/'verification.json').write_text(json.dumps({
                'passed':False,'state':'failed','error':str(error)},indent=2))
        raise
