# 代码来源与本次修改

2026-10-24 正式 HDMI 发射路径更换为本工程编写的 `src/video/game_hdmi_tx.v`：固定时序直通、四样本 LPCM 包、逐字节 BCH、ACR、AVI／Audio InfoFrame 和 Clear_AVMUTE。`game_hdmi_channel.v`／`game_hdmi_terc.v` 适配自用户提供的 `topic1_student_reference/project_code/risk_prototypes/hdmi_audio_route_b/rtl/hdmi_tmds_channel_encoder.v` 和 `hdmi_terc4_encoder.v`，文件头保留具体来源；参考分支的包组装／BCH／ACR 未直接移植。物理 PHY／ODDR 串行器继续采用原厂／课程代码。旧加密发射核、AXIS 适配器保留作对照回归，不再由正式顶层实例化。以下 10 月 21 日“未替换发射器”仅描述当时的验证工作，不能作为当前架构。

2026-10-21 新增接收侧验证 `script/check_hdmi_audio.py`，由本工程编写，读取 ModelSim 抓取的真实加密核 TMDS 输出，不移植或替换发射器。数据岛位序、TERC4／BCH、PCM／ACR 字段解释参考 HDMI 1.4 协议章节及 [hdl-util/hdmi](https://github.com/hdl-util/hdmi/tree/83b1c9543a91b776671a44e68e130f81cae437b7/src) 的固定 commit `83b1c9543a91b776671a44e68e130f81cae437b7`（`packet_assembler.sv`、`audio_sample_packet.sv`、`audio_clock_regeneration_packet.sv`）；仅查阅协议布局，没有复制第三方模块或加入综合。该仓库提供 MIT／Apache 许可证选择，原作者 Sameer Puri；不把协议参考或数字仿真表述为 HDMI 认证。

2026-10-21 新增可选音频候选处理：`script/prepare_game_audio.py` 读取已验收的原始 `assets/audio/AUDIO.PAK`，核对 24 轨 PCM 与 manifest 后，仅对即时动作白名单裁剪低电平前沿；阈值为 s16 绝对值 64、起音余量 96 样本、最大裁剪 576 样本。没有改音量、淡化、裁尾或重新编码。14 轨实际缩短 5.9～11.0 ms，其余轨道不变；所有保留样本逐字节相同。输出位于 `build/media/audio-lowlatency/`，保留上游路径／commit／MP3 哈希／权利说明，并增加父 PAK、父 PCM 哈希、原样本数、逐轨裁剪数和处理参数。原音源及 V4 保留；候选 PAK SHA256 为 `fd6cb47fd800811a997058306493b89644d84985d14adf93d930f635ea0dcb4d`，尚未板测，不改变素材权利来源。

本工程不是全部从零编写，也不是原例程直接换名。`doc/reference_manifest.json` 保存导入时的原始路径及 SHA-256；`editable:true` 的哈希是修改前来源哈希，不能当作当前文件哈希。

游戏版本的 `src/game/`、输入／菜单、排行榜 Flash、SD 音频流播／仲裁／混音均为本工程 RTL 实现。1-1 地上地图及敌人位置来自公开 [Xkeeper0/smb1](https://github.com/Xkeeper0/smb1) 反汇编，固定 commit `1cc3c92cbbe8cda44903657f3da332688e806a89` 的 `Area6`／`E_GroundArea6`；`script/pack_level_1_1.py` 解码生成 ROM 初始化、敌人表和 `assets/game/level_1_1.json` 来源记录。没有移植 FC CPU／PPU／APU。

2026-10-19 音频改用 [umaim/Mario](https://github.com/umaim/Mario)，固定 commit `980c275358704a49f868567aeec5bdfb347c4781`，`Source/Sounds/Themes/mp3/` 与 `Source/Sounds/Sounds/mp3/` 中的 24 个 MP3。`script/pack_game_audio.py` 经 GitHub API 获取、检查 Git blob SHA1，以 ffmpeg 离线转为 48kHz／16-bit 单声道 PCM；`assets/audio/manifest.json` 记录每轨路径、blob SHA1、源／PCM SHA256 和长度。已核对实际 SD 镜像中的 24 轨 PCM 与 WAV、源 MP3 哈希；`AUDIO.PAK` SHA256 为 `967773dc66ac401ba04b0c123d061ffcffbbc498c0745e47bdaec275bd2a864e`。未移植该仓库游戏代码，旧原创合成音模块保留测试但不再接入顶层。上游代码 MIT 不自动覆盖游戏音源权利，具体来源与权利边界保留在 manifest。

原型贴图取自用户提供的上级 `Mario-master`（readme 作者 tuxiaobei，C++14／EGE，仓库许可证 GPL-3.0）。`script/pack_game_assets.py` 按 `graphics.txt` 裁切并拆分为 85 个图块，`assets/game/manifest.json` 记录图像路径、裁切区域和哈希。没有移入 C++ 代码、字体或整仓资源；原件未改动。仓库的软件许可证不能证明其中马里奥美术的独立授权，正式公开作品前应替换为自有或授权素材；当前私有原型来源保留可追溯记录。

V4 预览页布局由本工程生成，像素字体复用自写 `src/video/osd_font.v`；五张预览图加入不同输入尺寸，游戏使用的左上图块区、调色板、V2 签名及 tile ID 均未改变。预览页不是新增第三方整图。首张图集保持原生 640×480，避免启动纹理提取被缩放破坏。

| 类别 | 文件/模块 | 处理方式 |
|---|---|---|
| 课程参考，保留原件 | `ip/vendor/course/` 中 SPI/SD、视频时序、异步 FIFO、HDMI PHY 等 | 源码正文未修改；`check_project.py` 检查来源哈希，允许 Git 换行转换 |
| 厂商加密 IP | HDMI transmitter、`sdr_as_ram`、`sdr_wrrd` | 直接通过 TD/ModelSim 支持的流程使用，没有解密或仿写内部逻辑 |
| 参考代码修改 | `ip/clock/`、`ip/sdram/`、`src/memory/`、`src/storage/sd_card_bmp.v`、视频时序/AXIS、`src/reference/bmp_read.v` | 按职责迁移；修正锁定/复位、四槽调度、帧标记、忙/刷新门控、错误恢复与工程连接 |
| 原创新增实现 | `bmp_sector_player.v` | 有背压的扇区缓存、BMP 几何校验和加载侧最近邻缩放 |
| 本轮新增实现 | `image_cache_controller.v`、`audio_controls.v` | 四槽滑动缓存、64 图目录调度、默认静音与 KEY3 短长按分流 |
| 原创新增实现 | `advanced_video.v`、`osd_font.v`、`video_controls.v` | 字幕、时间戳、半透明图层、调色、参数显示与交互 |
| 原创新增实现 | `audio_scope.v`、`transition_control.v` | PCM 双缓冲波形、峰值、黑屏边界提交与淡入淡出/显影 |
| 首版自写模块 | `pcm48_tone.v`、`reset_sync.v`、`frame_commit_bridge.v` | 音频节拍、复位同步、缓存提交；本轮扩展 bridge 的提交门控 |
| 自写验证与工具 | `test/`、`script/` | 独立黄金图像、测试平台、构建和镜像工具 |

`sdram_array_model.sv` 是自建功能器件模型，**不是厂商 SDRAM 模型**，只用于仿真，不进入综合。`tb_loader_recovery.sv` 内的 SD 模块是明确标注的扇区端点模型，也不进入综合。

ModelSim 正常编译和运行原有加密控制器；不存在破解加密 HDL、修改授权配置或绕过许可证的操作。原始资料上级目录不在 Git 范围内。参考代码的发布授权不由本工程重新声明，仓库保持 private。
