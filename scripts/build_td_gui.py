"""Create and exercise the real TD project/RUN flow, including constraint lists.

This uses native create_project/add_files/launch_runs, not the batch .prj flow.
The negative control must reproduce BIT-8123 when constraints are absent.
"""
from pathlib import Path
import argparse, hashlib, json, os, re, subprocess, time
from build_td import ROOT, stage_sources

def main():
    parser=argparse.ArgumentParser()
    parser.add_argument('--td',default=os.environ.get('TD_CONSOLE','E:/1_software/TD/bin/td_commands_prompt.exe'))
    parser.add_argument('--negative-control',action='store_true')
    args=parser.parse_args()
    out=ROOT/('build/td_gui_no_constraints' if args.negative_control else 'build/td_gui')
    files=stage_sources(out)
    (out/'verification.json').write_text(json.dumps({'passed':False,'state':'running'}))
    project=out/'media_player.al'
    # create_project initializes the device implicitly; reopening an existing
    # project must do so explicitly before launching native project runs.
    commands=['import_device eagle_s20.db -package EG4S20BG256']
    if not project.exists():
        commands.append('create_project media_player {'+out.as_posix()+'} -family EG4 -device EG4S20BG256')
    commands+=['open_project {'+project.as_posix()+'}', 'top_module media_player_top',
               'add_include_dir {'+out.as_posix()+'}',
               'add_files {'+' '.join(f.name for f in files)+'}']
    if not args.negative_control:commands.append('add_files {hx4s20c.adc media_player.sdc}')
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
    assert 'hx4s20c.adc' in settings and 'media_player.sdc' in settings,'GUI did not propagate constraints'
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
    timing=(phy/'media_player_phy.ts').read_text()
    wns={key:float(re.search(key+r':\s*([-\d.]+)ns',timing)[1]) for key in ['SWNS','HWNS']}
    assert all(v>=0 for v in wns.values()),wns
    area=(phy/'media_player_phy.area').read_text()
    pins=re.findall(r'set_pin_assignment\s+\{([^}]+)\}\s+\{LOCATION\s*=\s*(\w+)',(ROOT/'constraints/hx4s20c.adc').read_text())
    # TD's IO report is a placement check in addition to mere settings inclusion.
    for port,loc in pins:
        assert re.search(r'^\s*'+re.escape(port)+r'\s+(?:INPUT|OUTPUT|INOUT)\s+'+re.escape(loc)+r'\s',area,re.M),('IO location mismatch',port,loc)
    receipt={'passed':True,'project':str(project),'bitstream':str(phy/'media_player.bit'),
             'sha256':hashlib.sha256((phy/'media_player.bit').read_bytes()).hexdigest(),
             'pins_checked':len(pins),'timing_ns':wns,'native_gui_flow':True,'reviewed_warnings':known}
    (out/'verification.json').write_text(json.dumps(receipt,indent=2))
    print(json.dumps(receipt,indent=2))
    print('PASS native GUI RUN: constraints consumed, pins placed, bitstream generated, timing closed')

if __name__=='__main__':main()
