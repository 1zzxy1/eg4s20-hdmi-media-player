# 约束文件

`hx4s20c.adc` 对照 HX4S20C 手册分配 HDMI-A、TF、按键、拨码和 LED。差分 N 引脚由 TD LVDS33 配对，不另设逻辑输出。

`media_player.sdc` 约束 50MHz、40MHz、25MHz、125MHz 及 SDRAM 40MHz/172.8° 转发时钟。TD 要求分数倍频单独使用 `-multiply_by 2.5`，不能与 `-divide_by` 同时使用。

保留跨域和 SDRAM 路径的时序检查，未用跨域整组 false path 掩盖违例。当前复位入口采用 false path；SPI 外部输入/输出延迟、HDMI 模拟眼图和板级偏斜尚未完成验证。STA 正余量只描述现有约束覆盖的路径。
