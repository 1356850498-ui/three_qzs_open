# 三模块级联准 Z 源开环控制工程

队号：41093　队名：啊队队队　赛道：AMD 自主选题赛道。

本工程以 PYNQ-Z2 / xc7z020clg400-1 为目标，由 FPGA 输出三单元共 12 路 PWM 命令，实现载波移相、普通换向等待、启停与故障联动。工具版本为 Vivado 2025.2；时钟 100 MHz，载波 10 kHz，基波 50 Hz，M=0.6。主配置 D=0.2，对照配置 D=0。

## 快速开始

1. 下载或克隆整个仓库到英文、无空格短路径，例如 `D:/fpga/three_qzs_open`。
2. 安装 Vivado 2025.2 和 Zynq-7000 器件支持。
3. Windows 双击 `prepare_project.bat`。脚本创建两套工程并检查文件依赖；看到 `PREPARE_RESULT=PASS` 后，在 Vivado 中打开 `board/project_main/cascade_qzs.xpr`。对照工程为 `board/project_d0/cascade_qzs.xpr`。
4. Simulation Sources 中选择 `sim_parameters` → Make Active → Run Behavioral Simulation → Run All，可执行非法参数短测试；完整主测试选择 `sim_main`。

本仓库通过脚本创建 XPR 和厂商 IP 生成文件，不需要单独下载板卡预设包。Vivado 安装位置会自动查找；也可在项目根目录的 PowerShell 中指定实际路径：

```powershell
.\build\scripts\prepare_project.ps1 -VivadoBin 'E:\AMDDesignTools\2025.2\Vivado\bin'
```

Linux/macOS 可在 Vivado 命令环境中创建工程：

```text
vivado -mode batch -source build/scripts/create_cascade.tcl -tclargs main
vivado -mode batch -source build/scripts/create_cascade.tcl -tclargs d0
```

## 运行与查看结果

| 目的 | 入口 |
|---|---|
| 原理、框图、接口和参数 | [设计说明](report/design_overview.md)、[Word](report/design_overview.docx) |
| 测试范围与结果 | [仿真导航](sim/README.md)、[覆盖说明](sim/coverage.md) |
| 资源和时序报告 | [报告导航](build/README.md) |
| 主配置统计数据 | [数据说明](data/README.md) |
| 接线与 Vivado 操作 | [板级说明](board/README.md) |
| 自动核对保存结果 | 双击 `skill/run_check.bat`；详细结果生成在 `skill/results/check_result.txt`，需要 Python 3.9+ |

保存结果含 17 组仿真结果。主配置的实现报告记录 LUT=829、FF=367、BRAM=0，WNS=1.058 ns、WHS=0.118 ns；对照配置 WNS=1.494 ns。资源表按表头说明展示原始数值。`report/figures` 为设计示意与 RTL 仿真图。

大体积 WDB 波形和主测试完整 key_trace.csv 由运行仿真生成；仓库保留测试源、WCFG、结果文本和轻量统计。设计说明中的波形打开步骤在生成这些文件后使用。Word 保留原工程说明的版式，当前路径与操作入口以本页和 board/vivado_guide.md 为准。

## 完整构建

Windows 双击 `run_full.bat`，或运行：

```powershell
.\build\scripts\run_all.ps1 -VivadoBin 'E:\AMDDesignTools\2025.2\Vivado\bin'
```

脚本依次创建工程、运行回归、综合、实现并生成主配置位流。成功结束输出 `FULL_REPRODUCTION_RESULT=PASS`。运行日志位于 `build/reproduction_logs`，报告位于 `build/reports`，位流位于 `board/bitstream`。当前仓库也保留原工程生成的 BIT/HWH 与参数说明。

运行完整构建会更新保存的结果和报告，请在工作副本中执行。校验仓库文件使用：

```powershell
.\build\scripts\verify_delivery.ps1
```

`.gitattributes` 保留文件字节，避免换行转换影响 SHA256 校验；校验清单不包含 Git 自身的 `.git` 目录。

## 目录

| 目录 | 内容 |
|---|---|
| src | RTL、MEM、XDC 和 PS 预设 |
| sim | 测试源、运行脚本、波形配置与轻量结果 |
| build | 构建脚本、综合实现报告 |
| board | 位流、硬件描述、接线与操作说明；XPR 在本地生成 |
| data | 初始化数据、周期统计和故障注入记录 |
| skill | 可复用检查工具、经验与提示词模板 |
| report | 设计说明、图示与文件校验清单 |
