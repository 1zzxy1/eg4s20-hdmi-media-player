# EG4S20 HDMI 多媒体播放系统

面向 HX4S20C（EG4S20BG256）的 2026 安路赛道赛题一工程。

五项进阶功能已集成，默认全部启用。工程采用 640×480@59.524Hz、RGB888、SDRAM 双缓冲架构。完成软件仿真和 TD 构建不等于实板验收；尚未烧录、固化或测试断电启动。

- TF 卡 SPI 读取连续存储、正高度、24-bit 非压缩 BMP，尺寸 1..1920 × 1..1440；
- BMP 像素写入片内 2M×32 SDRAM 帧缓存；
- HDMI 输出视频和 48kHz 测试音；
- 按键切换与自动轮播；
- 进阶：时间戳/滚动字幕/半透明叠加、淡入淡出和显影、最近邻缩放、亮度/对比度与参数显示、PCM 波形/峰值。

## 目录

- `rtl/`：当前工程 RTL 和可编辑的参考模块。
- `vendor/course/`：课程资料中的原始参考 RTL 副本，保留原文件名；其中 `.enc.v` 需要 TD 解密环境。
- `scripts/import_reference.py`：从上级资料库补充参考源码，不覆盖已有文件。
- `reference_manifest.json`：参考文件来源和 SHA-256。
- `constraints/`：HX4S20C 管脚及时序约束。
- `sim/`：Icarus Verilog 自检测试平台。
- `docs/validation.md`：资源、带宽、时序结果及剩余风险。
- `docs/bringup.md`：测试卡准备、板卡操作与验收步骤。
- `docs/advanced-validation.md`：本轮五项功能、仿真边界及资源矩阵。
- `docs/code-provenance.md`：哪些是参考/加密 IP、哪些是本次自写和修改。

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
python scripts/verify.py
python scripts/build_td.py --stage bitstream
python scripts/build_td_gui.py
python scripts/make_sd_image.py build/media/demo-advanced.img
python scripts/profile_matrix.py
```

需要 Python 3、PATH 中的 `iverilog`/`vvp`、TD 6.2 以及 ModelSim。`test_vendor.py` 支持 `--modelsim`/`--td` 覆盖工具目录；HDMI 测试脚本当前使用本机目录。默认 TD console 路径可用 `--td` 或 `TD_CONSOLE` 覆盖。构建输出在 `build/td/`，主位流为 `media_player.bit`；图片镜像命令拒绝覆盖现有文件，也不直接操作物理磁盘。

顶层为 `rtl/media_player_top.v`。KEY1 复位、KEY2 下一张、KEY3 开关自动轮播；KEY4 短按切对比度、长按切淡入淡出/显影。SW1/2 调亮度，SW3 开关文字层，SW4 开关波形，HDMI-A 输出音视频。

TD GUI现在打开 **`build/td_gui/media_player.al`**，Programmer下载 **`build/td_gui/media_player_Runs/phy_1/media_player.bit`**。`build_td_gui.py`使用TD原生工程管理生成独立GUI工程，并实际运行与GUI RUN相同的流程，检查约束传递、23个IO位置和时序。`build/td`保留批处理构建用途；不要在仍缓存旧工程的窗口继续RUN。逐项实物演示请照 [板卡演示清单](docs/board-demo.md) 操作。

当前读取器是有界扇区扫描，不是 FAT 文件系统：从 LBA 2048 起，在前 64MiB 中搜索四张连续存储的 BMP。生成器默认创建混合尺寸四图 FAT16 镜像；`--native` 生成四张640×480图片供关闭缩放的配置使用。普通复制、删除后产生的碎片文件不保证支持。缩放为拉伸填满，不保持纵横比；没有双线性插值、FFT、两图交叉混合或真正的平移转场。

`python scripts/verify.py` 执行引脚/来源检查、11个模块/链路测试、23个BMP场景、18帧独立黄金像素比对、原厂加密SDRAM控制器测试及原厂HDMI数字接口测试。证据在 `build/verification/`；任何步骤失败即终止。SDRAM阵列使用自建器件模型，HDMI未建完整音频接收器和模拟PHY；这些边界不会被标作“全部硬件已证明”。

源码和验证结论保存在 private GitHub 仓库；构建数据库、日志、卡镜像和位流留在本机。原始资料上级目录未纳入 Git。
