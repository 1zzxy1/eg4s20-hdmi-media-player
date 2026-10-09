# EG4S20 HDMI 多媒体播放系统

面向 HX4S20C（EG4S20BG256）的 2026 安路赛道赛题一工程。

当前工程按资源约束采用 640×480@60Hz、RGB888、SDRAM 双缓冲架构，目标基础链路为：

- TF 卡 SPI 读取 640×480、24-bit 非压缩 BMP；
- BMP 像素写入片内 2M×32 SDRAM 帧缓存；
- HDMI 输出视频和 48kHz 测试音；
- 按键切换与自动轮播；
- 低资源扩展：亮度调节和状态提示。

## 目录

- `rtl/`：当前工程 RTL 和可编辑的参考模块。
- `vendor/course/`：课程资料中的原始参考 RTL 副本，保留原文件名；其中 `.enc.v` 需要 TD 解密环境。
- `scripts/import_reference.py`：从上级资料库补充参考源码，不覆盖已有文件。
- `reference_manifest.json`：参考文件来源和 SHA-256。
- `constraints/`：HX4S20C 管脚及时序约束（后续补齐）。
- `sim/`：Icarus Verilog 功能仿真（后续补齐）。

## 目标器件

- Family：`EG4`
- Device：`EG4S20BG256`
- 板卡：`HX4S20C`
- 系统时钟：50MHz，来自 `R7`
- 视频像素时钟：25MHz
- HDMI 串行时钟：125MHz
- SDRAM 用户时钟：125MHz

## 当前状态

工程正在从课程参考源码重建，尚未声称已经完成 TD 综合、布局布线、固化或硬件测试。所有构建结果、数据库、位流和日志均被 `.gitignore` 排除。
