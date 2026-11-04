# 板级工程与接线

| 文件/目录 | 用途 |
|---|---|
| project_main/cascade_qzs.xpr | D=0.2 主工程，综合顶层 cascade_qzs_board_top |
| project_d0/cascade_qzs.xpr | D=0 对照工程，综合顶层 cascade_qzs_d0_board_top |
| [vivado_guide.md](vivado_guide.md) | 当前目录对应的打开、仿真和实现步骤 |
| [pin_connections.csv](pin_connections.csv) | 12 路逻辑命令的板卡引脚与连接器对应 |
| bitstream/cascade_qzs_d020.bit、.hwh | 原工程保存的主配置位流与硬件描述 |
| ps_initialization/main、d0 | 已有 PS 初始化文件 |

将整个仓库放到英文短路径，先运行根目录 prepare_project.bat 创建主工程和对照工程，再打开表中的 XPR。

PL 时钟来自 PS。运行逻辑使用 100 MHz FCLK 与板级复位链，相关初始化文件位于 ps_initialization。

已有的逻辑端、驱动端、功率端分层测试条件见 [hardware_test_conditions.md](hardware_test_conditions.md)。
