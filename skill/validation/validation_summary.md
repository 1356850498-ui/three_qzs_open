# 工具验证结果

日期：2026-11-03。运行环境：Windows，Python 3.12.14，Python 标准库；报告来源 Vivado 2025.2。具体 Python 小版本见 validation_environment.json。

## 实际执行

在项目根目录运行：

```text
python skill/scripts/audit_evidence.py --project-root . --config skill/configs/three_qzs_open.json --out skill/validation/current_audit.json
python skill/scripts/validate_examples.py --project-root . --out skill/validation/validation_cases.json
```

验证脚本在当前工作目录建立隔离临时文件夹，结束后清理；请在有写入权限的工作目录运行，不会改动现有 RTL、结果或报告文件。current_audit.json 是对保存证据的核对输出；第二项输出记录验证脚本的预期与观察状态。

## 已观察到的结果

17 组保存测试结果全部满足 RESULT 与错误计数检查，main/d0 两份最终 Routed 报告通过配置的时钟和内部时序检查。主配置提取 LUT=829、FF=367、WNS=1.058 ns、WHS=0.118 ns；对照 WNS=1.494 ns。告警记录共 6 条，来自两配置各自 TIMING-18、LUTAR-1 和 no_output_delay；这是同一问题在不同字段/配置中的披露，不表示 6 个独立根因。

12 个正向/负向/迁移案例均符合预期。表中 fail 表示待检查样例被正确拒绝，并非验证脚本自身失败。

| 案例 | 预期状态 | 观察状态 | 验证结果 |
|---|---|---|---|
| saved_project_evidence | pass | pass | 通过 |
| missing_result | fail | fail | 通过 |
| incomplete_result | fail | fail | 通过 |
| pass_with_nonzero_errors | fail | fail | 通过 |
| pass_without_error_count | fail | fail | 通过 |
| conflicting_result | fail | fail | 通过 |
| incorrect_clock_requirement | fail | fail | 通过 |
| incorrect_top | fail | fail | 通过 |
| resource_budget_exceeded | fail | fail | 通过 |
| real_historical_negative_timing | fail | fail | 通过 |
| evidence_outside_project_root | fail | fail | 通过 |
| portable_synthetic_50mhz_controller | pass | pass | 通过 |

## 测试的含义

负向案例能够检出缺文件、未结束结果、带错误的伪 PASS、缺错误计数、冲突状态、时钟错配、顶层错配、资源超预算、历史负时序和越界证据路径。迁移案例使用不同目录、controller_top、sys_clk、50 MHz 与不同资源数，说明配置机制并未写死本队工程名称。

迁移案例使用不同顶层、目录、时钟和资源数的合成报告，用于验证配置迁移和解析行为。

