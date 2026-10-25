# IP 与参考代码

- `clock/`：可编辑的系统与视频 PLL 包装。
- `sdram/sdr_init_ref.enc.v`：课程来源、经修改的 SDRAM 初始化衍生件。
- `vendor/course/`：保持来源正文的 SPI/SD、异步 FIFO、HDMI 和 SDRAM IP；加密模块由 TD / ModelSim 正常编译。

来源路径与初始 SHA-256 见 `../doc/reference_manifest.json`。`python script/check_project.py` 在 workspace 根目录检查不可编辑副本；`script/import_reference.py` 只补充缺失的原始 vendor 文件，已修改源码需从 Git 恢复。

构建脚本只在 staging 中把 SDRAM 刷新参数从参考 125MHz 改为本工程实际 40MHz，原始 vendor 文件不改。仿真器件模型在 `test/`，不进入综合。
