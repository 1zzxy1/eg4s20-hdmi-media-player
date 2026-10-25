# 当前任务

用户确认BGM无杂音，右侧画面仍绕左；要求先只测试显示，并保存Git。

## 已完成

- 本地Git检查点d84d8db保存全部既有游戏进度，未推送。
- 独立纯视频顶层：SW1下A原厂HDMI、上B纯DVI，KEY4复位，测试图编号0～9、四色边框及左右坐标。
- 关闭游戏／SD／音频／排行／SDRAM实例，SD和Flash无读写。保留原游戏源码及位流。
- 原生TD RUN通过，bit b0becade21261481568ac2ff81feb4c1e17c6c3121c1be0a1df7e451305cdde4，629641字节，14:07:07。
- Slice14.73%、BRAM10／64、DSP0，setup +3.273ns／hold +0.011ns；29IO／68RTL／77staging配套通过。
- 两路径全帧／串行／同步与RGB负例通过；真实功能PLL下的SW／KEY4／存储闲置控制测试通过；统一回执见build/video_diagnostic_sim。
- README、板测说明、架构、赛题状态、test与.ai记录当前诊断，历史游戏操作保留并标明适用版本。

## 等待实屏定位

1. 用户下载build/video_diagnostic/media_player_Runs/phy_1/media_player.bit，无需SD。
2. SW全下拍A，SW1上拍B；看0～9顺序、红左／绿右是否完整，记录最左端编号。
3. 必要时KEY4按下松开重锁。反馈两张带完整屏幕四边照片及是否无信号。
4. 按A／B结果定位下一段，保持已恢复的BGM链路，不凭数字通过宣称画面修好。

本轮不烧板、不写卡、不固化、不推送；用户已明确授权Git本地保存。本轮不是赛事演示位流，后续才考虑恢复扩展。
