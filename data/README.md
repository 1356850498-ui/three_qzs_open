# 测试数据与参考结果

| 文件 | 内容 |
|---|---|
| [input/spwm_duty.mem](input/spwm_duty.mem) | RTL 使用的 200 点初始化数据，与 src/rtl/core 下同名文件一致 |
| [simulation/main/period_statistics.csv](simulation/main/period_statistics.csv) | 主配置逐单元、逐周期的窗口时间统计 |
| [simulation/main/interruption_cases.csv](simulation/main/interruption_cases.csv) | 主配置停机、故障、复位注入记录 |
| [simulation/main/result.txt](simulation/main/result.txt) | 主配置自检结果与检查计数 |

这些文件来自现有仿真结果。运行主仿真可在 sim/results/cascade_main 生成完整逐拍 key_trace.csv 和 WDB；仓库只保存轻量统计文件。行为参考模型位于 sim/cascade_tb.sv；测试覆盖与比较口径见 [sim/coverage.md](../sim/coverage.md)。
