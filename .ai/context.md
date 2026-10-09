# 当前工程

- 目标：2026 安路赛题一，HX4S20C / EG4S20BG256，TF SPI → BMP → SDRAM 双缓冲 → HDMI 音视频，手动切图、轮播、上电自启。
- 实现预算：640×480 RGB888，像素按 32 位存储，两帧占 2457600 字节；25MHz 像素、125MHz TMDS/SDRAM，100MHz TF 控制域。
- 当前只有参考模块和新增的音频、复位、亮度/状态叠加模块；顶层、约束、测试与 TD 构建尚待完成。25MHz 对应 59.524Hz，不能标为精确 60Hz。
- 本机工具：Icarus Verilog、TD 6.2（`E:/1_software/TD`）、GitHub CLI。
- GitHub：`1zzxy1/eg4s20-hdmi-media-player`，必须 private。
- 原始资料和整个上级目录不属于 Git 工程。构建数据库、日志、位流不可入库。
