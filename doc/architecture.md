# 工程架构

## 当前精简稳定性候选

`src/media_player_top.v` 仅连接游戏、图集加载、TF 音频、排行和原厂 HDMI。目标是减少依赖并恢复旧版 HDMI 集成方式；尚未确认实板杂音／环绕／加载等待的根因。

```text
TF SPI → 扇区仲裁 → BMP 原尺寸解析 → 图集签名／完整帧验证 → 双读口纹理 RAM
                  └→ 音频目录／PCM → 五声部混音 ───────────────────┐
                                                                 ↓
固定视频时序 → 地图／游戏渲染 → RGB 转 AXIS → 原厂 HDMI 核 → 厂商 PHY
                   ↑                              ↑
              KEY／SW、世界、排行            上电 EDID／实际 DDC
```

图集与音频共享卡，先完成图集，再启动音频。游戏每帧只读片内地图和纹理，不读取 SD 或 SDRAM。像素25MHz、SD侧50MHz、串行125MHz，原 PLL 参数保留，未使用的40MHz SDRAM输出及两条对应 generated clock 约束已移除。

| 模块 | 当前职责 |
|---|---|
| `storage/game_asset_loader.v` | V4 固定 LBA2337 读取一次原尺寸 BMP；失败等50ms重试，图集发布后停止 |
| `storage/bmp_sector_player.v` | `ENABLE_SCALE=0`，640×480／24-bit／bottom-up BMP 解析；像素直接交付，不依赖 SDRAM DMA |
| `game/game_texture_cache.v` | 提取85个16×16纹理、16色；每读副本11个2048×4 bank，两个独立读副本；完整帧和16像素签名校验后跨域发布 |
| `game/game_level_map.v` | 4096格真双口同步RAM；A口世界读写／重载，B口渲染读；数据由公开Area6对象流生成 |
| `game/game_world.v` | 帧步进Q4物理、串行地图碰撞、四敌槽、道具／龟壳／双火球、旗杆与城堡结算 |
| `game/game_video.v` | 同步地图和纹理流水、HUD／昵称／头像／排行、砖块／奖励／死亡演出；320×240视口两倍映射640×480 |
| `control/game_inputs.v` | 去抖、模式隔离、KEY3左／KEY2跳／KEY1右／SW4跑火；KEY4昵称和长按开始 |
| `audio/sd_pcm_player.v` | LBA1目录、48kHz s16le mono，BGM＋4 SFX，跨域扇区双缓冲、饱和混音 |
| `audio/pcm48_tone.v` | 48kHz节拍／ACR及首屏独立1kHz测试音 |
| `game/game_scores.v`、`storage/game_score_flash.v` | 前十排行、独立用户Flash双扇区CRC日志 |
| `video/game_hdmi_output.v` | `READ_EDID=1`；启动脉冲、实际DDC、完整行转AXIS、原厂HDMI核及视频背压锁存 |

HDMI固定25MHz、800×525、640×480、约59.524Hz，RGB／VIC1；HS96、前肩16、后肩48，VS2、前肩10、后肩33。48kHz双声道24-bit LPCM，单声道混音复制给左右，N6144／CTS25000。EDID用于恢复原参考集成接法，不自动改输出模式。没有增加横向像素补偿。

## 加载与输入边界

图集的LBA2337来自 `make_sd_image.py` 的FAT16固定布局：2048分区起点＋1引导＋2×128 FAT＋32根目录。它不是LBA2048，也不是通用FAT文件解析。当前只支持该镜像布局下的首张游戏图集，其他预览图不加载。

`asset_begin` 清写入计数，`asset_we` 交付原始BMP像素，`asset_commit` 表示完整源帧结束；纹理缓存仍独立检查307200像素和签名，正确后才锁定。加载就绪跨两拍同步回SD域，失败重试。底层SD永久不结束仍需复位，不承诺热插拔。

视频时序的read_req在精简顶层直接确认。游戏不再被SDRAM初始化、首帧DMA或显示切槽确认门控。KEY4在首屏请求PROFILE；PROFILE长按一秒产生quick_start，世界锁存到帧边界、图集和地图就绪后消费。进入游戏先松开KEY1–3使能。SW1全局静音，SW2仅首屏测试音，SW3未使用，SW4跑火。

## 游戏、声音和排行

关卡参考Area6／E_GroundArea6，212格、三坑、六管、17个敌人生成点。公开输入通关测试跑到x3264。不是NES模拟器；地下房、烟花、原版逐帧物理尚未完成。

世界按CONTACT→COMMIT→PICKUP→FIRE_STEP→FINISH结算，死亡优先，分数和生命按事件累加。奖励渲染两槽保存世界坐标和寿命；死亡120帧，滑旗后自动入城并逐帧TIME换分。固定文字用1024×8同步ROM，HUD复用一个double-dabble转换器，地图和纹理读口均保留一拍延迟。

`sd_sector_arbiter` 锁定完整扇区，`audio_sector_bridge` 用toggle握手跨域，短扇区／超时检测保留。播放器用五个512×16样本RAM，每声部两扇区，事件队列与generation标签防旧请求污染新音。混音在两次采样之间完成，HDMI消费上一份稳定样本，保留固定一采样延迟；本轮未改PCM算法和音源。

声音默认开，主／BGM／SFX为3／2／3；静音继续推进，TITLE／PROFILE／PLAY播放地上BGM，星音乐替换，死亡／触旗停BGM、保留事件音，重生重播。SW2测试音独立于SD，只在TITLE覆盖输出。

排行为96bit×10，分数降序、时间升序。用户Flash保留 `0x600000/0x601000` 两个4KiB扇区，JEDEC／归属检查、CRC／双日志／最后提交，不擦写未知区；不支持时保留RAM排行。它与FPGA配置Flash W25Q16不同，实板掉电恢复未验收。

## 保留但未启用的媒体代码

SDRAM四槽、图片目录扫描、切换／轮播、转场、亮度／对比度、窄视口、波形和首屏实验室源码及测试继续保留，本版顶层不实例化。此前四槽为当前图＋后三张，共4915200字节，显示确认后回收；这段属于历史设计能力，不能作为当前位流的功能说明。

直接封包器 `game_hdmi_tx.v` 也保留；HDMI专项用 `--direct` 检查，默认检查正式原厂路径。当前Slice7135／9800、LUT13444、FF5428、BRAM52／64、DSP3、PLL2、GCLK2，原生setup +4.053ns／hold +0.011ns。数字验证、资源下降均不能替代实板声画验收。

目录职责为 `src/ip/prj/script/test`，参考FPGA_3结构，不引入其STM32或Quartus依赖；不编辑生成的 `build/staging/gui/`。操作见 [板上测试](board-demo.md)，赛题完成度见 [进度](competition-status.md)。
