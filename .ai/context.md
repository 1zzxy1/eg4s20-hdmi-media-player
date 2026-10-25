# 当前上下文

最新实板反馈：BGM已无杂音，画面右端绕左仍在。用户要求暂关其他功能，只做画面诊断，并明确要求本地Git保存进度（不推送）。以下01:06候选描述保留为基线；当前游戏bit13:50已重建，见handoff，旧verification不匹配，诊断必须使用独立输出目录。

## 目标与授权

用户仅求BGM正常、游戏可玩、画面不环绕，要求查看Git／旧版；允许精简回退。2026-10-25完成精简稳定性候选，尚无本轮实板结果。不要恢复扩展功能、宣称根因已查明或声画已修好。本轮不写实体SD、不下载／固化、不提交／推送，不开子代理，保留已有目录迁移及dirty改动。

## 历史证据

本地／远端main均2a81835805b99f4ca82a81f0f6f23b105da56359（10月9日，马里奥前），无中间游戏提交／stash／不可达commit。不能整仓回退丢游戏，也没有“首次音乐正常版”的完整配套源码。

10月19日首次游戏实测“能玩”已同时报左侧显示异常；10月24日15:46首次明确有声，17:05报杂音、17:19确认独立测试音也杂音，烧16:50版。其间封包／PCM／采样节拍／PLL无修改，不能编造PCM算法回归。旧正常媒体为原厂HDMI、startup脉冲读EDID、DDC接实际引脚；10月24日失败原厂候选trigger=0、DDC悬空，未完整复原。差异存在但未证实根因。33.jpg显示左右校准边框一起环绕，没有新增−128像素补偿。

## 当前实现

- 顶层直接固定时序→游戏→原厂HDMI，READ_EDID=1／实际DDC；PLL／640×480、800×525、25MHz、48kHz音源与采样算法保持。无SDRAM、图片DMA、四槽／转场、advanced_video、波形／菜单实验室实例；源码／单元测试保留。
- game_asset_loader调用bmp_sector_player ENABLE_SCALE=0，V4首图LBA2337、原尺寸640×480，直接交付纹理；完整帧和16像素签名校验后发布，失败50ms重试，成功停止读图，再使能SD音频。初版误把2048分区起点当BMP，被本轮专项抓到并修正，不是此前实板卡住的原因结论。
- KEY3左、KEY2跳、KEY1右、SW4跑火；KEY4首屏进昵称，松开后长按一秒快捷开始，等待图集时请求锁存。SW1全局静音、SW2仅首屏独立1kHz测试音、SW3无功能。声音默认开，主／BGM／SFX=3／2／3，320×240逻辑视口两倍显示。
- LED1=SD初始化，LED2=图集已发布，LED3=图集失败|音频错误|Flash错误，LED4=原厂视频背压异常锁存，非音频overflow。
- 保留地图／纹理bank优化、世界／奖励／死亡／入城、昵称／头像／排行、一路BGM＋四SFX。未实现地下房、烟花、原作逐帧物理，不是FC模拟器。

## 当前产物与验证

正式入口prj/media_player.al，修改src／ip／prj/constraints后build_td_gui.py→check_deployment.py；不改build/staging/gui。关闭旧TD时不要保存旧清单，脚本登记65份RTL并清AutoExcluded。

本次原生TD RUN会话93631退出0，无需hold ECO：setup +4.053ns／hold +0.011ns／29 IO。位流prj/media_player_Runs/phy_1/media_player.bit，2026-10-25 01:06:38，633129字节，SHA256 612b575c4a54820af56f06b9569038156895cf4b1d5229b713248c36715a5d37。配套检查退出0、73个staging文件一致。Slice7135／9800=72.81%、LUT13444、FF5428、BRAM52／64=81.25%、DSP3、PLL2、GCLK2。相对上一版Slice94.99%下降，BRAM41升52，不能说全部下降。

游戏会话12228实际退出0、29个bench全过：真实V4截断／坏签名／恢复、全部21760纹理双读口、lobby、公开输入通关1451步／15跳／x3264、20帧场景等。HDMI会话6102退出0，默认vendor，36项输入哈希复核一致；测试音／立体声／V4各2099981组串行字、4031输入／4030恢复／精确尾1，19个IEC状态块；实际WAV黄金、187BMP／68音频扇区、启动304次等待、起播后无额外欠载。精简tail坐标／HUD各1228800像素，DDC无应答仍视频正常、1181下降沿；RGB负例检出。没有会应答的EDID显示器模型，不是电气或板测。

14项deployment测试及check_project通过，本轮未重完整14组，不沿用旧全套成功快照。综合sync0_reg的clk未驱动警告已按最终routed.v复核：8个输入寄存器移入PAD，ipclk均接u_flash/clk，即video PLL→GCLK后的像素时钟；旧sync0_reg实例已不存在，不是8个按键时钟被绑零。动态RAM初始化警告对应在用前覆盖的buffer；PHY仅保留旧器件slot／pre-route hold支持提示，实际最终setup／hold为正。

原V4镜像68157440字节、SHA256 37553923c0d73f69646ad592af4fe4b0d8b39c067435cc62a6ba29f87f03f637，BMP LBA2337、音频PAK LBA15097。10月24日原卡已写入／回读／弹出，本轮不改，无需重写。

## 交接

修改前备份build/rollback-evidence/before-stable-20261025，旧bit cf15d352…65ad。本轮成功候选的配套归档见handoff。此前f3954e20等本轮早期bit误用LBA2048，不能交付。

README／board-demo／architecture／competition-status／bringup／test说明与.ai按当前候选同步。赛题规则／资料索引保留，但当前位流暂不具备基础手动切图／轮播及全部五扩展，不是完整赛题交付。用户自行烧板，先LED2／进游戏，再听BGM／SW2测试音和检查右端环绕；实际三项故障及排行掉电／固化冷启／长稳仍待实测。
