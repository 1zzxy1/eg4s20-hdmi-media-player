# EG4S20 游戏稳定性候选

## 当前：仅测试画面错位（2026-10-25）

最新实测：A、B 都是 `8 9 0 1 2 3 4 5 6 7`，左右边框一起移到屏内（照片 `D:/download/44.jpg`）。旧数字检查未覆盖此实屏故障，不能据其通过宣称修复；也没有证据认定资源占用是根因。显示器型号未知，后续从 FPGA 输出兼容性处理。

当前待板测改用独立 **C SVGA DVI**：固定标准 800×600、40MHz、1056×628、约 60.317Hz、正极性同步。不读取 EDID，不是已完成的自动分辨率适配；它用于检验不同输出模式能否避免环绕。原 A/B 和游戏位流保留。

下载 `build/video_svga/media_player_Runs/phy_1/media_player.bit`，2026-10-25 14:37:01，629635 字节，SHA256 `56166cd2e49119044c8d68cf30cc1929cf5783e10fb5e818691d96fa2cf46167`。SW 全下，KEY4 可复位；只显示测试图、没有声音，不需要 SD 卡。应看到 `C SVGA DVI / 800 X 600`，编号从左到右 0～9、左红右绿、上蓝下黄。操作见 [板上测试](doc/board-demo.md)。

```powershell
python script/test_video_svga.py
python script/build_td_gui.py --video-svga
python script/check_project.py --video-svga
python script/check_deployment.py --video-svga
```

原生 TD 构建通过：setup +1.447ns、hold +0.025ns，Slice 492／9800（5.02%）、BRAM 0、DSP 0。最终数字专项通过两整帧 960000 像素、1965235 串行字及损坏颜色负例，功能 PLL 和同步检查通过；实际画面仍待用户下载确认。游戏的已正常 BGM 实现未修改，原卡不用重写。

### 上一轮 A/B 诊断（已实测两者都错位）

用户已实测确认BGM无杂音，右侧画面绕到左侧仍存在。游戏源码／素材已保存为本地Git检查点 `d84d8db`。现在使用独立纯视频诊断位流，暂时关闭游戏、TF读取、音频与排行写入；下面的游戏操作保留为基线说明。

诊断位流：`build/video_diagnostic/media_player_Runs/phy_1/media_player.bit`，14:07:07，629641字节，SHA256 `b0becade21261481568ac2ff81feb4c1e17c6c3121c1be0a1df7e451305cdde4`。SW1下拨为 `A VENDOR HDMI`，上拨为 `B PURE DVI`，KEY4重置视频；同一HDMI-A接口、同一640×480／25MHz时序。没有声音是诊断版的预期行为，不需要SD卡。看0～9编号是否从左到右连续、左红右绿边框是否在屏幕两端。具体步骤和结果判读见 [板上测试](doc/board-demo.md)。

```powershell
python script/test_video_diagnostic.py
python script/build_td_gui.py --video-diagnostic
python script/check_project.py --video-diagnostic
python script/check_deployment.py --video-diagnostic
```

诊断工程／staging／回执独立，不覆盖 `prj/` 下的游戏位流。Slice1444／9800=14.73%，BRAM10／64，DSP0，原生setup +3.273ns／hold +0.011ns。像素、同步和串行数字检查通过不等于实屏已恢复。

## 游戏基线（下文操作只适用于游戏位流）

游戏基线保留游戏、昵称／头像、排行、TF音乐与音效，暂停素材浏览、轮播、波形、调色及显示设置。用户最新实测确认BGM无杂音，但右侧画面仍绕到左边，因此本轮先使用上面的纯视频诊断。

Git 的早期历史只有马里奥开发前的源码，没有“第一次 BGM 正常”的游戏提交；当前完整游戏已本地保存为 d84d8db。已核对本机历史记录，未找到可完整恢复的中间源码；因此保留游戏，依据旧版接法恢复原厂 HDMI 核、上电 EDID 触发及实际 DDC 引脚连接，同时精简当前顶层。资源高、HDMI 差异均未证实为实板故障根因。

## 下载与操作

- 工程：`prj/media_player.al`；正式顶层：`src/media_player_top.v`。
- 位流：`prj/media_player_Runs/phy_1/media_player.bit`，2026-10-25 01:06:38，633129 字节。
- 位流 SHA256：`612b575c4a54820af56f06b9569038156895cf4b1d5229b713248c36715a5d37`。
- 继续使用原 V4 卡；本轮未改镜像、未写实体卡、未下载板卡或固化 Flash。
- [板上操作](doc/board-demo.md) · [下载与固化](doc/bringup.md) · [架构](doc/architecture.md) · [赛题与进度](doc/competition-status.md) · [来源](doc/code-provenance.md)。

上电先将 SW 全部下拨，等待 LED2 图集加载成功。按 KEY4 进入昵称，松开后再次长按 KEY4 一秒直接开始；短按逐字确认六字符和头像的流程也保留。进入游戏后松开 KEY1–3，再操作。

| 控件 | 当前用途 |
|---|---|
| KEY3／KEY2／KEY1 | 游戏中左走／跳跃／右走 |
| SW4 | 游戏中加速／火焰形态发射火球 |
| KEY4 | 首屏进入昵称；昵称长按一秒开始；死亡或结算后确认 |
| SW1 | 全局静音，上拨静音、下拨有声 |
| SW2 | 仅首屏以独立 1kHz 测试音覆盖 BGM；下拨恢复 |
| SW3 | 暂无功能 |

声音默认开，主／BGM／SFX 音量固定 3／2／3。输出固定 640×480，25MHz、800×525，约 59.524Hz；游戏采用 320×240 逻辑视口两倍放大。显示器负责放大到面板尺寸，没有增加横向坐标补偿。

## 构建与验证

在 workspace 下执行：

```powershell
python script/test_game.py
python script/test_hdmi_vendor.py
python script/build_td_gui.py
python script/check_deployment.py
```

日常构建使用 `build_td_gui.py → check_deployment.py`，成功后由用户用 TD Programmer／BitWriter 下载，无需 GUI 手动 RUN。构建前关闭旧 TD 工程，关闭时不要保存旧内存源清单。脚本持久登记全部正式 RTL，更新 staging 并实际执行原生 RUN；不要编辑 `build/staging/gui/`。

需要 Python 3、Icarus Verilog、ModelSim、TD 6.2，TD 默认 `E:/1_software/TD`。完整软件验证入口仍为 `python script/verify.py`，包含旧媒体功能；本轮专项验证不等于完整 14 组已重跑。结果和边界见 [当前进度](doc/competition-status.md)。

HDMI 专项默认原厂路径，`--direct` 可检查保留的直接核。包含真实 V4 PCM、独立音频解包、厂商串行器、游戏像素边界、故意错位负例及无响应 EDID 接收端下的 DDC 活动检查。数字验证不能代替实屏画面和试听。

## 当前数据路径

TF 首张 BMP → 原尺寸解码 → 双读口纹理缓存 → 游戏渲染 → 原厂 HDMI 核 → 厂商 PHY。图集成功后停止读图，再启动 TF 五声部 PCM；不再依赖 SDRAM 初始化、图片 DMA 或显示确认。

图集为 V4 固定布局 LBA2337 的 640×480、24-bit、正高度 BMP；完整帧和签名正确才发布，失败等待后重试。音频仍通过 LBA1 的目录定位。本版不提供任意图片浏览／通用 FAT 解析，其他五张预览 BMP 保留在卡中但不加载。

当前 Slice7135／9800（72.81%），LUT13444、FF5428、BRAM52／64、DSP3、PLL2、GCLK2。相比上一版 Slice94.99% 明显下降；恢复原厂核使 BRAM 从41升至52，不是所有资源都下降。原生 setup +4.053ns／hold +0.011ns，29 IO 检查通过。

## 目录与素材

```text
workspace/
├─ src/        正式 RTL：control、game、storage、memory、video、audio、common
├─ ip/         PLL、SD、SDRAM、厂商 HDMI／PHY 与参考 IP
├─ prj/        TD 工程、正式 ADC／SDC、位流与构建回执
├─ script/     构建、素材打包、验证
├─ test/       自检 bench 与功能器件模型
├─ assets/     游戏图集、音源、PCM 包及来源清单
├─ doc/        操作、架构、赛题与历史说明
├─ build/      可再生 staging、仿真、镜像及回退证据
└─ .ai/        当前上下文与交接
```

未启用的媒体模块保留源码和测试，方便声画稳定后逐项恢复。当前位流不满足基础手动切图／轮播及全部扩展，不能作为完整赛题功能交付。

继续使用 `build/media/game-audio-v4.img`，68157440 字节，SHA256：
`37553923c0d73f69646ad592af4fe4b0d8b39c067435cc62a6ba29f87f03f637`。

需要重建同布局镜像时：

```powershell
python script/pack_game_assets.py
python script/make_sd_image.py build/media/game-audio-new.img assets/game/atlas.bmp assets/game/preview_1.bmp assets/game/preview_2.bmp assets/game/preview_3.bmp assets/game/preview_4.bmp assets/game/preview_5.bmp --audio-pack assets/audio/AUDIO.PAK
python script/check_deployment.py --image build/media/game-audio-new.img
```

打包器拒绝覆盖已有镜像；不能把 .img 作为普通文件复制进卡。本轮无需重写原卡。游戏为自研 RTL 的 SMB 1-1 地上路线，含17个敌人生成点、道具／龟壳／火球、奖励与死亡／入城演出，保留昵称／头像／排行；不是 FC 模拟器，地下房、烟花和逐帧原作一致性未完成。
