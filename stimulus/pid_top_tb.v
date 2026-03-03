// -----------------------------------------------------------------------------
// pid_top_tb.v
// PID Controller ASIC Testbench (匹配全循环指令逻辑)
// -----------------------------------------------------------------------------
`timescale 1ns/1ps

module pid_top_tb();

  // =========================================================================
  // Parameters (完全匹配你的PID指令ROM路径)
  // =========================================================================
  parameter ROM_FILE = "D:/DLS/LIBEROPRO/cacl_angel/stimulus/pid.mem";
  parameter EXT_NUM_ITERS = 19982;
  parameter W = 24;
  parameter FRAC = 14;
  parameter NR = 32;
  parameter ADDRW = 5;

  // =========================================================================
  // DUT Signals (复用原有定义)
  // =========================================================================
  reg              clk;
  reg              rst_n;
  reg              START;
  reg  [W-1:0]     DATA_IN;
  reg  [ADDRW-1:0] DIR;
  reg              WRITE;
  wire             READY;
  wire [W-1:0]     DATA_OUT;
  reg              rom_we;
  reg  [7:0]       rom_waddr;
  reg  [15:0]      rom_wdata;
  reg  [7:0]       loop_addr;

  // Test data arrays (适配PID全循环逻辑)
  real ext_meas [0:EXT_NUM_ITERS-1];        // 测量值（每次循环读取）
  reg  [15:0]  ext_meas_int16 [0:EXT_NUM_ITERS-1]; // 16位整型测量值
  real ext_setpoint [0:EXT_NUM_ITERS-1];    // 期望值（每次循环读取）
  // ASIC输出数组
  real asic_output [0:EXT_NUM_ITERS-1];     // PID输出控制量(DB[8])
  reg  [23:0]  output_int16;
  reg  [15:0]  asic_output_int16 [0:EXT_NUM_ITERS-1];

  // PID核心参数（每次循环都会重新加载到DB[0-2]）
  real Kp = 0.04;    // 比例系数（1:1核心）
  real Ki = 0.01;   // 积分系数
  real Kd = 0;    // 微分系数

  // =========================================================================
  // DUT Instantiation (PID模块)
  // =========================================================================
`ifdef POST_SYN
  kf_top dut (
`else
  kf_top #(
    .W(W), .FRAC(FRAC), .NR(NR), .ADDRW(ADDRW), .ROM_FILE(ROM_FILE)
  ) dut (
`endif
    .clk(clk), .rst_n(rst_n), .START(START), .DATA_IN(DATA_IN),
    .DIR(DIR), .WRITE(WRITE), .READY(READY), .DATA_OUT(DATA_OUT),
    .rom_we(rom_we), .rom_waddr(rom_waddr), .rom_wdata(rom_wdata),
    .loop_addr(loop_addr)
  );

  // =========================================================================
  // Clock Generation (100 MHz)
  // =========================================================================
  initial clk = 0;
  always #5 clk = ~clk;

  // =========================================================================
  // Helper Functions (定标数转换)
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

  function real sm_to_real;
    input [W-1:0] sm;
    real val;
    begin
      val = $itor(sm[W-2:0]) / (1 << FRAC);
      sm_to_real = sm[W-1] ? -val : val;
    end
  endfunction

  // =========================================================================
  // Extended PID Test - 完全匹配全循环指令逻辑
  // =========================================================================
  task test_ext_pid;
    integer iter, cycle_count, fd;
    integer scan_ret;
    real pid_output, error;
    real sum_err_sq, sum_output_sq;
    real y;
    begin
      // 3. 初始化PID（仅启动，参数在循环中逐周期加载）
      loop_addr = 8'd2;  // LOOP指令跳回PC=0（匹配你的指令PC=25: 0030）
      rst_n = 1;
      START = 1; @(posedge clk); START = 0; // 启动ASIC

      // 初始化统计变量
      sum_err_sq = 0.0;
      sum_output_sq = 0.0;
      y = 0; // 初始测量值（可根据需要调整）

      DATA_IN = real_to_sm(0.0);               @(posedge clk); // PC0: Load DB[0]=Kp
      DATA_IN = real_to_sm(0.0);               @(posedge clk); // PC1: Load DB[1]=Ki
      // 4. 运行迭代（匹配PID全循环逻辑：每次迭代=1次PC0-25循环）
      for (iter = 0; iter < EXT_NUM_ITERS; iter = iter + 1) begin
        cycle_count = 0;
        // 逐周期加载PID参数（匹配指令PC0-4的Load逻辑）
        DATA_IN = real_to_sm(Kp);               @(posedge clk); // PC0: Load DB[0]=Kp
        DATA_IN = real_to_sm(Ki);               @(posedge clk); // PC1: Load DB[1]=Ki
        DATA_IN = real_to_sm(Kd);               @(posedge clk); // PC2: Load DB[2]=Kd
        DATA_IN = real_to_sm(15.5);             @(posedge clk); // PC3: Load DB[3]=期望值
        DATA_IN = real_to_sm(y);                @(posedge clk); // PC4: Load DB[4]=测量值
        DATA_IN = 0; // 后续周期无输入

        // 等待本次PID循环完成（PC到达25: LOOP指令）
        begin : pid_loop_wait
          forever begin
            @(posedge clk);
            // 循环结束标志：PC=25（你的LOOP指令位置）
            if (dut.Sequencer.pc == 8'd27) begin
              disable pid_loop_wait;
            end
            // 超时保护
            if (cycle_count > 300) begin 
              $display("WARNING: Timeout at iter %0d", iter);
              disable pid_loop_wait;
            end
          end
        end

        // 读取本次循环的PID输出和误差（匹配你的内存布局）
        pid_output = sm_to_real(dut.Memory_Registers.Data_Bank_inst.mem[8]); // DB[8]=控制量
        y=4*pid_output+5;
        error      = sm_to_real(dut.Memory_Registers.Data_Bank_inst.mem[5]);  // DB[5]=当前误差
        output_int16 = dut.Memory_Registers.Data_Bank_inst.mem[8];
        

        // 打印关键迭代结果
 
         $display("%4d | %8.6f ",iter + 1,pid_output);
      end

     
    end
  endtask

  // =========================================================================
  // Main Test (主流程)
  // =========================================================================
  initial begin
    $display("================================================================");
    $display("PID Controller ASIC Testbench (匹配全循环指令逻辑)");
    $display("指令循环: PC0(Load)→PC25(LOOP)→PC0 (无限循环)");
    $display("================================================================");

    // 初始化信号
    rst_n = 0; START = 0; DATA_IN = 0; DIR = 0; WRITE = 0;
    rom_we = 0; rom_waddr = 0; rom_wdata = 0; loop_addr = 0;

    // 复位
    repeat(3) @(posedge clk);
    rst_n = 1;
    repeat(2) @(posedge clk);

    // 运行PID扩展测试（匹配全循环逻辑）
    test_ext_pid;

    $display("\n================================================================");
    $display("PID测试完成 (全循环逻辑匹配)");
    $display("================================================================\n");
    $finish;
  end

  // 超时看门狗
  initial begin
    #50000000;  // 50ms超时保护
    $display("ERROR: PID测试超时!"); $finish;
  end

endmodule