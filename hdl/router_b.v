// -----------------------------------------------------------------------------
// router_b.v
// Router B - Operand selection for Arithmetic Unit (per paper Figure 3)
// -----------------------------------------------------------------------------
// Inputs (from paper Figure 3):
//   A     - Data from Data Bank port A
//   B     - Data from Data Bank port B
//   RQ    - Temporary register Q (accumulator)
//   RD    - Temporary register D (accumulator)
//
// Outputs to AU (per paper Figure 3):
//   R     - First operand to AU (Adder/Sub X input, Multiplier X input)
//   S     - Second operand to AU (Adder/Sub Y input, Multiplier Y input)
//
// Selection options:
//   R can be: A, RQ, 0, or all-1s
//   S can be: B, RD, 0, or all-1s
// -----------------------------------------------------------------------------
`timescale 1ns/1ps

module router_b
#(parameter W=24)
(
  // Inputs from Data Bank (per paper Figure 3 naming)
  input  [W-1:0] A,        // Data Bank port A output
  input  [W-1:0] B,        // Data Bank port B output

  // Inputs from temporary registers (per paper)
  input  [W-1:0] RQ,       // Temp register Q
  input  [W-1:0] RD,       // Temp register D

  // Control signals (select operand sources)
  input  [1:0]   sel_R,    // 00=A, 01=RQ, 10=ZERO, 11=ALL_ONES
  input  [1:0]   sel_S,    // 00=B, 01=RD, 10=ZERO, 11=ALL_ONES

  // Optional modifiers
  input          inv_R,    // 1 = bitwise invert R (default 0)
  input          inv_S,    // 1 = bitwise invert S (default 0)

  // Immediate select (for ALU carry/offset)
  input  [1:0]   sel_I,    // 00=ZERO, 01=+1, 10=-1, 11=ZERO

  // Outputs to AU (per paper Figure 3 naming)
  output [W-1:0] R,        // First operand to AU
  output [W-1:0] S,        // Second operand to AU
  output [W-1:0] I,        // Immediate value

  // Sign bits (useful for AU sign logic)
  output         msb_R,    // MSB of R (sign bit)
  output         msb_S     // MSB of S (sign bit)
);

  // ---- R source mux ----
  reg [W-1:0] R_mux;
  always @* begin
    case (sel_R)
      2'b00:   R_mux = A;             // Data Bank port A
      2'b01:   R_mux = RQ;            // Temp register Q
      2'b10:   R_mux = {W{1'b0}};     // Zero
      default: R_mux = {W{1'b1}};     // All ones (FFFFFF)
    endcase
  end

  // ---- S source mux ----
  reg [W-1:0] S_mux;
  always @* begin
    case (sel_S)
      2'b00:   S_mux = B;             // Data Bank port B
      2'b01:   S_mux = RD;            // Temp register D
      2'b10:   S_mux = {W{1'b0}};     // Zero
      default: S_mux = {W{1'b1}};     // All ones (FFFFFF)
    endcase
  end

  // ---- Optional inversion (bitwise) ----
  assign R = inv_R ? ~R_mux : R_mux;
  assign S = inv_S ? ~S_mux : S_mux;

  // ---- Immediate word ----
  reg [W-1:0] I_reg;
  always @* begin
    case (sel_I)
      2'b00:   I_reg = {W{1'b0}};              // 0
      2'b01:   I_reg = {{(W-1){1'b0}}, 1'b1};  // +1
      2'b10:   I_reg = {W{1'b1}};              // -1 (all ones)
      default: I_reg = {W{1'b0}};              // 0
    endcase
  end
  assign I = I_reg;

  // ---- Sign bits to AU ----
  assign msb_R = R[W-1];
  assign msb_S = S[W-1];

endmodule
