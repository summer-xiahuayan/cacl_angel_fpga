// -----------------------------------------------------------------------------
// cordic_angle_calc_kf.v
// 核心时序：滤波有效→送数给CORDIC→计数10个时钟→输出有效标志置位
// 接口：完全对齐原cordic_angle_calc + 新增angle_valid有效标志
// -----------------------------------------------------------------------------
`timescale 1ns/1ps

module cordic_angle_calc_kf
(
  input           clk,            // 100MHz时钟
  input           rst,            // 高有效复位（与原CORDIC模块一致）
  input  signed [15:0] cx_in,     // 原始CX输入（16位有符号）
  input  signed [15:0] cy_in,     // 原始CY输入（16位有符号）
  output signed [16:0] theta_1st_quad,  // 第一象限角度（17位，与原模块一致）
  output [1:0]         quadrant,        // 象限编号（2位，与原模块一致）
  output               angle_valid      // 新增：输出有效标志（CORDIC输入后10个时钟置位）
);

  // ===================== 参数配置 =====================
  localparam KF_W        = 24;        // KF数据位宽（Q23.14）
  localparam KF_FRAC     = 14;        // KF小数位宽（2^14）
  localparam KF_NR       = 32;
  localparam KF_ADDRW    = 5;
  localparam ROM_FILE    = "D:/DLS/LIBEROPRO/acc_filter/stimulus/kf_2d.mem";
  localparam DELAY_CNT   = 10;        // CORDIC输入后延迟输出有效的时钟数

  // ===================== 内部信号定义 =====================
  // 复位适配：原CORDIC高有效复位 → KF低有效复位
  wire rst_n = ~rst;

  // 1. 16位输入 → KF输入（公式：(X*5/32768)*2^14）
  reg signed [31:0] cx_conv_pre;
  reg signed [31:0] cy_conv_pre;
  reg signed [KF_W-1:0] cx_kf_in;
  reg signed [KF_W-1:0] cy_kf_in;

  // 2. KF滤波输出
  wire signed [KF_W-1:0] cx_kf_out;
  wire signed [KF_W-1:0] cy_kf_out;
  wire                   cx_kf_valid;
  wire                   cy_kf_valid;
  wire                   kf_valid;    // CX/CY滤波都有效

  // 3. KF输出→CORDIC输入（公式：32768*(X/2^14)/5）
  reg signed [31:0] cx_conv_tmp1;
  reg signed [31:0] cy_conv_tmp1;
  reg signed [31:0] cx_conv_tmp2;
  reg signed [31:0] cy_conv_tmp2;
  reg signed [31:0] cx_conv_tmp3;
  reg signed [31:0] cy_conv_tmp3;
  reg signed [15:0] cx_cordic_in_r; // 锁存送CORDIC的CX
  reg signed [15:0] cy_cordic_in_r; // 锁存送CORDIC的CY
  reg               cordic_data_load; // CORDIC数据加载标志（滤波有效时置位）

  // 4. 10时钟延迟计数
  reg [3:0]         delay_counter; // 0~9计数
  reg               angle_valid_i; // 有效标志寄存器

  // ===================== 子模块实例化 =====================
  // 子模块1：CX卡尔曼滤波
  kf_angel_app #(
    .W(KF_W), .FRAC(KF_FRAC), .NR(KF_NR), .ADDRW(KF_ADDRW), .ROM_FILE(ROM_FILE)
  ) u_kf_cx (
    .clk(clk),
    .rst_n(rst_n),
    .meas_in(cx_kf_in),
    .kf_pos_out(cx_kf_out),
    .kf_vel_out(),
    .data_out_valid(cx_kf_valid)
  );

  // 子模块2：CY卡尔曼滤波
  kf_angel_app #(
    .W(KF_W), .FRAC(KF_FRAC), .NR(KF_NR), .ADDRW(KF_ADDRW), .ROM_FILE(ROM_FILE)
  ) u_kf_cy (
    .clk(clk),
    .rst_n(rst_n),
    .meas_in(cy_kf_in),
    .kf_pos_out(cy_kf_out),
    .kf_vel_out(),
    .data_out_valid(cy_kf_valid)
  );

  // 子模块3：原CORDIC角度计算（输入为滤波后的数据）
  cordic_angle_calc u_angle_calc (
    .clk(clk),
    .rst(rst),
    .cx_in(cx_cordic_in_r),    // 滤波后CX
    .cy_in(cy_cordic_in_r),    // 滤波后CY
    .theta_1st_quad(theta_1st_quad),
    .quadrant(quadrant)
  );

  // ===================== 阶段1：16位→24位转换（送KF） =====================
  always @(posedge clk or posedge rst) begin
    if (rst) begin
      cx_conv_pre <= 32'd0;
      cy_conv_pre <= 32'd0;
      cx_kf_in <= {KF_W{1'b0}};
      cy_kf_in <= {KF_W{1'b0}};
    end else begin
      // 公式：(X*5/32768)*2^14 = (X*5) >> 1（硬件简化）
     // cx_conv_pre <= {{8{cx_in[15]}},cx_in};
     // cy_conv_pre <= {{8{cy_in[15]}},cy_in};
     // cx_kf_in <= {{3{cx_in[15]}},cx_in[15:0],{5{1'b0}}};//$signed({{16{cx_in[15]}}, cx_in}) * 32'd5;
      //cy_kf_in <= {{3{cy_in[15]}},cy_in[15:0],{5{1'b0}}};//$signed(cy_conv_pre >>> 1);

      cx_kf_in <= {{8{cx_in[15]}},cx_in[15:0]};
      cy_kf_in <= {{8{cy_in[15]}},cy_in[15:0]};
    end
  end

  // ===================== 阶段2：滤波有效合并 =====================
  assign kf_valid = cx_kf_valid & cy_kf_valid;

  // ===================== 阶段3：滤波有效时锁存数据到CORDIC =====================
  always @(posedge clk or posedge rst) begin
    if (rst) begin
      cx_conv_tmp1 <= 32'd0;
      cy_conv_tmp1 <= 32'd0;
      cx_conv_tmp2 <= 32'd0;
      cy_conv_tmp2 <= 32'd0;
      cx_conv_tmp3 <= 32'd0;
      cy_conv_tmp3 <= 32'd0;
      cx_cordic_in_r <= 16'd0;
      cy_cordic_in_r <= 16'd0;
      cordic_data_load <= 1'b0;
    end else if (kf_valid) begin
      // 步骤1：X/2^14 → 算术右移14位
     // cx_conv_tmp1 <= cx_kf_out>>5;
     // cy_conv_tmp1 <= cy_kf_out>>5;
      // 步骤2：×32768 → 左移15位（32768=2^15）
  //    cx_conv_tmp2 <= cx_kf_out*2;//cx_conv_tmp1 << 15;
     // cy_conv_tmp2 <= cy_kf_out*2;//cy_conv_tmp1 << 15;
      // 步骤3：÷5 → 乘逆元（209715/1048576≈1/5）+ 右移20位
    //  cx_conv_tmp3 <= cx_conv_tmp2>>>2;
   //   cy_conv_tmp3 <= cy_conv_tmp2>>>2;
      // 步骤4：锁存转换后的数据到CORDIC输入寄存器
      cx_cordic_in_r <= cx_kf_out[15:0];
      cy_cordic_in_r <= cy_kf_out[15:0];
      // 置位CORDIC数据加载标志（触发后续10时钟计数）
      cordic_data_load <= 1'b1;
    end else begin
      // 非滤波有效时，数据加载标志置0
      cordic_data_load <= 1'b0;
    end
  end

  // ===================== 阶段4：CORDIC数据加载后计数10个时钟 → 输出有效 =====================
  always @(posedge clk or posedge rst) begin
    if (rst) begin
      delay_counter <= 4'd0;
      angle_valid_i <= 1'b0;
    end else begin
      if (cordic_data_load) begin
        // 数据刚加载到CORDIC，重置计数器并开始计数
        delay_counter <= 4'd1;  // 第1个时钟（加载时钟为第0个）
        angle_valid_i <= 1'b0;
      end else if (delay_counter > 0 && delay_counter < DELAY_CNT) begin
        // 计数器递增（1→9）
        delay_counter <= delay_counter + 1'b1;
        angle_valid_i <= 1'b0;
      end else if (delay_counter == DELAY_CNT) begin
        // 计数到10个时钟，置位有效标志
        delay_counter <= 4'd0;   // 重置计数器
        angle_valid_i <= 1'b1;
      end else begin
        // 无数据加载且计数完成，有效标志置0
        angle_valid_i <= 1'b0;
      end
    end
  end

  // ===================== 输出赋值 =====================
  assign angle_valid = angle_valid_i;

endmodule