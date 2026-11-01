# 当前交接

## 2026-11-01 图库缩放、三秒轮播与五槽双向预取

- 用户已确认实施并关闭 TD；本轮仅改图库／缓存／状态显示及相关测试。显示设置第一项接入 BMP 解码器：FULL IMAGE 整图最近邻缩放，CENTER 2X 中心裁半宽半高后铺满 640×480；缓存包含缩放标签，切换时保留旧 ACTIVE 帧，重建后帧边界切入。游戏图集强制原尺寸解码，默认横向补偿 128、HDMI／DDC／PCM 链未改。
- 上电先验证／锁定游戏图集，再后台扫描和预取素材，不需先开 SW1。SW1 上拨自动轮播，显示确认且导航空闲后计时三秒，KEY1 暂停／继续，KEY2 前一张／KEY3 后一张；HUD 显示 AUTO:ON／PAUSED、3S、CACHE 与 LOADING。读卡／转场会延长实际间隔。
- 六槽反复构建超过 4900 MSlice，最终五槽：当前图＋前一张＋后三张，占 SDRAM 6,144,000 字节（32 位词地址 0～1,535,999）。逐槽扫描复用元数据查找／窗口淘汰逻辑；ACTIVE／未应答槽不可覆盖。原卡六图不能全驻留，快速跳出窗口仍可能读卡。底层接口支持六槽，正式 media_gallery 和菜单参数均为五槽。
- 用户允许资源不足时删校准页；五槽构建已满足容量和时序，故本版保留校准页，不动显示器已验证补偿。不要为了六槽再改动正常 HDMI 或音频。
- 最新正式 bit：prj/media_player_Runs/phy_1/media_player.bit，2026-11-01 18:35:30，637785 字节，SHA256 045d8aae090494121cbc304b595e28db0cc5e9c3c95d3bdfb95e61fe53ee155d。原生 TD GUI RUN、真实 fix_hold -eco 与重新生成位流通过，setup +2.435ns／hold +0.022ns；MSlice 4887／4900、LUT 18415／19600、BRAM 63／64、DSP 7／29。位流及报告另备份 build/rollback-evidence/gallery-five-20261101-183530/。
- 验证：最终缓存四／五／六槽、loader_cache（三秒／暂停）、loader_recovery、lab_ui 共六组通过；五槽菜单九完整帧字形／同步通过；33 个 BMP 解码／缩放场景及六真实素材全像素黄金通过；真实加密 SDRAM offset128 全帧／并发写通过；共享图集启动短扇区／坏签名重试、21760 纹理、六图扫描通过；5 项素材测试、29IO／75RTL 工程检查、85 staging 与 V4 配套检查、15 项部署测试、diff --check 通过。未重跑整个游戏／verify 全套；test.py 现登记19组，不能称19组全跑。共享图集仿真超过原180秒预算但直接重跑通过，test_game.py 将图集测试预算调整为600秒，未跳过断言。
- 修改文件集中于 src/storage/{bmp_sector_player,image_cache_controller,sd_card_bmp,media_gallery}.v、src/memory 的帧通路、game_menu_video／media_player_top，以及相关测试脚本／testbench；README、board-demo、architecture、competition-status 和 test/README 已同步五槽操作和边界。按用户既有 Git 保存授权，本轮验证后保存本地修复提交，不推送。
- 原 V4 镜像及实体 SD 卡不改、不烧板、不改 submission 下文档／RAR／摄影材料；未跟踪 doc/submission-plan.md 不触碰。新版尚待实板：SW全下启动检查画面与 BGM→SW1 看 CACHE:5／自动三秒→KEY1 暂停并前后切→SW1＋SW3 进入显示设置第一项 KEY1 切缩放，等待重建→关SW3返回图库→KEY4昵称／长按开始检查游戏。

## 2026-11-01 第二次样片与允许选择性加速

- 用户允许加速但优先一镜到底，覆盖上一条完全不变速的偏好。更新原执行指南：同一连续原片可对等待／重复操作 2×并标注，关键功能响应、轮播／转场、字幕及声音证据 1×，不拼不同录次。
- 第二样片 35.03 秒、720p／30 fps、HEVC，已复制到摄影目录 `01_实拍视频/01_第二次样片_原始文件.mp4`。图库无上一条波形叠层，流程更集中；屏幕仍偏小、背景杂物和机位变化需改善。音轨 mean -50.2 dBFS／peak -11.6 dBFS，未试听，需用户确认实际 BGM 和收音；不据此诊断音频故障。
- 下一步固定机位、改善收音后，录完整连续演练而非反复拍图库。未改工程、位流或 TF 卡，未剪辑原视频。

## 2026-11-01 用户要求功能演示一镜到底

- 用户明确功能演示不中断，取代此前分段剪辑方案。已更新唯一拍摄执行指南为连续约 2:55 的排练流程；Mac 仅回看、备份及必要转码，不拼接、不变速、不替换原音。
- 检查用户提供微信路径样片：56.87 秒、1280×720／30 fps、HEVC、AAC；复制原文件至摄影目录 `01_实拍视频/00_测试视频_原始文件.mp4`，抽帧在 `03_照片与截图/样片检查/`。屏幕约占宽度四成，杂物多；约 10 秒误入校准，15～21 秒素材页文字／字幕／波形重叠。BMP 历史提示不可当当前控制映射。
- 音轨电平 mean -43.9 dBFS、peak -11 dBFS，整体偏低；未主观试听，不据此声称音质正常或无杂音。下一步清桌、收紧构图、提高实际收音，录连续 20 秒主界面→图库原片。未修改工程或卡。

## 2026-11-01 按现存文件重新整理拍摄指导

- 用户再次要求从零逐步指导录制并用 MacBook 剪辑。只读核查发现，下方交接提到的两份拍摄脚本和五个素材子目录已不在摄影目录；不假定仍存在，也不回滚用户整理。
- 已阅读老师课件照片与场景讲义、当前板上操作，并直接核对 2026 选题指南第 14～15 页及 2025 上传要求第 1 页。2026 原文明确接受频谱或波形；2025 上传要求写 MP4／H.264、建议 3 分钟内和 300M 内，最终仍需以当届页面为准。
- 新建唯一执行指南 `../submission/摄影文档/00_拍摄与Mac剪辑执行指南.md`，含 10 秒样片、11 组镜头、约 2:50 成片顺序、逐段旁白、Mac iMovie 操作及交付检查。建立五个素材子目录，尚无本轮实拍素材。老师原始材料不变。
- 本轮未改 RTL、构建、位流或 TF 卡。下一步先指导用户录主界面 10 秒样片，检查清晰度、条纹、曝光和原声，通过后再拍首屏功能。

## 2026-11-01 拍摄执行清单与目录集中

- 用户要求一步步指导拍摄后用 MacBook 剪辑，并将所有摄影相关资料集中至 `submission/摄影文档`。已将原 `submission/像素跃境_演示视频拍摄脚本.md` 移入该目录，并新增 `00_先看这个_一步步拍摄与Mac剪辑.md`，包含 10 秒样片、10 组逐条拍摄操作、文件命名、Mac 原片传输、iMovie 粗剪／旁白／导出和回传步骤。
- 建立 `01_实拍视频`、`02_旁白录音`、`03_照片与截图`、`04_剪辑工程`、`05_最终成片` 五个文件夹供用户存放；目前尚无新实拍或成片，不将目录创建表述为已录制。原有课程照片与讲义保留原位。
- 已核对 board-demo 的操作分配；强调拍完首屏再进昵称、先关 SW3 再关 SW1、保留真实原声与转场过程。未改 RTL、构建、卡或位流。

## 2026-11-01 演示视频拍摄方案

- 用户要求参考上级 `submission/摄影文档` 筹划最终演示视频。已查看 13 张参考课件照片及两篇场景讲义，结合当前菜单、顶层和游戏状态机核对操作，生成 `submission/像素跃境_演示视频拍摄脚本.md`。
- 建议 3 分钟五段式：开场 10 秒、基础 30 秒、扩展 40 秒、游戏体验 80 秒、总结 20 秒。主题为复古游戏互动体验台，从素材展播到昵称／头像、关卡和成绩页；包含逐段分镜、讲解词、KEY／SW 操作、拍屏收音、原始素材清单及文档图号复用。
- 明确 3 分钟是参考课件制作建议，不冒充官方硬限制；48 kHz 为采样率、1 kHz 为测试音；现有为 PCM 波形而非 FFT 频谱；不虚构 Flash 冷启、当前成绩入榜或整关通关证据。继续使用用户已确认正常的 TD 手动 RUN 产物，未重建、改 RTL、写卡或烧板。

## 2026-10-31 技术文档矢量配图

- 用户回到提交文档制作，要求将可自绘的流程图／结构图分别生成 SVG，实拍、TD 截图和原理图局部截图由用户补充。已在上级 `submission/技术文档配图/` 生成 8 张统一风格的 1600px 宽 SVG：并发读取与帧切换、设计流程、系统整体框图、硬件连接关系、启动流程、TF 扇区仲裁、四槽缓存、音视频 HDMI 链路。
- 已将 8 张图直接嵌入 `submission/像素跃境：FPGA多媒体游戏机_技术文档.md`，移除对应 Mermaid／配图提示，保留 12 处实拍或软件截图提示。设计流程最后一步按用户要求标为“当前完整功能版待完成”。图中不含学校名称。
- 8 个 SVG 均通过 XML 解析和 ImageMagick 渲染；总览检查图在 `build/technical-diagram-qa/montage.png`。没有修改 RTL、TD 工程、位流、TF 卡或最终代码 RAR。
- 用户随后要求名称直接体现所在位置。现按章节连续编号：第一部分为图 1-1～图 1-5，第二部分为图 2-1～图 2-8，第三部分为图 3-1～图 3-8；8 个 SVG 文件名、图内题注和 Markdown 链接均已改为对应编号。原图 3.2.2 的近照与 TD 截图拆为图 3-2、图 3-3，其后顺延。

## 2026-10-31 用户确认 TD 手动 RUN 后显示正常

- SD 重写后用户仍反馈脚本构建程序闪过首屏后反复黑屏，同时官方默认检测程序画面／声音正常。用户曾要求换 HDMI-B，随后明确取消：通过官方 TD 程序 RUN 后已能正常显示。当前停止换口和进一步排障，以此实板反馈为准；此次未确认声音或其他功能。
- HDMI-B 引脚已只读核对手册第 11～12 页及官方 B 口例程：CLK C3、D0 G5、D1 F1、D2 E1、SCL P2、SDA R2。拟议的构建脚本补丁在首文件匹配阶段失败，没有修改代码／约束或启动 B 口构建，Git 状态已核实。
- 保留用户当前 TD RUN 得到的可用位流，不自动重建或覆盖。若复发，优先对照脚本构建和 GUI RUN 的输入、设置及产物；当前没有证据确定具体根因，也不将原脚本 verification.json 自动视为手动 RUN 新位流的有效回执。

## 2026-10-31 SD 卡重写完成

- 用户明确授权“帮我重写”。重新核实 F:／PhysicalDrive2、USB、7989100544 字节、序列号 121220160204、单分区且非系统盘后，锁定并卸载卷，备份覆盖区域，再写入 `build/media/game-audio-v4.img` 的全部 68157440 字节。
- 写入脚本 `build/rewrite_game_card_v4_20261031.py` 退出 0；冲刷后使用 FILE_FLAG_NO_BUFFERING 回读全部写入范围，SHA256 为 `37553923c0d73f69646ad592af4fe4b0d8b39c067435cc62a6ba29f87f03f637`，与源镜像完全一致。备份、receipt.json、filesystem-check.json、eject.json 均在 `build/media/sd-rewrite-v4-20261031-130858/`。
- 重挂载后只读 `chkdsk F:` 退出 0，报告无文件系统问题；六张 BMP 和 AUDIO.PAK 均可通过文件路径完整读取，哈希与正式素材一致。已锁卷、冲刷、卸载并通过 IOCTL_STORAGE_EJECT_MEDIA 安全弹出；可拔下装回开发板。
- 目录损坏已消除，黑屏是否解决仍需用户实板复测。当前 RTL／位流保持回退版，未操作板卡或修改提交材料。原卡完整物理容量约 8 GB，镜像只建立 64 MiB FAT16 分区，电脑所见小分区属于设计布局。

## 2026-10-31 SD 卡只读核查

- 用户反馈回退无效，插入开发板原卡要求检查。当前卡为 F:／PhysicalDrive2，USB，7989100544 字节，序列号 121220160204，非系统／启动盘。未写卡、未格式化、未执行 CHKDSK /F。
- 已发现 FAT16 根目录 LBA2305 损坏：前两条目录项包含 USBC 开头的异常数据，后有提前结束标记；八个工程文件的有效目录项位于 LBA2306。只读 `chkdsk F:` 退出 1，报告无效时间戳、大小、扩展属性、链指针，以及 11 个可恢复文件。普通文件读取曾出现 PermissionError 和 Invalid argument。
- 原始读卡备份及 JSON 核查在 `build/card-check/20261031-130249/`。首 68157440 字节完整读取成功，两次 FILE_FLAG_NO_BUFFERING 复读均无错误且哈希一致 f9cbdb2d4ecb3fa74393444406ca86c838d9c15e68ad997146e2d7c1dd5da36d。六张 BMP、图集签名、FPGAEND、完整 AUDIO.PAK、LBA1 音频目录均与 V4 配套镜像一致，文件 FAT 链连续完整；镜像全盘哈希差异包含目录损坏及 Windows System Volume Information 元数据。随后复查目录观察到 Windows 系统目录项变化，损坏的前两条项未变；原始快照和 root-recheck 文件均保留。
- 目录损坏已确认，但板上黑屏根因仍未证实：当前 FPGA 直接读图集 LBA2337、音频目录 LBA1／音频 LBA15097，图库按扇区扫描，不依赖 FAT 根目录。电脑 USB 读卡通过也不证明开发板 SPI／供电／接触正常。建议下一步将已验证的 V4 镜像重写到这张卡的前 65 MiB、绕过缓存回读核对，再实板对照；本轮用户只要求检查，尚未实施覆盖写入。

## 2026-10-31 黑屏对照回退

- 用户用 BitWriter 下载旧位流、原 V4 TF 卡时，显示器闪过游戏首屏后纯黑，仍有 HDMI 信号且板灯亮；要求先撤回一次代码修改。上次技术文档编辑没有修改 RTL。已将最近一次代码提交 `0d73f5f` 中的火焰花配色和龟壳滚动及配套测试回退；相关文件与前一提交 `cb139d3` 一致。原位流备份在 `build/rollback-evidence/pre-rollback-20261031/`。
- `python script/test_game.py` 34 个游戏 testbench 通过；原生 TD 构建、实际 `fix_hold -eco` 和重生 bit 通过，setup +2.435ns／hold +0.027ns；`check_project`、`check_deployment` 和 `git diff --check` 通过。回退版 `prj/media_player_Runs/phy_1/media_player.bit` 于 12:55:09 生成，637785 字节，SHA256 `735f3097b8f1d12fbb87be42d669f2a90483f33078e0084128b54e03646534ec`。沿用原 V4 TF 卡，未访问实体板卡或卡。
- 黑屏根因未定位，下一步用回退版在同板、同卡、同显示器下载复测。若仍黑屏，优先与 `build/rollback-evidence/board-confirmed-20261025-aligned/` 的实板已确认旧位流对照。上级提交文档及 RAR 未改；用户已有未跟踪 `doc/submission-plan.md` 未改。

## 2026-10-31 技术文档提交稿措辞复核

- 用户确认实板功能操作可用，要求保留 20 处配图标记、将技术文档改成提交稿口吻并补参考文献；用户将自行补图和处理第三方素材权利。已编辑上级 `submission/像素跃境：FPGA多媒体游戏机_技术文档.md`，去掉旧版／用户反馈／待实拍等内部工作记录，改为板上演示描述。未编造冷启动、排行榜掉电或长稳测试数值，TD 构建数字仍用实际回执。
- 修正 2.3.1 启动顺序：图集发布后，图库预取和 PCM 播放并行；已与 `src/media_player_top.v` 的 `assets_loaded` 接线核对。参考文献补官方指南 URL、HX4S20 手册版本、EG4S20 数据手册及游戏素材来源链接／固定提交。正文限字均通过，20 处配图标记未变，未出现学校名称；bit SHA256 与 `prj/verification.json` 一致。
- 交付目录仍为上级 `submission/`；未修改 RAR、实体卡、板卡或远端。以下 2026-10-27 的“尚无同版实拍／待复验”是当时状态，后续以本条用户确认及新增图像证据为准。

## 2026-10-27 提交作品名称统一

- 用户确定的唯一作品名称为“像素跃境：FPGA多媒体游戏机”，作品简介原文为：“《像素跃境》是一套基于安路 HX4S20C 开发板的交互式 HDMI 多媒体系统。作品以复古横版闯关为场景，将 TF 卡 BMP 图片读取、SDRAM 图像缓存、HDMI 音视频输出与游戏体验整合在同一设计中。游戏开始前，用户可手动切换或自动轮播素材图片；播放界面支持不同尺寸图片缩放、转场特效、动态字幕、亮度与对比度调节，以及随音频变化的波形显示。闯关过程中，玩家通过板载按键和拨码开关控制角色移动、跳跃与技能，并可设置昵称、选择头像、参与排行榜。作品用可玩的场景串联赛题的基础功能与拓展功能，展示 FPGA 在图像处理、音视频播放和实时交互方面的综合应用。”后续提交材料须以此为准，不改名称或简介。
- 旧报告 `技术文档/作品设计报告.md`、`.pdf` 已删除；唯一新稿已移至上级 `submission/像素跃境：FPGA多媒体游戏机_技术文档.md`，与代码 RAR 放在同一最终提交目录。名称和摘要定位已对齐；短节字数均低于用户上限，不含学校名称。系统框图用 Mermaid 表达，硬件／RTL／性能／证据边界按现有源码及 `prj/verification.json` 核对；当前完整功能版无同版实拍，不以仿真帧或旧反馈代替。
- 用户放回上级 `submission/` 的旧名 RAR 已仅重命名为 `像素跃境：FPGA多媒体游戏机_全部代码.rar`，归档内容未重打包。用户已有未跟踪的 `doc/submission-plan.md` 未改；未操作板卡／TF 卡／远端。当前 bit SHA256 `085ed198af4d8a3a58c43c10e25857660cfdd1e4176456059287d01a3af3ea5f`。
- 按用户补充的模板图文要求，`submission/像素跃境：FPGA多媒体游戏机_技术文档.md` 现有 20 处可搜索的 `### 配图：…####` 标记，分布于概述、硬件／RTL 设计和成果部分，区分示意图、TD 截图与当前完整功能位流实拍。重复场景允许复用照片；短节正文限字复核通过。加上实拍后须同步更新第三部分“尚无同版实拍／待复验”的文字。
- 旧 PDF 的 `build/render_technical_report.py` 已删除；自动审批以策略阻止递归删除旧 `build/technical_report_qa/` 页面检查图片，未换命令绕过。该生成目录不属于新稿交付。

## 2026-10-27 火焰花配色与龟壳滚动

- 游戏图集普通大马里奥的调色板索引 6→3、9→6，与参考项目 `Fire_mario` 在待机、跑步、跳跃、蹲下五个已使用帧量化后零像素差异；无需改 V4 TF 卡。静止龟壳现在被从上方再次踩中时进入滚动状态，并按面向方向前进；侧面踢动保留。
- `tb_game_enemies`、`tb_game_scene`（20 帧）、`test_game_assets.py`（6 项）通过；`git diff --check` 通过。原生 TD RUN、实际 `fix_hold -eco` 和重生 bit 通过，setup +2.293ns／hold +0.021ns，MSlice 4828／4900、LUT 18211／19600、BRAM 63／64、DSP 7／29。`check_project` 为 29 IO／75 RTL，`check_deployment` 为 85 staging／6 BMP／24 轨，均通过。
- 当前 bit：`prj/media_player_Runs/phy_1/media_player.bit`，2026-10-27 12:15:16，637785 字节，SHA256 `085ed198af4d8a3a58c43c10e25857660cfdd1e4176456059287d01a3af3ea5f`。未重跑完整回归，未实板验收；不写实体卡／不烧板／不推送。用户下一步只需下载当前 bit，在游戏里验火焰花和龟壳；原卡沿用。

## 2026-10-26 字幕、轮播与拨码行为

- SW1 首屏图库上拨即自动轮播，每秒一次，KEY1 暂停／继续，KEY2／KEY3 手动切图；SW2 首屏和游戏均显示底部滚动字幕与 PCM 波形；SW3 校准仅首屏。字幕六种模式：首屏、素材库、关卡前段、终点附近、大马里奥、通关。关卡位置以 player_x 1100 为分界，强化状态优先于地点。无需修改原 V4 卡。
- 新字幕 ROM 使用 1 BRAM；为控制资源，首屏 SW2 顶部重复状态面板在正式顶层关闭，图库／设置 HUD 仍显示状态，底部字幕与波形保留。TD 资源 MSlice 4838／4900、LUT 18157／19600、BRAM 63／64、DSP 7／29。原生 RUN 后 hold -0.020ns，经真实 fix_hold -eco 与重生 bit 为 setup +2.435ns／hold +0.027ns。
- 当前 bit：prj/media_player_Runs/phy_1/media_player.bit，2026-10-26 17:49:30，637785 字节，SHA256 41b4ab6461a22b385add19c5413b84cc874d9661d5a83d2c3bf102ae7cdbd0ed；verification passed=true。check_project 29IO／75RTL、check_deployment 85staging／6BMP／24轨通过。16 项基础仿真、tb_game_menu、18 帧 5529600 像素独立视频黄金均通过。未实板验收，不烧板／写卡／推送。
- 构建脚本现在仅在 TD 已 bitgen、无其他日志错误、setup 非负且 hold 为负时，允许 `wait_run phy_1` 的特定错误继续 ECO；本次最终 RUN 正常退出，`native_hold_exit_recovered=false`，该错误分支尚未由最终构建实际触发。旧 16:38 位流为历史，不能用于当前源码。用户已有未跟踪 doc/submission-plan.md 未改动。

## 2026-10-26 SW 操作核对与位流配套恢复

- 用户询问 SW1～SW4 用途；已从 src/game/game_menu.v、src/media_player_top.v、src/control/game_inputs.v、src/game/game_display_alignment.v 核对：首屏 SW1 图库，SW2 字幕／波形，SW1＋SW3 显示设置，SW4 音频设置；SW3 单独校准；进入游戏后 SW4 加速／火球，其他 SW1～SW3 不承担游戏动作。首屏 SW4 音频页优先；昵称界面禁用首屏 Debug。
- 只读检查发现磁盘 bit 为用户在 2026-10-25 17:51:31 手动 RUN 产物，SHA256 A8E9E5D3…，与 17:44:40 回执不符；其实际 hold 为 -0.011ns。未改 src／ip／素材，TD 已关闭。运行 python script/build_td_gui.py 原生构建会话75959退出0，实际 fix_hold -eco 后新 bit 于 2026-10-26 16:38:09 生成，636621字节，SHA256 42caa68652832a9d545637708854e1773a0d29497cd1473fb10ed54cdd9b0b5b，setup+2.435ns／hold+0.024ns，verification passed=true。check_project 29IO／74RTL、check_deployment 84staging／6BMP／24轨通过。
- README、competition-status、context 同步最新位流；尚未新实板验收，未重跑 RTL 功能专项。用户已有未跟踪 doc/submission-plan.md 为他人/用户文件，未编辑或提交；其中 18:20 位流不匹配记录已被本次重建解决，但该文件本身仍保留原状。不操作实体板卡／SD，不推送。

## 2026-10-25 17:44 GUI RUN 黑盒修复：保存清单缺项，已重新构建

- 用户手动 RUN 报 game_display_alignment、media_gallery、game_alignment_pattern 黑盒。`python script/check_project.py` 实际退出 1，缺 9 个登记（含 6 个历史诊断源）；17:37 的 syn/run.log 复现三条 HDL-8007。16:59 driver.log 三模块已被读取，而 17:37 保存的 `.al` 缺项，符合旧 GUI 清单覆盖更新登记。用户通过异步回复明确已关闭工程且未保存。
- 使用 diagnosing-bugs；未改 src／ip／约束／素材。复用 sync_project_sources 补回 74 个持久登记并清除 AutoExcluded。build_td_gui.py 对已有工程取消临时 RTL add_files，实际 native RUN 必须从保存的 `.al` 读取；TD 关闭后再次同步清单。新增 `.lock.f` 占用检查，避免边开 GUI 边改写。部署测试覆盖三个实际缺失模块的路径／综合开关／幂等性及锁定时禁止改写，共 15 项通过。
- 原生构建会话71842实际退出0，日志确认三模块 analyze 且无黑盒；完整综合／布局布线／bitgen、真实 fix_hold -eco 后重生 bit 均通过。setup +2.435ns，hold -0.011ns→+0.024ns。新 bit：prj/media_player_Runs/phy_1/media_player.bit，2026-10-25 17:44:40、636621字节，SHA256 da6dd4c3f4a104a08e7d3c2e715690395991f562a8b9d367ed4ad7b6210175f6；verification passed=true。
- 最后 check_project（29 IO／74 RTL）、check_deployment（84 staging／6 BMP／24轨原 V4）均退出0，diff检查通过。此次只改构建和说明，没有重跑未改 RTL 的音视频／游戏全套；恢复版仍待用户实板验收。17:37失败工程、日志和旧回执备份在 build/rollback-evidence/before-gui-source-repair-20261025/；用户失败 RUN 已移除了原 phy bit，未能在该目录备份旧恢复 bit，不能称其存在。正常旧版完整备份仍在 board-confirmed-20261025-aligned/。
- README、prj/README、bringup、competition-status、test/README、.ai 已同步。后续重新打开 prj/media_player.al；推荐关闭 GUI 后脚本构建，再下载最新 bit。SD 不需重写，未操作实体设备／未推送。按用户既有 Git 保存授权本地提交修复。

## 2026-10-25 恢复媒体实验室：构建与专项通过，待实板验收

- 用户已确认 d4a501e 人工补偿版实屏正常，要求补回停用功能并多次 continue。当前工作是恢复，不再等待旧官方探针或对齐反馈。不操作实体 SD／板卡、不推送；用户曾授权 Git 保存进度，最终验证后本地提交。
- 正常旧版完整备份为 build/rollback-evidence/board-confirmed-20261025-aligned/，bit SHA256 4046a723964bd328ad99d0e059d90ffbb68a2446ffdc922797fa5b294dea83e5。原 V4 镜像 37553923c0d73f69646ad592af4fe4b0d8b39c067435cc62a6ba29f87f03f637 未变，不需重写。
- 已恢复图库四槽／切图／轮播／转场、动态字幕、实际 PCM 波形、亮度／对比度等设置。新 media_gallery 封装存储，BOOT_ATLAS 复用同一 BMP decoder 优先发布游戏纹理，再扫描图库，音频扇区优先。游戏不等待图库就绪。全路径使用相同横向补偿，SDRAM 16 词对齐＋寄存器前缀处理任意偏移。
- 控件见 README／doc/board-demo：首屏 SW1 素材、SW2 字幕波形、SW1＋SW3 显示、SW4 音频；SW3 单独校准。KEY4 进昵称，松开再长按一秒开始，之后 Debug 禁用。游戏 KEY3 左／KEY2 跳／KEY1 右／SW4 跑火。
- 全功能布局曾超过 MSlice 4900；已共享 BMP 解码器、窄化目录／字串、分时校准数字、同步波形 RAM 和最终字形 ROM。同步 SDRAM 前缀尝试资源更差，已撤回。最终布局 4865 MSlice／4864 LSlice；报告 LUT18368/19600=93.71%、BRAM62/64、DSP7。局部时钟警告精确定位到 mem_clk_shift→u_gallery/u_sdram/u2_ram/SDRAM_CLK、0/1负载，为原有 SDRAM 转发时钟；脚本仅补 mem_clk_shift 名称匹配，仍拒绝其他来源警告。
- 最终原生构建会话13440退出0，真实 fix_hold -eco 将 hold -0.011ns 修到 +0.024ns，setup +2.435ns，并重新 bitgen。当前 bit 为 prj/media_player_Runs/phy_1/media_player.bit，2026-10-25 16:59:02、636621字节，SHA256 777df2d066b3dd2074eb470b16a7a08278685583aa7654752fb5360c3f7c2b89。verification passed=true；check_project 29IO/74RTL、check_deployment 84staging/6BMP/24轨通过，14项deployment测试通过。不能用旧bit或原生hold未修复的bit替代。
- 已完成游戏 33 项（新数值专项前）、基础媒体15项、BMP29种、alignment 全套与1024数字、真实原厂 SDRAM 全offset低4位＋128／639、真实BMP128／639。最终字形 ROM 的 offset128 lab、256字符×8行字体差分、4096色彩组合、scope、menu 已通过；最终18帧5529600像素video黄金退出0；最终HDMI会话79139退出0，真实SD BGM＋四SFX逐样本、立体声／测试音、校准／HUD／offset128帧通过，错一拍负例被检出，source_hashes与最终源一致。中途改源的旧HDMI回执不作证据。
- README、architecture、board-demo、bringup、competition-status、test/README 已更新恢复操作和板测边界。最终基础15项会话60300退出0，包含新同步字形、完整lab、缓存／故障恢复和全帧并发写；diff检查通过。此次恢复按用户授权本地Git保存，不推送。用户下一步自行下载新bit，SW全下先验对齐／BGM／昵称长按，再验SW1图库、SW2字幕波形、显示／音频设置和图库后台加载时声音；恢复版尚未实板验收，未重跑完整14组verify入口。

## 2026-10-25 手动适配自有显示器：已构建，待实屏校准

- 新证据／授权：用户确认同一板卡接其他显示器正常，只有自己的屏横向环绕；明确要求软件人工对齐。覆盖下方旧的“停止／只测官方／不改代码”边界。本轮不再追问品牌，不再交付 A/B/C。
- 正式游戏恢复交付：新增 `src/game/game_display_alignment.v`（SW3、按键帧级防抖、帧边界提交、进出模式等待松键）和 `game_alignment_pattern.v`（0～9、四色边框、数值和说明）。`game_video.v` 在同步地图读取之前以 `(raster_x+offset)%640` 映射源坐标，光栅计数和 HDMI 时序保持原样；顶层使用固定 320×240 两倍视口，启用 ALIGNMENT。校准时暂停游戏／特效并隔离游戏按键，BGM 继续原实现。
- 操作：默认 offset=128，SW3 上拨进入；KEY3 左移／KEY1 右移，1px 微调，按住 KEY2 改为 16px；长按连续；KEY4 归零。范围 0～639。松键、SW3 下拨回游戏并保留值；掉电恢复 128，不持久化 SD／Flash。需用户调到左红右绿贴边，记录 SOURCE OFFSET；若最终值不同，下一步固化该默认值。0 用于正常屏。
- 自动验证：`python script/test_alignment.py` 退出0，无补偿+右移128负例确实在像素比较失败；0/1/128/639 四组真实游戏／校准像素共2416640通过，控制器进出／粗细调／长按／环绕／毛刺通过。模型来自照片现象，不等于真实接收屏仿真。另重跑 inputs、boot、world、video 四个原有 bench 通过；未重跑完整 game 集。
- `python script/test_hdmi_vendor.py` 退出0：补偿128后的游戏经真实原厂 HDMI 核、完整HUD像素／同步通过；原有音调、非对称立体声、原 V4 镜像五声部 PCM／串行引脚音频全部通过；错一拍负例被捕获。回执 build/hdmi_vendor_sim/result.json 的 manual_alignment_128=pass。不把软件结果写成已实屏修好。
- 构建／配套：`build_td_gui.py`、`check_project.py`、`check_deployment.py` 全部通过。73 RTL、83 staging、29 IO。位流 `prj/media_player_Runs/phy_1/media_player.bit`，2026-10-25 15:47:02，633129字节，SHA256 `4046a723964bd328ad99d0e059d90ffbb68a2446ffdc922797fa5b294dea83e5`。setup +3.955ns，hold +0.012ns。Slice7430/9800=75.82%，LUT14017，FF5486，BRAM52，DSP3；比校准前增加295Slice/573LUT/58FF，无额外BRAM/DSP。
- 原 SD 镜像 hash仍37553923c0d73f69646ad592af4fe4b0d8b39c067435cc62a6ba29f87f03f637，6BMP/24音轨/LBA15097配套通过。不写实体卡、不操作板卡、不推送。更新 README、板测和测试说明；按用户要求本地 Git 保存修复。旧检查点 d84d8db、旧游戏归档和A/B/C仍保留。下一步仅需用户下载本位流，在自有屏上校准并复验游戏／BGM。

## 2026-10-25 继续：改用现成官方 A 位流进行实板对照

- 用户重新要求继续分析，随后明确选择现成 `31_hdmi_tx_display_A` 位流对照，不改代码、不重建。该指令覆盖下方“停止排障”的旧状态。A/B/C 失败和 BGM 正常的结论保持。
- 本轮重放用户 C 观察：`script/test_video_board.ps1 -Bitstream build/video_svga/media_player_Runs/phy_1/media_player.bit -Mode C -RecordOnly -ObservedOrder '7 8 9 0 1 2 3 4 5 6' -EdgesAtSides no -Photo D:/download/5.jpg`，实际退出 1，FAIL；这是导入已发生的实测，不是新板测。
- 官方源文件：`../官方资料/2_DEMO/DEMO_TD_5.6.2/31_hdmi_tx_display_A/prj/hdmi_tx_display_Runs/phy_1/hdmi_tx_display.bit`。复制到易选的 `build/official_a/official_hdmi_a.bit`，629635 字节，源与副本 SHA256 均为 `21545748d9c24860896ef2b84c1be2801b6093705b9b1ba7dfd6f7469eb31ad8`。没有重新编译、下载或固化。
- 配套 phy_1/run.log 和 phy.area：EG4S20BG256，时钟 R7，复位 A2；HDMI K1/F5/E3/B3，LVDS33，与当前工程一致。官方源码使用 clk_wize 的 25/125MHz、640×480 方格图和加密 DVITransmitter/Serial_N_1_lvds，区别于课程 lane_lvds_10_1 链路。源码时序存在 DE 起点偏移，不应将其声称为严谨的标准时序黄金。
- 实际 IO 报告有额外 VGA 输出，特别是 B2（本板 KEY2）为 VGA_HS 输出，测试不要按 KEY2；KEY1 是 A2 低有效复位，可按下再松开。无 SD 依赖、无声、无编号，预期彩色方格图；只做 SRAM 下载，保持同一 HDMI-A/线/屏，用户拍整屏。
- 官方正常则优先比较自研输出与官方的时序/编码/串行器；官方也环绕则提高板/线/屏和模式兼容性假设优先级，不能仅此断言硬件故障或 RTL 无法处理。此对照同时改变多个模块，不足以单独锁定根因。当前等待这一次真实板测，不继续给用户重烧 A/B/C。
- 本轮没有改 RTL/约束/游戏/BGM/SD，未访问实体卡或操作板卡，未推送；更新 .ai 记录并本地提交文档。

## 2026-10-25 最新：C 实板也失败，用户停止排障并要求交接

- 用户提供 D:/download/5.jpg，画面明确 C SVGA DVI／800 X 600；可见 7 8 9 0 1 2 3 4 5 6，色条7跨屏两端，红绿框仍位于屏内。用户认为比之前更差，明确要求停下、写文档给其他AI。不得再把C记为“待实测”或继续改代码／构建。
- 原始故障没有修好、没有确定根因。A/B实板失败，C实板也失败；数字模型未覆盖实际故障。C同时改变多个变量，不足以严格归因。已正常BGM／游戏源码与旧位流保留不变。
- 完整交接已写到仓库上级：D:/work/12_FPGA_Anlogic_TD/AI交接_显示环绕未解决_2026-10-25.md。含实测／数字验证边界、3条输出链、准确文件及哈希、Git恢复点、构建命令、资料入口、前代理不足与新代理边界。
- 两张照片复制到上级交接附件/：20261025_AB实测_B画面.jpg、20261025_C实测_仍然环绕.jpg；已逐一核对复制前后哈希。C照片SHA256 ea91f2100d04e85e884457ef747a0a2d03d577a8f12d6379ac002f8e1c862286。没有C精确偏移像素测量，不写成240px。
- 本次仅文档和照片归档，无RTL／约束／构建／设备操作。重新核对游戏c18d8f98、A/B b0becade、C 56166cd2和V4镜像37553923的现有哈希；它们不是板卡回读证明。根交接及附件在workspace Git范围外，仓库内最新状态同步并本地提交文档；未推送。
- 后续由用户交给其他AI继续。不要让用户重复下载相同失败位流，不再索要未知品牌型号，不凭资源／时序／仿真通过称实屏修复。下方全部为历史记录，遇“待C反馈”以本节覆盖。

## 2026-10-25 A/B 均实屏环绕，转 C 标准 SVGA 兼容性探针

- 用户提供 D:/download/44.jpg 并确认 A/B 都相同：编号 8 9 0 1 2 3 4 5 6 7，绿／红框一起移到屏内，约循环移位 128 源像素。照片显示 B PURE DVI；A 相同来自用户文字，不能伪称有 A 实拍。照片 SHA256 ec637267cd0fd1a8e4c163421f004fb57cc0258dc3d7b048a0fa87e428893117。
- 用户不知道显示器品牌型号，要求从输出端处理兼容性，不再索要型号。眼前仍只排显示，保留已正常的 BGM，暂关其他功能，Git 本地保存；不烧板／写卡／固化／推送。本轮未开子代理。
- 使用 diagnosing-bugs；没有板级自动捕获接口，旧数字仿真未复现真实环绕。按 HITL 模板适配 script/test_video_board.ps1，导入已经完成的用户观察，A/B 均实际返回 FAIL，记录在 build/video_board/；候选哈希不等于硬件回读验证。后续新板测需真实人工观察，不能用仿真绿色替代。
- 三项假设已向用户展示：低分辨率模式兼容、共用 PLL/PHY、旧版同步差异。Git 对比 2a818358 的 rtl/reference/IP/video_pll.v、vendor/course/hdmi_phy_warpper.v、lane_lvds_10_1.v、rtl/reference/video_rgb_to_axis_640x480.v 与当前对应源码 diff 均为空。尚未定位根因，不对游戏做 -128px 补偿，也不认定资源高是原因。
- 新 video_svga_top／video_svga_pattern／video_svga_pll 和独立 SDC：固定 DMT 800×600、40MHz／200MHz、总长1056×628、+HS128（FP40 BP88）、+VS4（FP1 BP23）、60.317Hz。PLL 保留 1GHz VCO／25MHz PFD 及原视频模拟参数，C0 外反馈50MHz、C1像素40、C2串行200。RGB及HS/VS/DE一起寄存，再进既有 DVI 编码／厂商PHY。原厂 HDMI 不实例化、DDC闲置，无 BRAM／DSP／游戏／SD／音频／排行。不是 EDID 自适应，C 成功也不能单凭它区分时钟、模式与DDC的具体因素。
- 操作：下载 build/video_svga/media_player_Runs/phy_1/media_player.bit，屏上 C SVGA DVI／800 X 600，SW不切换，KEY4按下复位松开重锁。无SD也可显示、无声。LED2=复位释放，LED3常亮、LED4常灭、LED1备用输入观察。看0～9与左红右绿是否归位；无信号单独反馈，不能当通过。
- build_td_gui.py／check_project.py／check_deployment.py 新 --video-svga，独立输出／staging／回执。第一次构建因TD不支持同条同时multiply/divide被检查拒绝，改为divide_by1.25；第二次捕获实际setup -0.670ns（图形字体→TMDS长组合路径），增加RGB与同步等长寄存；没有放宽断言或时序约束。
- 最终TD会话37716实际退出0，无ECO，setup +1.447ns／hold +0.025ns，29IO／71RTL／81staging配套通过。bit 2026-10-25 14:37:01，629635字节，SHA256 56166cd2e49119044c8d68cf30cc1929cf5783e10fb5e818691d96fa2cf46167。Slice492／9800=5.02%、LUT942、FF182、BRAM0、DSP0、PLL1、GCLK2；PHY仅旧器件slot／pre-route hold提示。综合key_meta_reg旧clk警告类似PAD输入寄存器打包提示，未据此认定实物故障。
- 新test_video_svga.py＋tb_video_svga.sv运行真实功能PLL与PHY，从串行引脚解码2整帧960000像素，与独立Python黄金逐像素对比，检查40/200MHz、HS128/BP88、1056×628、KEY4与存储闲置；蓝通道损坏负例必须检出。功能模型仍需200ns初始强制reset，不能称实板冷启动证明。初版bench对接收器取得锁定前的部分首行报799，已只在观察到VS后要求完整行，完整帧检查未放松。首轮会话58972退出0，但期间RTL新增寄存，不能将该回执作为最终输入证据；已追加起止哈希不变检查，当前最终重跑会话46973。
- 14项deployment测试已通过。游戏／音频／公共HDMI／原PLL／PHY相对d84d8db均无diff；prj游戏bit仍c18d8f98，旧A/B bit仍b0becade。没有重跑未改游戏全回归；旧基线回执源集因新增探针过期，下次构建游戏需重新生成，不能伪造receipt。
- README、板测说明、架构、赛题状态、test文档与.ai更新本轮事实。下一步等用户C实屏；成功再将游戏接入已验证输出并单独重验BGM，失败则用编号／边框／是否无信号继续收敛。尚不能称横向环绕修复。
- 最终会话46973实际退出0：两整帧960000像素、1965235串行字、40／200MHz与行帧同步、KEY4及存储闲置通过，蓝通道损坏负例在x0/y0被检出；build/video_svga_sim/result.json passed=true，起止输入哈希不变。仿真恢复图与独立黄金逐字节相同，参考图已目视。功能模型的两个load_reg端口宽度警告来自厂商模型将该脚声明成5位，而原IP模板连接单bit0，值均为0；不是实屏根因证据。
- 已导出最终路由网表build/video_svga_routed.v，确认keys_n[3]的PAD输入寄存器ipclk连接pix_clk，pixel_buffer经GCLK驱动该网；key_meta_reg旧实例不再存在，综合旧clk警告已核实为打包后的实例提示。导出没有改变位流。
- 本轮按用户要求本地Git保存诊断进度，提交题为 test: add SVGA compatibility probe for wrapped display；未推送。当前交付仍为56166cd2候选，实板待测。

## 2026-10-25 14:07 独立A／B画面诊断（历史交付，后续实测两者均错）

- 用户确认BGM已无杂音，右侧画面绕左仍存在，明确要求先关其他功能并Git保存。已本地提交游戏检查点d84d8db（包括此前未提交的目录迁移、全部游戏源码／素材／文档），未推送。BGM已好这一实板结论覆盖下方“无实测”的旧记录，不能宣称画面已好。
- 新src/diagnostic三模块：独立800×525／640×480计数器，10个64px编号栏、8px四色边框、左右000／639标签和坐标色带；同一像素送A原厂HDMI适配器和B纯DVI编码。SW1下A／上B，模式变化触发65536像素时钟复位，KEY4可手动复位；仍同一25MHzPLL／厂商PHY／HDMI-A，无偏移补偿。音频样本／ACR不送，不实例化游戏／SD／PCM／排行／SDRAM，SD和Flash片选高。B绕过AXIS／InfoFrame／数据岛，不代表改变游戏音乐实现。
- 独立顶层video_diagnostic_top；build_td_gui.py、check_project.py、check_deployment.py增加--video-diagnostic，输出build/video_diagnostic与build/staging/video_diagnostic；使用单独video_diagnostic.sdc，没有SD时钟。没有覆盖prj的游戏位流或修改游戏／音频／原HDMI适配器／PLL源码。新增模块会使旧默认游戏回执源集过期，下次恢复开发游戏应重新构建，不能复用旧receipt。
- TD会话53653实际退出0，29IO／68RTL／77staging检查通过；setup +3.273ns／hold +0.011ns，无ECO。诊断bit：build/video_diagnostic/media_player_Runs/phy_1/media_player.bit，2026-10-25 14:07:07，629641字节，SHA256 b0becade21261481568ac2ff81feb4c1e17c6c3121c1be0a1df7e451305cdde4。Slice1444／9800=14.73%、LUT2446、FF1494、BRAM10／64、DSP0、PLL1、GCLK1。PHY只有旧器件slot／pre-route hold支持警告。
- test_video_diagnostic.py：独立Python全帧黄金，ModelSim真实厂商HDMI／PHY，A恢复2整帧614400像素，B3整帧921600像素，各1679978串行字；检查HS96／后肩48／行800／帧480及RGB损坏负例。A、B捕获PNG与黄金逐字节一致，hdmi.png已目视。首轮编译修正了加密厂商源不能用-sv及需加载完整厂商模型库的问题，未改厂商源码。
- 新tb_video_diagnostic_controls覆盖真实功能PLL启动、A→B→A、KEY4按住／释放、存储引脚始终闲置；会话78954退出0、正向PASS。功能PLL模型需显式200ns初始reset脉冲，bench强制该输入模拟上电，硬件PLL配置未改；首次无脉冲长等已停止并留日志，不冒称模型证明物理冷启。两类测试合入统一runner，最终回执以build/video_diagnostic_sim/result.json为准。
- 14项deployment单元测试再次通过，诊断check_project／check_deployment通过。未重跑未修改的游戏完整回归／旧14组。此次无板测，等待用户A／B实屏照片；不要继续堆功能或推断根因。LED2=选中路径就绪、LED3=B DVI、LED4=A输入背压，LED1仅备用输入观测，不能沿用游戏LED含义。
- 最终统一runner会话73807实际退出0，A／B正向、RGB负例、功能PLL／按键控制全部通过；result.json passed=true，19项当前工程输入及厂商模型哈希一致。诊断bit配套检查再次通过；原游戏源码git diff相对d84d8db为空，原bit仍c18d8f98。此次未操作实体设备。
- 游戏bit仍c18d8f986f71935e388156a9bcbe432ce3101a015beafecdbc52f2c6e4ad1467，未覆盖；已备份game-20261025-135050，01:06完整配套仍在stable-20261025-010638。实际SD未访问，无需重写。文档及.ai已改为本轮诊断优先，基线游戏操作标为历史保留。
- 下一步用户下载诊断路径，SW全下拍A，再SW1上拍B，记录0～9顺序、红／绿边框位置；必要时KEY4重锁。两者正常则接回游戏入口；仅A错集中HDMI／AXIS／接收模式；两者错查共用时钟／物理链路与显示器识别。这是排查方向，不是仅凭组合即可证明的根因。

## 2026-10-25 实板反馈与画面专项开始

- 用户确认当前BGM已无杂音，右侧内容绕到左侧仍在；本轮只做显示诊断，暂时旁路其他功能。用户明确要求Git保存进度，取代此前“不提交”的本轮边界；只本地提交，不推送。
- 当前正式RTL与01:06归档一致。prj下bit被13:50:50一次构建更新为c18d8f986f71935e388156a9bcbe432ce3101a015beafecdbc52f2c6e4ad1467，staging73项仍与旧回执一致、资源／时序相同，但verification.json仍绑定612b575c，因此check_deployment正确拒绝；不能据旧回执给新文件背书，也不能仅凭用户反馈推断他烧的是哪个哈希。
- 在修改显示诊断前，本地Git检查点保存全部既有目录迁移、游戏源码、素材、测试、文档；生成物不入Git，原612b位流及配套归档继续保留。单独保存13:50文件。后续诊断用独立输出目录，不覆盖BGM已确认正常的游戏源码与位流。

## 2026-10-25 01:06 精简游戏、完整恢复原厂 HDMI 接法（当前候选，待板测）

- 用户当前只求BGM正常、游戏可玩、画面正常，允许精简／回退。已实施，不继续堆扩展。本轮未写实体SD、未下载板卡／固化、未提交／推送、未开子代理，保留既有dirty目录迁移。
- Git本地／远端main均2a81835805b99f4ca82a81f0f6f23b105da56359，10月9日马里奥前；reflog／stash／分支／不可达commit无中间游戏源码。没有首次BGM正常版完整配套，不能整仓reset丢游戏。
- 历史会话：10月19日首次“能玩”已报左侧异常；10月24日15:46首次确认有声，17:05报电流音，17:19确认独立测试音也杂音、烧16:50版。其间PCM／采样节拍／HDMI封包器／PLL没改，不能认定混音算法回归。旧正常多媒体为原厂HDMI＋startup EDID脉冲＋实际DDC；10月24日失败原厂候选trigger=0且DDC悬空。本轮恢复完整旧接法，差异存在但尚未证实故障根因。未增加横向坐标补偿。
- src/media_player_top.v精简为固定时序→game_video→game_hdmi_output READ_EDID=1→原厂PHY。取消SDRAM、图片DMA／FIFO、扫描／四槽、转场、两层advanced_video及首屏菜单实验室实例；对应源码／测试保留。SDC只删除未用的mem_clk／mem_shift，PLL参数保持。
- 新src/storage/game_asset_loader.v复用bmp_sector_player ENABLE_SCALE=0，LBA2337原尺寸640×480图集直接进入纹理缓存；完整307200像素与16像素签名正确才发布，失败50ms后重试，成功停止读图，再启动音频。首版误将2048分区起点当BMP，被新真实镜像专项抓到并改正；不能把新错误说成此前实板卡死根因。
- KEY3左／KEY2跳／KEY1右／SW4跑火；KEY4首屏进昵称，松开后再长按一秒开始。SW1全局静音，SW2仅首屏独立1kHz测试音，SW3空；默认有声、主／BGM／SFX=3／2／3，320×240逻辑视口两倍显示。LED1=SD初始化，LED2=图集发布，LED3=图集失败|音频错误|Flash错误，LED4=原厂视频背压异常锁存。当前不支持旧素材／轮播／波形／显示设置操作。
- 最终TD原生RUN会话93631实际退出0，无hold ECO，setup +4.053ns／hold +0.011ns、29 IO。bit为prj/media_player_Runs/phy_1/media_player.bit，2026-10-25 01:06:38，633129字节，SHA256 612b575c4a54820af56f06b9569038156895cf4b1d5229b713248c36715a5d37。65份RTL登记、73个staging与当前输入／位流／V4配套检查通过。前一份f3954e20等LBA2048候选已过期，不可交付。
- 当前Slice7135／9800=72.81%、LUT13444／19600、FF5428／19600、BRAM52／64=81.25%、DSP3、PLL2、GCLK2。上一版Slice94.99%下降，BRAM41升52，因恢复原厂核，不能说全部资源下降。资源高不是已证实根因。
- 综合sync0_reg clk未驱动警告经最终routed.v核对：8输入寄存器打包进PAD，ipclk均接u_flash/clk，由video PLL→GCLK驱动，旧sync0_reg实例已不存在。动态RAM的eram_init警告对应使用前写入的缓存。PHY仅剩旧器件slot／pre-route hold支持提示，SDRAM两条critical已随实例移除消失；最终时序为正。
- 游戏会话12228实际退出0，29bench全过：新loader真实V4截断／坏签名／恢复、全部21760纹理双读口；精简lobby昵称长按／atlas等待；公开输入通关1451步／15跳／x3264；20帧307200像素场景、奖励4352／死亡61441／入城6144黄金像素；地图、物理、音频、Flash等。日志build/game_sim/。
- HDMI会话6102实际退出0，默认vendor，36项输入哈希复核一致。测试音／非对称立体声／V4各2099981串行字、4031PCM输入／4030恢复／精确尾1、19个IEC状态块；实际WAV黄金、13音频与4媒体负例通过，187BMP／68音频扇区、启动304次等待、起播后无额外欠载。精简tail坐标／HUD各1228800像素／1920行／3完整帧结束；保留旧calibration路径也通过，RGB单拍负例检出。EDID测试1181个SCL下降沿且无应答时视频继续，不含会应答显示器EDID／模拟电气／实物声音。
- 14项deployment测试、check_project／check_deployment退出0。本轮未重完整14组，旧run.json不能当当前全量证据。尚无本轮板测，不宣称三项问题已修好。
- 默认V4镜像68157440字节、SHA256 37553923c0d73f69646ad592af4fe4b0d8b39c067435cc62a6ba29f87f03f637，首BMP LBA2337／音频PAK LBA15097；素材不变，原卡无需重写。
- 修改前备份build/rollback-evidence/before-stable-20261025/，本轮成功候选配套归档build/rollback-evidence/stable-20261025-010638/，含全部src／ip／script／test／assets、约束／staging／bit／verification／资源时序／游戏HDMI回执及最终routed.v。这是可追溯候选，尚非实板已确认稳定版。
- README、board-demo、bringup、architecture、competition-status、test/README和.ai已同步。赛题规则来源保留，明确本位流暂不满足基础手动切图／轮播及全部五扩展。用户下一步自行SRAM下载：SW全下、等LED2、KEY4进昵称再长按一秒；验跑跳／SW4、BGM／SW2测试音、TIME／云／管道是否仍绕回左侧。实板声画、排行掉电、固化冷启／长稳待验收。

下方均为历史交接，不覆盖本节与用户最新实测。

## 2026-10-24 20:32 撤回上一 HDMI 路径并减资源（当前候选，待板测）

- 用户实板确认 19:56 原厂候选仍有 BGM／独立测试音杂音、右侧图形环绕到左侧，新增卡在 LOADING TF GAME ATLAS；用户未改 SD 素材，要求先减少 Slice／BRAM、尝试回退。已授权实施，不再询问计划。不能把资源高当作已定位根因。
- 已将失败候选 bit、verification、资源／时序及原顶层／地图／纹理源保存在 `build/rollback-evidence/vendor-20261024-1956/`。Git 没有早期游戏配套源码，不能整仓 reset。`build/td/media_player.bit` 是 10 月 11 日旧产物，但 staging 后来被覆盖，不能宣称是用户记忆中的稳定版本或直接配套 V4。
- `src/media_player_top.v` 撤回原厂适配器，恢复 `game_hdmi_tx`；LED4 恢复音频待发队列 overflow。保留直接核内部、游戏坐标、PCM、PLL、SDC 和素材，不添加 −128 像素补偿。16:50 直接核旧版也有两项故障，所以本次是局部回退减负，不是已确认稳定回退。
- `game_level_map.v` 合并 world／video 镜像为一份真双口 RAM，读口仍一拍，A 口初始化／世界读写、B 口独立视频读，BRAM 6→4。`game_texture_cache.v` 每副本从三组 8192×4 改为十一组 2048×4 bank，每 bank 八 tile，保留两时钟域读副本、85 tile、签名／完整帧／DMA commit 发布及只读锁定，BRAM 24→22。撤回 HDMI 省 14，共省 18 BRAM。
- `python script/test_game.py` 会话 53167 实际退出 0，28 bench 通过；新增 4096 格地图双口并发／重载与全部 85×256 texel 双口跨 bank 检查通过，公开输入通关 1451 世界步／15 跳／x3264、20 帧场景及昵称续进通过。
- HDMI runner 默认 direct，保留 `--direct`，新增 `--vendor`。首次 direct 专项失败是三个音频负例漏传 tail，已在 `check_hdmi_audio.py` 补齐，未改核或放宽断言。重跑会话 50102 实际退出 0，`build/hdmi_sim/result.json` backend=direct；35 项源码 SHA256 与当前一致。测试音／变化立体声／真实 V4 三场景各 2099981 组串行字，4031 输入／4028 恢复、精确尾 3；20 个 IEC 块、13 音频负例、完整视频／HUD／四边、RGB 错一拍及两种同步负例通过。日志中的三个预期 Fatal 是负例成功检出。未重完整 14 组，不沿用历史全量快照。
- `python script/build_td_gui.py` 会话 51945 实际退出 0。新 bit 为 `prj/media_player_Runs/phy_1/media_player.bit`，2026-10-24 20:32:23，634293 字节，SHA256 `cf15d3525c93b805e1f28da4329f067ef0f56b4a9aae806bf1301c8990d465ad`。原生 hold −0.052ns 经真实 fix_hold -eco 后重生成位流，setup +2.047ns／hold +0.043ns／29 IO 通过，verification passed=true。
- 资源：布线 Slice 9309／9800（94.99%，仅比失败候选少 194），ECO 后 LUT 17646／19600（90.03%）、FF 6652（33.94%）、BRAM 41／64（64.06%），DSP8／PLL2／GCLK3。Slice 仍偏高，不能夸大减负成效。包内 SDRAM ECO 和单负载转发时钟警告仍保留，未放宽约束。
- deployment 14 项、check_project、check_deployment 实际退出 0，64 RTL／72 staging／29 IO、当前源／位流与六 BMP／24 轨 V4 配套。原 SD 镜像 SHA256 `37553923c0d73f69646ad592af4fe4b0d8b39c067435cc62a6ba29f87f03f637` 不变，不需写卡。README、architecture、board-demo、competition-status、test/README 及 .ai 同步。
- 下一步用户自行下载 20:32 候选，先看 LED2／ATLAS 加载与昵称长按续进，再试听 BGM／1kHz、检查横向环绕。三项实板问题仍未定位，不以仿真代替板测。本轮未操作实体 SD／FPGA／Flash、未开代理、未提交／推送，保留既有脏改动。

## 历史：2026-10-24 19:56 原厂 HDMI 对照候选（实板失败，已撤回）

- 已取得 `D:/download/33.jpg` 校准实拍：左右边框一同横移到画面内部，上下正常，说明现象不限于游戏文字。用户确认显示器原生 1920×1080、60Hz，经 HDMI–mini-HDMI 线直连 HDMI-A；实际输入模式仍未知，不反复索要原生规格或同一校准反馈。
- 正式新增 `src/video/game_hdmi_output.v`，顶层改用最终 RGB／DE／VS → 原有 AXIS 转换器 → 原厂加密 HDMI 核 → 厂商 PHY。保留游戏坐标、PCM、PLL、SDC、SD 素材，没有添加横向补偿。固定 25MHz、800×525、640×480、约 59.524Hz；原厂核依据 SOF／TLAST 重生成同步。LED4 现为锁定后视频背压锁存，不再表示直接核音频包溢出。原直接核保留，专项 `--direct` 可对照。
- 首次构建检出重新使用的 IP 被 `.al` 陈旧 `AutoExcluded=true` 排除；`script/build_td_gui.py::sync_project_sources` 已仅清除本次源文件的该缓存，新增幂等／保留无关设置测试。`python test/test_deployment.py` 14 项通过。视频专项最初 HS 断言失败来自接收侧漏解数据岛同步，已修为跨连续多包跟踪到双尾保护码；96 拍 HS／48 拍后肩断言未放宽，直接核正向视频也实际退出 0。
- 最终 `python script/build_td_gui.py` 会话 5056 实际退出 0。位流 `prj/media_player_Runs/phy_1/media_player.bit`，2026-10-24 19:56:02，634293 字节，SHA256 `deb15a10da5f994f05ece1a991f2b8a79d217478cee436518b41be2872043de5`。原生 hold −0.020ns 经真实 `fix_hold -eco` 后重新导出数据库与位流，setup +2.435ns／hold +0.024ns／29 IO 通过，`prj/verification.json` passed=true。
- 当前资源：Slice9503／9800（96.97%）、LUT17943／19600（91.55%）、FF7323／19600（37.36%）、BRAM59／64（92.19%）、DSP8、PLL2、GCLK3。已审阅原有 SDRAM ECO 位置及单负载转发时钟警告，未放宽约束。
- `python script/test_hdmi_vendor.py` 会话 64431 实际退出 0，回执 `build/hdmi_vendor_sim/result.json`。测试音／非对称立体声／真实 V4 各 2099981 组串行字，4031 输入／4030 恢复，精确尾 1；19 个 IEC 状态块、ACR／InfoFrame／重复 Clear_AVMUTE／24-bit 及负例通过。真实 V4 五声部混音含音量／暂停／静音，首扇区就绪后无额外欠载。坐标／校准／HUD 各 1228800 像素／1920 行／三次完整帧结束，RGB 单拍错位负例成功检出。35 项专项源码哈希已再次核对一致。未重完整 14 组，不能沿用旧全量成功结论。
- 配套与工程检查均实际退出 0：72 个 staging 文件、64 个持久登记 RTL、29 引脚、当前源／位流／六 BMP／24 轨 V4 一致。`git diff --check` 通过。原卡无需重写；旧 16:50 直接核位流已保存在 `build/hdmi_direct_baseline/media_player-1650.bit`，不可把旧版作为新版交付。
- README、architecture、board-demo、competition-status、test/README 与 `.ai` 已同步。未操作实体 SD／FPGA／Flash、未开代理、未提交／推送，保留全部既有脏改动。下一步用户下载上述 19:56 候选，检查 TIME／云／管道是否仍绕到左侧，并试听 BGM 与首屏 SW4 页的独立 1kHz 测试音。数字通过仅支持候选交付，不证明实板已修复或根因已定位。

## 历史：2026-10-24 HDMI 杂音与横向环绕排查（原候选之前）

- 用户确认 16:50 左右位流的 BGM 和独立 1 kHz 测试音均有电流杂音，右侧 TIME／云／管道仍绕到左侧。照片 `D:/download/222.jpg` 的固定横移只是现象，根因未定位。正式 RTL／PLL／SDC／素材／位流未改，没有新修复版；不让用户重复烧旧位流或写卡。
- HDMI 专项会话 35924、独立 PHY 会话 40732 均实际退出 0；34 项专项输入哈希已复核一致。实际 V4 音频、HUD／空白期同步、三种同步故障负例及厂商 PLL 功能模型通过。综合后自然扫描会话 23870 退出 0，实际 HUD 10240 像素和 48 拍后肩通过。旧完整 14 组回归早于本轮测试修改，只是历史证据。
- 从现有真实 routed DB 只读导出 `build/game_routed_debug.v` 与 `.sdf`。完整 SDF 注入因公开 SDRAM 空壳及 PLL specify 路径不匹配失败，不能当板上故障。`build/prepare_routed_sdf.py` 精确排除一个 SDRAM、两个 PLL 单元的延迟条目，保留其他单元及顶层互连；排除范围与 SHA256 见 `build/route_sim/sdf_scope.json`。未关闭 timing checks／specify。
- 有限 SDF 的 max 会话 29672、min 会话 6608 均实际退出 0，两者各从 HDMI 转发时钟恢复并连续核对 3177 组引脚输出字，Errors: 0。日志 `build/route_sim/limited_max.log`／`limited_min.log`；bench 为 `build/tb_routed_phy.sv`，使用合成光栅并强制发射器输入，不覆盖完整游戏和音频协议。PLL 延迟／相位与 SDRAM macro 未注入，仿真器另将 368 个负时序限制归零；这不是完整布线时序签核，更不能代表显示器实测通过。不要继续重复这些检查代替板测。
- 保持 bit SHA256 `7ab45e69ba71c12f3c1c7b6ecf867ed9c7924637b4dc8c0ac787b35b17e106e4`、V4 镜像不变。待现有位流四色校准的实板结果：重新上电首屏，SW1／2／4 关、仅 SW3 开，KEY3 选第三项 HDMI TEST PATTERN，KEY1 开启，再关 SW3 隐藏面板；不要按 KEY4。检查左红／右绿／上蓝／下黄是否也环绕，以区分游戏坐标和最终显示链路。校准反馈尚未取得，不能宣称杂音或画面已修复。
- 本轮同步 test/README、doc/board-demo 及 .ai/context／tasks／handoff；不操作实体 SD／FPGA／Flash，不开子代理，不提交／推送，保留既有脏改动。

## 2026-10-24 GUI 综合失败定位与脚本构建复验（最新）

- 用户手动 RUN 的 syn_1/run.log（16:44）明确报 HDL-8007：game_hdmi_tx is a black box。当前磁盘 .al 和本次运行快照均缺三份 game_hdmi 源，且物理运行参数为空；不能沿用上轮“GUI 已持久修复”的结论，也不能确认是何操作覆盖了文件。TD GUI 当时仍打开；本轮未实际操作 GUI。
- 用户决定以后统一脚本构建，不再手动 RUN。实际执行 python script/build_td_gui.py，会话31460已退出0，补齐63份RTL并完成原生综合／布局布线／bitgen。原生hold −0.012ns经真实fix_hold -eco后为 +0.024ns，setup +2.435ns，29 IO位置通过；prj/verification.json passed=true。
- 最新 bit SHA256：7ab45e69ba71c12f3c1c7b6ecf867ed9c7924637b4dc8c0ac787b35b17e106e4。python script/check_deployment.py 已退出0：71 staging文件与当前源码／位流、六BMP／24轨V4配套。SD镜像未变，无需重写；未操作实体卡／板／Flash，未提交／推送。
- check_project通过；python test/test_deployment.py的13项测试通过。最初使用python -m unittest test.test_deployment.GuiProjectTests因test不是包而导入失败，已改用项目直接入口；不是实现失败。正式RTL／测试／构建脚本均未改，本轮未重复14组完整回归，下方89468为之前完整回归记录。
- README及prj/README明确日常build_td_gui.py→check_deployment.py→下载位流；GUI无需RUN。构建前关闭旧GUI工程，关闭时不要保存旧文件清单覆盖磁盘。GUI保存／重开／点击RUN不属于本轮验证范围。用户自行烧板，画面四边／昵称／实验室效果仍需实测。

## 2026-10-24 昵称续进、实验室图层与 GUI 源清单修复（构建与完整回归通过）

- 最新用户反馈：HDMI-A 已能听到声音，不要求切换输出分辨率，要求显示正常；能进昵称但无法继续。保留音频／PLL／固定输出时序，不操作实体 SD、板卡或 Flash，不提交／推送。
- game_world 新增 quick_start 并跨帧锁存，PROFILE 长按 KEY4 一秒直接开始，图集加载完成后消费；保留短按编辑。顶层允许图集未加载时进入昵称，game_scene_text 显示等待／长按提示。tb_game_lobby 已专项通过。
- game_video 的 256 宽视口用 2/5 累加器映射完整 640 列，320 宽仍两倍，去除窄模式侧边黑带；fullscreen Debug 抑制游戏 HUD。波形／字幕在游戏之后叠加；波形有符号 X2 增益、粗线、中心线／网格、64样本／1.33ms 标题与 LEVEL 条。素材页恢复操作提示和 IMG／CACHE／ATLAS 状态；媒体按键脉冲延长为 50ms，供 SD 去抖可靠识别。显示菜单加入直连对比度／转场与全部复位。
- build_td_gui.py 新增 sync_project_sources，将缺少的正式 RTL 持久加入 .al，修复三份 game_hdmi 源缺登记的黑盒根因，兼容 TD 的裸 UsedInP&R。check_project 校验 63 个 RTL 均已登记；deployment 的幂等／设备及 RUN 保留测试通过。TD 开着旧工程时应关闭重开，避免旧内存列表覆盖磁盘。
- 专项已过：lobby、menu、game_video、menu_video、lab_ui、13 个 deployment 测试、29 IO／63 源检查。lab_ui.png 已目视，修正标题 33 字节截断并加首字独立位图检查。HDMI 接收侧 96 拍 HS／48 拍后肩检查已通过，独立 HS 延后8拍负例成功检出40拍后肩。实屏整体右移原因仍未证实，不能将这些数字证据当板级完成。
- 首次新版 TD 在默认 medium 布局局部布线冲突（u_sd_audio 两网），未交付；发现旧“high已保存”记录与实际 .al 不符。本轮已在 .al 及构建脚本显式保存 place effort high。最终 TD 原生 RUN 会话21392已退出0；原生 hold −0.012ns 经真实 fix_hold -eco 后为 +0.024ns，setup +2.435ns，29 IO位置通过，重新导出数据库与实际位流。bit 634293字节，SHA256 33b7b8fb67eb62b75ea0693e70d2d468219805bdcc978fb2014edc3235a1fc2d；最终Slice9192／9800（93.80%）、LUT17421（88.88%）、FF6648（33.92%）、BRAM45／64（70.31%）、DSP8、PLL2、GCLK3。check_deployment 已退出0，71个staging文件、当前源／位流及V4配套。下节旧位流哈希与旧回归不代表本轮。
- 完整14组首次79882检出scene_text三行旧文案断言，第二次62307检出tb_game_world通配端口缺quick_start；均已按新版需求修复并专项通过，RTL／位流未再改变。最终完整回归会话89468已实际退出0，14／14组通过，分项合计910.97秒；run.json passed=true／state=passed，209项输入与当前文件集合及SHA256完全一致，绑定快照77ecf58432377e8fe8f293959abf9ad7dfe48e93578c0b3dcc2c519a7536b5b7。28个game bench、20帧场景、1024字符、四帧全屏映射、15个基础bench、29个BMP、18帧媒体黄金、两种真实加密SDRAM及HDMI数字串行／音频／四边通过；RGB单拍错位及HS延后8拍负例均成功检出。后者日志尾Fatal是预期故障，不是回归失败。已再次实算bit哈希并运行check_deployment，退出0，当前源／71个staging文件／位流／六BMP与24轨V4配套。
- README、board-demo、architecture、bringup、competition-status、context、tasks已按最终事实同步；test/README保持回归启动前版本，测试增强见doc及源码。没有新变化无需重复全套。继续用V4原卡，无需重写；用户自行下载，先关闭旧TD工程再重开磁盘上的.al，首屏KEY4进昵称后长按KEY4一秒开始，检查素材切换／字幕／波形和实际四边。整体右移尚待上板确认，不能以数字通过宣称实屏修复。

## 2026-10-24 HDMI 声画、KEY 操作与首屏实验室改版

- 本轮依据用户 HDMI-A 无声、画面右移／黑带／绕回实测反馈实现；用户自行下载板卡。本轮未操作实体 SD、FPGA SRAM 或配置 Flash，未提交／推送，保留已有目录迁移与全部脏改动。下方历史“默认静音／SW 跑跳／暂停菜单／旧位流／Slice99.42%”均不适用于本版。
- 游戏 KEY3 左、KEY2 跳、KEY1 右、SW4 加速／火球；模式切换松开 KEY1–3 后使能，无需清零 SW。只有 TITLE 首屏允许 SW1 素材（KEY2 上一张／KEY3 下一张／KEY1 轮播）、SW2 动态字幕／实际 PCM 波形、SW3 显示设置、SW4 音频设置；设置页 KEY2／3 选、KEY1 改，SW4 优先。KEY4 单次进入昵称并清除 Debug／测试音／校准，保留显示音量设置。顶层隔离 TITLE 世界 jump 与菜单 profile_request，修复同次 KEY4 重入昵称；新增 tb_game_lobby 覆盖三种 SW 初态及昵称到游戏联测。
- 默认宽视口、声音开启、主／BGM／SFX 音量 3／2／3；首屏／昵称／游戏播放 BGM，首屏 Debug 不暂停。删除 PIXEL QUEST 和 ONE LEVEL 两行。六张真实仿真图已目视审阅，合成图 build/verification/lobby_review.png；这不是显示器实拍。
- 正式顶层换用自主 game_hdmi_tx＋channel／TERC4＋厂商 PHY／lane，移除正式旧 AXIS／加密发射核实例。RGB／HS／VS／DE 同延迟10拍，8拍前导＋2拍guard；四样本打包、48kHz／双声道24-bit LPCM、BCH／IEC状态／奇偶、ACR N6144／CTS25000、重复 AVI／AudioInfo／Clear_AVMUTE。固定25MHz／640×480／800×525／约59.524Hz，不是1080p输出；不读 EDID。LED4 锁存音频待发包溢出。channel／TERC4 来源和协议参考已在 code-provenance 记录。
- 默认布局两次、place effort high 一次曾因 audio_pending 到224位payload选择网络冲突而失败；通过增加 packet_load，分拍快照 PCM 与选择常量控制包解决，发送窗口不变。最终 TD 原生 RUN 成功，place effort high 保存在工程；没有设置非法 route effort。原生 hold −0.020ns，经真实 fix_hold -eco 修复到 +0.037ns，setup +1.980ns，重新导出数据库与位流，29 IO 位置通过。已审阅包内 SDRAM ECO 位置与单负载 mem_shift 转发时钟警告，未放宽约束。
- 正式 bit：prj/media_player_Runs/phy_1/media_player.bit，634293 字节，SHA256 af24ca6bea8d49b6e3fef649f0e5c7842a7d9dda0b7492f3d6f9e81e18bbfeec；prj/verification.json passed=true。最终布线 Slice9092／9800＝92.78%，hold修复后面积 LUT17174＝87.62%、FF6706＝34.21%、BRAM45／64＝70.31%、DSP8、PLL2、GCLK3。check_deployment 已真实退出0：71个 staging 文件、当前源／位流、六 BMP／24轨 V4 配套。
- 修改后 HDMI 专项已退出0：三个场景各2099981组串行符号与并行一致，4031 PCM输入／4028恢复、精确尾3样本、20个IEC状态块；ACR84、AVI／AudioInfo／GCP各5，13音频负对照。实际 V4 WAV黄金一致，187 BMP／68音频扇区，UNDER304只在启动；两种视频模式各1536000像素／2400行／4完整帧结束，含前段21拍video_delay＋3拍advanced_video。末尾故意错一拍fatal是必须被检出的负例，不能单看日志尾断言失败。
- 最终输入完整14组回归会话13645已实际退出0，14／14组全部通过，分项合计872.14秒；run.json passed=true／state=passed。208项src／ip／test／script／constraints／assets输入与当前文件集合及SHA256一致，成功快照e78e658e24f03db4c47ac7a76c2eef6f40b94157410fc5baf3597ec23bf7d18e与run绑定一致；bit实算SHA256也与TD回执一致。28个游戏bench、20帧场景、视频黄金、两种真实加密SDRAM及新HDMI均通过。不要再轮询旧会话或沿用修改前837920…5851快照；没有新变化无需重全套。
- README、board-demo、bringup、architecture、code-provenance、competition-status、test/README、context／tasks已同步。显示恢复只复位视口／调色板／亮度／校准，未复位对比度／转场，文档已如实写明。
- 默认V4素材和镜像未改，本日写卡已回读校验并弹出，继续使用原卡无需重写。下一步由用户下载新版，检查HDMI-A首屏BGM／SW4独立测试音／SW2波形，SW3校准四边及640×480输入模式，再测昵称隔离、KEY3／2／1＋SW4。实际无声和偏移是否消除仍待板测；不把数字验证当作实板修复证据。排行掉电、固化冷启、长稳、地下房／烟花／原版逐帧物理仍未完成。

## 2026-10-24 新版 V4 SD 已写入并安全弹出

- 用户本轮明确授权处理已插入的 SD，板卡由用户自行烧录。本次只完成写卡交付，不恢复无人值守开发；长期目标此前按用户要求 paused，下方 blocked／active 均为历史状态。
- 重新识别 F: 对应 PhysicalDrive2、USB Mass Storage Device、序列号 121220160204、7989100544 字节，非系统／启动盘，唯一 64MiB 分区；没有沿用旧 G 盘映射。先运行 check_deployment.py：当前 68 项正式输入／staging／TD 位流及六图／24 轨 V4 镜像配套通过，位流 ebc895…9245 不变。
- 锁定并卸载 F:，先备份和核对前 68157440 字节，再使用无缓存／写穿透方式写入默认 game-audio-v4.img、flush 后重新打开设备回读，全部 68157440 字节逐字节一致，SHA256 37553923c0d73f69646ad592af4fe4b0d8b39c067435cc62a6ba29f87f03f637。原覆盖区域可通过备份恢复；卡的原目录及前 65MiB 已被新版镜像替换，其余区域未写。
- 回执 build/media/sd-write-20261024-135832/receipt.json 为 passed=true／phase=verified，原区域备份 original-first-65MiB.bin，SHA256 edc3dc3f13d1133e6d84dd512ef29524e34bc837f648424ee8ef791754f34fbe。同目录一层的 write_confirmed_sd_20261024.py 是只绑定本次目标的一次性脚本，不应重跑或当作通用写卡工具。
- 重新挂载后六个 BMP 与 AUDIO.PAK 各自 SHA256 均与本地正式素材一致；Windows Shell 安全弹出已执行，随后磁盘2为 Size=0／No Media，F:\ 不可访问，可以取卡。65MiB 镜像使用 64MiB FAT 分区，Windows 只显示约64MiB属于正常布局，不是8GB卡容量损坏。
- 未下载 FPGA、未固化 Flash、未改 RTL／素材／位流、未重全套、未提交／推送。新版游戏／菜单／真实声音、显示左侧、排行掉电、固化冷启／长稳仍需用户上板；下载入口 prj/media_player_Runs/phy_1/media_player.bit，先全 SW 下拨、标题 KEY4 开始；声音默认关，KEY1 → AUDIO → AUDIO ON。

## 2026-10-24 13:48 实板验收连接复核

- 上一轮为进度汇报，没有新增实现或验证证据。本轮重新核对规则、当前任务与赛题对照，方向仍为同位流 HDMI 多媒体验收＋马里奥主题；当前 Slice 99.42%，不继续增加硬件逻辑，不把资源边界当作作品验收完成。
- 只读查询 Get-Disk／Get-Volume：仅两块内部 NVMe，盘符 C／D／E，没有 G 或可见外接 SD 磁盘。Get-PnpDevice -PresentOnly 按 Anlogic／JTAG／FTDI／USB Blaster／CH340／USB Serial／下载检索无匹配；结论是当前未识别目标设备，不能据此断言板卡物理未连接。与前次连接检查一致，后续实板验收需要设备状态变化。
- 未写实体卡、下载、固化、改 RTL／素材／位流或重跑全量回归；14／14 软件成功回执仍为上一节证据。待接入目标 TF 卡与已识别下载器后，再核对物理目标和本轮操作范围，验收新版 SW／菜单／声音、四边校准、排行掉电、配置 Flash 冷启和长稳。不能沿用旧 G 盘盘号执行写卡。
- 13:49 再次只读复核：仍仅两块内部 NVMe、C／D／E，目标下载器无匹配，没有活跃 vvp／vsim／TD／BitWriter 进程。本轮前一次状态复述属于 no progress；同一设备阻塞已连续三目标轮，目标工具已返回 blocked。目标未完成，待设备接入及用户恢复后继续实板验收；不重复无变化测试或制造状态文档进展。下方 active 为历史状态。

## 2026-10-24 最新完整回归通过与显示元数据排查

- 上一目标轮核对原会话 61288 确认 live，属于 verified wait；本轮继续同一进程，已取得真实退出码 0，14／14 组全部通过，各组耗时合计 990.28 秒。不重启／并发，不改运行输入、不缩测试覆盖。
- `build/verification/run.json` 为 passed=true／state=passed；204 项当前 src／ip／test／script／prj/constraints／assets 输入与快照完全一致，run 绑定的快照 SHA256 `dba10c5ad6870ba9161e3bd749e4696c25c216a1aa12dc2bed9e186157262c6f` 核对一致。27 游戏测试全通过，公开输入通关 1451 世界步／15 跳／x3264；20 帧场景完整结束，奖励4352／死亡61441／入城6144黄金像素通过。18 帧媒体／5529600 像素黄金、真实加密 SDRAM 两种源与 HDMI 数字串行／音频／边界通过。
- 26 张 PPM 均核对为本轮启动后生成，全部640×480且与既有已审阅 PNG 逐像素一致；再次目视 controls_review.png。排行榜图只有首项有效，其他行的分数／时间为 bench 常量，不能作为真实排行榜记录。未重新生成相同 PNG 或冒称实屏截图。
- 最终 HDMI 回执 30 项源码／14 项抓取哈希及 TD 位流哈希再次核对一致；位流仍 ebc895…9245，V4 默认镜像不变。hdmi.log 尾部的 pixel mismatch Fatal 来自 runner 最后的故意单拍错位负对照，须被检出，已由 runner 验证，不是本次失败。本轮未改 RTL／IP／约束／素材／位流或物理资源，未重 TD，Slice 99.42%；没有写实体卡／下载／固化／提交／推送或新开代理。README／competition-status／context／tasks 已更新最新完整结果，下方活跃会话及未重全套说明均属历史。
- 为左侧问题只读解码已有测试音／双声道／V4 三种抓取的首个 AVI InfoFrame：82 02 0d、checksum 正确，RGB／VIC1／pixel repetition0；Scan Information／Picture Aspect Ratio 未指定、Active Format Information 无效，没有误报1080p的证据。已补充 board-demo；只核对首包与数字数据，未认定过扫描为根因，未擅改像素时钟／元数据。
- 目标保持 active。软件本轮验证已收尾，不重复无变化的全套；下一步仍需新版控制／TF 实屏声音／四边校准、排行掉电、配置 Flash 固化／冷启／长稳，及报告视频。地下房／烟花／逐帧原版物理仍未完成。资源已超过用户99%边界，不继续堆硬件逻辑；没有这些实物与正式材料证据不能标记完赛或完美复刻。

## 2026-10-24 官方规则更新、演示路线与全量超时诊断

- 复核工程现状，最终 Slice 99.42%，遵循用户资源边界，本轮没有增加硬件逻辑、改 RTL／IP／约束／素材或重 TD，没有写实体卡／下载／固化／提交／推送。保留全部既有目录迁移与脏改动。
- 官网公开通知 id53 及扫描 PDF 第 5 页确认提交截止 2026-11-04 18:00、决赛 11-20～22；2026 上传细则此次公开列表未找到，不能称未发布或套用 2025。取得官网 9 月 2 日更新的安路指南，物理第 14～15 页与本地旧版规则确有差异：平台标题改“推荐”，正文 EG4S20 定制板及禁止额外处理器仍保留；扩展明确非必做、不设单项固定分值，按数量／难度／质量／稳定性／展示综合评分。已目视通知相关页和指南完整相关页并核对 SHA256。下载件在 build/official-20261024，稳定官网链接／完整 SHA256 见 competition-status，上级原件未改。浏览器工具认证不可用，使用官网正常公开请求获取资料，未登录、读取用户凭据或上传。
- 更新 competition-status／context／tasks，纠正“截止仅课程来源”；board-demo 新增 3～5 分钟同位流主题演示路线，对应游戏→真实 BMP／轮播→缩放与参数／转场→测试音／波形→返回与排行。补充 25MHz／800×525 名义 59.524Hz，未将其认定为左侧异常原因，硬件问题仍未修复。
- 完整回归 57869 已实际退出 1：verification／pins／media／unit／bmp／game_assets／deployment／audio_preparation／level 九组通过；game 的二十帧场景在旧 300 秒预算超时。文件时间戳证明完整输出 16 帧、正在生成第 17 帧，不是仅凭缺少 fatal 判断无卡死；失败 run/results/game.log 和部分 PPM 保存在 build/archive/verification-20261024-scene-timeout。更早 frame_path 120 秒超时后，独立真实 vvp 退出 0，现模块预算 300 秒（其余 120），完整 unit 已实测 184.64 秒通过。script/test.py 保留超时部分输出、明确 TIMEOUT 与 failed results。
- 本轮修改 script/test_game.py：场景有限预算 600 秒，其余 180 秒不变，超时保存部分 stdout／stderr、failed results、非零退出；test/tb_game_scene.sv 每个完整帧核验后输出进度并刷新缓冲，二十帧和全部黄金断言不变。内联 mock 注入验证场景 600／普通 180 两分支的实际失败、输出保留和非零退出，均通过。test/README 同步。
- 本阶段启动完整回归会话 61288，早期观察到四组通过，unit 171.0 秒，随后进入 BMP。该会话现已退出 0、14 组全通过，最终快照绑定及当前输入一致性已核对，详见最上方最新交接；不要继续轮询或重启已结束的句柄。
- 目标保持 active。实板缺口：1080p 左侧、新 SW／菜单／TF 声音、排行掉电、配置 Flash／冷启／长稳；地下房／烟花／逐帧物理、正式报告视频仍未完成。没有开新代理。git diff --check 已通过，仅既有换行提示；收尾文档后再检查。

## 2026-10-24 验收回执归属修正与串行验证收尾

- 上一目标轮为进度汇报，按目标审计视为 no progress。本轮复核 Git／上级 AGENTS、README／.ai、赛题要求与资料索引，保持官方 HDMI 多媒体同位流＋马里奥主题。Slice 99.42%，不增加综合逻辑；未开代理、写卡、下载、固化、提交／推送，保留既有目录迁移。
- 补齐上一串行验证轮交接：最新 `build/hdmi_sim/result.json` 含测试音／变化立体声／真实 V4 三串行场景，各 2099981 组符号／4030 PCM；短专项三个理想相位、初次启动及运行中复位、反位序／交换通道负例通过。上一轮最终 HDMI 会话 26142 已实际退出 0，本轮核对关联源码、串行／并行抓取及厂商模型共 50 项 SHA256，全部一致。理想时钟不涵盖 PLL／电气／显示器，游戏校准尾链仍单独测至并行 TMDS，不能扩大为完整顶层板测。
- 发现旧 `script/verify.py` 直到结束才取源码哈希，且重跑前不使旧成功快照失效；失败／中断或测试期间输入变化时可能错误关联历史成功。修正为启动先标记 run.json 为 running／passed=false、删除旧成功快照、清空进度；全部计划分项退出 0 且前后源码／IP／测试／脚本／约束／assets 集合与哈希一致，才发布 source_hashes 并在成功 run.json 绑定其 SHA256。异常／中断不保留成功快照；强杀可能留 running，不能当作成功。同一工程不要并发执行。此为前后快照比对，不是文件系统锁定，也不保证发现瞬时修改后还原。
- 新 `test/test_verification.py` 7 项通过（退出 0）：真实子进程成功及日志／快照绑定、子进程开始前旧成功失效、非零失败停止后续、代码增删改和音频素材变化拒绝、KeyboardInterrupt、启动异常、空／重复计划拒绝。完整配置 13→14 组，本轮没有重跑完整 14 组；旧 results／source_hashes 仍为历史记录，不手工冒写全绿。README、test/README、competition-status、context／tasks 同步。
- 实际 `python script/check_deployment.py` 再次退出 0：68 项正式输入和当前位流、6 BMP／24 轨 V4 镜像配套；位流 `ebc895...9245`、V4 `375539...f637` 不变。正式 RTL／IP／约束、资源、媒体未改，未重 TD。git diff --check 和两个新增／修改脚本的行尾空白检查均通过，只有既有 LF／CRLF 提示；unittest discover 入口也确认同样 7 项通过。
- 目标保持 active；1080p 左侧实屏异常、新 SW／菜单／SD 音频上板、排行掉电、配置 Flash／冷启／长稳仍缺，地下房／烟花／逐帧原版物理及正式 2026 上传要求仍未完成。优先实板验收，不把资源满或数字仿真视为完成。

## 2026-10-24 联测最终回执收尾

- 上一轮新增实际媒体联测属于 progress；本轮恢复时会话 98682 已不存在，未重新启动仿真。核对 10 月 21 日 11:53:06 生成的最终 `build/hdmi_sim/result.json` 和 runner 写回条件，两种视频模式均完成 1228800 像素／1920 行／三次完整帧检查，RGB 单拍错位负例在 x0/y0 被检出。35 项关联源码和音视频抓取 SHA256 全部与当前文件一致；最终回执包含 V4 媒体联测。未取回旧进程退出码，不将回执核验写成重新运行全套。
- 本轮重新执行 `python script/check_deployment.py` 与 `git diff --check`，均退出 0；68 项正式输入、位流、6 BMP／24 音轨 V4 镜像配套通过，仅常规换行警告。未改 RTL、位流或媒体，未操作实体设备。长期目标保持 active，下一步仍以实板显示边界、SW／菜单／声音、排行掉电及固化冷启验收为先；Slice 99.42% 不代表实物验收完成。

## 2026-10-21 实际 V4 镜像音频到 HDMI 联测（优先于下方历史）

- 上一轮为状态汇报，按 goal 为 no progress；本轮核对当前 Git／README／.ai 及上级官方基础四项／扩展／禁限和资料索引后，继续官方多媒体＋马里奥主题。Slice 已 99.42%，本轮只增加验证，无综合逻辑、TD、实体 SD／FPGA／Flash、提交／推送或代理操作；保留原有目录迁移。
- 新 `test/tb_hdmi_sd_audio.sv` 以真实 V4 `.img` 的 LBA1 目录和 PCM 扇区驱动 12.5MHz 字节端点，串正式 sd_sector_arbiter／audio_sector_bridge／sd_pcm_player、pcm48_tone 和一拍 audio_valid 到原厂加密 HDMI 核。持续 BMP 请求并检查 512 字节事务及客户隔离。新 `script/check_sd_audio_capture.py` 先核对目录／PAK／WAV／manifest，再从独立 WAV、公开事件与首扇区完成推导有符号混音／分档音量／暂停／静音，不读取私有声部位置或 RAM。
- 连续五帧（84ms）4031 输入全部匹配独立黄金；HDMI 恢复 4030，最后恰好 1 个待发。BGM＋跳跃／金币／火球／碎砖，500 样本音量、300 暂停、300 静音；187 BMP／68 音频扇区。UNDER=304 与初次扇区等待一致，各声部起播后无额外欠载；不能把启动计数冒称零。四种媒体负对照：改样本／丢失／重复／整体晚一采样。原有测试音／立体声／13 音频负对照及两视频模式／RGB 错位负对照保留。
- 开发中独立模型发现首扇区在混音末声部扫描前就绪，不能一概按采样起点判断整次混音；调整字节端点固定响应等待以避开窗口，并强制命令／首扇区完成距采样边沿超过整个混音窗口。没有放宽样本比较或读取 DUT 私有状态；此测试不覆盖边沿临界 CDC 极限。
- HDMI runner 已集成并记录所有关联源码、六个媒体抓取、镜像与音源 manifest 哈希，失败先删旧成功回执。README、test/README、board-demo、competition-status、context／tasks 同步。下方完整 13 组／139 项仍属历史；本轮没有重全套。正式 RTL／约束与位流／V4 未改变。
- 证据仅覆盖卡镜像字节交付端点到 TMDS，bench 发布事件，非真实 SD 命令／电气／卡、完整顶层、游戏事件生成或显示器发声；短窗未覆盖真实素材结束／循环或饱和输出，保留既有专项边界。1080p 左侧、实板 SW／声音／排行掉电、配置 Flash／冷启／长稳、地下房／烟花／逐帧物理与正式材料仍缺。长期 goal 保持 active。

## 2026-10-21 实际 HDMI 音频数据岛验收（优先于下方历史）

- 上一 goal 轮仅汇报，属于 no progress；本轮重新核对 Git／规则／README／.ai、上级赛题基础四项／扩展／禁限及资料索引，继续“官方 HDMI 多媒体＋马里奥主题”。Slice 99.42%，没有增加综合逻辑；不新开代理、不提交／推送、不访问实体 SD／FPGA／Flash，保留既有脏目录迁移。
- 新增 `script/check_hdmi_audio.py`，修改 `test/tb_hdmi_vendor.sv`、`script/test_hdmi_vendor.py`。在与实际加密 HDMI 核相同的输入边沿抓 PCM，并抓三路 10-bit 输出；以八拍前导／两拍保护码定界，接收侧独立解 TERC4／BCH、样本与 ACR。查阅固定 hdl-util/hdmi commit `83b1c9543a91b776671a44e68e130f81cae437b7` 的协议布局，未复制发射器或修改厂商 IP，来源已记入 doc/code-provenance。
- 两个五视频帧抓取分别使用真实 pcm48_tone 的 1kHz 立体声方波和逐样本变化／左右不同的 24-bit 挑战。各输入 4031／按序精确恢复 4030，抓取末尾精确剩 1 个待发样本；所有 packet BCH、PCM 奇偶、19 个完整 192 样本 IEC 状态块、consumer 48kHz 24-bit、N=6144／CTS=25000、AVI／音频 InfoFrame 校验、输入 520／521 周期及累积漂移检查通过。观测输入至包起始 15..1525 像素时钟，不是 SD／游戏到扬声器的端到端延迟。
- 13 种实际抓取故障负对照检出：BCH、非法 TERC4、改样本、换声道、IEC 奇偶、丢／重复样本、ACR 错误／缺失、InfoFrame 校验、声道状态采样率、块起点周期和采样节拍漂移。改内容／状态时先修复奇偶，要求后续实质检查命中；每个负例匹配指定错误原因。
- 扩展的 `python script/test_hdmi_vendor.py` 同时保留既有坐标视频、两种游戏尾链／校准模式和 RGB 单拍错位负对照。正式回执 `build/hdmi_sim/result.json` 记录音频解码结果及四抓取文件哈希、全部关联源哈希；任一步失败先清除旧成功回执。日志里的像素错位 Fatal 属预期负对照，不是回归失败。实际 `check_deployment.py` V4 配套检查与 git diff --check 通过（常规换行 warning 保留）。
- 本轮只重跑受影响的 HDMI 分项，不重全套或 TD。旧完整 verify 13 组全 PASS／139 项快照保持历史；与其对比仅 test/README、tb_hdmi_vendor、test_hdmi_vendor 变化，新增 check_hdmi_audio，正式 src/ip/constraints 未变，位流仍 `ebc895...9245`、V4／候选媒体不变。README、test/README、board-demo、competition-status、来源与 .ai 同步，并修正此前仍写 11／12 组或“全量执行中”的当前状态文字。
- 软件测试止于数字 TMDS 符号，不包含实际 TF BGM／SFX 从存储到 HDMI 的完整链、物理串行器／EDID／显示器发声或完整协议合规。1080p 左侧异常、控制／声音实板、排行掉电／配置 Flash／冷启长稳及正式材料仍缺；地下房／烟花／逐帧物理也未完成。长期 goal 保持 active。

## 2026-10-21 动作音效低电平前沿候选（优先于下方历史）

- 上一轮仅汇报，按 goal 审计为 no progress。本轮复核现有工作树、规则、README／.ai 及上级赛事与技术要求／资料索引，保持官方同位流多媒体验收＋马里奥主题。Slice 已 99.42%，没有增加 RTL；未启动代理、操作实体卡／FPGA／Flash、提交／推送，保留既有目录迁移。
- 纠正前轮音频分析的潜在误读：14～21 ms 是 >256 的明显起音时间，不是完全静音；较低幅值下早有信号，不能全部裁掉。新增 `script/prepare_game_audio.py`，只处理即时动作白名单：首个 abs(s16)>64 前保留 96 样本（2 ms），最多裁 576 样本（12 ms），超出短窗口的停顿及短音不动；不裁尾、不改音量／波形、不重编码。碎砖原本立即起音，保持不动；音乐、死亡、暂停、通关等编排不动。
- 实际 14 轨减少 5.896～11.042 ms（跳跃 6.521、金币 7.750、顶砖 6.188 ms），所有保留波形及尾音与原始 WAV 逐字节一致。新目录 `build/media/audio-lowlatency/` 含 PAK、24 WAV、manifest，保留上游／权利／源哈希并记录父 PAK／PCM、原样本数及裁剪数；拒绝覆盖目录和二次处理。候选 PAK 10198016 字节，SHA256 `fd6cb47fd800811a997058306493b89644d84985d14adf93d930f635ea0dcb4d`。
- 新候选镜像 `build/media/game-audio-v5-candidate.img`，68157440 字节，SHA256 `bf44304f35f2d306eedd2aface8c6031b55bd9eb5d0ad26364b6bbafe41d7f78`。`check_deployment.py` 新增 `--audio-directory`，默认仍检查原始 V4；实际候选配套通过（6 BMP／24 轨／LBA15097／68 staging），漏传对应目录的真实候选负例非零拒绝。原 PAK／V4／位流哈希不变、默认 V4 不变，不需要重综合。
- 新 `test/test_audio_preparation.py` 7 项独立通过：真实 24 轨与原始 WAV 保留区／尾音比较、裁剪区幅值／余量、原始 MP3 SHA256／Git blob 来源、负满幅／立即起音／静音／短音／长停顿／上限、确定性／损坏／重复处理／CLI WAV／拒绝覆盖；既有部署 12 项通过。最终完整 `python script/verify.py` 13 组全部 PASS，退出 0，合计约 772 秒；139 项 src/ip/test/script/constraints 与最终 source_hashes 精确一致。包含 27 游戏 bench、29 BMP 场景、原始素材／镜像／部署／音频预处理、18 帧媒体黄金及真实加密 SDRAM／HDMI 接口与像素错位负对照。公开输入仍 1451 世界步／15 跳／x3264，音频并发／生命周期欠载为零（仿真端点）。本轮未改 RTL、未重 TD；旧 11／12 组快照仅作历史。当前无活跃测试进程，收尾只更新 doc／.ai。
- README、bringup、code-provenance、competition-status、test/README、context／tasks 已同步候选用途。尚未实屏试听，不把素材提前量当作 SD／播放器或端到端延迟改进。1080p 左侧、实板控制／音频／排行掉电、配置 Flash／冷启／长稳、地下房／烟花／逐帧物理及正式材料仍未完成，goal 保持 active。

## 2026-10-21 下载前位流／TF 配套检查（优先于下方历史）

- 上一轮用户要求汇报，只有状态复核，按 goal 审计属于 no progress。本轮再次读规则、README、.ai、上级赛事技术要求与资料索引，保持“官方 HDMI 多媒体赛题＋马里奥主题”方向。当前 Slice 99.42%，没有新增硬件逻辑；未新开代理、写实体卡、下载／固化、提交／推送，保留既有脏目录迁移。
- 新增 `script/check_deployment.py`：默认检查当前 V4，`--image` 支持当前素材重新打包到其他文件名，`--json` 给出成功／失败结果并以非零退出拒绝失败。复用 `build_td.stage_sources` 在临时目录推导当前输入，不修改真实 staging；核对源集合／哈希、实际 staging／TD 回执、成功 native flow、有限非负 SWNS／HWNS、位流哈希。按 RTL 宏检查首 BMP 原生尺寸、16 像素签名、纹理区调色板；检查 PAK 与音频 manifest 的整体／逐轨样本与 PCM 哈希，再复用打包规则重建预期镜像，核对整个镜像长度／哈希，覆盖 FAT／结束标记／LBA1 目录／PCM。不接受设备或盘符作为媒体输入，不访问实体设备。
- 新增 `test/test_deployment.py`，12 项独立测试通过：过期／新增源、改动／缺失／多余 staging、被替换位流、失败／负对照回执、负／缺失／NaN／Inf 时序、旧无音频镜像、损坏目录／PCM／镜像长度、签名／调色板、逐轨 manifest 和 CLI 错误退出。签名／调色板负例同时重建卡镜像，避免只靠哈希不同得出假通过。另重跑既有 media_image 7 项、game_assets 5 项，均 PASS。
- 实际 `python script/check_deployment.py` 与 `--json` 均通过：68 输入、当前位流 `ebc895...9245`、V4 `375539...f637`、六张混合尺寸 BMP、24 音轨、音频 LBA15097。实际旧 `build/media/game-cache.img` 以退出码 1 拒绝。产物和源码未重建／改写；工具证明本地配套，不证明实体卡内容、显示器或固化冷启。
- `script/verify.py` 已加入 deployment，配置数 11→12；没有重跑完整套件或 TD。旧全量 source_hashes 保留历史：相较该快照变动 test/README、test_hdmi_vendor、verify，新增 tb_hdmi_game_pipeline、test_deployment、check_deployment；所有正式 src/ip/constraints 未变。新增分项证据与上轮 HDMI 分项分开，不改写旧完整绿／哈希。
- 同步 README、bringup、competition-status、test/README 与 .ai。原显示器左侧问题、实板控制／声音／排行掉电、Flash 固化／冷启／长稳和正式材料仍未完成；地下房／烟花／逐帧物理也未补齐。当前无活跃构建或测试进程，长期 goal 保持 active。

## 2026-10-21 显示边界实际尾链联测（优先于下方历史）

- 上一目标轮仅汇报状态，按目标审计属于 no progress；本轮完成实际新增验证。重新读取上级规则、README、.ai、赛事技术要求及资料索引，方向保持官方 HDMI 多媒体赛题＋马里奥主题。Slice 已 99.42%，先补显示稳定性证据，没有新增硬件逻辑、写卡、下载／固化、提交／推送或启动代理。
- 新增 `test/tb_hdmi_game_pipeline.sv`，把真实 game_video → advanced_video（TEXT/COLOR/TRANSITION=0、SCOPE=1）→ game_menu_video → AXIS → 加密 HDMI 核串联。使用厂商 raster、全屏 Debug 坐标图／菜单关闭校准两种模式，持续测试音 PCM／ACR 激励。按双视频 guard 判断视频期、独立解码 RGB，完整核对左右像素、640 像素行宽、800 时钟行周期、480 行帧及四边颜色。两种模式各五帧周期、1228800 像素、1920 行及三次完整帧结束通过；首个未同步帧不计入。RGB 单独延迟一拍的负对照在 x0／y0 正确失败（got=000000 expected=000015）。
- `script/test_hdmi_vendor.py` 自动运行旧直连 bench、两种新增模式及负对照；独立日志、输入哈希回执 `build/hdmi_sim/result.json`，先移除旧回执避免失败后误用。游戏 RTL 需 SystemVerilog 编译，厂商加密核及 primitive 需 Verilog 编译（do 等是 SV 保留字），因此拆成两次 vlog。没有修改厂商文件或规避实际编译错误。最终命令退出 0，旧 bench 2399 行／1536072 marker 像素／4031 PCM 通过；新增两种模式 PASS，负对照 Fatal 是预期证据。厂商宽度／protected 模型告警仍保留，非电气签核。
- 本轮仅脚本和测试变更，未重 TD 或全量 verify。与既有 source_hashes 比较，仅 `script/test_hdmi_vendor.py` 变化，新增本 bench；所有正式 src/ip/constraints 未变。位流 SHA256 仍 `ebc895cfd524ffb54854ad61325c0799255c2317225fe16f115bfc3a59d89245`。旧全套 134 项快照是此前证据，新测试以 HDMI 独立回执为准，不手工冒写全套绿。
- 本测试不含 TF／SDRAM 取图、关卡交互、所有菜单组合、PHY／EDID／音频包解码；只能说明所测视频尾链未发现丢边，不能宣称 1080p 显示器异常已解决。旧两张下载截图实际为 BitWriter／TD，并非显示器照片。上轮询问左侧裁切／黑边／错位的异步问题尚无回答，不重复询问、不将静默当答案。下一步结合校准整屏实拍和显示器输入模式定位，软件可继续审视同位流赛题验收缺口。
- 同步 test/README、board-demo、competition-status、context／tasks。本轮无活跃仿真进程，长期目标未完成，保持 active；地下房／烟花／逐帧物理、实板音频／排行掉电／固化冷启／长稳、正式报告视频与官方上传时间仍缺。

## 2026-10-21 修正屏幕按键提示（当前优先）

- 用户恢复长期目标后，重新核对工作树、.ai、README、上级资料索引及赛题基础／扩展／禁限条款。上一版 Slice 已 99.42%，本轮修复实际演示中的误导提示；未扩展硬件操作授权，未写卡、下载／固化、提交／推送，保留既有目录重构与脏工作区。
- 原标题仍显示 JUMP START／LEFT SCORES，资料提示 JUMP CONFIRM，结算提示 BACK TITLE，与当前 SW 跑跳／KEY 操作不符。只改 `src/game/game_scene_text.v` 四条现有 ROM 文案（8／9／10／15）并同步 `test/tb_game_scene_text.sv` 的验收文本：K4 START、K2/K3 SCORES、K2/K3 EDIT／AVATAR、K4 NEXT／CONFIRM、K1 BACK/MENU。核对真实 top／inputs／world／menu：标题／资料／结算的 K4 按下处理，暂停菜单／Debug 短按松开处理；K1 在资料／排行返回，在死亡／通关打开菜单。输入逻辑、图集、音频包未改。
- 真实 `python script/build_td_gui.py` 重建通过：18395 LUT／7639 FF／61 BRAM9K／8 DSP／2 PLL／3 GCLK、29 IO；最终 route 9743／9800 Slice（99.42%），与 10 月 19 日入城版相同。原生 Hold −0.020 ns，经 fix_hold -eco 后 +0.024 ns，Setup +1.787 ns，重新生成数据库和位流，无放宽约束。包内 SDRAM ECO／转发时钟告警限定审阅保留，非实物签核。
- 当前位流 `prj/media_player_Runs/phy_1/media_player.bit`，SHA256 `ebc895cfd524ffb54854ad61325c0799255c2317225fe16f115bfc3a59d89245`；替代下方旧哈希。68 项正式源／staging 生成映射、68 项 staging 回执哈希、62 个工程引用、位流哈希核对通过。
- 最终 `python script/verify.py` 11 组全 PASS，含 27 游戏 bench、29 BMP 场景、5 素材／7 镜像测试、18 帧媒体黄金及真实加密 SDRAM／HDMI 数字接口。文字 ROM 1024 次同步字符读取通过，公开输入通关仍 1451 世界步／15 跳／x3264。134 项 src/ip/test/script/constraints 与最终 source_hashes 完全一致，无新增漏测文件；收尾仅改 doc／.ai。
- 重新生成的 26 张游戏／菜单图中，22 张与前版 PNG 逐像素不变；标题、资料、排行、死亡提示四张仅 x192..447、y352..359 的提示区域变化，资料额外 y248..255 头像提示区域变化，其余像素完全一致。新提示已目视检查，最终 PNG、game_review.png／death_review.png 已刷新；新增 controls_review.png 以原分辨率拼接四张界面。全部为仿真图，不是实屏；排行仿真图仅第一项有效，其他行端点常量不是实际排行榜记录。
- V4 镜像与 PAK 哈希复核未变：镜像 `37553923c0d73f69646ad592af4fe4b0d8b39c067435cc62a6ba29f87f03f637`，PAK `967773dc66ac401ba04b0c123d061ffcffbbc498c0745e47bdaec275bd2a864e`。本轮提示修正只需更新位流；此前旧实体卡仍不含音频，新 V4 尚未写卡，不能误称只更新位流即可让旧卡播放音乐。
- README、board-demo、competition-status、context／tasks 已同步提示与当前位流；保留赛题同一固件验收主线。地下房、烟花、逐帧物理仍缺，1080p 左侧异常、实屏音效／排行掉电／固化／冷启长稳及正式材料仍需推进。本轮有实际改动和新验收证据，长期 goal 保持 active；资源到 99% 不代表实板验收完成。

## 2026-10-19 跑步入城与通关音乐窗口（当前优先）

- 本节优先于下方历史。继续官方 HDMI 多媒体赛题＋马里奥主题自研 RTL，不是 NES 模拟器，不称完美复刻。用户此前可玩反馈有效；本轮未写实体卡、下载 FPGA、固化 Flash、提交／推送，不沿用旧盘号，保留既有脏工作区与目录重构。重新核对上级官方要求索引，BMP／轮播／测试音／固化及扩展仍是主线。
- `src/game/game_world.v` 在滑旗落地进入 CASTLE 时请求一次事件 6（现有 clear 音轨 7.8106 秒）；复用 animation_frames 交替两张跑步图，朝右自动走，以 Q4 每帧 24 步进并钳位门口 x3264。`flag_phase=3`，`game_video.v` 隐藏大小角色。flag_frames 扩至 9-bit，CASTLE 饱和到 480 帧（约 8.06 秒），入门后 TIME 每帧减一／每点加 50 分，时间清零且窗口结束才 CLEAR 并提交一次排行。菜单／资料／排行暂停续播、不重发音乐。这是展示窗口，不是 PCM 完成握手或原作逐帧时序；烟花未实现。
- 未改 top／SD 播放器、图集、音频包及 V4 镜像。新增 `test/tb_game_clear.sv`，更新 scene／runner、test/README、README、architecture、board-demo、competition-status 及 context／tasks。
- 定向 clear bench 覆盖大小角色×TIME 0／400、滑旗落地、提前一次音请求、两跑步帧、门口钳位／隐藏 phase、480 帧、时间换分、一次排行及菜单／资料／排行暂停。独立公开输入通关为 1451 世界步／15 跳／x3264，无传送／force；步数增加来自通关演出。事件检查不是实际 HDMI 试听。
- 最终真实 TD `prj/verification.json` passed=true：18395 LUT（93.85%）／7639 FF／61 BRAM9K／8 DSP／2 PLL／3 GCLK、29 IO。比死亡演出版少 54 LUT、多 14 FF，BRAM 不变；打包 4876 MSlice／4876 LSlice，最终 route 4876 MSlice／4867 LSlice，共 9743／9800 Slice（99.42%）。原生 Setup +1.787 ns／Hold −0.020 ns，fix_hold -eco 后 Hold +0.024 ns，实际数据库／位流重新生成，无放宽约束。SDRAM ECO／单负载转发时钟告警仍限定审阅，非板级签核。
- 当前位流 `prj/media_player_Runs/phy_1/media_player.bit`，SHA256 `d422636ddd93647c219e5dd0ea57bbe1c6edfc0f46ae68e87b2b9955d3f9e673`。68 正式源／staging 生成映射、68 回执哈希、62 项工程引用及位流／镜像／PAK 哈希核对通过；TD 原生 .al 的 UsedInP&R 未转义，以实际 File 条目查引用，不用通用 XML 重写。
- `python script/test_game.py` 27 bench 全 PASS，最终重新编译源码后完整 `python script/verify.py` 11 组全 PASS：游戏 27、BMP 29、素材 5／镜像 7、18 帧媒体黄金、真实加密 SDRAM／HDMI 数字接口。134 项 src/ip/test/script/constraints 与最终 source_hashes 完全一致，无新增漏测文件，之后只更新 doc／.ai。
- 场景 20 帧，新增行走／小角色进门／大角色进门三图，独立原始 BMP 核对入城／门纹理 6144 黄金像素；原奖励 4352／死亡 61441 黄金保留通过。菜单另六帧；原有 23 张 PPM 与此前已审阅 PNG 逐像素一致，最终 26 张 PNG 和 game_review.png 已刷新／检查，入城专项 clear_review.png，均为仿真图。
- V4 镜像 `build/media/game-audio-v4.img` 68157440 字节，SHA256 `37553923c0d73f69646ad592af4fe4b0d8b39c067435cc62a6ba29f87f03f637`；PAK 起始 LBA15097，SHA256 `967773dc66ac401ba04b0c123d061ffcffbbc498c0745e47bdaec275bd2a864e`。本轮未改／未写卡，旧卡仍无音频。写新版须重新核对物理目标，不是普通复制。
- 当前 Slice 已超 99%，继续加功能须先优化打包容量；不为占资源加逻辑。下一步以新版实板测试为主：控制／Debug／音效／死亡入城、1080p 显示器左侧异常、排行掉电、配置 Flash 固化／冷启长稳。地下房、烟花／完整原作演出、逐帧物理、手柄／自由留言、正式报告视频及官方 2026 截止／上传要求仍缺。本次不更改长期 goal 状态。

## 2026-10-19 死亡演出与最终回归（当前优先）

- 本节优先于下方历史。继续官方 HDMI 多媒体赛题＋马里奥主题自研 RTL，不是 NES 模拟器，不称完美复刻。用户上一版可玩反馈保留；本轮仅本机实现／验收，没有写实体 SD、下载 FPGA、固化 Flash、提交／推送，不沿用旧盘号。保留用户既有脏工作区和目录重构。
- `game_world.v` 增加 120 帧死亡场景：停顿 24 帧后用既有 signed Q4 y／vy 弹起、穿地落出画面，坠坑初速向下，底部钳位避免 9-bit 回绕。演出结束才接受重试或看排行；敌人、镜头、计时、分数冻结，菜单／资料／排行可暂停续播。`death_active` 通过顶层接渲染，不改变 playing，不重开 BGM，也不重复死亡音请求／最终提交。
- `game_video.v` 死亡时保留关卡，复用 `GAME_TILE_AVATAR6` 的死亡姿态，屏顶负 y 模差裁剪，不受大形态、朝向、闪烁／星／火焰／变身配色影响。未更换素材或 V4 镜像。改动还包括死亡专项 bench、场景 bench、world／video 端口和 runner 的场景超时预算（17 帧由 180 秒提高到 300 秒），以及 README／architecture／board-demo／测试说明。
- 定向死亡测试 PASS：公开输入两次侧撞／重试，加高处超时、最后一命、坠坑内部 COMMIT 快照；检查逐帧轨迹、24 帧停顿／120 帧演出、提前确认无效、菜单续播、冻结世界与一次性音效／排行事件。不冒称实际音频试听或所有死亡由公开输入触发。
- 当前 TD `prj/verification.json` passed=true：18449 LUT（94.13%）／7625 FF／61 BRAM9K／8 DSP／2 PLL／3 GCLK，29 IO；比上一版增加 213 LUT／15 FF，BRAM 不变。打包 4875 MSlice／4876 LSlice，余量紧。原生 Setup +2.435 ns／Hold −0.020 ns，`fix_hold -eco` 后 Hold +0.024 ns，重新生成实际数据库／位流，无放宽约束。SDRAM ECO 与单负载转发时钟警告仍保留并限定审阅，非实物签核。
- 当前位流 `prj/media_player_Runs/phy_1/media_player.bit`，SHA256 `71ad0296730d8656592ac4743dc3df67909513f4e7ef6699fe4c72fca5beae84`。字节／UTF-8 方式审计通过：68 项正式源／staging 生成映射、68 项回执哈希、62 项 TD 工程引用、位流／V4 镜像／PAK 哈希。TD 原生 `.al` 的 UsedInP&R 未转义，通用 XML 解析失败，按实际 File 条目检查引用，没有改写工程。
- `python script/test_game.py` 26 bench 全 PASS，随后完整 `python script/verify.py` 11 组全 PASS，包括游戏 26、BMP 29 场景、素材 5／镜像 7 项、18 帧媒体黄金、真实加密 SDRAM／HDMI 数字接口。最终 133 项源码／IP／测试／脚本／约束哈希与验收快照完全一致，无新增漏测文件；收尾后仅更新 doc／.ai。公开输入通关保持 1397 世界帧／15 跳／x3264。
- 场景 bench 17 帧，奖励 4352 和死亡姿态／透明／穿地／屏顶裁剪／提示面板 61441 黄金像素通过；菜单另六帧。原有 18 张 PPM 与已审阅 PNG 逐像素一致，新增五张死亡 PNG 已生成并检查，23 图总览 `build/verification/game_review.png`、死亡专项 `death_review.png`，不是实屏截图。
- V4 镜像与音频包未改：`build/media/game-audio-v4.img` 68157440 字节，SHA256 `37553923c0d73f69646ad592af4fe4b0d8b39c067435cc62a6ba29f87f03f637`；PAK 起始 LBA15097，SHA256 `967773dc66ac401ba04b0c123d061ffcffbbc498c0745e47bdaec275bd2a864e`。旧卡无音频包；新镜像仍未写实体卡。
- competition-status、context／tasks 已同步资源、时序、位流与验证结果。下一步经相应授权核对实体目标，写 V4／回读、下载当前位流，实测控制、Debug、奖励／死亡、SD 音频、显示校准及排行掉电。地下房、完整通关演出、逐帧物理、手柄／自由留言、1080p 左侧异常、冷启长稳与正式交付仍未完成。

## 2026-10-19 同帧奖励结算与死亡优先级（当前优先）

- 本节优先于下方历史，长期方向仍是官方 HDMI 多媒体赛题＋马里奥主题。用户上一版可玩反馈有效；本轮仅本机实现／验收，未写实体卡、下载／固化、提交／推送，不复用旧 G／物理盘号。保留既有脏工作区和目录重构。
- 先用 `tb_game_settlement.sv` 在旧 RTL 真实复现金币＋1UP 丢分／漏金币事件：初始 700 分，本应 1900、实际 1700。`game_world.v` 现分 COMMIT→PICKUP→FIRE_STEP→FINISH 四拍，快照 pickup／grow／fire；分数和命数逐拍累加，各事件可连续 valid，不再被后续赋值覆盖。100 币＋1UP 同帧可加两命，各守 15 命上限。保留出土期限、首次花朵开火时机、成长脚底和触旗前高度，仅多三个像素时钟（120ns）。
- COMMIT 先判 CONTACT 已死亡／坠落／超时，死亡后不再顶砖、拾物或触旗，不重复扣命／提交排行，之前已击杀分数保留。新 bench 定向注入内部碰撞快照，接真实 game_scores／game_reward_fx；覆盖并发奖励、双加命、四类道具×五档旗杆、四击杀＋金币＋道具、出土／成长、暂停续算、死亡与排行，不冒称公开输入通关。
- 最终 TD passed=true：18236 LUT／7610 FF／61 BRAM9K／8 DSP／2 PLL／3 GCLK，29 IO；比上一版少 32 LUT／15 FF，BRAM 不变。原生 Setup +2.435ns／Hold −0.011ns，fix_hold -eco 后 Hold +0.027ns，实际数据库和位流重新生成，无放宽约束；保留原有限定审阅包内警告，非实物签核。
- 当前位流 `prj/media_player_Runs/phy_1/media_player.bit`，SHA256 `4c6ab7e83c6958275f534b3b0b9c0f88cb0f5baba91d43fc9fbf35b504c6bdb2`。68 正式源／约束与 staging 按生成规则一致，68 回执哈希、62 项工程引用、位流／镜像／PAK 哈希全部核对通过。勿编辑 staging。
- 最终 `python script/verify.py` 的 11 组全 PASS，25 游戏 bench、29 BMP 场景、5 素材／7 镜像测试、18 帧媒体黄金、真实加密 SDRAM／HDMI 数字接口；132 项源码／IP／测试／脚本／约束与最终 source_hashes 完全一致，无新增漏测文件。公开输入通关保持 1397 世界帧／15 跳／x3264。本轮重新生成 18 张 PPM 与此前已视觉审阅 PNG 逐像素一致，无视觉设计变化。
- V4 镜像／音频包未改，无需重做素材：`build/media/game-audio-v4.img` 68157440 字节，SHA256 `37553923c0d73f69646ad592af4fe4b0d8b39c067435cc62a6ba29f87f03f637`；PAK 起始 LBA15097，SHA256 `967773dc66ac401ba04b0c123d061ffcffbbc498c0745e47bdaec275bd2a864e`。新版镜像仍未写实体卡。
- 更新 README、architecture、test/README、competition-status、board-demo 及 context／tasks；最终验收后仅改 doc／.ai，不污染源码快照。下一步须经相应授权后核对实体目标并上板：新控制、Debug、奖励、SD 音频、显示校准和排行掉电。1080p 左侧异常、地下房／完整演出／逐帧物理、手柄／自由留言、冷启长稳／报告仍缺，不称完美复刻；目标仍 active。

## 2026-10-19 奖励动画与物理打包优化（当前优先）

- 本节优先于下方历史。本轮接续已授权的本机实现／验收，没有实体写卡、板卡下载／固化、提交／推送；用户之前可玩的反馈仍有效，但不代表本次新版已上板。不沿用旧 G／物理盘号。
- `game_world.v` 新增 reward_valid/kind/x/y，覆盖金币砖、碎砖、拾道具／1UP、击敌、触旗；`game_reward_fx.v` 两个世界坐标短效槽，旋转抛币 24 帧后 200 文字 24 帧，其他奖励上浮 40 帧。满槽轮换替换、菜单冻结、状态清理／坐标边界保护；game_video／top 已接，复用现有纹理／字体。原 score 逻辑未改，同 COMMIT 多项得分非阻塞覆盖风险未扩修。
- 新特效曾令物理打包超限：MSlice 5015→4987→4961→4938，不能只看 LUT 总量。共享双槽轨迹两周期消隐运算，游戏固定文案移至 `game_scene_text.v` 1024×8 同步 ROM、提前和地图同拍读取，不加 RGB 级；名字／排行／Debug 逐字符选择；五个 HUD 数字共用 `game_hud_decimal.v` 一套 double-dabble（125 时钟一轮，最坏约 149 时钟发布，排行 x272 前稳定）。保留双槽和既有功能后构建通过。
- 当前 TD `prj/verification.json` passed=true：18268 LUT／7625 FF／61 BRAM9K／8 DSP／2 PLL／3 GCLK，29 IO 核对。相比上一版少 72 LUT／23 FF、多一 BRAM，不宣称全面降资源。原生 Setup +2.255 ns／Hold −0.012 ns，fix_hold -eco 后 Hold +0.022 ns，实际数据库和位流重新生成，无放宽约束。包内 SDRAM ECO／转发时钟警告限定审阅，非板级签核。
- 位流 SHA256 `d227e8df882fa6e41a6f43ccfb38930206d31c530d62114d6e5486ee131a804e`。正式入口 `prj/media_player.al`，位流 `prj/media_player_Runs/phy_1/media_player.bit`，不编辑 staging。68 项正式源／约束按生成规则与 staging 一致、68 回执哈希、62 工程引用、位流／V4／PAK 哈希已核对。
- 最终完整 `python script/verify.py` 11 组全 PASS：24 游戏 bench、29 BMP 场景、5 素材、7 镜像、18 帧媒体黄金及真实加密 SDRAM／HDMI 数字接口。新增奖励／文字 ROM／共享 BCD 三 bench；world 测试补新端口；道具／敌人／通关核对 reward payload。共享 BCD 原子测试曾因等待 126 时钟未排空旧事务误报，改 250 后覆盖全部 125 调度相位并通过，无掩盖 RTL 故障。
- `tb_game_scene` 十二帧＋4352 奖励 ROI 黄金像素通过；原九帧 SHA256 与优化前完全一致，18 张游戏／菜单 PNG 已重转、像素核对并视觉检查，汇总 `build/verification/game_review.png`。`tb_game_video` 四帧覆盖 Debug 文字 ROM 与事件／位置动态字段的 2048 次字符坐标检查。公开输入通关仍 1397 世界帧／15 跳／x3264。不是实屏图。
- V4 镜像／PAK 未改，不需为新奖励动画重做素材：`build/media/game-audio-v4.img` 68157440 字节，SHA256 `37553923c0d73f69646ad592af4fe4b0d8b39c067435cc62a6ba29f87f03f637`；PAK 起始 LBA15097，SHA256 `967773dc66ac401ba04b0c123d061ffcffbbc498c0745e47bdaec275bd2a864e`。新音频镜像仍未写实体卡。
- README、architecture、board-demo、competition-status、test/README、context／tasks 已更新。test/README 在验收结束前更新，最终审计 131 项已测文件与 source_hashes 全部一致，无新增漏测文件；收尾后只更新 doc／.ai。保留既有脏工作区与目录重构，不提交。
- 下一步经授权后核对实体卡／写 V4 并回读，下载当前位流，实测新控制、奖励、音频、Debug、校准与排行掉电。1080p 显示器左侧异常未定位；地下房、完整演出、逐帧物理、手柄／自由留言、通用 FAT 碎片／热插拔、冷启长稳／正式报告仍缺，不称完美复刻。资源只余 3 BRAM，继续扩展先预算。

## 2026-10-19 混合尺寸主题素材、音乐生命周期与 BRAM 优化（当前优先）

- 本节优先于下方历史。继续执行“官方 HDMI 多媒体赛题＋马里奥主题”，不称完美复刻。用户此前游戏可玩反馈保留；本轮没有写实体卡、下载／固化、提交／推送，不复用旧 G／物理盘号。
- pack_game_assets.py 生成六张像素风主题 BMP：640×480、320×240、800×600、641×479、640×480、960×720。首图纹理区／85 tile／调色板／V2 签名不变，纹理区 SHA256 45676da60da3dfb29b4622acc14e06d05fdf803c62182a47dd416f20650f640b。标签字体来自 osd_font.v，自带正确 KEY 说明。5 项素材测试通过。
- sd_pcm_player.v 新接 star_mode：循环星音乐替换 BGM，星结束重启地上 BGM，死亡／旗杆／城堡／重开停 BGM 但保留 SFX，重生从头；菜单暂停保留位置、静音继续推进，混音空闲处切歌并 generation 拒收旧歌在途扇区。顶层按 PLAY 状态使能 BGM。新 tb_game_music 检查实际输出 PCM、1021 样本非整扇区循环和多次在途切歌，underruns=0；原并发／故障测试全部保留。
- PCM 从单数组改成五个独立 512×16 同步双时钟 RAM，读寄存器后选 bank，启动目录复用声部 4 的第二 bank；只缩单数组深度曾未省 RAM，独立 bank 才经 TD 实证节省三 BRAM。
- 最终 TD passed=true：18340 LUT／7648 FF／60 BRAM9K／8 DSP／2 PLL／3 GCLK，29 IO 核对；原生 Hold −0.020 ns 经 fix_hold -eco 后 +0.020 ns，Setup +2.435 ns，无放宽约束，重新生成数据库／位流。最终 area 报告也为 60 BRAM。位流 SHA256 4f9553ec06c408520e56a8295e5381ca692ece68ceaea32582cbe190e216e998，回执 prj/verification.json。SDRAM ECO／单负载时钟告警限定审阅，仍非实物签核。
- 完整 python script/verify.py 的 11 组全 PASS：21 游戏 bench、29 BMP 场景（六张实际素材各 307200 像素＋背压）、5 素材测试、7 镜像测试、18 帧媒体黄金、真实加密 SDRAM／HDMI 数字接口。证据 build/verification/results.json 和 source_hashes.json。收尾后只更新文档，source_hashes 的 test/README.md 保留验收时版本，勿把它当作 RTL 未验收。
- 收尾只读审计通过：124 项已测文件哈希未变，唯一差异为 test/README.md 文档；65 正式源／staging 映射（含生成头文件规则）、65 staging 回执哈希、59 工程引用、当前位流／V4 镜像／PAK 哈希均一致。最终 area 报告为 18340 LUT／7648 FF／60 BRAM，Hold ECO 后资源数已核实。
- 新 build/media/game-audio-v4.img，68157440 字节，SHA256 37553923c0d73f69646ad592af4fe4b0d8b39c067435cc62a6ba29f87f03f637；PAK 未变（SHA256 967773dc66ac401ba04b0c123d061ffcffbbc498c0745e47bdaec275bd2a864e），起始 LBA 15097，不沿用 V3 的 13193。旧镜像保留。独立检查实际 V4 的 MBR／BPB／双 FAT／连续链／六 BMP／标记／PAK 全字节／LBA1 目录／24 轨 WAV PCM，全部通过，证据为本轮工具输出。
- 六张 build/advanced_sim/asset_*.png 为独立黄金值通过 RTL 全像素核对后生成，不是直接仿真捕获或实屏截图；已看过素材及缩放预览。15 张旧游戏／菜单 PNG 的像素核对证据保留，游戏视觉 RTL 未改。
- 重新看官方 PDF 物理 14～15 页，强调多媒体应用场景、自主 FPGA、稳定展示、无额外处理器；详细 BMP／测试音条款来自官方 PPT／课程索引，PDF 扩展不强制与 PPT 至少一项差异保留。规则、产物、资源、测试和 .ai 已同步。
- 剩余：1080p 显示器左侧异常、地下房／完整演出／逐帧物理、手柄／留言、通用 FAT 碎片／热插拔、实屏音频／排行掉电／冷启长稳／正式报告。新版本尚未写卡／上板，目标仍 active，不能宣称完美复现或总体完成。

## 2026-10-19 SW／KEY 菜单、游戏反馈与 TF 音频新版（当前优先）

- 用户已反馈上一版游戏能玩；此前 game-cache.img 已授权写实体卡并回读。本轮只做源码／素材／镜像／本机验证，没有写新版卡、下载或固化、提交或推送。原始资料与用户既有重构／脏工作区保留。不要从下方历史推断游戏从未上板，也不要复用旧 G／盘号直接写盘。
- 新控制：SW1 右、SW3 左、SW2 跳、SW4 跑／火球，左右同时上拨下蹲；上电及退出菜单／资料／排行后四 SW 全下重新使能。KEY1 松开菜单／返回，KEY2/3 选择，KEY4 短按确认；Debug KEY2/3 前后图、KEY4 短轮播／长全屏。菜单暂停世界，小窗 Debug 保留冻结游戏背景。显示／声音／昵称头像／排行不再占用 SW。
- 新增顶砖上弹、四碎片、变身闪烁。菜单字符 ROM 及两拍同步对齐，OSD 和测试音动态字段已修正，六帧逐字像素回归；九帧场景包含三种反馈。15 PNG 与最终 PPM 逐像素一致，不是实屏截图。
- TF 音频：固定 umaim/Mario commit 980c275358704a49f868567aeec5bdfb347c4781，24 轨、48kHz s16le mono，BGM＋四 SFX、扇区双缓冲、串行饱和混音、音量、8 项事件队列／generation。真实扇区仲裁器＋跨域桥＋播放器的虚拟 12.5MHz SPI 并发 BMP 测试 underruns=0、sectors=28；故障注入覆盖坏目录、短扇区、队列溢出、timeout／cardloss 隔离及迟到回执。并非实卡带宽／试听证据。
- 上电静音、窄视口、OSD 关。AUDIO 开启 SD 声音、独立主／BGM／SFX 音量及音效试听；第七项独立 1kHz／48kHz 测试音只在菜单期间覆盖 SD，不依赖音频包。旧卡无 PAK 时 E／游戏静音，测试音可用。波形显示门控后的实际输出。旧 game_audio.v 只保留独立测试，不在正式顶层实例化。
- 中间构建在 x29y16_local2 的 submit／u_scores/mux13_syn_2[0] 冲突，回执按失败处理，没有交付。将排行榜候选记录改为 idle 跟随、submit 进入插入状态后锁定，去掉 96 位数据使能对 submit 的依赖；补测提交后变更名字／头像／分数不污染快照，完整重新综合／布局布线通过。
- 最终 TD：18330 LUT（93.52%）／7596 FF／63 BRAM9K（98.44%）／8 DSP／2 PLL／3 GCLK，29 IO 位置核对。原生 Hold −0.020 ns，经脚本 fix_hold -eco 后 +0.024 ns，Setup +2.435 ns；数据库及位流已重新生成，未放宽约束。包内 SDRAM ECO／单负载转发时钟已限定对象审阅，未关闭告警。资源余量很紧，不宣称总资源比旧版低。
- prj/verification.json passed=true。位流 prj/media_player_Runs/phy_1/media_player.bit，SHA256 0707ed5eccffdc12cee02c1c57168fb641bbf4a1da87e770df8eb9f937c603a4。65 项正式 RTL／头文件／约束与 staging 一致（global_def 40MHz、feature_config 按生成规则），59 项工程引用存在，staging 回执／位流／媒体哈希核对通过。
- 最终 python script/verify.py 的 11 组全部 PASS，其中 test_game.py 20 bench 全 PASS，另含 18 帧／5529600 像素媒体黄金、真实加密 SDRAM 与 HDMI 数字接口。结果 build/verification/results.json，已测源哈希 source_hashes.json。排行榜／Flash 全 96 位元数据与故障保护均覆盖；公开输入通关保持 1397 世界帧／15 跳／x3264。
- 新镜像 build/media/game-audio-v3.img，68157440 字节，SHA256 4426ca36b2fefc9be90bd29695e5e3f503f704dbe0ce9beacbe964b99411ce88；PAK 10209792 字节，SHA256 967773dc66ac401ba04b0c123d061ffcffbbc498c0745e47bdaec275bd2a864e。六 BMP＋结束标记＋PAK（LBA13193）、LBA1 绝对目录，已独立检查 MBR／BPB／双 FAT／连续链／源哈希／24 PCM 与 WAV。普通复制不能替代整盘写入；新镜像尚未写卡。
- README、doc/board-demo、bringup、architecture、code-provenance、competition-status、test/README 和 .ai 已同步。competition-status 统一为当前事实，移除互相矛盾的旧按键／资源描述。
- 未解决：1080p 显示器左侧异常，当前仍 640×480 输出，四边校准辅助定位，需实屏照片与输入模式；地下房、完整演出、逐帧原版物理仍缺。星音乐目前叠加，重生 BGM 可能延续。无手柄／自由留言／通用 FAT 碎片／热插拔保证，音频跨域异常隔离至复位。下一步单独授权写卡／下载，实测控制、音频、Debug、校准和用户 Flash 排行掉电，再配置 Flash 固化／冷启／长稳／报告视频。

## 2026-10-19 游戏 TF 卡已写入并验证

- 用户明确要求将游戏镜像写入已插入的 G 盘 SD 卡。写前核对 G → 物理磁盘 2，USB 可移动设备、序列号 121220160204、7989100544 字节，非系统／启动盘、单一 G 分区，根目录未见用户文件。
- 实际写入 `build/media/game-cache.img` 共 68157440 字节。写前独占锁定并卸载卷，备份即将覆盖的前 65 MiB 至 `build/media/sd-write-20261019-115015/original-first-65MiB.bin`；这是覆盖区域备份，不是整张 8GB 卡的备份。
- 刷新写缓存后以无缓存物理读完整回验，SHA256 与镜像一致：`1de2792200f0db93dc634f1ee68968043eb55b3456b6aee04260319591e9dab8`。回执 `build/media/sd-write-20261019-115015/receipt.json` passed=true。Windows 重读分区表后 G 为健康 FAT、64 MiB 分区，剩余空间未分配；六张 PIC00001..6.BMP 和 FPGAEND.BIN 均可见，六张 BMP 与 assets/game 来源逐文件 SHA256 一致。
- 使用一次性 `build/write_game_card.py`，目标序列号／容量／盘号／G 映射和镜像哈希均有断言；首次在写盘前因 DriveLetter JSON 类型假设退出，无写入，修正后一次写入成功。没有下载 FPGA 或编程配置 Flash，也没有提交／推送。下一步安全弹出 SD，插板，用已验收游戏位流 JTAG 测试。

## 2026-10-12 SMB 1-1 最终交付状态（优先于下方中间记录）

- 本轮地上路线实现与本机验收完成，四键／SW／Debug 媒体／默认静音保留。用户没有授权本轮实体下载、写 TF、固化、提交或推送，均未执行。
- 最终 TD：17813 LUT（90.88%）／7473 FF／51 BRAM9K（79.69%）／8 DSP／2 PLL／3 GCLK，29 IO 位置核对通过。相比未压缩版节省 11 BRAM，bank 独立同步读实现已被实际综合验证。
- 原生路由 Setup +1.919 ns／Hold −0.004 ns，经 `fix_hold -eco` 后 Setup +1.919 ns／Hold +0.025 ns。已重新导出物理数据库并重新 bitgen，未放宽约束。`script/build_td_gui.py` 包含条件修复、日志检查、引脚和时序验收、staging 哈希及失败回执；单独点击 GUI RUN 不包含脚本后处理。
- `prj/verification.json` passed=true。位流 `prj/media_player_Runs/phy_1/media_player.bit`，SHA256 `c44adc7754ab738d2fa28ce918e3588a3ba958105a74792b378fe07168d7e6e0`。V2 卡镜像 `build/media/game-cache.img`，SHA256 `1de2792200f0db93dc634f1ee68968043eb55b3456b6aee04260319591e9dab8`。
- `python script/verify.py` 11 组全部通过，随后 `python script/test_game.py` 16 个 bench 全部通过。公开输入完整通关 1397 世界帧／15 跳／x3264，无内部传送。真实 atlas 的六帧 PNG 已重新生成并检查，见 `build/game_sim/game_*.png`，不是实板截图。排行预览只有第一项有效，其他行分数来自测试端点常量。
- 正式源码／头文件／约束 59 项与 staging 一致，feature_config 和 40MHz global_def 按生成规则核对。全套软件验证后仅 build_td_gui.py 改变，已用最终真实 TD 构建验证；对应源码哈希按该验收更新，不把它算作重新执行全部软件套件。
- README、bringup、competition-status、context、tasks 已更新；声音操作明确在 SW3 Debug 中 KEY1 后按 KEY4，游戏中该组合为正常跑跳。视频 HUD 使用大写 X，TIME 400，SW4 音频提示不再误导游戏按键。
- 仍缺地下奖励房、原版音乐、完整死亡／碎砖／烟花演出、逐帧原版物理；背景景物循环布置，不能称完美复现。下一步上板验证游戏及 Debug、用户 Flash 排行掉电恢复，再做配置 Flash 固化／冷启／长稳。

## 2026-10-12 SMB 1-1 地上路线重构（历史中间记录）

- 用户已授权实施，保留四键、SW1 视口、SW2 色彩、SW3 Debug、SW4 产品叠层；不操作实体板卡、TF 或 Flash，不提交或推送。
- `pack_level_1_1.py` 解码公开 Xkeeper0/smb1 commit `1cc3c92cbbe8cda44903657f3da332688e806a89` 的 Area6 与 E_GroundArea6；212 格／3 坑／6 管道／17 敌，旗杆 x3168、城堡起点 x3232、门 x3264。生成地图 ROM、enemy_spawns.vh、来源 JSON，`--check` 通过。
- `game_world.v` 改同步地图串行碰撞；修正 signed 定点单位／混合无符号跳速、空中连跳、顶砖后误探测；加入四敌槽侧面/地面碰撞、蘑菇/1UP/星/花、超级/火焰/蹲伏头部空间、双火球、龟壳/踢壳/壳与敌人/火球与敌人接触。TIME 400、24帧减1，真实elapsed60帧；旗杆高度奖励与城堡TIME每单位50分。BRICK_COIN 231帧多币窗口、100币加命。按住KEY1跑步/火焰连续发射；声音手势仅Debug。
- 已通过独立公开端口物理/道具/敌人测试（新physics/powerups/enemies）；通关1397帧/15跳/x3264/3命，含旗杆城堡结算，没有force/内部传送。此前15组游戏bench通过，新增enemies与后续video修正需最终全套重跑。
- video代理已接同步地图、四敌／大角色／道具／火球；正在补原版HUD、隐藏砖透明、去旧悬浮金币、旗杆城堡坐标、蹲伏脚底对齐、FLAG/CASTLE不中断、云山灌木、真实中段终点图片。最终测试和图片以当前文件/回执为准。
- RAM优化：地图4bit合法0..14写、外部8bit零扩展；texture 85tile，三组32tile bank双镜像，无效ID透明。第一次bank mux置于RAM读寄存器前被TD推断成DRAM导致38875LUT，已改独立bank同步读+寄存bank选择，局部texture测试通过，等待TD核实。不要保留第一次失败推断方案。
- 中间 native RUN 17790LUT/7472FF/62BRAM/8DSP，Setup+2.435ns、Hold-0.020ns（AXIS→HDMI FIFO和reset removal），不能交付；更早旧版16198LUT与正时序属于10-11旧版。本轮当前TD仍在运行，位流须prj/verification.json passed=true且源码一致才能交付。
- README、board-demo、architecture、code-provenance已部分同步；最终竞争进度/context/tasks与验证哈希待收尾。地下房、原版BGM、死亡演出/逐帧物理未实现，不称完美复现。新V2镜像未改素材，仍SHA256 `1de2792200f0db93dc634f1ee68968043eb55b3456b6aee04260319591e9dab8`。

## 2026-10-11 Pixel Quest 实现

- 最终 native GUI RUN 已收敛：16198 LUT（82.64%）／6983 FF／29 BRAM9K／5 DSP／2 PLL／3 GCLK，29 IO，Setup +0.266ns／Hold +0.019ns；prj/verification.json passed=true，bit SHA256 89ce003518000da6847fb4022951b1fef694ad1f7b39e50329d5042d4ec00ad6。这个结果取代下述中间失败记录。控制50MHz改PLL C0后消除负hold；没有新增时序例外。
- 综合输入寄存器undriven clk警告复核：物理数据库report_cells显示8个KEY/SW PAD均已打包IREG，ipclk=pix_clk、rst=u_rpix/sync[2]、diq对应key_s0/sw_s0，非未驱动实际时钟。原包内SDRAM ECO与单负载转发时钟警告保留回执。

- 用户授权 Implement the plan。新增自研一关 RTL 游戏、TF 首 BMP 图集解析、Debug 真 BMP 浏览、四KEY和SW、6字符名字／8头像／前十排行、原创芯片音乐与事件音效。不是 FC 模拟器或完整原作复刻；地图共享函数固定于 RTL，原型贴图源 Mario-master 的 graphics.txt，assets/game/manifest.json 可追溯。
- 顶层已实际接入所有模块，29 IO，KEY1 不再作系统异步复位；game_boot_reset 使用 PLL 锁定。SW1 两档逻辑视口而非 HDMI 改时序；SW2 量化色彩；SW3 Debug 冻结世界；SW4 状态／实际输出PCM波形。game_debug_controls 完整接回媒体 brightness/contrast/transition/auto/previous/next。默认静音，KEY1后按KEY4声音。
- 排行榜96bit×10，结果快照排队等flash就绪，双读取端口分别给UI和存储；用户Flash0x600000/0x601000双日志，JEDEC EF4017/EF3017、完整区域归属、CRC32、commit-last、回读、超时，未知内容拒擦；配置Flash W25Q16独立。未实际擦写硬件。
- 最终源码的10组verify全部通过，其中12个游戏测试包含公开端口操作通关619世界帧/15跳/3条命/score1300/x1505，非force传送。真实atlas BMP送纹理缓存后生成四个307200像素完整界面；PPM重新转PNG并检查标题、资料、榜单、游戏，菜单文字无遮挡。十进制显示用串行double-dabble避免像素组合除法。104个源码／IP／脚本／测试／约束文件与source_hashes.json一致，位流与TD回执哈希一致。卡镜像SHA256：09894c8db3f4b70332d8708aa174ddabf41f6757344847be6aab3c5157e705f3。榜单预览测试仅第一项有效，其余数字为测试输入常量，不代表实际排名记录。
- 中间构建历史（已被本节首条最终结果取代）：早期简化顶层batch位流setup+.124ns/hold+.019ns可构建，但缺Debug集成，不是交付。完整native第一次15957LUT/6987FF/29BRAM/5DSP，setup+.150ns/hold-1.642ns，验收拒绝。set_param place fix_hold high、route hold_fix_iteration10已固化构建脚本，但当时仅靠这些策略未消除外部50MHz与PLL40MHz跨域负hold。
- 最终时钟：sys_pll反馈C0从100MHz改50MHz（FBCLK_DIV1/CLKC0_DIV20/CPHASE19），VCO仍1000MHz，memory40/shift172.8度未改；sd_clk直接用C0、boot也用sd_clk，SDC新增sd_clk divide1，保留全部时序路径，无blanket falsepath。游戏菜单底板改纯色防砖块遮字。
- 已更新README、board-demo、bringup、architecture、competition-status、code-provenance、test README；收尾将新版操作置于board-demo最前，修正bringup旧按键／镜像／23 IO说明，下方旧记录保留。旧媒体版位流和回执已复制build/archive/media-before-game-20261011。游戏镜像build/media/game-cache.img已生成；没写实体TF、没下载板卡、没固化、没Git提交/推送。两路子代理余额错误退出，Sol资产代理完成测试与最终顶层只读审查无确定连接错误。

## 2026-10-10 四槽预取、默认静音与工程重整

- 用户已反馈旧版所有功能上板可用，本轮按要求实现当前图＋后三张预取、最多 64 张目录；显示 DMA 确认后回收上一槽补后继，≤4 张常驻，坏图有界跳过。source done 与本次 DMA memory finish 同时满足才 READY；没有新增 DMA 超时恢复。
- 默认 SOUND OFF / CUT；KEY3 短按轮播、长按≥1秒松开切音频，KEY4 短对比度、长按循环 CUT/FADE/WIPE。OSD 新增缓存数、图片序号/总数、静音状态。连续转场确保完整淡入后才处理下一事务。
- 参考 FPGA_3 职责分层：src/ip/prj/script/test/doc；正式顶层 src/media_player_top.v，约束 prj/constraints。原 rtl/vendor/scripts/sim/constraints/docs 已迁移；历史日志/pycache 归 build/archive，历史文档 doc/history。上级原始资料与历史 build 保留。
- 新 GUI 入口 prj/media_player.al，位流 prj/media_player_Runs/phy_1/media_player.bit；生成源码在 build/staging/gui，修改正式源码须运行 python script/build_td_gui.py。旧 build/td_gui 不代表本轮。原生 add_files 按单文件加入，避免嵌套 Tcl 列表被 TD 当成文件名。
- TD 原生 RUN 成功，23 IO/ADC/SDC 检查通过：6738 LUT、4156 FF、19 BRAM9K、5 DSP、2 PLL、4 GCLK；SWNS +1.823ns、HWNS +0.019ns。位流 SHA-256 09bbbb53791cc0523e93488380bc55aaf9dc7c811ffc9e126c692b7056e38ec2，回执 prj/verification.json。原 SDRAM ECO/单负载转发时钟两类警告仍已审阅，不宣称板级签核。
- 缺约束负控制重跑通过，实际复现 BIT-8123；旧负例目录移至 build/archive/td_gui_no_constraints_pre_restructure 后生成新负例，避免旧源码残留。最终检查 42 个工程引用、RTL/staging 一致、位流回执哈希、已测源码哈希及文档链接通过。TD 原生 .al 使用未转义 UsedInP&R，通用 XML 解析器会拒绝；引用检查按 TD 原生文本格式，未改写可用工程。
- python script/verify.py 八组全通过：引脚/来源、5 项镜像、14 模块/链路、23 BMP、18 帧/5529600 像素黄金、真实加密 SDRAM 及 BMP 链路、HDMI 数字接口。另四显示槽全帧并发回归通过。证据 build/verification。
- build/media/demo-cache-6.img 已生成，包含六张连续 BMP 及 FPGAEND.BIN 标记；未写实体卡。新工具支持 1..64 张但总容量限制在扫描范围，旧卡无标记时扫描可能较慢。
- 上级三个资料索引复核：8345 路径缺失 0；原始官方 7869、课程 462、赛题 6。2026 官方日程/上传要求缺失，11月4日仅课程来源；应用场景、固化/冷启/长稳与交付报告仍待完成。见 doc/competition-status.md。
- 按用户要求并行分工：可用 gpt-6-astra 做缓存/边界审查，gpt-6-sol 做架构建议/镜像/四槽测试；Luna 与新版 Sol 调用被环境拒绝、Terra 不在可用列表，已向用户说明，由主线程补资料盘点与整合，未冒称四种模型都执行成功。
- 本轮未提交、推送、烧录或固化新版。下方下载器/未上板内容是历史，当前用户反馈优先；保留既有驱动排障改动。下一步按 doc/board-demo.md 用新位流和六图镜像验收，再固化配置 Flash。

## 2026-10-10 重启后仍为代码 52，内核签名校验失败

- 用户已重启（系统 LastBootUpTime 10:50:01），但 VID_0547&PID_1002 仍为代码 52、0xC0000428。系统 SYS 哈希与上轮安装的 TD win10 包一致，排除未替换文件；本次启动的 CodeIntegrity 3004 仍指向 CYUSB.sys。
- Windows SDK signtool `/kp /c driver.cat cyusb.sys` 校验 TD dl-cable/win10 包失败，报 `The signing certificate is not valid for the requested usage`；官方资料 win7_64、win8_10_64 和 TD dl-cable/win7 也均失败。普通 Authenticode Valid 不代表满足内核加载要求，不再盲目重复安装这些包。
- 只读核对：Secure Boot 开启；DeviceGuard 报 VBS 运行、SecurityServicesRunning={1}（没有报告 HVCI 服务 2）。不应无证据要求关闭内存完整性。当前尚未到 FPGA JTAG 链排查阶段。
- 可选后续：获取厂商明确支持 VID_0547&PID_1002 的 Windows 11 签名驱动；或经用户选择，用 Windows 高级启动中的“禁用驱动程序强制签名”进行一次启动的诊断，重启恢复，不能保证受其他策略约束时有效。没有修改系统安全策略、刷下载器固件或再安装驱动。

## 2026-10-10 下载器驱动更新，等待 Windows 重启

- 用户授权更新下载器驱动。比对官方资料：`win8_10_64` 就是原已安装包；两个“新版TD驱动PH1P35使用方法”ZIP 内为 AL_LINK_FT/FTDI 工具及固件，不适配当前 VID_0547 下载器，未使用。
- 已用 pnputil 导出原 `oem348.inf`，备份在 `C:/Users/xu/AppData/Local/Temp/anlogic-driver-backup-ce3f42a816104126a98925dbfd0db379`，包含 INF、SYS、CAT。确认此包仅绑定当前 Anlogic 下载器后，卸载旧包并安装 `E:/1_software/TD/driver/dl-cable/win10/cyusb.inf`；新包仍命名 oem348.inf、版本号仍为 3.4.7.0，但 SYS/CAT 内容不同。系统 SYS 已与新包一致，SHA-256 `D78C2F28340E33F19549AB8C284A8C7783C55C9B483D1B2EB00FBA728D097BAA`。
- 安装返回需要重启，目前设备代码 14（CM_PROB_NEED_RESTART）。尝试 pnputil /restart-device 被拒绝，原因是等待系统重启。安装日志中重启前仍有代码 52 / CodeIntegrity 3004，因此不能宣布签名问题解决；用户保存工作并重启 Windows 后须重新检查设备状态和 BitWriter Refresh。
- 未修改驱动签名强制、安全启动或内存完整性设置，未自动重启电脑，也未执行 FPGA/Flash 下载。下一步先读实际 PnP 问题码：若为 0 再验证 JTAG 识别；若仍为 52，则进一步核对 Windows 11 内核签名兼容性。

## 2026-10-10 BitWriter 无法识别下载器

- 用户确认 `build/td_gui` 已能 RUN，随后 BitWriter Refresh 无法识别。Windows 已枚举 `Anlogic usb cable v0.1`，硬件 ID `USB\VID_0547&PID_1002`，设备问题代码 52、状态 0xC0000428；CodeIntegrity 日志 3004 指向 `CYUSB.sys` 完整性验证失败。当前阻断点在驱动加载，尚未验证 FPGA JTAG 链。
- 当前驱动 `oem348.inf` / Cypress 3.4.7.0（2011-10-17），其 SYS 哈希与上级官方资料的 `driver/win8_10_64` 副本一致。TD 自带 `E:/1_software/TD/driver/dl-cable/win10/cyusb.inf` 匹配该硬件 ID，其 SYS 与当前安装版本不同；普通 Authenticode 校验通过，但尚未验证 Windows 11 内核是否接受。优先尝试这一完整驱动包，不能保证只换包即可修复。
- `driver/al-link` 包匹配 VID_336C，不能直接当作当前 VID_0547 的匹配驱动。只读检查已完成，未安装/卸载驱动、未修改系统安全设置、未重启，也未执行 SRAM/Flash 下载。

## 2026-10-10 RUN 报错复核

- 本次只排查并记录，未修改 RTL、约束或生成工程，也未重新编译、下载或提交。
- 当天 09:58 的失败日志仍来自 `build/td/media_player_Runs/phy_1/run.log`，末尾为 BIT-8123；当前 `build/td/media_player.al` 无 ADC/SDC 文件登记，实际 phy `settings.cfg` 的 ADCList/SDCList 均为空。
- 应关闭旧工程并打开 `build/td_gui/media_player.al`。该入口登记了两个约束文件，已有 2026-10-09 16:30 的成功原生 RUN 日志；本次重新核对全部引用文件存在、约束副本与源文件一致、23 个布局引脚与 ADC 一致，以及位流 SHA-256 与 verification.json 一致。时序报告 SWNS +1.872ns、HWNS +0.003ns。这是既有产物复核，不能表述为今天重新 RUN 成功。
- `python scripts/check_project.py` 通过 23 引脚覆盖、位置无重复与 vendor 来源检查。PHY-7002 指向包内 SDRAM 原语的中间 ECO 位置；PHY-5079 指向 `u_sdram/u2_ram/SDRAM_CLK` 的单负载转发时钟。两条警告在成功构建中也存在，不是此次 bitgen 阻断原因，实物时钟质量仍待验证。

## GUI RUN真实链路修复与写卡状态

- 用户点击RUN失败，实际`build/td/media_player_Runs/phy_1/run.log`报BIT-8123：未约束IO。对应syn/phy的`settings.cfg`中ADCList/SDCList均为空，原`.al`也没有约束登记。不要拿之前批处理成功证明用户GUI已成功。
- 用原失败的`media_player_pr.db`执行bitgen，快速重现BIT-8123；新增`scripts/build_td_gui.py`以原生工程API生成并验证GUI RUN，独立目录`build/td_gui`避免旧GUI实例与批处理导出互相影响。`build_td.py`抽出共同的`stage_sources`，41个源码/头文件/约束与先前已验证stage逐字节一致。
- 原生GUI流程实际检查ADC/SDC已读、23个IO与板卡约束一致、bitgen成功、setup/hold非负；缺约束负控制必须捕获BIT-8123。syn/phy默认流程脚本与用户GUI输出逐字节相同。重建时清理本脚本生成的run产物，拒绝陈旧日志；已有工程显式import_device后再launch，避免只依赖首次create_project的隐式初始化。
- 新入口：`build/td_gui/media_player.al`；新位流：`build/td_gui/media_player_Runs/phy_1/media_player.bit`；具体哈希和验收值读`build/td_gui/verification.json`，源码未改变播放器功能。README/bringup/board-demo均已更新。
- Git归档：main上`fix: preserve constraints in native TD GUI runs`，同步同一private仓库。所有run、日志和镜像保留本机，不进入Git。
- 在本轮报错之前，用户已明确确认SD卡磁盘2可清空：65MiB四图镜像已写入并完整无缓存回读，SHA-256与镜像一致，Windows识别四张BMP和健康FAT卷。卡上64MiB分区正常，剩余空间未分配。未执行FPGA JTAG下载或Flash固化；不要继续把“TF卡未写”当当前状态。

## TD GUI与实物演示配置

- 用户需要明确`.al`入口、基础/扩展勾选清单，以及4 KEY、CONFIG1、4 SW、BUZ/SW、DIG/LED对应操作。新增`docs/board-demo.md`，README/bringup链接到逐项清单。
- 实际手册/原理图核对：SW1..4上=1下=0；CONFIG1连PROGRAM_B，不是应用复位；BUZ开关只控制板载蜂鸣器，音频仍走HDMI；DIG/LED仅切换8位数码管/8组双色灯，不控制四颗独立状态灯。
- 修正`rtl/media_player_top.v`独立LED极性为高有效（手册第6页图2-3），前三灯亮代表就绪，LED4亮为违约。其余功能和按键映射保留。
- `scripts/build_td.py`补TD版本、GUI约束及runs；发现TD console改写`.al`并丢掉约束列表，构建成功后恢复完整GUI工程。最初缺TD_Version导致打开失败，已修正并用真实TD重建通过。
- 本轮验证：23引脚/来源哈希检查，`.al`所有源文件存在及ADC/SDC/runs登记检查，TD综合/布局布线/bitgen通过。5597 LUT、3761 REG、19 BRAM9K、5 DSP、2 PLL、4 GCLK；setup +1.872ns/hold +0.003ns。当前bit哈希见advanced-validation。上一轮全套仿真保留为33a468d证据，本轮没有重跑数据通路仿真和七配置矩阵。
- Git归档：main上`fix: prepare TD GUI project and board demo controls`，同步同一private远端，不提交生成工程、日志、镜像、位流。用户已打开TD，完成后提示重新打开更新的`.al`。
- 本轮未写物理卡、未JTAG下载或固化；实际成功仍需用户逐项观察。

## 本轮五项扩展

- 用户明确要求五项先全部实现、由用户决定资源取舍；子代理仅允许OpenCode渠道DeepSeek，全部只读。主代理完成编码、独立裁决和实际工具验证。
- 新增`bmp_sector_player`、`advanced_video`、`osd_font`、`video_controls`、`audio_scope`、`transition_control`，接入同一顶层；增加KEY4/SW4约束和控制域BUFG。参考DMA加入busy/refresh门控，FIFO提供背压，调度器可有界跳过坏图。
- 本轮软件证据：11项模块/链路、23个BMP场景、18帧独立黄金图像；ModelSim实际加密SDRAM控制器与HDMI核测试。并发另一bank写入58752/74752字时显示帧仍完整正确。
- TD全开5673 LUT/3770 REG/19 BRAM9K/5 DSP/2 PLL/4 GCLK，setup +1.872ns、hold +0.012ns；7个profile均正余量，唯一候选全功能位流SHA-256在`docs/advanced-validation.md`。
- `build/media/demo-advanced.img`为65MiB四图混合尺寸FAT16镜像，簇链/目录/尺寸已检查；未操作物理卡。`build/advanced_sim/preview_all.png`为与RTL核对一致的黄金图像预览，不是板卡截图。
- 正式记录：`docs/advanced-plan.md`、`advanced-validation.md`、`code-provenance.md`、`review-disposition.md`；源码/验证/工具改动以Git diff和提交为准。
- 本轮Git归档：`feat: integrate all five multimedia extensions`，在main上提交并同步同一private仓库；未切分支/打tag。普通Git网络不可用时使用Git Database API精确同步对象、非强制更新远端ref，并核对HEAD/远端tree/隐私状态；构建产物和运行日志不提交。
- 下一步先由用户看功能/资源矩阵作取舍，再做实板/固化验收。不得称“任意输入、模拟电气、完整接收端、实物都已证明”。

## 2026-10-12 游戏素材图集 V2

- `script/pack_game_assets.py` 已扩展到 85 个 tile（保留 0～20 原 ID，新增管道/地形/城堡/道具/龟/龟壳/火球等 21～84）；支持 16×32、≤16×24 素材上下分片及天空色透明化。
- 图集签名从 `GAME_ATLAS_V1!@#` 升级为 `GAME_ATLAS_V2!@#`，manifest 格式为 `game-atlas-bmp-v2`；固定 16 色 4bpp 调色板，避免量化吞掉绿植、灰石和云层。
- 已重新生成 `assets/game/atlas.bmp`、`preview_1.bmp`～`preview_5.bmp`、`manifest.json`、`src/game/game_assets.vh`，并把六张新图重建为 `build/media/game-cache.img`。旧图集镜像保留为 `build/media/game-cache-v1-backup.img`；没有写实体 TF 卡。
- `python test/test_game_assets.py` 4 项通过；V2 镜像 SHA-256：`1de2792200f0db93dc634f1ee68968043eb55b3456b6aee04260319591e9dab8`。后续若改 tile ID，需同步游戏地图和 `game_video` 的素材引用。

## 首版历史

- 已创建 `1zzxy1/eg4s20-hdmi-media-player`，必须保持 private。首次 API 同步提交 `df573c9`，原初始化提交保留于本地 `local-bootstrap` 分支。
- 首版顶层、PLL lock/分域复位、48kHz PCM/ACR、亮度/状态条、TF/BMP/双缓冲/HDMI 完成集成。参考修改和来源见 manifest、Git diff 及 `docs/validation.md`。
- 本地功能提交 `b449c0c`；后续静态检查修订保留于 Git 历史。API 同步可能生成等价 tree 的不同 commit，须按实时 HEAD/远程核对。
- 6 个 Icarus 测试全部通过；TD 6.2 完成综合/布局布线/位流，setup +1.471ns、hold +0.011ns。LUT 4167、REG 3415、BRAM9K 18、PLL 2、DSP 0。
- 40MHz SDRAM / 50MHz TF 替代不满足时序的 125MHz / 100MHz；SDRAM 刷新周期定义在构建 staging 中跟随更新，vendor 原件不改。
- `build/media/demo.img` 含四张连续 BMP 的 FAT16 分区，MBR/BPB/文件簇链已检查；没有写入实体 TF 卡。
- Git HTTPS 受失效本机代理和直连重置影响，使用 GitHub API 上传已提交对象，验证 tree 哈希。后续同步必须保留同样校验，不能称普通 git push 已成功。
- 已接受的具体 TD 告警、IO 约束缺口、扇区扫描/SDHC 限制见验证文档。首次上板按 `docs/bringup.md`，需要板卡、SDHC 卡、HDMI 音频接收设备。
- 尚未烧录、固化、断电重启或实物测试；下一阶段是系统硬件验收、卡异常处理及文件系统升级，不能声称已完赛。
