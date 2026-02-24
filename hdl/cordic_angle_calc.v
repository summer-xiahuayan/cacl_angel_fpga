`timescale 1ns/1ns
// 顶层模块：cx/cy归一化 + 全象限映射到第一象限 + 输出象限编号
module cordic_angle_calc (
    input           clk,            // 系统时钟
    input           rst,            // 复位（高有效）
    // 输入：16位有符号cx/cy原始数据
    input  signed [15:0] cx_in,     // 对应MATLAB的cx_data
    input  signed [15:0] cy_in,     // 对应MATLAB的cy_data
    // 输出：第一象限角度 + 象限编号
    output signed [16:0] theta_1st_quad, // CORDIC输出的第一象限角度（0~π/2）
    output reg [1:0]     quadrant        // 象限编号（1=第一，2=第二，3=第三，4=第四）
);

// ===================== 第一步：参数定义 =====================
// MATLAB归一化参数
localparam signed [15:0] CX_DC        = 16'd17685;    // cx直流分量
localparam signed [15:0] CY_DC        = 16'd16800;    // cy直流分量
localparam signed [15:0] CX_NORM_COEFF= 16'd4990;     // cx归一化系数
localparam signed [15:0] CY_NORM_COEFF= 16'd5255;     // cy归一化系数
localparam DIV_SHIFT      = 10;                       // 除2^10 = 右移10位

// ===================== 第二步：归一化计算（保留原有逻辑） =====================
reg signed [15:0] cx_minus_dc;
reg signed [15:0] cy_minus_dc;
always @(posedge clk or posedge rst) begin
    if (rst) begin
        cx_minus_dc <= 16'sd0;
        cy_minus_dc <= 16'sd0;
    end else begin
        cx_minus_dc <= cx_in - CX_DC;
        cy_minus_dc <= cy_in - CY_DC;
    end
end

reg signed [31:0] cx_mul_coeff;
reg signed [31:0] cy_mul_coeff;
always @(posedge clk or posedge rst) begin
    if (rst) begin
        cx_mul_coeff <= 32'sd0;
        cy_mul_coeff <= 32'sd0;
    end else begin
        cx_mul_coeff <= cx_minus_dc * CX_NORM_COEFF;
        cy_mul_coeff <= cy_minus_dc * CY_NORM_COEFF;
    end
end

reg signed [16:0] cx_norm;
reg signed [16:0] cy_norm;
always @(posedge clk or posedge rst) begin
    if (rst) begin
        cx_norm <= 17'sd0;
        cy_norm <= 17'sd0;
    end else begin
        cx_norm <= {cx_mul_coeff[31], cx_mul_coeff[25:10]} ;
        cy_norm <= {cy_mul_coeff[31], cy_mul_coeff[25:10]} ;
    end
end

// ===================== 第三步：正确的象限判断 + 粗旋转（映射到第一象限） =====================
reg [1:0] quadrant_comb;          // 组合逻辑判断象限
reg signed [16:0] cx_mapped;     // 映射到第一象限的cx
reg signed [16:0] cy_mapped;     // 映射到第一象限的cy

// 组合逻辑：象限判断 + 粗旋转（无延迟）
always @(*) begin
    // 默认值（避免综合器报警）
    quadrant_comb = 2'd1;
    cx_mapped = 17'sd0;
    cy_mapped = 17'sd0;

    // 严格按象限规则判断 + 标准粗旋转（映射到第一象限）
    if (cx_norm >= 0 && cy_norm >= 0) begin
        // 第一象限：无需旋转，直接使用原坐标
        quadrant_comb = 2'd0;
        cx_mapped = cx_norm;
        cy_mapped = cy_norm;
    end else if (cx_norm < 0 && cy_norm >= 0) begin
        // 第二象限：逆时针转90° → (x,y) = (y, -x)
        quadrant_comb = 2'd1;
        cx_mapped = cy_norm;
        cy_mapped = -cx_norm;
    end else if (cx_norm < 0 && cy_norm < 0) begin
        // 第三象限：逆时针转180° → (x,y) = (-x, -y)
        quadrant_comb = 2'd2;
        cx_mapped = -cx_norm;
        cy_mapped = -cy_norm;
    end else if (cx_norm >= 0 && cy_norm < 0) begin
        // 第四象限：逆时针转270° → (x,y) = (-y, x)
        quadrant_comb = 2'd3;
        cx_mapped = -cy_norm;
        cy_mapped = cx_norm;
    end

    // 防除0：若映射后cx=0，强制设为1（避免CORDIC迭代异常）
    if (cx_mapped == 17'sd0) begin
        cx_mapped = 17'sd1;
    end
end

// 打拍同步：组合逻辑结果寄存器化（优化时序）
reg [1:0] quadrant_reg;
reg signed [16:0] cx_mapped_reg;
reg signed [16:0] cy_mapped_reg;
always @(posedge clk or posedge rst) begin
    if (rst) begin
        quadrant <= 2'd0;
        cx_mapped_reg <= 17'sd0;
        cy_mapped_reg <= 17'sd0;
    end else begin
        quadrant <= quadrant_comb;
        cx_mapped_reg <= cx_mapped;
        cy_mapped_reg <= cy_mapped;
    end
end

// ===================== 第四步：实例化CORDIC（仅输出第一象限角度） =====================
cordic u_cordic (
    .clk      (clk),
    .rst      (rst),
    .x_i      (cx_mapped_reg),    // 映射到第一象限的cx
    .y_i      (cy_mapped_reg),    // 映射到第一象限的cy
    .theta_i  (17'sd0),           // VECTOR模式固定为0
    .x_o      (),                 // 悬空
    .y_o      (),                 // 悬空
    .theta_o  (theta_1st_quad)    // 输出第一象限角度（0~π/2）
);


endmodule