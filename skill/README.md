# Vivado 工程仿真与实现结果检查工具

**它帮你检查：仿真是否记录为通过、实现时序是否通过、用了多少 FPGA 资源。**

适用于已经做过仿真和布局布线的 Vivado 工程。你不用懂准 Z 源，也不用改本队的 RTL。它读取结果文件，不负责替你写电路或运行仿真。

## 一、拿到本队工程后，怎么用？

1. 保留整个 `three_qzs_open` 文件夹，不要只拿走这个说明文件。
2. 打开 `skill` 文件夹，双击 **`run_check.bat`**。
3. 等待窗口显示结果。详细中文报告在 **`skill/results/check_result.txt`**，用记事本打开就能看。

需要 Python 3.9 或以上，不需要安装额外 Python 库。入口会查找电脑上的 Python；如果找不到，会提示安装 Python。

本队工程的输入路径已经配好。第一次使用不需要编辑配置，也不需要打开 Vivado。

## 二、结果怎么看？

本工程现有结果的检查示例：

```text
仿真结果文件：17/17 组通过检查
实现报告：2/2 套通过检查

通过 | 实现配置 main
  建立裕量 WNS=1.058 ns；保持裕量 WHS=0.118 ns
  LUT=829，FF=367，RAMB36=0，RAMB18=0
  时钟=100.0 MHz
```

| 看到什么 | 意思是什么 | 接下来做什么 |
|---|---|---|
| 某测试“通过” | 结果文件记录 PASS，错误数明确为 0 | 保留对应测试和日志 |
| 某测试“失败” | 缺文件、测试未完成、记录失败或错误数不为 0 | 按报告列出的文件和原因排查 |
| WNS 或 WHS 为负 | 建立或保持时序未通过 | 回 Vivado 看对应关键路径 |
| LUT、FF 等数字 | 顶层实现使用的资源数 | 与本项目预算和优化前数据比较 |
| TIMING-18、no_output_delay | 输入/输出延时约束有缺项 | 核对真实接口要求，不能直接认定外部时序通过 |
| LUTAR-1 | 有 LUT 驱动异步复位的提示 | 检查复位结构及其使用条件 |

**检查通过表示“这些保存的文件符合检查条件”。它没有重新仿真，也不能证明实物已经正常运行。**

## 三、其他队伍换成自己的工程，怎么用？

### 1. 先准备自己的结果

仿真应由真实自检测试生成一个文本结果，例如：

```text
RESULT=PASS
ERRORS=0
```

这两行要由实际测试结果决定，不能手填 PASS。出现错误应记录 RESULT=FAIL 和实际错误数；没跑完不能沿用上次 PASS。现有 testbench 不输出这种格式时，需要先增加结果记录。

在 Vivado 完成实现后，生成这两份文本报告。以下命令在你的工程打开后，在 Tcl Console 执行，文件生成到 Vivado 当前工作目录下的 build/reports：

```tcl
open_run impl_1
file mkdir build/reports
report_timing_summary -delay_type min_max -report_unconstrained -file build/reports/timing.rpt
report_utilization -hierarchical -file build/reports/utilization.rpt
```

确认 impl_1 已完成布局布线，报告头显示 `Design State : Routed`。把文件放到自己工程中，并在下一步配置里填写实际相对路径。

### 2. 复制工具，填写一份配置

把整个 `skill` 文件夹复制到**自己工程的根目录里面**。将 `configs/my_project.example.json` 复制一份，命名为 **`my_project.json`**，用记事本修改：

| 配置项 | 填什么 | 示例 |
|---|---|---|
| tests 中 name | 自己看得懂的测试名称 | controller |
| tests 中 path | 测试结果文件位置 | sim/results/controller/result.txt |
| implementations 中 name | 这套实现的名称 | default |
| top | RTL 顶层模块名 | controller_top |
| timing | 时序报告位置 | build/reports/timing.rpt |
| utilization | 层级资源报告位置 | build/reports/utilization.rpt |
| clock | 报告 Clock Summary 里的时钟名 | sys_clk |
| period_ns | 时钟周期，单位 ns | 50 MHz 填 20.0；100 MHz 填 10.0 |
| max_resources | 可选资源上限；没有要求就保留 {} | {} |

文件路径从**你的工程根目录**起算，使用 `/`。多个测试或实现可以在对应数组中增加条目。不要照抄本队的 17 组测试名。

### 3. 双击运行

再双击 `run_check.bat`。只要存在 `configs/my_project.json`，就自动使用你的配置；否则才用本队示例配置。打开 `results/check_result.txt` 查看中文结果。

Linux/macOS 或喜欢命令行的使用者，在自己的工程根目录运行：

```text
python skill/scripts/run_check.py
```

所以：**本队工程可以直接运行；其他工程需要先准备上述结果、改配置。它不是不作任何适配就能检查所有工程的万能工具。**

## 四、为什么做这个工具？已经验证到什么程度？

整理本队工程时发现：旧清单有 5 项与实际文件不符；目录里同时保存了早期时序失败报告和最终通过报告；内部时序通过后仍有外部延时约束缺项。由此提炼出这个方法：把要检查的结果逐项列清楚，再用脚本核对状态、报告顶层、实现阶段、时钟和指标，同时保留告警。

脚本已实际核对本队 17 组保存结果与两套最终实现报告。12 个验证案例检查了缺文件、伪 PASS、错误数、错时钟、错顶层、超资源和历史负时序等情况；提供 Windows 快捷入口与中文报告。测试依据见 [验证记录](validation/validation_summary.md)，详细来源见 [经验来源](references/evidence_and_origin.md)。

## 五、什么时候不能直接用？

- 只有 RTL，没有实际仿真结果和实现报告：需要先运行自己的工程。
- 不是 Vivado 文本报告，或报告表格格式不同：需要修改解析脚本。本包实际验证过的是 Vivado 2025.2 的格式。
- 仿真结果格式不同：先让自检测试生成明确状态和错误数。
- 想检查功率电路、驱动兼容性、完整 DRC/CDC 或实板波形：这些超出这个工具的范围。
- 报告来自旧 RTL 或另一套参数：工具能检查文件内容，不能证明报告确实由当前代码产生，仍需版本冻结与从零复现。

需要进一步学习时，再看 [排错清单](references/troubleshooting.md)、[验证设计方法](references/verification_contract.md)和[给大模型的提问模板](references/prompt_workflow.md)。这些是辅助资料，第一次使用不用先读完；提问模板也不代替真实历史对话。
