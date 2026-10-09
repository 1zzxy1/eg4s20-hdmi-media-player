# EG4S20 HDMI 多媒体播放系统

面向 HX4S20C（EG4S20BG256）的 2026 安路赛道赛题一工程。

首版已通过 6 个模块功能测试、TD 6.2 综合和布局布线，并生成 `.bit`。尚未上板、固化或完成全链路实测。工程采用 640×480@59.524Hz、RGB888、SDRAM 双缓冲架构，基础链路为：

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
- `constraints/`：HX4S20C 管脚及时序约束。
- `sim/`：Icarus Verilog 自检测试平台。
- `docs/validation.md`：资源、带宽、时序结果及剩余风险。
- `docs/bringup.md`：测试卡准备、板卡操作与验收步骤。

## 目标器件

- Family：`EG4`
- Device：`EG4S20BG256`
- 板卡：`HX4S20C`
- 系统时钟：50MHz，来自 `R7`
- 视频像素时钟：25MHz
- HDMI 串行时钟：125MHz
- SDRAM 用户时钟：40MHz，转发时钟相移 172.8°
- TF 控制时钟：50MHz；初始化 SPI 约 100kHz，读取 SPI 12.5MHz

## 当前状态

```sh
python scripts/test.py
python scripts/build_td.py --stage bitstream
python scripts/make_sd_image.py build/media/demo.img
```

需要 Python 3、PATH 中的 `iverilog`/`vvp` 和已授权的 TD 6.2。默认 TD console 路径可用 `--td` 或 `TD_CONSOLE` 覆盖。构建输出在 `build/td/`，主位流为 `media_player.bit`；图片镜像命令拒绝覆盖现有文件，也不直接操作物理磁盘。

顶层为 `rtl/media_player_top.v`。按键 KEY1 复位、KEY2 下一张、KEY3 开关自动轮播；SW1/2 调亮度，SW3 开关状态条，HDMI-A 输出音视频。

当前读取器是有界扇区扫描，不是 FAT 文件系统：从 LBA 2048 起，在前 64MiB 中搜索四张连续存储的正高度 640×480 RGB888 BMP。使用生成器创建的四图 FAT16 镜像可满足这一布局；普通复制、删除后产生的碎片文件不保证支持。只保证项目中所列软件验证，不代表整机已达成竞赛要求。

源码和验证结论保存在 private GitHub 仓库；构建数据库、日志、卡镜像和位流留在本机。原始资料上级目录未纳入 Git。
