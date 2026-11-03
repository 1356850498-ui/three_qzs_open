# 仿真结果导航

建议先读 [覆盖说明](coverage.md)，再看下列结果。所有已有结果属于离线 RTL 仿真，不是实板测量。

| 目的 | 结果文件 | 说明 |
|---|---|---|
| 主配置完整功能 | [cascade_main/result.txt](results/cascade_main/result.txt) | 64,280,717 项检查、148 次启动、144 组中断 |
| D=0 对照 | [cascade_d0/result.txt](results/cascade_d0/result.txt) | 每单元 402 个完整周期 |
| 按键与故障优先级 | [cascade_buttons/result.txt](results/cascade_buttons/result.txt) | 抖动、长按、跨复位、来源显示 |
| 非法参数短测试 | [cascade_parameters/result.txt](results/cascade_parameters/result.txt) | 6 种非法配置拒绝，可用于初次打开后的快速试跑 |
| 所有测试范围 | [coverage.md](coverage.md)、[test_summary.json](test_summary.json) | 4 组级联测试和 13 组继承回归 |

生成波形后查看：在 Vivado 中 File → Open Waveform，打开 `sim/results/cascade_main/cascade_main.wdb`；再打开配置 `sim/cascade_main.wcfg`。本仓库不附带 WDB；运行对应仿真可生成波形，其他测试同理。

仿真可生成逐拍数据与统计：`results/cascade_main/key_trace.csv`、`period_statistics.csv`、`interruption_cases.csv`。这些是测试台输出，阅读 CSV 前先看 coverage 中的统计口径。

重新仿真：主 XPR 的 Simulation Sources 有 sim_main、sim_d0、sim_buttons、sim_parameters，选中所需集合 Make Active，再 Run Behavioral Simulation → Run All。主测试计算量较大，短测试只验证非法参数处理，不能替代完整主回归。

批量运行脚本位于 `build/scripts`；每组结果的检查范围见 coverage.md。
