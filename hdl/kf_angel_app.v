// -----------------------------------------------------------------------------
// kf_angel_app.v
// 独立卡尔曼滤波应用模块（基于test_ext_kf核心逻辑封装）
// 功能：2D卡尔曼滤波，固化初始化系数，仅对外暴露时钟/复位/输入/输出端口
// 输入：时钟、复位、测量值（24位固定点）
// 输出：滤波后位置/速度（24位固定点）、输出有效标志
// -----------------------------------------------------------------------------
`timescale 1ns/1ps

module kf_angel_app
#(
  // 固定点参数（和原测试模块一致）
  parameter W = 24,
  parameter FRAC = 14,
  parameter NR = 32,
  parameter ADDRW = 5,
  // ROM文件路径（根据实际路径修改）
  parameter ROM_FILE = "D:/DLS/LIBEROPRO/acc_filter/stimulus/kf_2d.mem"
)
(
  input              clk,          // 100MHz时钟
  input              rst_n,        // 低有效复位
  input  [W-1:0]     meas_in,      // 输入测量值（24位固定点，Q(23,14)）
  output reg [W-1:0] kf_pos_out,   // 滤波后位置输出（同格式）
  output reg [W-1:0] kf_vel_out,   // 滤波后速度输出（同格式）
  output reg         data_out_valid// 输出有效标志（高电平表示数据可用）
);

  // =========================================================================
  // 内部信号（对接原DUT接口）
  // =========================================================================
  reg              START;
  reg  [W-1:0]     DATA_IN;
  reg  [ADDRW-1:0] DIR;
  reg              WRITE;
  wire             READY;
  wire [W-1:0]     DATA_OUT;
  wire             data_out_valid_dut; // DUT输出有效
  reg  [7:0]       loop_addr;
  reg              rom_we;
  reg  [7:0]       rom_waddr;
  reg  [15:0]      rom_wdata;

  // 状态控制寄存器（初始化/运行）
  reg [7:0]        init_cont;      // 初始化计数器（0~20）
  reg [15:0]       data_cont;      // 数据输入计数器
  reg              init_done;      // 初始化完成标志

  // =========================================================================
  // DUT实例化（原卡尔曼滤波核心模块）
  // =========================================================================
  kf_angel_top #(
    .W(W), .FRAC(FRAC), .NR(NR), .ADDRW(ADDRW), .ROM_FILE(ROM_FILE)
  ) dut (
    .clk(clk), .rst_n(rst_n), .START(START), .DATA_IN(DATA_IN),
    .DIR(DIR), .WRITE(WRITE), .READY(READY), .DATA_OUT(DATA_OUT),
    .data_out_valid(data_out_valid_dut), .rom_we(rom_we), .rom_waddr(rom_waddr),
    .rom_wdata(rom_wdata), .loop_addr(loop_addr)
  );

  // =========================================================================
  // 固定点转换函数（复用原测试模块）
  // =========================================================================
  function [W-1:0] real_to_sm;
    input real x;
    reg sign;
    integer mag_int;
    begin
      sign = (x < 0.0);
      mag_int = (sign ? -x : x) * (1 << FRAC);
      real_to_sm = {sign, mag_int[W-2:0]};
    end
  endfunction

  // =========================================================================
  // 初始化逻辑（固化系数，无需外部配置）
  // =========================================================================
  always @(posedge clk or negedge rst_n) begin
    if (!rst_n) begin
      // 复位初始化
      START     <= 1'b0;
      DATA_IN   <= {W{1'b0}};
      loop_addr <= 8'd0;
      init_cont <= 8'd0;
      init_done <= 1'b0;
      rom_we    <= 1'b0;
      rom_waddr <= 8'd0;
      rom_wdata <= 16'd0;
      DIR       <= {ADDRW{1'b0}};
      WRITE     <= 1'b0;
    end else if (!init_done) begin
      // 阶段1：启动信号
      if (init_cont == 8'd0) begin
        loop_addr <= 8'd20;       // 固定loop_addr=20（原测试值）
       // DATA_IN   <= real_to_sm(0.0);
        START     <= 1'b1;        // 拉低START
        init_cont <= init_cont + 1'b1;
      end
      // 阶段2：逐时钟加载固化的KF初始化系数（共21个参数）
      else begin
        START <= 1'b0;
        case(init_cont)
          8'd1:  DATA_IN <= real_to_sm(0.0);    // x1 初始位置
          8'd2:  DATA_IN <= real_to_sm(0.03);   // x2 初始速度
          8'd3:  DATA_IN <= real_to_sm(1.0);    // p11
          8'd4:  DATA_IN <= real_to_sm(0.0);    // p12
          8'd5:  DATA_IN <= real_to_sm(0.0);    // p21
          8'd6:  DATA_IN <= real_to_sm(1.0);    // p22
          8'd7:  DATA_IN <= real_to_sm(1.0);    // phi11
          8'd8:  DATA_IN <= real_to_sm(0.1);    // phi12
          8'd9:  DATA_IN <= real_to_sm(0.0);    // phi21
          8'd10: DATA_IN <= real_to_sm(1.0);    // phi22
          8'd11: DATA_IN <= real_to_sm(0.01);   // q11
          8'd12: DATA_IN <= real_to_sm(0.0);    // q12
          8'd13: DATA_IN <= real_to_sm(0.0);    // q21
          8'd14: DATA_IN <= real_to_sm(0.01);   // q22
          8'd15: DATA_IN <= real_to_sm(1.0);    // h1
          8'd16: DATA_IN <= real_to_sm(0.0);    // h2
          8'd17: DATA_IN <= real_to_sm(0.1);    // R
          8'd18: DATA_IN <= real_to_sm(0.0);    // g1
          8'd19: DATA_IN <= real_to_sm(0.0);    // g2
          8'd20: DATA_IN <= real_to_sm(0.0);    // u
          8'd21: begin
            DATA_IN  <= meas_in;   // 第一个测量值（外部输入）
            init_done <= 1'b1;     // 初始化完成，进入运行阶段
          end
          default: DATA_IN <= {W{1'b0}};
        endcase
        if (init_cont <= 8'd20) begin
          init_cont <= init_cont + 1'b1;
        end
      end
    end
  end

  // =========================================================================
  // 运行阶段：数据输入/输出逻辑（按你指定的时序）
  // =========================================================================
  always @(posedge clk or negedge rst_n) begin
    if (!rst_n) begin
      kf_pos_out    <= {W{1'b0}};
      kf_vel_out    <= {W{1'b0}};
      data_out_valid<= 1'b0;
      data_cont     <= 16'd0;
      DATA_IN       <= {W{1'b0}};
    end else if (init_done) begin
      // 初始化完成后，按data_out_valid_dut触发数据更新
      if (data_out_valid_dut) begin
        // 输出滤波后数据
        kf_pos_out    <= DATA_OUT;
        kf_vel_out    <= 'd0;//dut.Memory_Registers.Data_Bank_inst.mem[1]; // 速度从内部存储读取
        data_out_valid<= 1'b1;
        // 输入下一个测量值
        DATA_IN       <= meas_in;
        data_cont     <= data_cont + 1'b1;
      end else begin
        data_out_valid<= 1'b0;
      end
    end
  end

endmodule