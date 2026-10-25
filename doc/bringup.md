# 下载、图片卡与 Flash 固化

用户已反馈上一版游戏可玩。2026-10-24 已将新版 V4 镜像写入用户本次插入的约 8GB SD，完成前 65MiB 备份、整段逐字节回读及六 BMP／音频包文件校验，并安全弹出；回执在 `build/media/sd-write-20261024-135832/receipt.json`。2026-10-25本轮为精简游戏稳定性候选，恢复原厂HDMI完整EDID／DDC接法，暂停首屏实验室；素材保持V4，不用重写已校验的卡。新版板卡由用户自行烧录，下载／固化和实板效果尚未确认。按键与新版本验收见 [板上操作](board-demo.md)。

## 准备文件

在 workspace 下执行：

```powershell
python script/pack_game_assets.py
python script/verify.py
python script/build_td_gui.py
python script/make_sd_image.py build/media/game-audio-new.img assets/game/atlas.bmp assets/game/preview_1.bmp assets/game/preview_2.bmp assets/game/preview_3.bmp assets/game/preview_4.bmp assets/game/preview_5.bmp --audio-pack assets/audio/AUDIO.PAK
```

当前可直接使用已生成的 `build/media/game-audio-v4.img`，65MiB，含六张像素风混合尺寸 BMP、结束标记和 24 轨音频包。SHA-256 为 `37553923c0d73f69646ad592af4fe4b0d8b39c067435cc62a6ba29f87f03f637`。首图仍为 640×480，后五张为 320×240、800×600、641×479、640×480、960×720。`assets/audio/AUDIO.PAK` 未变，不必重新下载；来源见其 manifest。上面的命令用于重新打包，工具拒绝覆盖已有文件，旧 V3 镜像保留。首张带签名的 atlas 是游戏启动必需的。以下为保留的媒体素材工具用法，当前精简位流不支持普通图片浏览，不能用这些图片替换首张游戏图集：

```powershell
python script/make_sd_image.py build/media/custom.img a.bmp b.bmp c.bmp d.bmp e.bmp f.bmp
```

打包器可传1..64张正高度、24-bit非压缩BMP，尺寸1..1920×1..1440；总量受镜像容量限制。当前硬件只读取LBA2337的首张640×480带签名图集，不再扫描其他图片。生成的 65MiB 镜像含 MBR、FAT16、连续图片簇及结束标记。`--count N` 仅用于自动生成测试图，`--native` 生成 640×480 测试图。

音频不是在 FPGA 中解码 MP3：工具离线转为 48kHz、16-bit 单声道 PCM 并打成扇区对齐包。镜像在 LBA1 写入带绝对位置的音频目录，因此**不能仅复制 `AUDIO.PAK` 到旧卡，也不能把 `.img` 复制为卡内文件**。旧 `game-cache.img` 没有音频包；本次卡已经于 2026-10-24 更新到 V4。后续确需重写时重新核对当前目标，不沿用历史盘号。新镜像独立检查了 MBR/BPB、两份 FAT、八个连续文件、LBA1 目录、24 轨 PCM 与源文件哈希。

准备下载前执行游戏版配套检查：

```powershell
python script/check_deployment.py
```

默认核对已生成的 V4 镜像；若刚运行上方重新打包命令，改用 `python script/check_deployment.py --image build/media/game-audio-new.img`。成功应同时显示当前源码／TD 位流匹配与 TF 图片／音频匹配。它检查实际 staging 和回执，不会刷新真实 staging 来掩盖过期工程；也检查图集签名、调色板、音频来源清单，并把镜像与当前素材按打包规则重建的结果逐字节哈希比较。旧无音频游戏卡镜像、损坏目录、旧素材或被替换的位流均会非零退出。源码或 staging 不符时重新构建；镜像不符时打包到新文件。检查通过只证明本地文件配套，不代表实体 TF 已写入、HDMI 音频正常或板测完成。

## JTAG 易失下载测试

可选音频对比：`build/media/game-audio-v5-candidate.img` 是同一位流的低延迟素材候选，默认仍采用原始 V4。候选由 `python script/prepare_game_audio.py` 从原始 PAK 生成新目录 `build/media/audio-lowlatency/`，再将上面的镜像打包命令的输出改为新文件、`--audio-pack` 改为该目录的 `AUDIO.PAK`。已生成的候选无需重复生成；工具拒绝覆盖，重做时用 `--output-directory` 指定新目录。下载前核对：

```powershell
python script/check_deployment.py --image build/media/game-audio-v5-candidate.img --audio-directory build/media/audio-lowlatency
```

候选只把 14 条即时音效的低电平前沿缩短约 5.9～11.0 ms，不修改保留波形、尾音、BGM、死亡或通关音乐，不改变位流。先可对比 `assets/audio/` 与 `build/media/audio-lowlatency/` 的同名 WAV；实际选择需在同一板卡、显示器、音量下对比跳跃／金币／顶砖／变身／火球，检查起音、尾音、连续触发及四音效叠加。尚未实屏试听，不据此宣称端到端延迟降低；原始 V4 和音源始终保留。

1. 连接 HX4S20C 供电、USB Cable 下载口和 HDMI-A，显示器选择对应输入。
2. 把新镜像作为整盘镜像写入 SDHC 卡并回读校验，不能把 `.img` 当普通文件复制；执行前核对物理盘号和卡内数据可清空。2026-10-24 本次卡已完成，可直接插板测试；Windows 显示约 64MiB 分区是镜像布局，实板测试前不要重新格式化或扩容。
3. 打开 `prj/media_player.al`，用 TD Programmer / BitWriter 刷新 JTAG 链，确认 EG4S20BG256。
4. 选择 `prj/media_player_Runs/phy_1/media_player.bit`，执行 FPGA SRAM 配置。RUN 是编译，Program 才是下载。
5. 所有SW下拨，等待LED1 SD初始化及LED2图集完成，随后应播放BGM。首屏SW2为独立1kHz测试音，SW1为全局静音。KEY4进入昵称，松开后长按一秒直接开始；图集等待期间保留开始请求。游戏KEY3左、KEY2跳、KEY1右、SW4跑步／火球。进入游戏先松开KEY1–3。SW3暂空，旧素材／波形／显示实验室已停用。按[板上测试](board-demo.md)验收实际音乐、画面环绕和进入游戏；当前未确认实板故障已恢复。
6. JTAG SRAM 配置断电丢失，CONFIG1 也可能触发重新配置；它不能代替固化验收。

如下载器未显示，先查看当前 Windows 设备状态，不沿用历史驱动报错结论；`.ai/handoff.md` 保留此前代码 52 排查供追溯。

## 固化为上电运行的 FPGA 配置

此处“固件”是 FPGA 配置位流。先确认本轮 JTAG 测试通过，再使用 TD / 板手册对应的配置 Flash 流程。

- 目标是 **配置 Flash W25Q16，16Mbit（约 2MB）**；不要选到用户 SPI Flash W25X64/W25Q64。
- 由 TD 配置转换或 Programmer 支持的流程生成/选择正确格式；`.bit` 不能直接改后缀冒充 `.bin`。具体界面选项需按安装的 TD 版本确认。
- 执行配置 Flash 擦除、编程和校验，保留 Programmer 成功记录及源位流 SHA-256。
- 断电，移除 PC 下载依赖，按板级启动配置独立供电；应自动读取 TF 图集、显示首屏、默认播放音乐并恢复排行榜。
- 冷启动至少十次，再连续游玩／播放至少 60 分钟，记录是否花屏、卡死、丢音或 LED4 亮。次数/时长是工程验收建议，并非已核实的赛事硬性条文。

## 构建故障定位

`BIT-8123` 表示未约束 IO，检查实际 RUN 的 ADCList/SDCList 是否包含正式约束。当前 `build_td_gui.py` 已实际验证约束传递及 29 个 IO 位置；不要打开历史空约束工程或允许未约束 IO 来绕过。

此前PHY-7002来自SDRAM中间ECO位置重放置，PHY-5079对应SDRAM单负载转发时钟；本版取消SDRAM实例，这两条警告不再出现。当前RUN的setup +4.053ns／hold +0.011ns，29 IO正确。板级电气与显示器兼容仍需实测，不扩大false path掩盖故障。
# 游戏版补充

当前下载入口仍为 `prj/media_player.al` 和 `prj/media_player_Runs/phy_1/media_player.bit`；TF 卡应使用 `build/media/game-audio-v4.img`，首图是游戏 atlas。四 KEY／SW 的新映射见 [板上演示](board-demo.md) 顶部。本版没有首屏Debug实验室；KEY1在昵称／排行返回，游戏中右移，SW1静音、SW2首屏测试音。整个系统的上电复位来自 PLL 锁定，重新加载配置或断电会重新读取图集。

固化配置仍用 W25Q16（约 2MB）；排行榜用独立用户 W25X64／W25Q64（约 8MB）的两个日志扇区。这两者用途和引脚不同。先用 JTAG SRAM 下载验证画面、声音、排行榜写回，再按上方配置 Flash 流程固化，脱离下载器冷启验收。本轮生成文件不等于已完成硬件烧录。

---
