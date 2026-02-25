// -----------------------------------------------------------------------------
// kf_top.v
// Kalman Filter ASIC Top-Level (per paper Figure 3)
// -----------------------------------------------------------------------------
// Integrates all components per paper's architecture:
//   Sequencer   - PC + ROM (256x16) + instruction decode
//   Router A    - Data input mux and address routing
//   Data Bank   - NR x 24-bit register file + RQ/RD accumulators
//   Router B    - Operand selection for AU
//   AU          - Arithmetic Unit (Adder/Sub, Multiplier, Mult. Inverse)
//
// External Interface (per paper Figure 3):
//   DATA_IN     - 24-bit external data input
//   DATA_OUT    - 24-bit output (AU result)
//   DIR         - 5-bit external address
//   WRITE       - External write control
//   READY       - System ready status
//   START       - Start execution
//   RESET       - System reset (active low in this implementation)
// -----------------------------------------------------------------------------
`timescale 1ns/1ps

module kf_angel_top
#(
  parameter W=24,
  parameter FRAC=14,
  parameter NR=32,
  parameter ADDRW=5,
  parameter ROM_FILE = ""     // Path to instruction .mem file (empty = use programming port)
)(
  input              clk,
  input              rst_n,          // Active-low reset (paper uses active-high RESET)

  // External interface (per paper Figure 3)
  input              START,          // Start execution
  input  [W-1:0]     DATA_IN,        // External data input
  input  [ADDRW-1:0] DIR,            // External address input
  input              WRITE,          // External write request
  output             READY,          // System ready status
  output [W-1:0]     DATA_OUT,       // Output (AU result)
  output             data_out_valid,
  // ROM programming interface (for backward compatibility / debug)
  input              rom_we,
  input  [7:0]       rom_waddr,
  input  [15:0]      rom_wdata,

  // Loop control (for continuous KF operation)
  input  [7:0]       loop_addr     // Address for LOOP instruction (default: 0)
);

  // ========== Forward declarations ==========
  wire au_done;               // AU done signal (for DIV only)
  wire [W-1:0] au_result;     // AU registered result (for DIV)
  wire [W-1:0] au_result_comb; // AU combinational result (for ADD/SUB/MUL)
  wire au_result_comb_valid;  // High when combinational result is valid

  // ========== Sequencer ==========
  // Instruction format per paper: "a4 a3 a2 a1 a0 b4 b3 b2 b1 b0 c1 c0 d1 d0 e f"
  wire [4:0]  ctl_a;      // Field A [15:11]: Address A - 5 bits
  wire [4:0]  ctl_b;      // Field B [10:6]:  Address B - 5 bits
  wire [1:0]  ctl_c;      // Field C [5:4]:   PC control
  wire [1:0]  ctl_d;      // Field D [3:2]:   AU operation
  wire        ctl_e;      // Field E [1]:     AU start
  wire        ctl_f;      // Field F [0]:     Write enable

  sequencer #(.ROM_FILE(ROM_FILE)) Sequencer (
    .clk        (clk),
    .rst_n      (rst_n),
    .start      (START),
    .continue_i (au_done),     // AU done signal (forward declared)
    .loop_addr  (loop_addr),   // Jump target for LOOP instruction
    .ready      (READY),
    .ctl_a      (ctl_a),
    .ctl_b      (ctl_b),
    .ctl_c      (ctl_c),
    .ctl_d      (ctl_d),
    .ctl_e      (ctl_e),
    .ctl_f      (ctl_f),
    .rom_we     (rom_we),
    .rom_waddr  (rom_waddr),
    .rom_wdata  (rom_wdata),
    .pc_dbg     ()
  );

  // ========== Result Selection Logic ==========
  // Three sources for write data:
  // 1. DATA_IN: External data input (when no AU operation)
  // 2. au_result_comb: Combinational result for ADD/SUB/MUL (same cycle)
  // 3. au_result: Registered result for DIV (after done=1)
  //
  // Single-cycle ops (ADD/SUB/MUL):
  //   - Instruction has e=1 (start), f=1 (write), c=00 (increment)
  //   - au_result_comb_valid=1 in same cycle
  //   - Write au_result_comb to Data Bank on posedge
  //
  // Multi-cycle ops (DIV):
  //   - Instruction has e=1 (start), f=0 (no write), c=01 (wait)
  //   - Wait for au_done=1 (24 cycles later)
  //   - Then store with f=1 using au_result

  // Track DIV result for store instruction
  reg div_result_valid;
  always @(posedge clk or negedge rst_n) begin
    if (!rst_n) begin
      div_result_valid <= 1'b0;
    end else if (au_done) begin
      div_result_valid <= 1'b1;      // DIV completed, result is valid
    end else if (ctl_f && div_result_valid) begin
      div_result_valid <= 1'b0;      // Result consumed by write
    end
  end

  // Latch combinational result for 2-instruction pattern (e=1,f=0 then e=0,f=1)
  // This allows the compute result to persist for the following store instruction
  reg [W-1:0] comb_result_lat;
  reg         comb_result_valid;
  always @(posedge clk or negedge rst_n) begin
    if (!rst_n) begin
      comb_result_lat <= {W{1'b0}};
      comb_result_valid <= 1'b0;
    end else if (au_result_comb_valid && !ctl_f) begin
      // Latch result when e=1 (compute) but f=0 (no immediate write)
      comb_result_lat <= au_result_comb;
      comb_result_valid <= 1'b1;
    end else if (ctl_f && comb_result_valid) begin
      // Result consumed by write
      comb_result_valid <= 1'b0;
    end
  end

  // Select result source:
  // - au_result_comb when combinational result is valid AND immediate write (e=1,f=1)
  // - comb_result_lat when deferred write (e=0,f=1 after e=1,f=0)
  // - au_result when DIV result is ready (au_done or div_result_valid)
  wire use_comb_result = au_result_comb_valid;
  wire use_latched_comb = comb_result_valid;
  wire use_div_result = au_done || div_result_valid;
  wire [W-1:0] au_result_mux = use_comb_result  ? au_result_comb :
                               use_latched_comb ? comb_result_lat :
                               use_div_result   ? au_result : {W{1'b0}};


                 

  // ========== Router A ==========
  // Connects: DATA_IN, AU result -> Data Bank
  wire [W-1:0]     ra_data;       // Data to Data Bank
  wire [ADDRW-1:0] ra_dira;       // Address A to Data Bank
  wire [ADDRW-1:0] ra_dirb;       // Address B to Data Bank
  wire             ra_write;      // Write enable to Data Bank

  // Data source selection:
  // - 01 = AU result (combinational, latched, or registered)
  // - 00 = DATA_IN (external input)
  wire [1:0] sel_data = (use_comb_result || use_latched_comb || use_div_result) ? 2'b01 : 2'b00;

  // External vs Sequencer control (per architecture diagram):
  // When READY=1, system is idle and accepts external DIR/WRITE commands
  // When READY=0, sequencer is running and uses ctl_a/ctl_b/ctl_f
  wire use_external = READY;      // Use external DIR when system is ready/idle

  // Mux write signal: external WRITE when READY, sequencer ctl_f when running
  wire write_mux = use_external ? WRITE : ctl_f;

  router_a #(.W(W), .ADDRW(ADDRW)) Router_A (
    // Inputs
    .DATA_IN    (DATA_IN),
    .result     (au_result_mux),  // Muxed: combinational for ADD/SUB/MUL, registered for DIV
    .ctl_a      (ctl_a),
    .ctl_b      (ctl_b),
    .DIR        (DIR),
    .WRITE      (write_mux),      // Muxed: external WRITE when READY, ctl_f when running
    .READY      (READY),
    // Control
    .sel_data   (sel_data),
    .sel_dira   (use_external),   // Use external DIR when READY, ctl_a when running
    .sel_dirb   (1'b0),           // Use ctl_b (port B is read-only, sequencer controlled)
    .sel_write  (2'b00),          // Direct write control (pass through WRITE)
    // Outputs to Data Bank
    .data       (ra_data),
    .dira       (ra_dira),
    .dirb       (ra_dirb),
    .write      (ra_write)
  );

  // ========== Memory Registers (Data Bank + RQ + RD) ==========
  wire [W-1:0] db_A, db_B;        // Data Bank outputs (to Router B)
  wire [W-1:0] RQ_out, RD_out;    // RQ/RD outputs (to Router B)

  mem_reg #(.W(W), .NR(NR), .ADDRW(ADDRW), .FORWARD(1)) Memory_Registers (
    .clk    (clk),
    // Data Bank interface (per paper naming)
    .write  (ra_write),
    .dira   (ra_dira),
    .dirb   (ra_dirb),
    .data   (ra_data),
    .A      (db_A),
    .B      (db_B),
    // RQ/RD interface (disabled for now - paper doesn't specify encoding)
    .rq_we  (1'b0),
    .rq_d   (db_A),
    .RQ     (RQ_out),
    .rd_we  (1'b0),
    .rd_d   (db_A),
    .RD     (RD_out)
  );

  // ========== Router B ==========
  // Connects: Data Bank outputs, RQ, RD -> AU operands R, S
  wire [W-1:0] R_bus, S_bus, I_bus;

  // Operand selection - default to Data Bank outputs
  // (Paper doesn't specify encoding for RQ/RD selection)
  wire [1:0] sel_R = 2'b00;       // 00 = A (Data Bank port A)
  wire [1:0] sel_S = 2'b00;       // 00 = B (Data Bank port B)

  router_b #(.W(W)) Router_B (
    // Inputs from Data Bank
    .A      (db_A),
    .B      (db_B),
    // Inputs from accumulators
    .RQ     (RQ_out),
    .RD     (RD_out),
    // Control
    .sel_R  (sel_R),
    .sel_S  (sel_S),
    .inv_R  (1'b0),
    .inv_S  (1'b0),
    .sel_I  (2'b00),
    // Outputs to AU
    .R      (R_bus),
    .S      (S_bus),
    .I      (I_bus),
    .msb_R  (),
    .msb_S  ()
  );

  // ========== Arithmetic Unit ==========
  wire au_busy;

  au #(.W(W), .FRAC(FRAC)) AU (
    .clk    (clk),
    .rst_n  (rst_n),
    .start  (ctl_e),              // AU start from Field E
    // Operands from Router B
    .R      (R_bus),
    .S      (S_bus),
    .I      (I_bus),
    // Control from sequencer
    .ctl_d  (ctl_d),
    // Combinational outputs (for single-cycle ADD/SUB/MUL)
    .result_comb       (au_result_comb),
    .result_comb_valid (au_result_comb_valid),
    // Registered outputs (for multi-cycle DIV)
    .result (au_result),
    .done   (au_done),
    .busy   (au_busy)
  );

  //outputctr
  wire [15:0] PC;
  assign PC={ctl_a,ctl_b,ctl_c,ctl_d,ctl_e,ctl_f};
  
  assign data_out_valid=(PC==16'h0001);
  // ========== Output ==========
  assign DATA_OUT = au_result_mux;

endmodule
