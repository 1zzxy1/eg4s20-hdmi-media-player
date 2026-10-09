# 当前交接

- 已创建 `1zzxy1/eg4s20-hdmi-media-player`，必须保持 private。首次 API 同步提交 `df573c9`，原初始化提交保留于本地 `local-bootstrap` 分支。
- 首版顶层、PLL lock/分域复位、48kHz PCM/ACR、亮度/状态条、TF/BMP/双缓冲/HDMI 完成集成。参考修改和来源见 manifest、Git diff 及 `docs/validation.md`。
- 6 个 Icarus 测试全部通过；TD 6.2 完成综合/布局布线/位流，setup +1.471ns、hold +0.011ns。LUT 4167、REG 3415、BRAM9K 18、PLL 2、DSP 0。
- 40MHz SDRAM / 50MHz TF 替代不满足时序的 125MHz / 100MHz；SDRAM 刷新周期定义在构建 staging 中跟随更新，vendor 原件不改。
- `build/media/demo.img` 含四张连续 BMP 的 FAT16 分区，MBR/BPB/文件簇链已检查；没有写入实体 TF 卡。
- Git HTTPS 受失效本机代理和直连重置影响，使用 GitHub API 上传已提交对象，验证 tree 哈希。后续同步必须保留同样校验，不能称普通 git push 已成功。
- 已接受的具体 TD 告警、IO 约束缺口、扇区扫描/SDHC 限制见验证文档。首次上板按 `docs/bringup.md`，需要板卡、SDHC 卡、HDMI 音频接收设备。
- 尚未烧录、固化、断电重启或实物测试；下一阶段是系统硬件验收、卡异常处理及文件系统升级，不能声称已完赛。
