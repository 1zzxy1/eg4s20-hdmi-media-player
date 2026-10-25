# EG4S20 游戏稳定性候选

当前目标只有三项：BGM 正常、游戏可玩、画面完整。2026-10-25 版暂时停用素材浏览、轮播、波形、调色及显示设置，保留游戏、昵称／头像、排行、TF 音乐与音效；尚未经过本轮实板验收，不能称为已经恢复正常。

Git 本地和远端 main 仅有马里奥开发前的源码，没有“第一次 BGM 正常”的游戏提交。已核对本机历史记录，未找到可完整恢复的中间源码；因此保留游戏，依据旧版接法恢复原厂 HDMI 核、上电 EDID 触发及实际 DDC 引脚连接，同时精简当前顶层。资源高、HDMI 差异均未证实为实板故障根因。

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
