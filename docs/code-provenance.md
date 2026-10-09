# 代码来源与本次修改

本工程不是全部从零编写，也不是原例程直接换名。`reference_manifest.json` 保存导入时的原始路径及 SHA-256；`editable:true` 的哈希是修改前来源哈希，不能当作当前文件哈希。

| 类别 | 文件/模块 | 处理方式 |
|---|---|---|
| 课程参考，保留原件 | `vendor/course/` 中 SPI/SD、视频时序、异步 FIFO、HDMI PHY 等 | 源码正文未修改；`check_project.py` 检查来源哈希，允许 Git 换行转换 |
| 厂商加密 IP | HDMI transmitter、`sdr_as_ram`、`sdr_wrrd` | 直接通过 TD/ModelSim 支持的流程使用，没有解密或仿写内部逻辑 |
| 参考代码修改 | `rtl/reference/` 的 PLL、帧 DMA、图片调度、AXIS、include 等 | 修正锁定/复位、缓存握手、帧标记、忙/刷新门控、错误恢复与工程连接 |
| 原创新增实现 | `bmp_sector_player.v` | 有背压的扇区缓存、BMP 几何校验和加载侧最近邻缩放 |
| 原创新增实现 | `advanced_video.v`、`osd_font.v`、`video_controls.v` | 字幕、时间戳、半透明图层、调色、参数显示与交互 |
| 原创新增实现 | `audio_scope.v`、`transition_control.v` | PCM 双缓冲波形、峰值、黑屏边界提交与淡入淡出/显影 |
| 首版自写模块 | `pcm48_tone.v`、`reset_sync.v`、`frame_commit_bridge.v` | 音频节拍、复位同步、缓存提交；本轮扩展 bridge 的提交门控 |
| 自写验证与工具 | `sim/`、`scripts/` | 独立黄金图像、测试平台、构建和镜像工具 |

`sdram_array_model.sv` 是自建功能器件模型，**不是厂商 SDRAM 模型**，只用于仿真，不进入综合。`tb_loader_recovery.sv` 内的 SD 模块是明确标注的扇区端点模型，也不进入综合。

ModelSim 正常编译和运行原有加密控制器；不存在破解加密 HDL、修改授权配置或绕过许可证的操作。原始资料上级目录不在 Git 范围内。参考代码的发布授权不由本工程重新声明，仓库保持 private。
