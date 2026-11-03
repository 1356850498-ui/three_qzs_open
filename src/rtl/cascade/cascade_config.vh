// 全工程参数入口。单位：Hz、100 MHz时钟拍、ppm。D0对照由独立顶层固定选择。
`ifndef CASCADE_CONFIG_VH
`define CASCADE_CONFIG_VH
`define QZS_CLOCK_HZ 100_000_000    // FPGA 控制逻辑的时钟频率：100 MHz
`define QZS_CARRIER_TICKS 10000     // 一个完整三角载波周期包含 10000 拍，即 100 μs，载波频率为 10 kHz
`define QZS_TABLE_LEN 200           // 一个完整正弦周期用 200 个采样点表示。每个载波周期推进一点，因此正弦频率为 50 Hz
`define QZS_MAIN_D_PPM 100000       // 主工程的直通占空比 D=0.2
`define QZS_DEAD_TICKS 100          // 普通上下管换向时的死区时间：100 拍
`define QZS_REF_MIN 200             // 正弦参考值的下限，用于检查参考是否合法
`define QZS_REF_MAX 800             // 正弦参考值的上限，用于检查参考是否合法
`define QZS_DELAY_U1 0              // 单元 1 的载波延迟：0 μs，0°
`define QZS_DELAY_U2 1667           // 单元 2 的载波延迟：16.67 μs，约 60°
`define QZS_DELAY_U3 3333           // 单元 3 的载波延迟：33.33 μs，约 120°
`define QZS_BUTTON_TICKS 2_000_000  // 按键去抖及故障释放稳定等待的时间：20 ms，用于过滤按键接触时的抖动
`endif
