# EG4S20 HDMI 游戏与多媒体实验室

用户已实板确认：人工横向补偿后的画面正常、BGM 无杂音、游戏可玩。当前已在同一工程中恢复素材浏览、切图／轮播、动态字幕、PCM 波形与显示设置，原生构建和部署配套检查通过；恢复版仍需用户实板验收。

## 下载和日常构建

工程入口：`prj/media_player.al`；正式顶层：`src/media_player_top.v`。日常执行：

```powershell
python script/build_td_gui.py
python script/check_project.py
python script/check_deployment.py
```

三个命令成功后，用户用 TD Programmer／BitWriter 下载 `prj/media_player_Runs/phy_1/media_player.bit`。无需手动 RUN；不要修改 `build/staging/gui/`。构建前关闭旧 TD 工程，关闭时不要保存过期的源文件清单。构建报告和输入／位流配套回执位于 `prj/verification.json`。

如果手动 RUN 出现 `game_display_alignment`、`media_gallery` 或 `game_alignment_pattern is a black box`，先关闭工程且不要保存旧清单，再执行上述三个命令，完成后重新打开 `prj/media_player.al`。旧 GUI 缓存可能把新增文件登记覆盖掉；构建脚本会补全持久登记、清理排除缓存，并在工程被占用时拒绝改写。已有工程的脚本 RUN 直接使用保存的 RTL 清单，避免临时 `add_files` 掩盖 GUI 缺项。

2026-10-25 17:44:40 修复 GUI 源文件清单后重新生成的恢复版位流为 636621 字节，SHA256 `da6dd4c3f4a104a08e7d3c2e715690395991f562a8b9d367ed4ad7b6210175f6`。实际 hold ECO 修复并重新生成位流后，setup +2.435ns／hold +0.024ns；RTL 与此前恢复版相同，LUT 18368／19600（93.71%）、BRAM 62／64、DSP 7／29。资源较紧，后续扩展需重新评估。

继续使用原 V4 SD 卡，素材和音频布局没有变化，无需重写卡。当前没有操作实体卡、下载 FPGA 或固化配置 Flash。详细下载流程见 [下载与固化](doc/bringup.md)。

## 操作

上电先将 SW 全部下拨，等待 LED2 图集就绪。首屏按 KEY4 进入昵称，松开后再次长按 KEY4 一秒开始。进入昵称后，首屏 Debug 操作关闭。

| 场景 | 拨码／按键 | 用途 |
|---|---|---|
| 首屏素材 | SW1 上拨 | 显示完整素材 BMP；KEY2 上一张、KEY3 下一张、KEY1 开／关自动轮播 |
| 字幕／波形 | 首屏 SW2 上拨 | 滚动字幕、状态和真实 PCM 波形；可与素材页叠加 |
| 显示设置 | 首屏 SW1＋SW3 上拨，SW4 下拨 | KEY2／KEY3 选择，KEY1 修改视口、色彩、测试图、亮度、对比度、转场或复位设置 |
| 音频设置 | 首屏 SW4 上拨 | KEY2／KEY3 选择，KEY1 修改开关、三组音量、音效编号／试听、独立 1kHz 测试音 |
| 横向校准 | SW3 上拨，SW1／SW4 下拨 | KEY3 左移、KEY1 右移；按住 KEY2 为 16 像素粗调；KEY4 归零；下拨 SW3 保留调整值并退出 |
| 游戏 | KEY3／KEY2／KEY1 | 左走／跳跃／右走 |
| 游戏 | SW4 | 加速／火焰形态发射火球 |

校准默认 128，范围 0～639，断电恢复默认值，不写 SD／Flash。输出固定 640×480，保留原 HDMI 时钟、DDC 和正常的音频通路。显示设置切换逻辑视口缩放，两种视口均铺满输出宽度；不会切换显示器输入分辨率。

默认有声，主／BGM／SFX 音量为 3／2／3。波形显示 64 个 48kHz PCM 样本（1.33ms）、零线、幅度参考、增益和电平条。声音开关在音频设置中，SW1 不再是旧稳定性版本的全局静音。

## 数据与模块

启动优先读取 V4 首张 BMP 的游戏图集，完整帧和签名通过后锁定纹理缓存、启动音频；随后复用同一个 BMP 解码器扫描六张素材并预取。图库使用 SDRAM 四槽，当前图＋后三张，显示确认后回收旧槽。游戏不等待图库或 SDRAM 就绪；SD 扇区仲裁优先服务音频。

图库、菜单、字幕和游戏共用相同的横向补偿值。SDRAM 按 16 词对齐读取，最多 16 词的小缓冲处理行内微调，避免奇数偏移时读错像素。

```text
workspace/
├─ src/          正式 RTL：game、storage、memory、video、audio、control、common
├─ ip/           PLL、SD、SDRAM、厂商 HDMI／PHY
├─ prj/          TD 工程、约束及当前构建回执
├─ assets/       地图、图集、音频及来源清单
├─ script/       构建、素材制作、验证与部署检查
├─ test/         自检仿真与独立黄金参考
├─ doc/          操作、架构、赛题与来源
├─ .ai/          协作上下文与交接
└─ build/        生成物、仿真日志、镜像及稳定版本备份
```

[板上操作](doc/board-demo.md) · [架构](doc/architecture.md) · [赛题与进度](doc/competition-status.md) · [代码来源](doc/code-provenance.md) · [测试说明](test/README.md)。

游戏是自研 RTL 单关实现，保留昵称／头像／排行、道具、敌人、BGM 与音效；不声称 FC 原作逐帧完美复刻。恢复版的实屏效果、声音、冷启、排行掉电和长稳仍需验收。先前已确认正常的对齐版完整备份在 `build/rollback-evidence/board-confirmed-20261025-aligned/`。
