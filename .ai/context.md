# 当前工程

- 目标：2026 安路赛题一，HX4S20C / EG4S20BG256，TF SPI → BMP → SDRAM 双缓冲 → HDMI 音视频，手动切图、轮播、上电自启。
- 实现预算：640×480 RGB888，像素按 32 位存储，两帧占 2457600 字节；25MHz 像素、125MHz TMDS、40MHz SDRAM、50MHz TF 控制域。
- 已完成首版顶层/引脚/SDC、6 个自检测试和 TD 位流；25MHz 对应 59.524Hz。尚未硬件验收，不可称完赛。
- 本机工具：Icarus Verilog、TD 6.2（`E:/1_software/TD`）、GitHub CLI。
- GitHub：`1zzxy1/eg4s20-hdmi-media-player`，必须 private。
- 原始资料和整个上级目录不属于 Git 工程。构建数据库、日志、位流不可入库。
- 常用命令：`python scripts/test.py`；`python scripts/build_td.py --stage bitstream`。当前细节见 `docs/validation.md` 和 `docs/bringup.md`。
