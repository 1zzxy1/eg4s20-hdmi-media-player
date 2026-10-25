# 软件验证

## 当前：手动横向校准

用户换屏确认其他屏正常，目标改为针对自有屏人工补偿。`python script/test_alignment.py` 使用实际 `game_video`、同步 map/texture 延迟和接收端循环移位模型。无补偿／接收端右移 128 的负例在像素比较中失败；补偿和接收端偏移同为 0、1、128、639 时逐行比较游戏与校准图，每例 604160 像素，共 2416640 像素通过（校准值文字因数值不同而排除）。另测粗细调、环绕、长按、切换时按键隔离与拨码毛刺。模型只复现照片中的循环移位现象，不能证明真实显示器根因。

`python script/test_hdmi_vendor.py` 追加 `pipeline_aligned`：正式渲染补偿 128 后，经加密原厂 HDMI 核解码，对照独立 HUD 黄金检查全部像素和同步。原有音调、非对称立体声、原 V4 镜像 BGM＋四路音效、串行引脚解码和故意错一拍负例也全部通过。回执 `build/hdmi_vendor_sim/result.json` 含 `manual_alignment_128=pass`。另单独重跑 `tb_game_inputs`、`tb_game_boot`、`tb_game_world`、`tb_game_video` 均通过；没有宣称完整游戏测试集全部重跑。

原生 TD 构建、`check_project.py`、`check_deployment.py` 通过。板测采用正式游戏的 SW3 校准图，按 [板上操作](../doc/board-demo.md) 调节，尚待用户确认这块屏上的最终值及游戏／BGM。

## 历史探针记录（A/B/C 已实屏失败）

最新实板反馈为 A/B 均按 `8 9 0…7` 环绕。当前候选入口 `python script/test_video_svga.py`，输出 `build/video_svga_sim/`：实际功能 PLL 产生 40／200MHz，经正式 PHY 引脚恢复 TMDS，核对独立 Python 黄金画面、800×600 完整帧、HS128／后肩88／行1056／帧628、KEY4 与存储闲置；损坏蓝通道的负例必须失败。PLL 启动同样需要仿真专用 reset 脉冲，不是实板冷启动证明。构建与部署参数为 `--video-svga`。

原始实屏故障没有可自动复现的板级捕获接口，不能称此数字回归锁住了根因。`script/test_video_board.ps1` 按 diagnosing-bugs 的 HITL 模板适配 Windows，记录实际人工观察、照片与候选哈希；旧 A/B 的已给定反馈导入后均返回 FAIL。它不是照片自动识别或 FPGA 回读。最终验收仍需新 C 位流在用户显示器上显示正确。

本轮纯视频诊断使用 `python script/test_video_diagnostic.py`，独立回执在build/video_diagnostic_sim/result.json。A原厂HDMI与B纯DVI的像素由独立Python图像黄金检查，包含编号、字体、完整边框和坐标色带；接收侧检查HS宽度／后肩／整行／整帧，正式PHY输出逐字对照；损坏AXIS RGB的负例必须检出。两路径共用640×480／25MHz，模拟检查不等于实屏正常。

同一入口还运行tb_video_diagnostic_controls：实际功能PLL模型下检查A→B→A、KEY4按住／释放和存储引脚始终闲置。该模型用bench的200ns初始reset脉冲模拟上电，硬件原PLL配置不变；不将它当真实冷启验收。最终回执绑定19项工程输入及厂商模型哈希。本轮统一入口实际退出0，各项PASS；不替代旧14组或实板声画验证。

旧 A/B 诊断构建为 `python script/build_td_gui.py --video-diagnostic`；工程与部署检查都追加同一参数。输出／staging／回执均独立，不访问TF卡，不覆盖游戏位流。当前用户已确认游戏BGM无杂音，A/B 画面均环绕；不要把旧数字通过当作实屏已正常。

当前是2026-10-25精简游戏候选，未启用的媒体代码与测试保留。优先运行：

```powershell
python script/test_game.py
python script/test_hdmi_vendor.py
python test/test_deployment.py
python script/check_project.py
python script/build_td_gui.py
python script/check_deployment.py
```

本轮29个游戏bench、默认原厂HDMI专项、14项deployment测试、工程及位流配套检查实际成功退出；TD原生RUN完成、29个IO正确、setup +4.053ns／hold +0.011ns。未重跑完整14组，不沿用旧完整成功快照；软件通过不能替代显示器声音／画面实测。

## 游戏专项

`test_game.py` 自动收集 `test/tb_game_*.sv`，当前29个bench。缺少bench、编译失败、无正向PASS或超时均非零退出；场景预算600秒，其余180秒，超时保存部分日志。

- `tb_game_asset_loader` 用真实V4镜像LBA2337，依次注入短扇区、图集签名损坏，第三次恢复；检查完整307200像素、85×256纹理的全部双读口数据和成功后不再读卡。本轮专项抓到新加载器误用LBA2048的问题并已更正；这不是此前实板卡死根因的证据。
- `tb_game_lobby` 默认STABILITY=1，与精简顶层一致：关闭旧菜单，SW1静音、SW2首屏测试音、KEY4进昵称／长按一秒开始，覆盖加载等待和KEY3／2／1＋SW4。STABILITY=0保留旧首屏实验室路径。
- 地图全部4096格双口读写／重载、纹理全部85×256 texel、物理／道具／敌人、音乐生命周期、五声部音频并发／故障、结算、排名／Flash日志等保留。
- 公开输入通关不使用force／传送：1451世界步、15跳、到达x3264并结算排行。
- 场景检查真实图集与20个307200像素帧；奖励4352、死亡／裁剪／面板61441、入城6144黄金像素。仿真图不是实屏照片。
- `tb_game_scene_text` 检查1024次同步字符读取和空格填充；HUD检查共享转换器及发布期限。

旧菜单／波形／窄视口等单元继续回归，只证明保留模块行为，不代表当前顶层启用了它们。游戏回执在 `build/game_sim/results.json`，runner须实际退出0并显示29个PASS；分项进度不能单独当作整套成功。

## HDMI专项

`python script/test_hdmi_vendor.py` 默认vendor，回执 `build/hdmi_vendor_sim/result.json`。`--direct` 检查保留的直接核，回执 `build/hdmi_sim/result.json`。运行先撤销旧成功回执，各场景必须有正向PASS；ModelSim退出码本身不足。

正式路径：`video_timing_data → game_video → game_hdmi_output → 厂商PHY／lane`。坐标和实际HUD使用STABILITY=1，不经过已停用的媒体叠层；四色校准另检查保留的旧叠层。逐行640像素／800时钟、每帧480行、HS96拍／后肩48拍，RGB错一拍负例必须检出。原厂重建同步，直接核的两种同步注入负例不适用。

测试音、非对称立体声、真实V4三个场景各检查2099981组串行引脚字。PCM输入4031，原厂恢复4030，精确尾1；直接核恢复4028，精确尾3，不放宽丢样门槛。独立解码TERC4／BCH／奇偶／IEC状态块、48kHz／24-bit格式、N6144／CTS25000、InfoFrame及采样节拍，13种音频负例必须检出。

EDID启动启用，检查DDC有活动且无接收端应答时视频继续；当前1181个SCL下降沿。未模拟会应答的真实显示器EDID，不能称完整EDID兼容验收。

实际V4目录和PCM经仲裁、跨域桥、五声部混音到HDMI，以源WAV独立黄金逐样本比较。短窗口含187个BMP／68个音频扇区、音量／暂停／静音，启动304次声部等待，首扇区就绪后无额外欠载。四种媒体负例拒绝改样本、丢失、重复和整体晚一采样。实际音效结束、非整扇区循环、星音乐、饱和与故障另由游戏专项覆盖。

短串行器专项 `test_hdmi_phy.py` 覆盖理想相位、功能PLL模型及复位，反转位序／交换lane的负例必须检出。数字验证不包含真实SD电气、PLL抖动、模拟眼图、实屏发声或完整HDMI合规。

## 完整回归与保留媒体功能

`python script/verify.py` 为14组完整入口，包括自身门禁、工程／来源、素材、游戏、镜像、部署故障、音频预处理、基础媒体、缩放、媒体视频、加密SDRAM两种模式与HDMI。启动使旧成功失效；全部分项成功且src／ip／test／script／constraints／assets输入集合及哈希一致后发布成功快照。不得并发重跑或修改运行输入。只有 `run.json` 为passed并绑定当前快照，才能称完整成功；`results.json`只反映进度。

媒体测试保留0／1／4／6／64图、坏图与延迟DMA、四槽回收、29个BMP缩放场景、18帧5529600像素黄金、真实加密SDRAM模型；这些功能本版不实例化。自建存储器件模型不是厂商时序签核。

`test_deployment.py` 现14项，含staging／位流过期、GUI登记／AutoExcluded、目录／PCM／图集损坏等。`check_deployment.py` 只核对实际已构建的位流／回执／73个staging文件及V4镜像，不刷新staging、不访问设备，也不证明仿真或板测通过。
