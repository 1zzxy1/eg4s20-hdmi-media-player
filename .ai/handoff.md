# 当前交接

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
