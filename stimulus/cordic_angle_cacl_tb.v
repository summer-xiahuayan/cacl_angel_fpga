`timescale 1ns/1ns
`include "cordic.v"
module cordic_angle_calc_tb ();

// ===================== 基础信号 =====================
reg           clk;
reg           rst;
reg  signed [15:0] cx_in;
reg  signed [15:0] cy_in;

// 模块输出
wire signed [16:0] theta_1st_quad;  // 第一象限角度（定点）
wire [1:0]         quadrant;        // 象限编号

// 文件操作
integer cx_file, cy_file, out_file,true_angle_file;
integer read_cnt;
reg     file_end;

// 检测角度更新
reg  signed [16:0] theta_1st_prev;
parameter EXT_NUM_ITERS = 19982;
real error [0:EXT_NUM_ITERS-1];
real error_sum=0.0;



// ===================== 实例化模块 =====================
cordic_angle_calc u_angle_calc (
    .clk            (clk),
    .rst            (rst),
    .cx_in          (cx_in),
    .cy_in          (cy_in),
    .theta_1st_quad (theta_1st_quad),
    .quadrant       (quadrant)
);

// ===================== 时钟生成 =====================
initial begin
    clk = 0;
    forever #5 clk = ~clk;  // 100MHz
end
real theta_1st_rad ;
real theta_1st_deg;
real true_angle;

        // 第二步：根据象限计算真实角度（仅浮点阶段处理，极简！）
real real_theta_rad;
real real_theta_deg;
// ===================== 核心：打印结果（仅浮点转换时计算真实角度） =====================
task print_result;
    input integer cnt;
    input signed [15:0] cx;
    input signed [15:0] cy;
    input [1:0] q;
    input signed [16:0] theta_1st;
    input real true_angle;
    real error_deg;
    begin
        // 第一步：第一象限角度转浮点（核心转换公式）
        theta_1st_rad = $itor(theta_1st) / 32768.0;
        theta_1st_deg = theta_1st_rad * 180.0 / 3.1415926535;

        // 第二步：根据象限计算真实角度（仅浮点阶段处理，极简！）      
        case (q)
            0: begin  // 第一象限：直接用
                real_theta_rad = theta_1st_rad;
                real_theta_deg = theta_1st_deg;
            end
            1: begin  // 第二象限：π - 第一象限角度
                real_theta_rad = 3.1415926535/2 + theta_1st_rad;
                real_theta_deg = 180.0/2 + theta_1st_deg;
            end
            2: begin  // 第三象限：-π + 第一象限角度
                real_theta_rad = 3.1415926535 + theta_1st_rad;
                real_theta_deg = 180.0 + theta_1st_deg;
            end
            3: begin  // 第四象限：-第一象限角度
                real_theta_rad = 3.1415926535*3/2+theta_1st_rad;
                real_theta_deg = 180.0*3/2+theta_1st_deg;
            end
        endcase
        error_deg= real_theta_deg-true_angle;
        // 打印结果（简洁明了）
        $display("数据点%0d | cx=%0d, cy=%0d | 象限%0d", cnt, cx, cy, q);
        $display("第一象限角度：%f rad / %f °", theta_1st_rad, theta_1st_deg);
        $display("FPGA计算角度：%f rad / %f °", real_theta_rad, real_theta_deg);
        $display("MATLAB计算角度：%f °", true_angle);
        $display("误差：%.6f °\n", error_deg);
        error[cnt]=error_deg;
        error_sum=error_sum+error_deg;
        if (out_file != 0) begin
         $fwrite(out_file, "%f\n", real_theta_deg);
        end
        // 写入文件（可选）
       // if (out_file != 0) begin
        //    $fwrite(out_file, "%d,%d,%d,%d,%f,%f\n", 
        //        cnt, cx, cy, q, real_theta_deg, true_angle);
       // end
    end
endtask

// ===================== 主流程 =====================
initial begin
    // 初始化
    rst = 1;
    cx_in = 0;
    cy_in = 0;
    read_cnt = 0;
    file_end = 0;
    true_angle = 0;
    theta_1st_prev = 0;
    #20 rst = 0;

    // 打开文件
    true_angle_file=$fopen("D:/DLS/LIBEROPRO/cacl_angel/stimulus/angle_deg_360.txt", "r");
    cx_file  = $fopen("D:/DLS/LIBEROPRO/cacl_angel/stimulus/cx_int16.txt", "r");
    cy_file  = $fopen("D:/DLS/LIBEROPRO/cacl_angel/stimulus/cy_int16.txt", "r");
    out_file = $fopen("D:/DLS/LIBEROPRO/cacl_angel/stimulus/angle_result.txt", "w");
    if (cx_file==0 || cy_file==0||true_angle_file==0) begin $display("文件打开失败！"); $stop; end
   // if (out_file!=0) $fwrite(out_file, "数据点,cx,cy,象限,FPGA计算角度(rad),MATLAB计算角度(°)\n");

    // 逐行读取+检测角度更新
    while (!file_end) begin
        @(posedge clk);
        
        // 读取数据
        if (!$feof(cx_file) && !$feof(cy_file)) begin
            $fscanf(cx_file, "%d", cx_in);
            $fscanf(cy_file, "%d", cy_in);
            read_cnt = read_cnt + 1;
        end else begin
            file_end = 1;
        end

        @(posedge clk);
        @(posedge clk);
        @(posedge clk);
        @(posedge clk);
        @(posedge clk);
        @(posedge clk);
        @(posedge clk);
        @(posedge clk);
        @(posedge clk);
        @(posedge clk);
        $fscanf(true_angle_file, "%f", true_angle);
        print_result(read_cnt, cx_in, cy_in, quadrant, theta_1st_quad,true_angle);
   
    end

    // 结束
    $display("测试完成，共处理%0d个数据点", read_cnt);
    $display("平均误差：%.6f",error_sum/EXT_NUM_ITERS);
    $fclose(cx_file); $fclose(cy_file); $fclose(out_file);
    #100 $stop;
end

endmodule