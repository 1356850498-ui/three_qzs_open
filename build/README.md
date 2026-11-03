# 构建与最终报告导航

| 内容 | 主配置 D=0.2 | 对照配置 D=0 |
|---|---|---|
| 最终实现时序 | [timing.rpt](reports/main/implementation/timing.rpt) | [timing.rpt](reports/d0/implementation/timing.rpt) |
| 最终实现资源 | [utilization.rpt](reports/main/implementation/utilization.rpt) | [utilization.rpt](reports/d0/implementation/utilization.rpt) |
| 时钟 | [clocks.rpt](reports/main/implementation/clocks.rpt) | [clocks.rpt](reports/d0/implementation/clocks.rpt) |
| DRC | [final_drc.rpt](reports/main/implementation/final_drc.rpt) | [final_drc.rpt](reports/d0/implementation/final_drc.rpt) |
| 方法学与边界 | [methodology.rpt](reports/main/implementation/methodology.rpt) | [methodology.rpt](reports/d0/implementation/methodology.rpt) |

`reports/main` 与 `reports/d0` 直接目录中为综合阶段等资料，`implementation` 内为最终布局布线报告。`pre_carrier_register` 是首轮优化前历史报告，含负时序，不用于最终验收。时序等报告头中的绝对路径是生成时的位置。utilization.rpt 是保留原数值的资源表视图，按表头说明展示；当前入口以本表为准。

从零复现使用根目录 `prepare_project.bat` / `run_full.bat`，或 scripts 下同名 PowerShell 流程。安装位置通过 -VivadoBin 或 VIVADO_BIN 指定，无需修改脚本源文件。

完整构建会更新原有保存结果，因此请先复制整个包作为工作副本。文件校验清单不会随构建自动刷新，重建后出现哈希变化是正常的，需要重新冻结归档，而不能继续沿用旧校验结论。
