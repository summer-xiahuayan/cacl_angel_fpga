// -----------------------------------------------------------------------------
// router_a.v
// Router A - Data input multiplexer and address routing (per paper Figure 3)
// -----------------------------------------------------------------------------
// Inputs (from paper):
//   DATA_IN  - External 24-bit data input
//   result   - AU result (from SR register)
//   READY    - System ready status
//   DIR      - External 5-bit address (directly from external interface)
//   ctl_a    - Address A from sequencer (5 bits)
//   ctl_b    - Address B from sequencer (5 bits)
//
// Outputs to Data Bank (per paper Figure 3):
//   data     - Data to write to Data Bank
//   dira     - Address for port A (read/write)
//   dirb     - Address for port B (read only)
//   write    - Write enable to Data Bank
// -----------------------------------------------------------------------------
`timescale 1ns/1ps

module router_a
#(parameter W=24, parameter ADDRW=5)
(
  // Inputs per paper's naming
  input  [W-1:0]      DATA_IN,     // External data input
  input  [W-1:0]      result,      // AU result (from SR)
  input  [ADDRW-1:0]  ctl_a,       // Address A from sequencer
  input  [ADDRW-1:0]  ctl_b,       // Address B from sequencer
  input  [ADDRW-1:0]  DIR,         // External address input
  input               WRITE,       // External write request
  input               READY,       // System ready status

  // Control signals (accent, not explicitly shown in paper but needed)
  input  [1:0]        sel_data,    // 0=DATA_IN, 1=result, 2=ZERO, 3=FFFFFF
  input               sel_dira,    // 0=ctl_a, 1=DIR
  input               sel_dirb,    // 0=ctl_b, 1=DIR
  input  [1:0]        sel_write,   // Write enable control

  // Outputs to Data Bank (per paper Figure 3 naming)
  output reg [W-1:0]      data,    // Data to Data Bank
  output     [ADDRW-1:0]  dira,    // Address A to Data Bank
  output     [ADDRW-1:0]  dirb,    // Address B to Data Bank
  output reg              write    // Write enable to Data Bank
);

  // Data mux: selects data source for writing to Data Bank
  always @* begin
    case (sel_data)
      2'd0:    data = DATA_IN;       // External data input
      2'd1:    data = result;        // AU result
      2'd2:    data = {W{1'b0}};     // Zero (constant)
      default: data = {W{1'b1}};     // All ones (constant FFFFFF)
    endcase
  end

  // Address muxes
 assign dira = sel_dira ? DIR : ctl_a;
 assign dirb = sel_dirb ? DIR : ctl_b;
//assign dira = ctl_a;
//assign dirb = ctl_b;


  // Write-enable mux / gating
  always @* begin
    case (sel_write)
      2'd0:    write = WRITE;            // Direct write control
      2'd1:    write = WRITE & READY;    // Write only when READY
      2'd2:    write = 1'b0;             // Disabled
      default: write = 1'b1;             // Always enabled
    endcase
  end

endmodule
