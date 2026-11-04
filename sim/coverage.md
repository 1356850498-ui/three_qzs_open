# 三单元与继承测试覆盖



| 测试组 | 结果 | 检查数 | 覆盖摘要 |
| --- | --- | --- | --- |
| cascade_main | PASS | 64280717 | 570/546/522周期；148次启动；144中断；3单元错误 |
| cascade_d0 | PASS | 40243646 | 每单元402周期；无直通 |
| cascade_buttons | PASS | 20 | 抖动、长按、跨复位、优先级、3路来源LED |
| cascade_parameters | PASS | 6 | 6种非法配置全部拒绝 |
| qzs | PASS | 170516994 | 单单元相关回归，详见同名result |
| normal_spwm | PASS | 36687682 | 单单元相关回归，详见同名result |
| interlock | PASS | 10947 | 单单元相关回归，详见同名result |
| arbiter | PASS | 262145 | 单单元相关回归，详见同名result |
| parameter | PASS | 40023 | 单单元相关回归，详见同名result |
| qzs_board | PASS | 240041 | 单单元相关回归，详见同名result |
| board | PASS | 240041 | 单单元相关回归，详见同名result |
| core | PASS | 65522879 | 单单元相关回归，详见同名result |
| deadtime | PASS | 3 × 17011 | 单单元相关回归，详见同名result |
| compare | PASS | 20128 | 单单元相关回归，详见同名result |
| reset | PASS | 见原日志 | 单单元相关回归，详见同名result |
| equivalence | PASS | 16780300 | 单单元相关回归，详见同名result |
| trace | PASS | 见原日志 | 单单元相关回归，详见同名result |

主集成连续覆盖40.24 ms以上，超过两个完整50Hz周期。每拍完整12位输出与独立事件/换向等待模型比较；载波、参考索引是被检查量，不作为期望答案。逐周期CSV分别记录三个单元的并集、左右臂时间和四标签窗。

继承回归在新目录实际重新运行：包括窗口参数边界、普通SPWM、受控互锁、仲裁全组合、参考异常、旧D0与H桥逐拍对照、按键和实际proc_sys_reset IP。新级联D0使用同一受控互锁的无ST分支，与旧D0流水延迟不同，不能用旧单单元等价结果冒充新级联逐拍等价。

结果文本和轻量统计位于 sim/results；运行仿真可生成日志、WDB 和完整逐拍 CSV。按键加速测试使用8拍等待，真实100MHz及100拍死区不缩短。没有形式证明、任意SEU覆盖或硬件按键延迟测量。




继承覆盖说明仅作历史参考：reference/legacy_coverage.md。当前有效结论以本次results实际文件为准。

未覆盖：实板PS/加载、门极兼容、真实过流与独立关断、功率回路动态、任意SEU、形式证明、全输入空间不变量。
