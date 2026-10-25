# 当前上下文

当前目标只排查画面横向环绕。用户已实板确认BGM无杂音，仍有右侧内容绕到左侧；要求暂关其他功能并Git保存。游戏检查点已本地提交d84d8db，包含之前目录迁移和全部游戏素材；不推送、不烧板、不写卡。本轮未开子代理。

## 当前诊断交付

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

用户只需SRAM下载诊断bit，SW全下看A，SW1上看B，各拍完整屏幕，记录最左编号、右绿框是否绕左。若暂时无信号，KEY4按下松开再等几秒。两者均正常→对比游戏输入链；A错B正常→HDMI／AXIS／接收模式；均错→共用时钟／物理输出／显示器时序识别。组合只能指导排查，不能直接定根因。无实板A／B结果前不恢复功能或宣称修复。

## 保留游戏基线

d84d8db是完整可恢复源码进度。prj游戏bit现为13:50:50的c18d8f986f71935e388156a9bcbe432ce3101a015beafecdbc52f2c6e4ad1467，已备份build/rollback-evidence/game-20261025-135050；旧verification绑定01:06的612b575c，不能给重建bit背书。01:06配套归档build/rollback-evidence/stable-20261025-010638含src／ip／素材／staging／bit／报告。新增诊断源使旧游戏receipt源集过期，恢复开发游戏时重新脚本构建。

基线：原厂HDMI READ_EDID=1／实际DDC，固定640×480；V4首BMP LBA2337直接加载纹理，完整帧／签名成功后启音频，失败重试；KEY3左KEY2跳KEY1右SW4跑火，KEY4昵称后长按一秒，SW1静音SW2首屏测试音。BGM＋四SFX、昵称／头像／排行保留；素材轮播等扩展暂未启用。Slice72.81%、BRAM52／64，29游戏bench与原厂HDMI专项已过，详细历史见handoff。

V4镜像68157440字节，SHA256 37553923c0d73f69646ad592af4fe4b0d8b39c067435cc62a6ba29f87f03f637，原卡无需重写。旧Git2a818358是马里奥前，只能作为接法参考，不能拿来整仓回退游戏。当前还不满足完整赛题功能，参赛信息仍见competition-status，眼前只解决实屏。
