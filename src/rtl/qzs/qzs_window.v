`timescale 1ns/1ps
// Four labelled MPSPWM intervals per complete carrier cycle. No runtime D input.
module qzs_window #(
    parameter integer ST_D_PPM=0, MIN_ST_CYCLES=20,
    parameter integer REF_MIN=200, REF_MAX=800, EDGE_MARGIN=2
)(  input   wire            clk_sys     ,
    input   wire            rst_n       ,
    input   wire            run_permit  , // 是否允许运行
    input   wire            ref_valid   , // 正弦参考值是否已经准备好
    input   wire    [13:0]  carrier     , 
    input   wire    [9:0]   ref_l       , // 左右参考
    input   wire    [9:0]   ref_r       ,
    
    output  wire            config_ok   , // D、窗口宽度等参数是否合法
    output  wire            reference_ok, // 当前左右参考是否符合范围、相加是否为1000
    output  reg             st_left     , 
    output  reg             st_right    , 
    output  reg     [3:0]   st_vector   , // 对应的四位开关命令
    output  reg             raw_st_left , // 按照当前载波位置，此刻是否应让左臂或右臂直通
    output  reg             raw_st_right
);
    
    
    localparam integer W=ST_D_PPM/400;
    localparam integer STATIC_OK=(ST_D_PPM>=0 && ST_D_PPM<=300000 &&  // 检查D范围 
        MIN_ST_CYCLES>=1 && EDGE_MARGIN>=2 &&  // 最小窗口拍数这个设置至少为1,窗口边界裕量至少为2
        REF_MIN>=0 && REF_MIN<=500 && REF_MAX>=500 && REF_MAX<=1000 && // 0 ≤ 参考下限 ≤ 500  500 ≤ 参考上限 ≤ 1000
        REF_MIN+REF_MAX==1000 &&  // 检查参考范围是否对称
        (ST_D_PPM==0 || (W>=MIN_ST_CYCLES &&
            5*REF_MIN>=W+EDGE_MARGIN && 5*(1000-REF_MAX)>=W+EDGE_MARGIN)));
    // W                 → 实际直通窗口有多宽
    // MIN_ST_CYCLES     → 这个窗口最少要多宽
    // EDGE_MARGIN       → 放好窗口后，离载波峰谷至少留多少余地
    // DEAD_CYCLES       → 普通换向时，两管都关闭的等待拍数
        
    assign config_ok=STATIC_OK;
    assign reference_ok=ref_valid && (ref_l>=REF_MIN) && (ref_l<=REF_MAX) &&
        (ref_r>=REF_MIN) && (ref_r<=REF_MAX) && ({1'b0,ref_l}+{1'b0,ref_r}==11'd1000);
        
    wire [12:0] ql={1'b0,ref_l,2'b00}+{3'b0,ref_l};
    wire [12:0] qr={1'b0,ref_r,2'b00}+{3'b0,ref_r};
    
 // All arithmetic is unsigned 14 bit after static range checks. Invalid
 // configurations are blocked even if elaboration wraps a bound expression.
    localparam [13:0] WIDTH=W;

 // Compare in parallel before selecting the reference sign. For complementary
 // references, ref_l>=500 is exactly ql>=qr. Avoid a serial min/max comparator,
 // mux, offset adder, then interval comparator on the same timing path.
    wire low_l  =(carrier>={1'b0,ql}-WIDTH) && (carrier<{1'b0,ql}); // 载波必须大于或等于“左阈值减窗口宽度”，并且小于左阈值
    wire high_l =(carrier>={1'b0,ql}) && (carrier<{1'b0,ql}+WIDTH);
    wire low_r  =(carrier>={1'b0,qr}-WIDTH) && (carrier<{1'b0,qr});
    wire high_r =(carrier>={1'b0,qr}) && (carrier<{1'b0,qr}+WIDTH);
    
    reg     [3:0]   next_vector; // 对应哪一种四路命令,按 S1、S2、S3、S4 排列
    
    always @(*)
    begin
        raw_st_left =0;
        raw_st_right=0;
        next_vector =0;
        if(run_permit && STATIC_OK && reference_ok && ST_D_PPM!=0)
        begin
            if(ref_l>=500) // 左参考≥500：选 low_r、high_l
            begin
                if(low_r)
                begin 
                    raw_st_right=1;
                    next_vector=4'b1011;
                end
                else if(high_l)
                begin 
                    raw_st_left=1;
                    next_vector=4'b1101;
                end
            end 
            else // 左参考<500：选 low_l、high_r
            begin
                if(low_l)
                begin 
                    raw_st_left=1;
                    next_vector=4'b1110;
                end
                else if(high_r)
                begin 
                    raw_st_right=1;
                    next_vector=4'b0111;
                end
            end
        end
    end
    always @(posedge clk_sys or negedge rst_n)
    begin
        if(!rst_n)
        begin 
            st_left <=0;
            st_right<=0;
            st_vector[3:0]<=0;
        end
        else 
        begin 
            st_left<=raw_st_left;
            st_right<=raw_st_right;
            st_vector[3:0]<=next_vector[3:0];
        end
    end
endmodule
