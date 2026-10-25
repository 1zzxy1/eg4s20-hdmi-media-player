# TD 工程入口

当前正式目标是恢复媒体实验室的游戏版，使用下方默认命令。历史 `--video-diagnostic`／`--video-svga` 仅用于独立画面诊断，不是当前交付目标。

日常在 workspace 根目录运行 `python script/build_td_gui.py`，生成并实际执行原生 TD RUN；随后运行 `python script/check_deployment.py`。无需在 TD GUI 中手动 RUN，GUI 仅用于下载。构建前关闭旧工程，关闭时不要保存旧文件清单。

手动 RUN 报新增模块 `is a black box` 时，关闭工程且不要保存，运行 `python script/build_td_gui.py` 和 `python script/check_project.py`，完成后重新打开本目录的 `media_player.al`。脚本补全保存在 `.al` 中的全部 RTL 登记，并清理旧的排除缓存；已有工程的原生 RUN 不再临时添加 RTL 来掩盖缺项。检测到 `.lock.f` 时会先停止，防止打开的旧 GUI 再覆盖清单。

- 打开：`media_player.al`；顶层 `media_player_top`，器件 EG4S20BG256。
- 下载：`media_player_Runs/phy_1/media_player.bit`。
- 验证回执：`verification.json`，含位流 SHA-256、29 个引脚检查、setup/hold 余量和已审阅警告。
- 正式管脚/时序约束：`constraints/hx4s20c.adc`、`constraints/media_player.sdc`。

`.al`、RUN 数据库、日志和回执均为本机生成物。工程引用 `../build/staging/gui/` 的源码与约束副本，修改正式源文件后须重新运行脚本。共享工程应共享完整源码树，接收者本机重建，不单独发送 `.al`。

关闭旧 `build/td` 或 `build/td_gui` 工程后再打开此入口，避免沿用旧约束列表。`build_td.py` 是保留的批处理/配置矩阵工具，不是日常 GUI 入口。
