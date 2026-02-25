// -----------------------------------------------------------------------------
// mem_reg.v
// Memory Registers Block (per paper Figure 3)
// -----------------------------------------------------------------------------
// Contains:
//   Data_Bank - NR × 24-bit dual-read, single-write register file
//   RQ        - 24-bit temporary register (accumulator for Q matrix)
//   RD        - 24-bit temporary register (accumulator for D matrix)
//
// Data Bank ports (per paper Figure 3):
//   Inputs:  data (write data), dira (addr A), dirb (addr B), write (WE)
//   Outputs: A (read port A), B (read port B)
//
// Paper Section 4: "the architecture includes registers RQ and RD that are
// used as accumulators for temporary operands"
// -----------------------------------------------------------------------------
`timescale 1ns/1ps

// -----------------------------------------------------------------------------
// RQ Register - 24-bit accumulator with write-enable (no reset per paper)
// -----------------------------------------------------------------------------
module RQ #(parameter W=24) (
  input              clk,
  input              we,
  input  [W-1:0]     d,
  output reg [W-1:0] q
);
  always @(posedge clk)
    if (we) q <= d;
endmodule

// -----------------------------------------------------------------------------
// RD Register - 24-bit accumulator with write-enable (no reset per paper)
// -----------------------------------------------------------------------------
module RD #(parameter W=24) (
  input              clk,
  input              we,
  input  [W-1:0]     d,
  output reg [W-1:0] q
);
  always @(posedge clk)
    if (we) q <= d;
endmodule

// -----------------------------------------------------------------------------
// Data_Bank - NR × 24-bit dual-read, single-write register file
// Per paper: 32 registers for 2-state KF (Equation 10)
// -----------------------------------------------------------------------------
module Data_Bank
#(parameter W=24, parameter NR=32, parameter ADDRW=5, parameter FORWARD=1)
(
  input                  clk,

  // Write port (from Router A)
  input                  write,      // Write enable
  input  [ADDRW-1:0]     dira,       // Write address (shared with read A)
  input  [W-1:0]         data,       // Write data

  // Read port A
  // Address shared with write (dira)
  output reg [W-1:0]     A,          // Read data port A

  // Read port B
  input  [ADDRW-1:0]     dirb,       // Read address B
  output reg [W-1:0]     B           // Read data port B
);

  reg [W-1:0] mem [0:NR-1];

  // Synchronous write
  always @(posedge clk)
    if (write) mem[dira] <= data;

  // Asynchronous read - no forwarding for port A
  // Port A shares address with write port, so forwarding would create
  // circular dependency for single-cycle read-modify-write operations.
  // The correct value is always in mem[] after the previous write.
  always @* begin
    A = mem[dira];
  end

  // Port B can use forwarding since it has a separate address
  always @* begin
    B = mem[dirb];
    if (FORWARD && write && (dirb == dira)) B = data;  // Write-through
  end

endmodule

// -----------------------------------------------------------------------------
// mem_reg - Top wrapper: Data Bank + RQ + RD (per paper Figure 3)
// -----------------------------------------------------------------------------
module mem_reg
#(parameter W=24, parameter NR=32, parameter ADDRW=5, parameter FORWARD=1)
(
  input              clk,

  // Data Bank interface (per paper Figure 3 naming)
  input              write,         // Write enable (from Router A)
  input  [ADDRW-1:0] dira,          // Address A (read/write)
  input  [ADDRW-1:0] dirb,          // Address B (read only)
  input  [W-1:0]     data,          // Write data (from Router A)
  output [W-1:0]     A,             // Read data port A (to Router B)
  output [W-1:0]     B,             // Read data port B (to Router B)

  // RQ register interface
  input              rq_we,         // RQ write enable
  input  [W-1:0]     rq_d,          // RQ write data
  output [W-1:0]     RQ,            // RQ output (to Router B)

  // RD register interface
  input              rd_we,         // RD write enable
  input  [W-1:0]     rd_d,          // RD write data
  output [W-1:0]     RD             // RD output (to Router B)
);

  // Data Bank instance
  Data_Bank #(
    .W(W), .NR(NR), .ADDRW(ADDRW), .FORWARD(FORWARD)
  ) Data_Bank_inst (
    .clk   (clk),
    .write (write),
    .dira  (dira),
    .data  (data),
    .A     (A),
    .dirb  (dirb),
    .B     (B)
  );

  // RQ accumulator register
  RQ #(.W(W)) RQ_inst (
    .clk (clk),
    .we  (rq_we),
    .d   (rq_d),
    .q   (RQ)
  );

  // RD accumulator register
  RD #(.W(W)) RD_inst (
    .clk (clk),
    .we  (rd_we),
    .d   (rd_d),
    .q   (RD)
  );

endmodule
