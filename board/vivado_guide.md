# Vivado 操作步骤（当前整理目录）

先将整个 `three_qzs_open` 放到英文、无空格短路径，使用 Vivado 2025.2 并安装 Zynq-7000 支持。

1. Open Project，打开 `board/project_main/cascade_qzs.xpr`。缺少该文件时先运行根目录 `prepare_project.bat`。综合顶层应为 `cascade_qzs_board_top`，器件为 `xc7z020clg400-1`。源码参数文件为 `src/rtl/cascade/cascade_config.vh`，QZS_MAIN_D_PPM=200000 对应 D=0.2。
2. 首次检查建议在 Sources → Simulation Sources 选择 `sim_parameters`，右键 Make Active，Run Simulation → Run Behavioral Simulation，再 Run All。测试应自行结束并输出 RESULT=PASS。该短测试只验证非法参数处理。
3. 完整主测试选择 `sim_main`，顶层 `cascade_main_tb`；另外有 `sim_d0` 和 `sim_buttons`。切换仿真集合不需要修改综合顶层。完整测试耗时较长。
4. 运行主仿真生成波形后，File → Open Waveform 打开 `sim/results/cascade_main/cascade_main.wdb`，再打开 `sim/cascade_main.wcfg`；Zoom Fit 查看全程，放大约 100 μs 查看载波周期。
5. 重新构建时依次 Run Synthesis、Run Implementation。Open Implemented Design 后查看 Timing Summary、Utilization、DRC、CDC 和 Methodology。不得通过放宽约束掩盖真实违例。最终历史报告导航见 `build/README.md`。
6. Generate Bitstream 的原生输出在 `board/project_main/cascade_qzs.runs/impl_1`。只有完整脚本流程会自动更新 `board/bitstream` 保存副本；单独 GUI 重建不会刷新旧校验清单。
7. 对照工程是 `board/project_d0/cascade_qzs.xpr`，顶层 `cascade_qzs_d0_board_top`，固定 D=0。两套 XPR 的源文件依赖均在本包中。
8. PL 时钟来自 PS；PS 初始化文件位于 `board/ps_initialization`。板卡引脚见 `board/pin_connections.csv`。

旧版 Word 中可能保留 `rtl/`、`verification/`、`handoff/` 等原路径；当前分别对应 `src/rtl/`、`sim/` 和拆分后的 report/build/board。以本说明和根 README 的入口为准。
