"""Copy a minimal reference set without overwriting existing project files."""
from pathlib import Path
import hashlib
import json
import shutil

ROOT = Path(__file__).resolve().parents[1]
LIB = ROOT.parent / '课程资料/02 FPGA创新设计赛道安路赛项（完赛系列）'
SOURCE = next(p for p in LIB.glob('第二讲*/第1课*') if p.is_dir())
EDITABLE = ['SD/bmp_read.v', 'SD/sd_card_bmp.v', 'SD/frame_read_write.v',
            'SD/frame_fifo_read.v', 'SD/frame_fifo_write.v', 'SD/sdram.v',
            'SD/video_timing_data.v', 'IP/sys_pll.v', 'IP/video_pll.v',
            'video_rgb_to_axis_640x480.v', 'include/sdr_init_ref.enc.v']
VENDOR = ['SD/sd_card_top.v', 'SD/sd_card_cmd.v', 'SD/sd_card_sec_read_write.v',
          'SD/spi_master.v', 'SD/color_bar.v', 'SD/video_define.v', 'SD/video_delay.v',
          'IP/afifo_16_32_256.v', 'IP/afifo_32_16_256.v', 'include/global_def.v',
          'include/sdr_as_ram.enc.v', 'include/sdr_wrrd.enc.v',
          'hdmi_phy_warpper.v', 'lane_lvds_10_1.v', 'startup_pulse.v',
          'hdmi1.4b_transmitter_core/hdmi_1_4b_transmitter_core_wrapper.enc.v']

def main():
    entries = []
    for folder, paths in [('rtl/reference', EDITABLE), ('vendor/course', VENDOR)]:
        for rel in paths:
            src, dst = SOURCE / rel, ROOT / folder / rel
            digest = hashlib.sha256(src.read_bytes()).hexdigest()
            if not dst.exists():
                dst.parent.mkdir(parents=True, exist_ok=True)
                shutil.copyfile(src, dst)
            entries.append({'source': src.relative_to(ROOT.parent).as_posix(),
                            'destination': dst.relative_to(ROOT).as_posix(),
                            'source_sha256': digest, 'editable': folder.startswith('rtl')})
    manifest = ROOT / 'reference_manifest.json'
    if not manifest.exists():
        manifest.write_text(json.dumps(entries, ensure_ascii=False, indent=2)+'\n', encoding='utf-8')
    print(f'Reference files available: {len(entries)}; existing files preserved')

if __name__ == '__main__':
    main()
