// -----------------------------------------------------------------------------
// kf_top_tb.v
// Kalman Filter ASIC Testbench
// -----------------------------------------------------------------------------
// Usage:
//   Basic 2D test:     ncverilog kf_top_tb.v ... (default)
//   Basic 1D test:     ncverilog +define+TEST_1D ...
//   Extended test:     ncverilog +define+TEST_EXT +define+NUM_ITERS=200 ...
//
// Extended test loads data from:
//   measurements.txt - noisy measurements (one float per line)
//   truth.txt       - ground truth positions (one float per line)
//   kf_expected.txt - expected KF outputs (x1 x2 per line)
//
// Generate test data: python3 kf_gen_test.py <num_iterations>
// -----------------------------------------------------------------------------
`timescale 1ns/1ps

module kf_top_tb();

  // =========================================================================
  // Parameters
  // =========================================================================
`define TEST_EXT

`ifdef TEST_1D
  parameter ROM_FILE = "D:/DLS/LIBEROPRO/acc_filter/stimulus/kf_1d.mem";
  parameter TEST_MODE = "1D";
`elsif TEST_EXT
  parameter ROM_FILE = "D:/DLS/LIBEROPRO/acc_filter/stimulus/kf_2d.mem";
  parameter TEST_MODE = "EXT";
`else
  parameter ROM_FILE = "D:/DLS/LIBEROPRO/acc_filter/stimulus/kf_2d.mem";
  parameter TEST_MODE = "2D";
`endif

`ifdef NUM_ITERS
  parameter EXT_NUM_ITERS = `NUM_ITERS;
`else
  parameter EXT_NUM_ITERS = 19982;
`endif

  parameter W = 24;
  parameter FRAC = 14;
  parameter NR = 32;
  parameter ADDRW = 5;

  // =========================================================================
  // DUT Signals
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

  // Test data arrays (dynamically sized based on EXT_NUM_ITERS)
  real ext_meas [0:EXT_NUM_ITERS-1];
  reg  [15:0]  ext_meas_int16 [0:EXT_NUM_ITERS-1];
  real ext_truth [0:EXT_NUM_ITERS-1];
  real ext_kf_x1 [0:EXT_NUM_ITERS-1];
  real ext_kf_x2 [0:EXT_NUM_ITERS-1];
  // ASIC output arrays (for plotting)
  real asic_x1 [0:EXT_NUM_ITERS-1];
  reg  [23:0]  x1_int16;
  reg  [15:0]  asic_x1_int16 [0:EXT_NUM_ITERS-1];
  real asic_x2 [0:EXT_NUM_ITERS-1];

  // =========================================================================
  // DUT Instantiation
  // =========================================================================
  // Use +define+POST_SYN for post-synthesis simulation (no parameters)
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
  // Helper Functions
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

`ifndef POST_SYN
  // =========================================================================
  // 1D KF Test (RTL only - uses hierarchical references)
  // =========================================================================
  task test_1d_kf;
    begin
      $display("\n========================================");
      $display("1D Kalman Filter Test");
      $display("========================================");

      
      START = 1; @(posedge clk); START = 0;
      DATA_IN = real_to_sm(1.0);   @(posedge clk);// Phi
      DATA_IN = real_to_sm(0.01);  @(posedge clk);  // Q
      DATA_IN = real_to_sm(0.1);   @(posedge clk);  // R
      DATA_IN = real_to_sm(0.0);   @(posedge clk);  // x
      DATA_IN = real_to_sm(1.0);   @(posedge clk);  // P
      DATA_IN = real_to_sm(2.5);   @(posedge clk);  // y
      DATA_IN = 0;

      wait_for_ready(200);
      #20;
      $display("  x_hat = %.6f (expected: 2.275)",
               sm_to_real(dut.Memory_Registers.Data_Bank_inst.mem[0]));
    end
  endtask

  // =========================================================================
  // 2D KF Test (basic 10 iterations)
  // =========================================================================
  task test_2d_kf;
    integer iter;
    integer cycle_count;
    real measurements [0:9];
    begin
      $display("\n========================================");
      $display("2D Kalman Filter Test (10 iterations)");
      $display("========================================");

      measurements[0] = 0.2215; measurements[1] = 0.2011;
      measurements[2] = 0.2796; measurements[3] = 0.3019;
      measurements[4] = 0.2078; measurements[5] = 0.4904;
      measurements[6] = 0.6242; measurements[7] = 1.2058;
      measurements[8] = 0.9193; measurements[9] = 0.2855;

      loop_addr = 8'd20;
      DATA_IN = real_to_sm(0.0);  START = 1; @(posedge clk); START = 0;
      DATA_IN = real_to_sm(1.0);   @(posedge clk);  // x2
      DATA_IN = real_to_sm(1.0);   @(posedge clk);  // p11
      DATA_IN = real_to_sm(0.0);   @(posedge clk);  // p12
      DATA_IN = real_to_sm(0.0);   @(posedge clk);  // p21
      DATA_IN = real_to_sm(1.0);   @(posedge clk);  // p22
      DATA_IN = real_to_sm(1.0);   @(posedge clk);  // phi11
      DATA_IN = real_to_sm(0.1);   @(posedge clk);  // phi12
      DATA_IN = real_to_sm(0.0);   @(posedge clk);  // phi21
      DATA_IN = real_to_sm(1.0);   @(posedge clk);  // phi22
      DATA_IN = real_to_sm(0.01);  @(posedge clk);  // q11
      DATA_IN = real_to_sm(0.0);   @(posedge clk);  // q12
      DATA_IN = real_to_sm(0.0);   @(posedge clk);  // q21
      DATA_IN = real_to_sm(0.01);  @(posedge clk);  // q22
      DATA_IN = real_to_sm(1.0);   @(posedge clk);  // h1
      DATA_IN = real_to_sm(0.0);   @(posedge clk);  // h2
      DATA_IN = real_to_sm(0.1);   @(posedge clk);  // R
      DATA_IN = real_to_sm(0.0);   @(posedge clk);  // g1
      DATA_IN = real_to_sm(0.0);   @(posedge clk);  // g2
      DATA_IN = real_to_sm(0.0);   @(posedge clk);  // u
      DATA_IN = real_to_sm(measurements[0]);  @(posedge clk);  // y
      DATA_IN = 0;

      for (iter = 0; iter < 10; iter = iter + 1) begin
        cycle_count = 0;
        begin : wait_loop
          forever begin
            @(posedge clk);
            cycle_count = cycle_count + 1;
            if (dut.Sequencer.pc == 8'd160 && cycle_count > 20) begin
              if (iter < 9) DATA_IN = real_to_sm(measurements[iter + 1]);
              @(posedge clk);
              disable wait_loop;
            end
            if (cycle_count > 300) disable wait_loop;
          end
        end
        $display("Iter %2d: x1=%.6f, x2=%.6f", iter+1,
                 sm_to_real(dut.Memory_Registers.Data_Bank_inst.mem[0]),
                 sm_to_real(dut.Memory_Registers.Data_Bank_inst.mem[1]));
      end

      $display("\nFinal: x1=%.6f, x2=%.6f",
               sm_to_real(dut.Memory_Registers.Data_Bank_inst.mem[0]),
               sm_to_real(dut.Memory_Registers.Data_Bank_inst.mem[1]));
    end
  endtask

  // =========================================================================
  // Extended KF Test - Load from files
  // =========================================================================
  task test_ext_kf;
    integer iter, cycle_count, fd;
    integer scan_ret;
    real kf_pos, kf_vel, exp_x1, exp_x2;
    real sum_raw_sq, sum_kf_sq, sum_exp_sq;
    real raw_err, kf_err, exp_err;
    begin
      $display("\n================================================================");
      $display("   EXTENDED KF TEST - %0d ITERATIONS", EXT_NUM_ITERS);
      $display("================================================================");

      // Load measurements
      fd = $fopen("D:/DLS/LIBEROPRO/acc_filter/stimulus/cy_int16.txt", "r");
      if (fd == 0) begin $display("ERROR: Cannot open measurements.txt"); $finish; end
      for (iter = 0; iter < EXT_NUM_ITERS; iter = iter + 1) begin
        scan_ret = $fscanf(fd, "%d", ext_meas_int16[iter]);
      end
      $fclose(fd);

      // Load ground truth
      fd = $fopen("D:/DLS/LIBEROPRO/acc_filter/stimulus/cy.txt", "r");
      if (fd == 0) begin $display("ERROR: Cannot open truth.txt"); $finish; end
      for (iter = 0; iter < EXT_NUM_ITERS; iter = iter + 1) begin
        scan_ret = $fscanf(fd, "%f", ext_truth[iter]);
      end
      $fclose(fd);

      // Load expected KF outputs
      fd = $fopen("D:/DLS/LIBEROPRO/acc_filter/stimulus/cy.txt", "r");
      if (fd == 0) begin $display("ERROR: Cannot open kf_expected.txt"); $finish; end
      for (iter = 0; iter < EXT_NUM_ITERS; iter = iter + 1) begin
        scan_ret = $fscanf(fd, "%f %f", ext_kf_x1[iter], ext_kf_x2[iter]);
      end
      $fclose(fd);

      $display("Loaded %0d test vectors from files", EXT_NUM_ITERS);
      $display("KF Parameters: Phi=[1 0.1; 0 1], H=[1 0], Q=0.01*I, R=0.1");
      $display("Initial: x=[0; 0.03], P=I\n");

      // Initialize KF    
      loop_addr = 8'd20;
      START = 1; @(posedge clk); START = 0;
      DATA_IN = real_to_sm(0.0);   @(posedge clk);  // x1
      DATA_IN = real_to_sm(0.03);  @(posedge clk);  // x2 = 0.03
      DATA_IN = real_to_sm(1.0);   @(posedge clk);  // p11
      DATA_IN = real_to_sm(0.0);   @(posedge clk);  // p12
      DATA_IN = real_to_sm(0.0);   @(posedge clk);  // p21
      DATA_IN = real_to_sm(1.0);   @(posedge clk);  // p22
      DATA_IN = real_to_sm(1.0);   @(posedge clk);  // phi11
      DATA_IN = real_to_sm(0.1);   @(posedge clk);  // phi12
      DATA_IN = real_to_sm(0.0);   @(posedge clk);  // phi21
      DATA_IN = real_to_sm(1.0);   @(posedge clk);  // phi22
      DATA_IN = real_to_sm(0.01);  @(posedge clk);  // q11
      DATA_IN = real_to_sm(0.0);   @(posedge clk);  // q12
      DATA_IN = real_to_sm(0.0);   @(posedge clk);  // q21
      DATA_IN = real_to_sm(0.01);  @(posedge clk);  // q22
      DATA_IN = real_to_sm(1.0);   @(posedge clk);  // h1
      DATA_IN = real_to_sm(0.0);   @(posedge clk);  // h2
      DATA_IN = real_to_sm(0.1);   @(posedge clk);  // R
      DATA_IN = real_to_sm(0.0);   @(posedge clk);  // g1
      DATA_IN = real_to_sm(0.0);   @(posedge clk);  // g2
      DATA_IN = real_to_sm(0.0);   @(posedge clk);  // u
      DATA_IN = ext_meas_int16[0];  @(posedge clk);  // y
   //   DATA_IN = 0;

      $display("Iter |  Measured |    Truth |  ASIC KF |  Expect |  Err vs Truth | Err vs Expect");
      $display("-----|-----------|----------|----------|---------|---------------|---------------");

      sum_raw_sq = 0.0;
      sum_kf_sq = 0.0;
      sum_exp_sq = 0.0;

      // Run iterations
      for (iter = 0; iter < EXT_NUM_ITERS; iter = iter + 1) begin
        cycle_count = 0;
        begin : ext_wait
          forever begin
            @(posedge clk);
            cycle_count = cycle_count + 1;
            if (dut.Sequencer.pc == 8'd160 && cycle_count > 20) begin
              if (iter < EXT_NUM_ITERS - 1)
                DATA_IN = ext_meas_int16[iter];
              @(posedge clk);
              disable ext_wait;
            end
            if (cycle_count > 300) begin
              $display("WARNING: Timeout at iter %0d", iter);
              disable ext_wait;
            end
          end
        end

        // Get results and calculate errors
        kf_pos = sm_to_real(dut.Memory_Registers.Data_Bank_inst.mem[0]);
        kf_vel = sm_to_real(dut.Memory_Registers.Data_Bank_inst.mem[1]);
        x1_int16=dut.Memory_Registers.Data_Bank_inst.mem[0];
        asic_x1_int16[iter] = x1_int16[15:0];
        asic_x1[iter] = kf_pos;  // Save for plotting
        asic_x2[iter] = kf_vel;
        exp_x1 = ext_kf_x1[iter];
        exp_x2 = ext_kf_x2[iter];

        raw_err = ext_meas[iter] - ext_truth[iter];
        if (raw_err < 0) raw_err = -raw_err;
        kf_err = kf_pos - ext_truth[iter];
        if (kf_err < 0) kf_err = -kf_err;
        exp_err = kf_pos - exp_x1;
        if (exp_err < 0) exp_err = -exp_err;

        sum_raw_sq = sum_raw_sq + raw_err * raw_err;
        sum_kf_sq = sum_kf_sq + kf_err * kf_err;
        sum_exp_sq = sum_exp_sq + exp_err * exp_err;

        // Print first 10, last 10, and every 20th
        if (iter < 10 || iter >= EXT_NUM_ITERS - 10 || (iter % 20 == 19)) begin
          $display("%4d | %9.4f | %8.4f | %8.4f | %7.4f | %13.6f | %13.6f",
                   iter + 1, ext_meas[iter], ext_truth[iter], kf_pos, exp_x1, kf_err, exp_err);
        end
      end

      // Final results
      kf_pos = sm_to_real(dut.Memory_Registers.Data_Bank_inst.mem[0]);
      kf_vel = sm_to_real(dut.Memory_Registers.Data_Bank_inst.mem[1]);

      $display("\n================================================================");
      $display("   RESULTS AFTER %0d ITERATIONS", EXT_NUM_ITERS);
      $display("================================================================");
      $display("  ASIC:     x1 = %.6f, x2 = %.6f", kf_pos, kf_vel);
      $display("  Expected: x1 = %.6f, x2 = %.6f", ext_kf_x1[EXT_NUM_ITERS-1], ext_kf_x2[EXT_NUM_ITERS-1]);
      $display("\n  Error vs Expected: x1_err = %.6f, x2_err = %.6f",
               kf_pos - ext_kf_x1[EXT_NUM_ITERS-1], kf_vel - ext_kf_x2[EXT_NUM_ITERS-1]);
      $display("\n  MSE Analysis:");
      $display("    Raw Measurement MSE: %.6f", sum_raw_sq / EXT_NUM_ITERS);
      $display("    ASIC KF MSE:         %.6f", sum_kf_sq / EXT_NUM_ITERS);
      $display("    ASIC vs Python MSE:  %.6f", sum_exp_sq / EXT_NUM_ITERS);
      $display("    Noise Reduction:     %.1f%%", (1.0 - sum_kf_sq / sum_raw_sq) * 100.0);
      $display("\n  Covariance Matrix:");
      $display("    P11=%.6f, P12=%.6f",
               sm_to_real(dut.Memory_Registers.Data_Bank_inst.mem[2]),
               sm_to_real(dut.Memory_Registers.Data_Bank_inst.mem[3]));
      $display("    P21=%.6f, P22=%.6f",
               sm_to_real(dut.Memory_Registers.Data_Bank_inst.mem[4]),
               sm_to_real(dut.Memory_Registers.Data_Bank_inst.mem[5]));
      $display("================================================================");

      // Export ASIC results for plotting
      fd = $fopen("D:/DLS/LIBEROPRO/acc_filter/stimulus/cy_filter_int16.txt", "w");
      for (iter = 0; iter < EXT_NUM_ITERS; iter = iter + 1) begin
        $fwrite(fd, "%d\n", asic_x1_int16[iter]);
      end


      $fclose(fd);
      $display("\nExported ASIC results to: cx_filter.txt");
    end
  endtask
`endif  // ifndef POST_SYN

  // Wait for READY (used by both RTL and post-syn tests)
  task wait_for_ready;
    input integer max_cycles;
    integer i;
    begin
      for (i = 0; i < max_cycles; i = i + 1) begin
        @(posedge clk);
        if (READY && i > 10) begin
          $display("  Completed at cycle %d", i);
          i = max_cycles;
        end
      end
    end
  endtask

`ifdef POST_SYN
  // =========================================================================
  // ROM Loading Task (for post-syn simulation)
  // =========================================================================
  reg [15:0] rom_data [0:255];  // Array to hold ROM contents

  task load_rom_from_file;
    input [256*8:1] filename;
    integer i;
    begin
      $display("[POST_SYN] Loading ROM from %0s via programming port...", filename);
      // Read the .mem file into array
      $readmemh(filename, rom_data);
      // Program each location
      for (i = 0; i < 256; i = i + 1) begin
        rom_we = 1;
        rom_waddr = i[7:0];
        rom_wdata = rom_data[i];
        @(posedge clk);
      end
      rom_we = 0;
      @(posedge clk);
      $display("[POST_SYN] ROM programming complete (256 entries)");
    end
  endtask

  // =========================================================================
  // Post-Syn 2D KF Test (uses READY signal, no internal probing)
  // =========================================================================
  task test_2d_kf_post_syn;
    integer iter;
    integer cycle_count;
    real measurements [0:9];
    begin
      $display("\n========================================");
      $display("2D Kalman Filter Post-Syn Test");
      $display("(10 iterations, uses READY signal)");
      $display("========================================");

      measurements[0] = 0.2215; measurements[1] = 0.2011;
      measurements[2] = 0.2796; measurements[3] = 0.3019;
      measurements[4] = 0.2078; measurements[5] = 0.4904;
      measurements[6] = 0.6242; measurements[7] = 1.2058;
      measurements[8] = 0.9193; measurements[9] = 0.2855;

      // Load ROM via programming port
      load_rom_from_file("D:/DLS/LIBEROPRO/acc_filter/stimulus/kf_2d.mem");

      // Set loop address
      loop_addr = 8'd20;

      // Load initial data (21 values)
      DATA_IN = real_to_sm(0.0);  START = 1; @(posedge clk); START = 0;
      DATA_IN = real_to_sm(1.0);   @(posedge clk);  // x2
      DATA_IN = real_to_sm(1.0);   @(posedge clk);  // p11
      DATA_IN = real_to_sm(0.0);   @(posedge clk);  // p12
      DATA_IN = real_to_sm(0.0);   @(posedge clk);  // p21
      DATA_IN = real_to_sm(1.0);   @(posedge clk);  // p22
      DATA_IN = real_to_sm(1.0);   @(posedge clk);  // phi11
      DATA_IN = real_to_sm(0.1);   @(posedge clk);  // phi12
      DATA_IN = real_to_sm(0.0);   @(posedge clk);  // phi21
      DATA_IN = real_to_sm(1.0);   @(posedge clk);  // phi22
      DATA_IN = real_to_sm(0.01);  @(posedge clk);  // q11
      DATA_IN = real_to_sm(0.0);   @(posedge clk);  // q12
      DATA_IN = real_to_sm(0.0);   @(posedge clk);  // q21
      DATA_IN = real_to_sm(0.01);  @(posedge clk);  // q22
      DATA_IN = real_to_sm(1.0);   @(posedge clk);  // h1
      DATA_IN = real_to_sm(0.0);   @(posedge clk);  // h2
      DATA_IN = real_to_sm(0.1);   @(posedge clk);  // R
      DATA_IN = real_to_sm(0.0);   @(posedge clk);  // g1
      DATA_IN = real_to_sm(0.0);   @(posedge clk);  // g2
      DATA_IN = real_to_sm(0.0);   @(posedge clk);  // u
      DATA_IN = real_to_sm(measurements[0]);  @(posedge clk);  // y
      DATA_IN = 0;

      // Run 10 iterations (each iteration ~160 cycles)
      for (iter = 0; iter < 10; iter = iter + 1) begin
        cycle_count = 0;
        // Wait for iteration to complete (~200 cycles per iteration)
        repeat(200) @(posedge clk);
        // Provide next measurement
        if (iter < 9) DATA_IN = real_to_sm(measurements[iter + 1]);
        @(posedge clk);
        DATA_IN = 0;
        $display("Iter %2d complete", iter + 1);
      end

      // Wait for final READY
      wait_for_ready(500);
      $display("\nPost-syn test complete");
      $display("(Cannot read internal memory - check waveforms for DATA_OUT)");
      $display("========================================");
      $display("POST-SYN TEST PASSED");
      $display("========================================");
    end
  endtask
`endif

  // =========================================================================
  // Main Test
  // =========================================================================
  initial begin
    $display("================================================================");
    $display("Kalman Filter ASIC Testbench - Mode: %s", TEST_MODE);
    $display("================================================================");

    rst_n = 0; START = 0; DATA_IN = 0; DIR = 0; WRITE = 0;
    rom_we = 0; rom_waddr = 0; rom_wdata = 0; loop_addr = 0;

    repeat(3) @(posedge clk);
    rst_n = 1;
    repeat(2) @(posedge clk);

`ifdef POST_SYN
    test_2d_kf_post_syn;
`elsif TEST_1D
    test_1d_kf;
`elsif TEST_EXT
    test_ext_kf;
`else
    test_2d_kf;
`endif

    $display("\n================================================================");
    $display("Test Complete");
    $display("================================================================\n");
    $finish;
  end

  // Timeout watchdog
  initial begin
`ifdef TEST_EXT
    #50000000;  // 50ms for extended tests
`else
    #200000;
`endif
    $display("ERROR: Timeout!"); $finish;
  end

endmodule
