`timescale 1ns/1ns
module cordic_angle_calc_kf_tb ();

// ===================== 基础信号 =====================
reg           clk;
reg           rst;
reg  signed [15:0] cx_in;
reg  signed [15:0] cy_in;

// 模块输出
wire signed [16:0] theta_1st_quad;  // 第一象限角度（定点）
wire [1:0]         quadrant;        // 象限编号
wire               angle_valid;     // 新增：输出有效标志

// 文件操作
integer cx_file, cy_file, out_file, true_angle_file;
integer read_cnt;
reg     file_end;

// 误差统计
parameter EXT_NUM_ITERS = 19982;
real error [0:EXT_NUM_ITERS-1];
real error_sum=0.0;

// ===================== 实例化模块 =====================
cordic_angle_calc_kf u_angle_calc_kf (
    .clk            (clk),
    .rst            (rst),
    .cx_in          (cx_in),
    .cy_in          (cy_in),
    .theta_1st_quad (theta_1st_quad),
    .quadrant       (quadrant),
    .angle_valid    (angle_valid)
);

// ===================== 时钟生成 =====================
initial begin
    clk = 0;
    forever #5 clk = ~clk;  // 100MHz（周期10ns）
end

// ===================== 角度转换与打印任务 =====================
real theta_1st_rad ;
real theta_1st_deg;
real true_angle;
real real_theta_rad;
real real_theta_deg;

// 打印结果任务（仅处理有效数据）
task print_result;
    input integer cnt;
    input signed [15:0] cx;
    input signed [15:0] cy;
    input [1:0] q;
    input signed [16:0] theta_1st;
    input real true_angle;
    real error_deg;
    begin
        // 第一象限角度转浮点（核心转换公式）
        theta_1st_rad = $itor(theta_1st) / 32768.0;
        theta_1st_deg = theta_1st_rad * 180.0 / 3.1415926535;

        // 根据象限计算真实角度
        case (q)
            0: begin  // 第一象限：直接用
                real_theta_rad = theta_1st_rad;
                real_theta_deg = theta_1st_deg;
            end
            1: begin  // 第二象限：π/2 + 第一象限角度
                real_theta_rad = 3.1415926535/2 + theta_1st_rad;
                real_theta_deg = 90.0 + theta_1st_deg;
            end
            2: begin  // 第三象限：π + 第一象限角度
                real_theta_rad = 3.1415926535 + theta_1st_rad;
                real_theta_deg = 180.0 + theta_1st_deg;
            end
            3: begin  // 第四象限：3π/2 + 第一象限角度
                real_theta_rad = 3.1415926535*3/2 + theta_1st_rad;
                real_theta_deg = 270.0 + theta_1st_deg;
            end
        endcase

        // 误差计算
        error_deg = real_theta_deg - true_angle;
        error[cnt] = error_deg;
        error_sum = error_sum + error_deg;

        // 打印结果
        $display("=====================================");
        $display("数据点%0d | 输出有效：YES", cnt);
        $display("cx=%0d, cy=%0d | 象限%0d", cx, cy, q);
        $display("第一象限角度：%f rad / %f °", theta_1st_rad, theta_1st_deg);
        $display("FPGA(KF)计算角度：%f rad / %f °", real_theta_rad, real_theta_deg);
        $display("MATLAB计算角度：%f °", true_angle);
        $display("误差：%.6f °", error_deg);
        $display("=====================================\n");

        // 写入文件
        if (out_file != 0) begin
            $fwrite(out_file, "%d,%d,%d,%d,%f,%f\n", 
                cnt, cx, cy, q, real_theta_deg, true_angle);
        end
    end
endtask

// ===================== 主测试流程（核心修正：输出有效时更新输入） =====================
initial begin

    
    // 打开文件
    true_angle_file = $fopen("D:/DLS/LIBEROPRO/cacl_angel/stimulus/angle_filter_result.txt", "r");
    cx_file         = $fopen("D:/DLS/LIBEROPRO/cacl_angel/stimulus/cx_int16.txt", "r");
    cy_file         = $fopen("D:/DLS/LIBEROPRO/cacl_angel/stimulus/cy_int16.txt", "r");
    out_file        = $fopen("D:/DLS/LIBEROPRO/cacl_angel/stimulus/angle_result_kf.txt", "w");
    
    // 文件打开检查
    if (cx_file==0 || cy_file==0 || true_angle_file==0) begin
        $display("文件打开失败！");
        $stop;
    end
    // 写入文件头
    if (out_file!=0) begin
        $fwrite(out_file, "数据点,cx,cy,象限,FPGA(KF)计算角度(°),MATLAB计算角度(°)\n");
    end

    // 第一步：读取第一组初始输入
    if (!$feof(cx_file) && !$feof(cy_file) && !$feof(true_angle_file)) begin
        $fscanf(cx_file, "%d", cx_in);
        $fscanf(cy_file, "%d", cy_in);
        $fscanf(true_angle_file, "%f", true_angle);
        read_cnt = read_cnt + 1;
    end else begin
        file_end = 1;
    end



    // 初始化
    rst = 1;
  //  cx_in = 0;
   // cy_in = 0;
    read_cnt = 0;
    file_end = 0;
  //  true_angle = 0;
    repeat(5) @(posedge clk);  // 复位至少5个时钟
    rst = 0;
    // 核心逻辑：循环等待输出有效，有效时打印+更新输入
    while (!file_end) begin
        // 等待angle_valid置位（输出有效）
      //  @(posedge clk iff angle_valid);
        @(posedge clk);
        if (angle_valid) begin
            
        // 输出有效时：打印当前数据结果
        print_result(read_cnt, cx_in, cy_in, quadrant, theta_1st_quad, true_angle);

        // 输出有效时：读取下一组输入数据（更新输入）
        if (!$feof(cx_file) && !$feof(cy_file) && !$feof(true_angle_file)) begin
            $fscanf(cx_file, "%d", cx_in);
            $fscanf(cy_file, "%d", cy_in);
            $fscanf(true_angle_file, "%f", true_angle);
            read_cnt = read_cnt + 1;
        end else begin
            file_end = 1;  // 无数据可读，结束循环
        end
            
        end

    end

    // 测试结束处理
    $display("=====================================");
    $display("KF版本测试完成，共处理%0d个有效数据点", read_cnt-1);  // 减1是因为最后一次读取未打印
    $display("平均误差：%.6f °", error_sum/(read_cnt-1));
    $display("=====================================");
    
    // 关闭文件
    $fclose(cx_file);
    $fclose(cy_file);
    $fclose(true_angle_file);
    $fclose(out_file);
    
    #100 $stop;
end

endmodule