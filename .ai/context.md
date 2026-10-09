# 当前工程

- 目标：2026 安路赛题一，HX4S20C / EG4S20BG256，TF SPI → BMP → SDRAM 双缓冲 → HDMI 音视频，手动切图、轮播、上电自启。
- 实现预算：640×480 RGB888，像素按 32 位存储，两帧占 2457600 字节；25MHz 像素、125MHz TMDS、40MHz SDRAM、50MHz TF 控制域。
- 五项扩展已整合：时间/字幕/半透明层、fade/wipe、1..1920×1..1440 BMP最近邻缩放、亮度对比度/参数OSD、PCM波形/峰值。默认all；资源取舍由用户决定。
- 全开TD实测5673 LUT、3770 REG、19 BRAM9K、5 DSP、2 PLL、4 GCLK，setup +1.872ns、hold +0.012ns，位流已生成。25MHz对应59.524Hz，尚未硬件验收。
- 本机工具：Icarus Verilog、TD 6.2（`E:/1_software/TD`）、GitHub CLI。
- GitHub：`1zzxy1/eg4s20-hdmi-media-player`，必须 private。
- 原始资料和整个上级目录不属于 Git 工程。构建数据库、日志、位流不可入库。
- 常用命令：`python scripts/verify.py`；`python scripts/build_td.py --stage bitstream`；`python scripts/profile_matrix.py`。当前细节见 `docs/advanced-validation.md`、`code-provenance.md`和`bringup.md`；旧validation.md只作历史。
- ModelSim可运行真实加密HDMI/SDRAM控制器，已接自建器件模型完成缩放→FIFO→SDRAM→显示及并发装载测试；不能再无证据声称“原厂IP不能仿真”。SPI电气/模拟PHY/完整HDMI音频接收/硬件未验证。
