// -----------------------------------------------------------------------------
// kf_angel_app_tb.v
// 卡尔曼滤波应用模块（kf_angel_app）的专用测试模块
// 功能：
//  1. 加载测试数据（measurements.txt/truth.txt）
//  2. 驱动kf_angel_app模块，模拟真实数据输入
//  3. 验证滤波输出，计算误差并输出结果
// -----------------------------------------------------------------------------
`timescale 1ns/1ps

module kf_angel_app_tb();

  // =========================================================================
  // 参数配置（和应用模块保持一致）
  // =========================================================================
  parameter W          = 24;
  parameter FRAC       = 14;
  parameter NR         = 32;
  parameter ADDRW      = 5;
  parameter ROM_FILE   = "D:/DLS/LIBEROPRO/acc_filter/stimulus/kf_2d.mem";
  parameter TEST_ITERS = 5000;  // 测试迭代次数（可修改）

  // =========================================================================
  // 测试信号定义
  // =========================================================================
  // 时钟/复位
  reg              clk;
  reg              rst_n;
  // 模块输入
  reg  [W-1:0]     meas_in;      // 模拟测量值输入
  // 模块输出
  wire [W-1:0]     kf_pos_out;   // 滤波后位置
  wire [W-1:0]     kf_vel_out;   // 滤波后速度
  wire             data_out_valid;// 输出有效标志

  // 内部测试变量
  real ext_meas [0:TEST_ITERS-1];  // 加载的测量值（实数）
  real ext_truth [0:TEST_ITERS-1]; // 加载的真实值（实数）
  real asic_pos  [0:TEST_ITERS-1]; // 模块输出位置（实数）
  real asic_vel  [0:TEST_ITERS-1]; // 模块输出速度（实数）
  integer iter;
  integer fd;
  integer cycle_count;

  // =========================================================================
  // 实例化被测模块（kf_angel_app）
  // =========================================================================
  kf_angel_app #(
    .W(W),
    .FRAC(FRAC),
    .NR(NR),
    .ADDRW(ADDRW),
    .ROM_FILE(ROM_FILE)
  ) u_kf_angel_app (
    .clk(clk),
    .rst_n(rst_n),
    .meas_in(meas_in),
    .kf_pos_out(kf_pos_out),
    .kf_vel_out(kf_vel_out),
    .data_out_valid(data_out_valid)
  );

  // =========================================================================
  // 时钟生成（100MHz，周期5ns）
  // =========================================================================
  initial begin
    clk = 1'b0;
    forever #5 clk = ~clk;
  end

  // =========================================================================
  // 固定点?实数转换函数（核心工具）
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
  // 子任务1：加载测试数据（measurements.txt / truth.txt）
  // =========================================================================
  task load_test_data;
    integer fd_meas, fd_truth;
    integer scan_ret;
    begin
      // 加载测量值
      fd_meas = $fopen("D:/DLS/LIBEROPRO/acc_filter/stimulus/measurements.txt", "r");
      if (fd_meas == 0) begin
        $display("ERROR: 无法打开 measurements.txt！");
        $finish;
      end
      for (iter = 0; iter < TEST_ITERS; iter = iter + 1) begin
        scan_ret = $fscanf(fd_meas, "%f", ext_meas[iter]);
      end
      $fclose(fd_meas);

      // 加载真实值
      fd_truth = $fopen("D:/DLS/LIBEROPRO/acc_filter/stimulus/kf_expected.txt", "r");
      if (fd_truth == 0) begin
        $display("ERROR: 无法打开 truth.txt！");
        $finish;
      end
      for (iter = 0; iter < TEST_ITERS; iter = iter + 1) begin
        scan_ret = $fscanf(fd_truth, "%f %f", ext_truth[iter],asic_vel[iter]);
      end
      $fclose(fd_truth);

      $display("成功加载 %0d 组测试数据！", TEST_ITERS);
    end
  endtask

  // =========================================================================
  // 子任务2：打印测试结果（误差统计）
  // =========================================================================
  task print_test_result;
    real sum_raw_err, sum_kf_err;
    real raw_mse, kf_mse;
    begin
      sum_raw_err = 0.0;
      sum_kf_err  = 0.0;

      // 计算均方误差（MSE）
      for (iter = 0; iter < TEST_ITERS; iter = iter + 1) begin
        sum_raw_err = sum_raw_err + (ext_meas[iter] - ext_truth[iter])**2;
        sum_kf_err  = sum_kf_err  + (asic_pos[iter] - ext_truth[iter])**2;
      end
      raw_mse = sum_raw_err / TEST_ITERS;
      kf_mse  = sum_kf_err  / TEST_ITERS;

      // 打印统计结果
      $display("\n==================== 测试结果统计 ====================");
      $display("原始测量值 MSE：%.6f", raw_mse);
      $display("滤波后位置 MSE：%.6f", kf_mse);
      $display("噪声抑制率：%.1f%%", (1.0 - kf_mse/raw_mse)*100.0);
      $display("最后一次迭代结果：");
      $display("  滤波位置：%.6f | 真实位置：%.6f | 误差：%.6f",
               asic_pos[TEST_ITERS-1], ext_truth[TEST_ITERS-1],
               abs(asic_pos[TEST_ITERS-1]-ext_truth[TEST_ITERS-1]));
      $display("  滤波速度：%.6f", asic_vel[TEST_ITERS-1]);
    end
  endtask

  // =========================================================================
  // 子任务3：导出结果到文件（便于绘图分析）
  // =========================================================================
  task export_result_to_file;
    begin
      fd = $fopen("D:/DLS/LIBEROPRO/acc_filter/stimulus/kf_app_test_result.txt", "w");
      if (fd == 0) begin
        $display("WARNING: 无法导出测试结果文件！");
      //  return;
      end

      // 写入表头
      $fwrite(fd, "Iter, Measured, Truth, KF_Pos, KF_Vel, Pos_Err\n");
      // 写入所有迭代结果
      for (iter = 0; iter < TEST_ITERS; iter = iter + 1) begin
        $fwrite(fd, "%d,%.6f,%.6f,%.6f,%.6f,%.6f\n",
                iter+1, ext_meas[iter], ext_truth[iter],
                asic_pos[iter], asic_vel[iter],
                abs(asic_pos[iter]-ext_truth[iter]));
      end
      $fclose(fd);

      $display("\n测试结果已导出到：kf_app_test_result.txt");
    end
  endtask

  // =========================================================================
  // 辅助函数：绝对值计算
  // =========================================================================
  function real abs;
    input real x;
    begin
      abs = (x < 0) ? -x : x;
    end
  endfunction
 // =========================================================================
  // 测试主流程
  // =========================================================================
  initial begin
    // --------------------------
    // 1. 初始化
    // --------------------------
    $display("================================================================");
    $display("开始测试 kf_angel_app 模块 - 迭代次数：%0d", TEST_ITERS);
    $display("================================================================");

    // 复位信号初始化
    rst_n    = 1'b0;
    meas_in  = {W{1'b0}};
    cycle_count = 0;

    // 加载测试数据（从文件读取）
    load_test_data();

    // --------------------------
    // 2. 复位释放
    // --------------------------
    repeat(5) @(posedge clk);  // 复位至少5个时钟
    rst_n = 1'b1;
    $display("\n[阶段1] 复位释放，模块进入初始化阶段...");

    // --------------------------
    // 3. 等待模块初始化完成（前21个时钟）
    // --------------------------
    meas_in = real_to_sm(ext_meas[0]);
    repeat(21) @(posedge clk);
    $display("[阶段2] 模块初始化完成，开始输入测量数据...");

    // --------------------------
    // 4. 循环输入测量值，采集输出
    // --------------------------
    $display("\nIter |  输入测量值  |  PYTHON值  |  滤波位置  |  位置误差  |  滤波速度");
    $display("-----|--------------|----------|------------|------------|----------");

    for (iter = 0; iter < TEST_ITERS; iter = iter + 1) begin
      // 输入当前测量值
      meas_in = real_to_sm(ext_meas[iter+1]);
      
      // 等待输出有效（最多300个时钟超时保护）
      cycle_count = 0;
      begin : wait_valid
        forever begin
          @(posedge clk);
          cycle_count = cycle_count + 1;
          
          // 输出有效，采集数据
          if (data_out_valid) begin
            asic_pos[iter] = sm_to_real(kf_pos_out);
            asic_vel[iter] = sm_to_real(kf_vel_out);
            
            // 打印关键迭代结果（前10/后10/每50次）
            if (iter < 10 || iter >= TEST_ITERS-10 || (iter % 50 == 49)) begin
              $display("%4d |  %9.4f  | %8.4f |  %8.4f |  %8.6f | %8.4f",
                       iter+1, ext_meas[iter], ext_truth[iter],
                       asic_pos[iter], abs(asic_pos[iter]-ext_truth[iter]),
                       asic_vel[iter]);
            end
            disable wait_valid;
          end
          
          // 超时保护
          if (cycle_count > 300) begin
            $display("WARNING: 迭代%0d超时！", iter);
            disable wait_valid;
          end
        end
      end
    end

    // --------------------------
    // 5. 测试结果统计与导出
    // --------------------------
    print_test_result();
    export_result_to_file();

    // --------------------------
    // 6. 测试结束
    // --------------------------
    $display("\n================================================================");
    $display("kf_angel_app 模块测试完成！");
    $display("================================================================");
    $finish;
  end

  // =========================================================================
  // 超时看门狗（防止死循环）
  // =========================================================================
  initial begin
    #(50_000_000);  // 50ms超时
    $display("ERROR: 测试超时！");
    $finish;
  end

endmodule