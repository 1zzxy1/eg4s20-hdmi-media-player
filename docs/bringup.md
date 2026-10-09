# HX4S20C 首次上板流程

## 先准备本地文件

在 workspace 执行：

```sh
python scripts/test.py
python scripts/build_td.py --stage bitstream
python scripts/make_sd_image.py build/media/demo.img
```

或用四张自选正高度、非压缩 640×480 RGB888 BMP：

```sh
python scripts/make_sd_image.py build/media/custom.img a.bmp b.bmp c.bmp d.bmp
```

镜像是 17MiB、MBR + FAT16 文件系统，四张图片连续分配，便于当前扇区扫描器读取。程序只创建普通文件，不烧写磁盘。不支持通过任意编辑器删除/重拷图片后仍假定连续。

## 板卡与操作

1. 使用 HX4S20C，核对器件 EG4S20BG256；连接供电和 USB Cable，HDMI 接板上 A 口及带音频的显示设备。
2. 将镜像写入一张可擦除的 SDHC 卡。**执行写卡前必须确认具体物理磁盘和现有数据可以清空**；本任务尚未执行此步骤。
3. 先用 TD Programmer 把 `build/td/media_player.bit` 下载到 FPGA 做易失性调试。当前未执行任何下载，也未验证 PC 已识别实际板卡。
4. KEY1（A2）复位，KEY2（B2）下一张，KEY3（B1）开启/关闭自动轮播。启动默认手动模式，自动加载首图。
5. SW1/2 组成亮度模式：00 原图、01 +32、10 +64、11 −32；SW3 打开状态条。拨码的实际高低方向以板卡测量为准。
6. LED1 SDRAM 初始化完成；LED2 已提交首帧；LED3 HDMI 视频锁定；LED4 HDMI AXIS ready 违约粘滞标志。输出按低有效设计，需核对实际 LED 极性。
7. 屏幕应按四图切换，状态条绿色代表已显示、橙色代表等待；扬声器应输出 1kHz 测试音，采样率 48kHz。

## 固化与竞赛验收

先完成易失性下载测试，再使用 TD/板手册对应流程把设计固化到配置 Flash W25Q16（16Mbit），不要误选用户 SPI Flash。`.bit` 不可直接改后缀冒充 `.bin`；配置转换和固化步骤需按 Programmer 实际格式及板卡接线确认。

| 验收项 | 当前状态 | 上板证据 |
|---|---|---|
| TF BMP → SDRAM → HDMI | 代码集成、模块仿真、构建通过 | 拍摄完整四图与颜色/方向正确性 |
| 手动与自动切图 | 已集成帧提交握手 | 快速按键、长按、加载中切换、无撕裂视频 |
| HDMI 48kHz 音频 | PCM/ACR 仿真通过 | 接收端声音与采样率、连续播放 |
| 上电自运行 | RTL 有复位/自动首图流程 | 固化后断 USB 数据连接，冷启动至少十次 |
| 亮度及信息叠加 | 模块仿真通过 | 操作四档、无颜色回绕、状态条同步 |
| 稳定性 | 待验收 | 至少 60 分钟轮播、无欠载/闪屏/丢音 |

先定位 LED 状态和 TD 实际报告，再决定是否修改频率/约束。不要通过禁用检查或扩大 false path 掩盖故障。内存有效带宽及 TF/HDMI 外部电气时序仍是重点验证对象。
