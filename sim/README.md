# 仿真

运行 `python scripts/verify.py` 执行完整软件验证，任一失败即非零退出。分项可单独运行：

- `test.py`：11项，包括保留的首版模块回归、新转场/波形/控制、坏图调度恢复和真实异步FIFO整帧回读。
- `test_advanced.py`：23个BMP场景，独立Python随机访问黄金算法；包括坏头、短扇区、中途失败、无响应、严格尺寸模式和故意污染黄金像素的负控制。
- `test_video.py`：9种风格×2个完整640×480帧，共5529600像素；检查RGB、SOF、TLAST、消隐、帧内参数快照、滚动、各对比度档位、淡化和显影、波形与峰值、叠加层颜色。
- `test_vendor.py`：ModelSim运行原厂加密SDRAM控制器，连接自建JEDEC功能器件模型、真实FIFO与视频时序，逐像素核对整帧。`--bmp` 增加真实缩放器及背压联接。
- `test_hdmi_vendor.py`：ModelSim运行原厂加密HDMI核和TD RAM/FIFO模型，验证5帧期间锁定、AXIS ready、TMDS已知RGB解码、无X及PCM/ACR激励。

模型边界：`tb_loader_recovery` 中的 SD 模型是扇区端点，不是SPI电气模型。`tb_frame_path` 默认是App接口存储模型，`REAL_SDRAM`时改用实际加密控制器，`BMP_SOURCE`时使用真实缩放器。`sdram_array_model.sv`只提供器件功能，未作为特定速度等级的JEDEC时序签核。HDMI测试未解码全部音频数据岛/校验码，未验证EDID兼容和模拟PHY眼图。测试PASS不得扩大到这些范围。

testbench与器件模型只在`sim/`；TD构建只收集`rtl/`、`vendor/`，不会把仿真模型或桩带入位流。
