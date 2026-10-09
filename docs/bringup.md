# HX4S20C 五项扩展版上板流程

按键、拨码和逐项演示表见 [board-demo.md](board-demo.md)。TD GUI打开 `build/td/media_player.al`；Programmer下载同目录 `media_player.bit`。该目录为生成工程，正式源码仍在`rtl/`。

## 先准备本地文件

在 workspace 执行：

```sh
python scripts/verify.py
python scripts/build_td.py --stage bitstream
python scripts/make_sd_image.py build/media/demo-advanced.img
```

或用四张自选正高度、非压缩 RGB888 BMP（宽1..1920，高1..1440）：

```sh
python scripts/make_sd_image.py build/media/custom.img a.bmp b.bmp c.bmp d.bmp
```

镜像是65MiB、MBR + FAT16文件系统，四张图片连续分配。默认尺寸640×480、320×240、800×600、641×479；`--native`可生成四张固定640×480图。程序只创建普通文件，不烧写磁盘。不支持删除/重拷图片后仍假定连续。

## 板卡与操作

1. 使用 HX4S20C，核对器件 EG4S20BG256；连接供电和 USB Cable，HDMI 接板上 A 口及带音频的显示设备。
2. 将镜像写入一张可擦除的 SDHC 卡。**执行写卡前必须确认具体物理磁盘和现有数据可以清空**；本任务尚未执行此步骤。
3. 先用 TD Programmer 把 `build/td/media_player.bit` 下载到 FPGA 做易失性调试。当前未执行任何下载，也未验证 PC 已识别实际板卡。
4. KEY1（A2）复位，KEY2（B2）下一张，KEY3（B1）开启/关闭自动轮播。启动默认手动模式，自动加载首图。
5. SW1是亮度低位，SW2是高位：两者下=原图；仅SW1上=+32；仅SW2上=+64；两者上=−32。SW3上打开时间戳、参数面板和滚动字幕；SW4上打开音频波形/峰值。方向依据手册第18页的标准摆放。
6. KEY4（C1）短按后松开：对比度100%→50%→150%→200%循环；长按至少1秒后松开：FADE/WIPE切换。参数于下一帧生效。
7. 四颗独立绿色LED高有效（手册第6页）：LED1亮=SDRAM初始化完成；LED2亮=已提交首帧；LED3亮=HDMI核锁定输入视频时序；LED4亮=HDMI AXIS ready违约粘滞标志。正常播放应前三亮、第四灭。LED3不证明显示器已经接收音视频。DIG/LED不控制这四颗灯。
8. 屏幕应按四图切换，混合尺寸图拉伸为640×480；淡出至全黑后换图，再淡入，或用显影模式。扬声器应输出1kHz测试音，采样率48kHz；波形来自同一份PCM。

## 固化与竞赛验收

先完成易失性下载测试，再使用 TD/板手册对应流程把设计固化到配置 Flash W25Q16（16Mbit），不要误选用户 SPI Flash。`.bit` 不可直接改后缀冒充 `.bin`；配置转换和固化步骤需按 Programmer 实际格式及板卡接线确认。

| 验收项 | 当前状态 | 上板证据 |
|---|---|---|
| TF BMP → SDRAM → HDMI | 代码集成、模块仿真、构建通过 | 拍摄完整四图与颜色/方向正确性 |
| 手动与自动切图 | 已集成帧提交握手 | 快速按键、长按、加载中切换、无撕裂视频 |
| HDMI 48kHz 音频 | PCM/ACR 仿真通过 | 接收端声音与采样率、连续播放 |
| 上电自运行 | RTL 有复位/自动首图流程 | 固化后断 USB 数据连接，冷启动至少十次 |
| 五项扩展 | 模块、黄金像素和组合链路仿真通过 | 字幕、转场、混合尺寸、四档亮度/对比度、波形逐项演示 |
| 稳定性 | 待验收 | 至少 60 分钟轮播、无欠载/闪屏/丢音 |

先定位 LED 状态和 TD 实际报告，再决定是否修改频率/约束。不要通过禁用检查或扩大 false path 掩盖故障。内存有效带宽及 TF/HDMI 外部电气时序仍是重点验证对象。
