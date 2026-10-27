# 当前上下文

2026-10-27 最新：火焰花形态配色与 Mario-master 的 Fire_mario 素材五个使用帧量化后逐像素一致；静止龟壳从上方再次踩中也会滚动，侧面碰撞保持原行为。TD 原生构建与实际 hold ECO 后 bit 为 prj/media_player_Runs/phy_1/media_player.bit，2026-10-27 12:15:16，637785 字节，SHA256 085ed198af4d8a3a58c43c10e25857660cfdd1e4176456059287d01a3af3ea5f，setup +2.293ns／hold +0.021ns。MSlice 4828／4900、LUT 18211／19600、BRAM 63／64。敌人及 20 帧场景专项、6 项素材测试、check_project、check_deployment 通过；没有重跑完整 14 组回归。SW1 首屏图库每秒轮播、SW2 首屏和游戏字幕／PCM 波形、SW3 仅首屏校准均保留。原 V4 卡未变，尚未新实板验收；不烧板、不写卡、不推送。下方旧位流均为历史。

最新为 2026-10-25 17:44 GUI RUN 黑盒修复：旧 TD GUI 保存的 `.al` 漏掉三个实际实例化模块，工程检查与综合日志均复现。用户已关闭工程且未保存；已补全 74 个 RTL 登记。已有工程的脚本 RUN 只从持久清单读取 RTL，关闭 TD 后再次同步，并在检测到工程锁时拒绝改写。此次仅改构建／测试／文档，src、ip、约束、SD 素材未变。完整 native RUN 会话71842退出0，真实 hold ECO 后 setup+2.435ns／hold+0.024ns；最新 bit 为2026-10-25 17:44:40、636621字节，SHA256 da6dd4c3f4a104a08e7d3c2e715690395991f562a8b9d367ed4ad7b6210175f6。check_project、check_deployment、15项deployment测试通过；未重跑未改RTL完整回归，恢复版仍待板测。重新打开 prj/media_player.al，原 V4 卡不需重写，不烧板／不写卡／不推送；Git保存按用户既有授权。下段16:59位流为历史记录，最新产物以上述17:44和handoff顶部为准。

用户已实板确认人工补偿版 d4a501e 的画面、BGM 和游戏正常，当前授权恢复此前删除的媒体实验室功能。图库四槽／BMP 手动切图与轮播／字幕／实际 PCM 波形／显示和音频设置已接回，同一 BMP 解码器优先完成游戏纹理再服务图库，音频仲裁优先；任意横向偏移使用 SDRAM 16 词对齐和寄存器前缀。默认补偿128、固定640×480，保留正常 HDMI／PCM 链。首屏 SW1 素材、SW2 字幕波形、SW1＋SW3 显示、SW4 音频，SW3 单独校准；KEY4 进昵称，松开再长按一秒开始，之后 Debug 禁用。最终原生构建和hold ECO通过：bit为2026-10-25 16:59:02、636621字节，SHA256 777df2d066b3dd2074eb470b16a7a08278685583aa7654752fb5360c3f7c2b89；setup+2.435ns/hold+0.024ns，LUT18368/19600、BRAM62/64、DSP7，资源较紧。check_project、check_deployment、14项deployment负例、18帧5529600像素黄金、全部同步字形差分、offset128实验室与最终原厂HDMI音视频专项均通过，回执hash一致。详见handoff顶部；本地Git保存，恢复版仍待板测。正常旧版完整备份在 build/rollback-evidence/board-confirmed-20261025-aligned/，bit SHA256 4046a723964bd328ad99d0e059d90ffbb68a2446ffdc922797fa5b294dea83e5。原 V4 卡 hash37553923c0d73f69646ad592af4fe4b0d8b39c067435cc62a6ba29f87f03f637 未变、不需重写。不烧板、不写实体卡、不推送。下方为历史记录，不能覆盖本段。

## 历史实屏结论：A/B/C 都失败（新任务见顶部）

C照片D:/download/5.jpg显示C SVGA DVI／800 X 600，编号7 8 9 0…6，色条7跨两端，红绿框在屏内；未精确量出偏移像素。C位流56166cd2不是修复版，不能再标“待实测”。两种分辨率都失败，根因未定，数字仿真没有复现真实故障。用户要求后续从FPGA端处理兼容性，但当前停止由本代理继续尝试。

## 历史 C SVGA DVI 技术记录（数字通过、实板失败）

最新用户反馈 A/B 均为 8 9 0 1 2 3 4 5 6 7，照片 D:/download/44.jpg 为 B；红绿框一起到屏内，约128源像素循环偏移。原理想数字仿真不复现，不能当真实故障回归。显示器杂牌型号未知，用户要求从FPGA输出处理兼容性，不再询问型号。HITL脚本script/test_video_board.ps1导入已提供观察后A/B均FAIL，候选哈希非板卡回读证明。

独立新顶层 src/diagnostic/video_svga_top.v，配套 video_svga_pattern.v、ip/clock/video_svga_pll.v、prj/constraints/video_svga.sdc。固定标准800×600／40MHz／200MHz，1056×628，+HS128 FP40 BP88，+VS4 FP1 BP23，约60.317Hz；RGB与同步一起寄存。只有DVI与厂商PHY，DDC闲置，无BRAM／DSP／存储／音频；不是EDID自适应。模式、PLL与DDC均不同，不能用C结果单独证明哪一项根因。

使用 python script/test_video_svga.py；构建／工程／部署检查统一加 --video-svga。产物 build/video_svga/media_player_Runs/phy_1/media_player.bit，2026-10-25 14:37:01，629635字节，SHA256 56166cd2e49119044c8d68cf30cc1929cf5783e10fb5e818691d96fa2cf46167。原生TD实际退出0：setup +1.447ns／hold +0.025ns，Slice492=5.02%、BRAM0、DSP0，29IO／71RTL／81staging配套通过。显示C SVGA DVI／800 X 600；SW不切换，KEY4复位，LED2就绪、LED3常亮、LED4常灭。

数字新专项最终会话46973实际退出0：功能PLL→正式PHY串行引脚→两整帧960000像素／1965235串行字、行帧同步、40／200MHz、KEY4、存储闲置均通过，损坏蓝通道负例被检出。起止源码哈希一致；回执build/video_svga_sim/result.json passed=true。实际路由网表确认KEY4 PAD输入寄存器ipclk接pix_clk，旧key_meta_reg时钟警告为打包后旧实例提示。后续实板C仍失败，数字通过不代表修复；14项deployment通过。技术提交be49471，题为test: add SVGA compatibility probe for wrapped display，未推送。

## 上一轮 A/B 诊断（数字通过，实屏两者均错）

独立顶层src/diagnostic/video_diagnostic_top.v，video_diagnostic_pattern独立640×480计数器，video_diagnostic把同一图像送A原厂HDMI与B纯DVI。SW1下A／上B，KEY4复位；改变模式自动2.62ms复位，固定25MHz／800×525／约59.524Hz。编号0～9每栏64px，左红右绿上蓝下黄8px边框，LEFT000／RIGHT639标签。B绕开AXIS FIFO、音频岛和InfoFrame；仍共用原video_pll、厂商PHY和HDMI-A。没有横向补偿。

不实例化游戏、SD、PCM、排行、SDRAM，无声音；SD和Flash片选保持高，卡可拔。LED2=路径就绪、LED3=DVI、LED4=A背压锁存，LED1仅备用输入观测，不表示SD。

构建／核对均追加--video-diagnostic：
python script/test_video_diagnostic.py
python script/build_td_gui.py --video-diagnostic
python script/check_project.py --video-diagnostic
python script/check_deployment.py --video-diagnostic

产物build/video_diagnostic/media_player_Runs/phy_1/media_player.bit，2026-10-25 14:07:07，629641字节，SHA256 b0becade21261481568ac2ff81feb4c1e17c6c3121c1be0a1df7e451305cdde4。输出与staging独立，没有覆盖prj游戏位流。原生RUN会话53653退出0，setup +3.273ns／hold +0.011ns，29IO／68RTL／77staging检查通过；Slice1444=14.73%、LUT2446、FF1494、BRAM10／64、DSP0、PLL1、GCLK1。

数字测试：A两整帧614400像素、B三整帧921600像素，与Python独立黄金一致；各1679978组串行字、HS96／后肩48／行800／帧480，RGB损坏负例检出。hdmi.png／dvi.png是仿真参考，不是实拍。controls覆盖实际功能PLL启动、A→B→A、KEY4复位、SD／Flash闲置，78954退出0；模型需要额外初始reset脉冲模拟上电，不能扩大为实板冷启证据。统一runner及输入哈希回执在build/video_diagnostic_sim/result.json。14项deployment测试通过，未重完整游戏／14组回归。

## 下一步

等待用户现成官方 A 位流实板对照，不再安排重复 A/B/C 测试。保持同一板/线/屏；官方正常则对比输出链差异，官方也错则重点排外围与模式兼容性，仍不直接定根因。保留 BGM 及游戏基线，原卡不用重写；无板级自动捕获，不以数字仿真替代实屏结论。

## 保留游戏基线

d84d8db是完整可恢复源码进度。prj游戏bit现为13:50:50的c18d8f986f71935e388156a9bcbe432ce3101a015beafecdbc52f2c6e4ad1467，已备份build/rollback-evidence/game-20261025-135050；旧verification绑定01:06的612b575c，不能给重建bit背书。01:06配套归档build/rollback-evidence/stable-20261025-010638含src／ip／素材／staging／bit／报告。新增诊断源使旧游戏receipt源集过期，恢复开发游戏时重新脚本构建。

基线：原厂HDMI READ_EDID=1／实际DDC，固定640×480；V4首BMP LBA2337直接加载纹理，完整帧／签名成功后启音频，失败重试；KEY3左KEY2跳KEY1右SW4跑火，KEY4昵称后长按一秒，SW1静音SW2首屏测试音。BGM＋四SFX、昵称／头像／排行保留；素材轮播等扩展暂未启用。Slice72.81%、BRAM52／64，29游戏bench与原厂HDMI专项已过，详细历史见handoff。

V4镜像68157440字节，SHA256 37553923c0d73f69646ad592af4fe4b0d8b39c067435cc62a6ba29f87f03f637，原卡无需重写。旧Git2a818358是马里奥前，只能作为接法参考，不能拿来整仓回退游戏。当前还不满足完整赛题功能，参赛信息仍见competition-status，眼前只解决实屏。
