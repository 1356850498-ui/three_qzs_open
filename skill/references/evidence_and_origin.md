# 经验来源与验证依据

技能包从工程的独立验证模型、版本审计、时序优化和告警复核中提炼。可复用部分包括：逐项配置结果路径、核对显式状态和错误数、核对顶层与 Routed 阶段、提取时钟和资源、保留告警及证据哈希。

## 工程观察与可复用经验

| 现有证据（相对项目根目录） | 保存的事实 | 提炼的经验 |
|---|---|---|
| report/development_process.md | 旧 source_manifest 有 5 条与实际文件不符 | 显式版本/路径/哈希，不沿用旧验收 |
| build/reports/pre_carrier_register/main/implementation/timing.rpt | 首轮主配置 WNS=-0.164 ns、TNS=-1.201 ns | 将历史与最终实现分开，负时序不得算通过 |
| build/reports/main/implementation/timing.rpt | 最终主配置 WNS=1.058 ns、WHS=0.118 ns | 核对 Routed 和真实配置；保留外部约束缺项 |
| build/reports/main/implementation/utilization.rpt | LUT=829、FF=367、RAMB36/RAMB18=0 | 从顶层行提取，不能累加父子层级重复计算 |
| build/reports/warnings_review.md | 16 项 TIMING-18、1 项 LUTAR-1；CDC-3 信息另行复核 | 输出告警与覆盖边界；不把内部时序等同接口验收 |
| sim/results/cascade_main/result.txt | CHECKS=64280717、STARTS=148、CUT_CASES=144、UNIT_ERROR_CASES=3 | 同时覆盖稳定与切换场景，次数不是独立场景覆盖率 |
| sim/results/cascade_d0/result.txt | 每单元 402 个完整周期 | 单独保存对照配置结果 |
| sim/coverage.md | 17 组 PASS、独立事件/换向等待模型、未覆盖硬件范围 | 区分模型来源和验证层级 |
| report/development_process.md 与 sim/coverage.md | 新旧 D0 流水差异 | 功能复用不自动继承逐拍等价结论 |

以上为工程保存的仿真与实现证据。技能包真实运行输出与所读文件哈希见 ../validation/current_audit.json，负向和迁移测试见 ../validation/validation_summary.md。


## 使用范围

验证输出记录在 validation 目录。脚本读取保存的仿真/报告文件，解析格式为 Vivado 2025.2 文本报告；迁移案例采用合成文本。RTL 接口语义、约束合理性和实物波形属于各工程自身的验证范围。提示词模板作为可复制的排错方法使用，不提供生成成功率或性能增益数值。
