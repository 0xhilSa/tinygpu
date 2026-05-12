// =============================================================================
// TinyGPU - ALU (Arithmetic Logic Unit)
// =============================================================================
// Supports: ADD, SUB, MUL, DIV, AND, OR, XOR, NOT, SHL, SHR, NAND, NOR, XNOR
// 32-bit operands, 32-bit result
// Flags: Zero, Negative, Overflow, Carry
// =============================================================================

`timescale 1ns / 1ps

module alu(
  input  wire [31:0] operand_a,     // First operand
  input  wire [31:0] operand_b,     // Second operand
  input  wire [3:0]  alu_op,        // Operation select
  output reg  [31:0] result,        // ALU result
  output wire        flag_zero,     // Result == 0
  output wire        flag_neg,      // Result is negative (MSB set)
  output reg         flag_overflow, // Signed overflow
  output reg         flag_carry     // Carry/borrow out
);

  // -------------------------------------------------------------------------
  // ALU Operation Codes
  // -------------------------------------------------------------------------
  localparam ADD = 4'b0000;  // Addition
  localparam SUB = 4'b0001;  // Subtraction
  localparam MUL = 4'b0010;  // Multiplication (lower 32 bits)
  localparam DIV = 4'b0011;  // Division (quotient)
  localparam AND = 4'b0100;  // Bitwise AND
  localparam OR = 4'b0101;  // Bitwise OR
  localparam XOR = 4'b0110;  // Bitwise XOR
  localparam NOT = 4'b0111;  // Bitwise NOT (operand_a)
  localparam SHL = 4'b1000;  // Logical shift left
  localparam SHR = 4'b1001;  // Logical shift right
  localparam NAND = 4'b1010;  // Bitwise NAND
  localparam NOR = 4'b1011;  // Bitwise NOR
  localparam XNOR = 4'b1100;  // Bitwise XNOR
  localparam MOD = 4'b1101;  // Modulo (remainder)
  localparam SAR = 4'b1110;  // Arithmetic shift right (sign-extend)
  localparam PASS = 4'b1111;  // Pass operand_a through

  // -------------------------------------------------------------------------
  // Internal signals
  // -------------------------------------------------------------------------
  wire [32:0] add_result;   // 33-bit for carry detection
  wire [32:0] sub_result;   // 33-bit for borrow detection
  wire [63:0] mul_result;   // 64-bit full multiply
  wire [31:0] div_quotient;
  wire [31:0] div_remainder;
  wire        div_by_zero;

  // -------------------------------------------------------------------------
  // addition / aubtraction (with carry/borrow)
  // -------------------------------------------------------------------------
  assign add_result = {1'b0, operand_a} + {1'b0, operand_b};
  assign sub_result = {1'b0, operand_a} - {1'b0, operand_b};

  // -------------------------------------------------------------------------
  // multiplication (32x32 -> 64-bit, keep it lower 32)
  // -------------------------------------------------------------------------
  assign mul_result = operand_a * operand_b;

  // -------------------------------------------------------------------------
  // division (handle divide-by-zero)
  // -------------------------------------------------------------------------
  assign div_by_zero = (operand_b == 32'b0);
  assign div_quotient = div_by_zero ? 32'hFFFF_FFFF : (operand_a / operand_b);
  assign div_remainder = div_by_zero ? operand_a : (operand_a % operand_b);

  // -------------------------------------------------------------------------
  // ALU Operation Mux
  // -------------------------------------------------------------------------
  always @(*) begin
    result       = 32'b0;
    flag_overflow = 1'b0;
    flag_carry    = 1'b0;

    case (alu_op)
      ADD: begin
        result        = add_result[31:0];
        flag_carry    = add_result[32];
        // signed overflow: both operands same sign, result different sign
        flag_overflow = (~operand_a[31] & ~operand_b[31] &  result[31])
                      | ( operand_a[31] &  operand_b[31] & ~result[31]);
      end

      SUB: begin
        result = sub_result[31:0];
        flag_carry = sub_result[32]; // borrow
        // signed overflow: operands different sign, result sign != operand_a sign
        flag_overflow = ( operand_a[31] & ~operand_b[31] & ~result[31])
                      | (~operand_a[31] &  operand_b[31] &  result[31]);
      end

      MUL: begin
        result = mul_result[31:0];
        flag_carry = |mul_result[63:32]; // upper bits set = overflow
        flag_overflow = |mul_result[63:32];
      end

      DIV: begin
        result = div_quotient;
        flag_overflow = div_by_zero;
      end

      AND: result = operand_a & operand_b;
      OR: result = operand_a | operand_b;
      XOR: result = operand_a ^ operand_b;
      NOT: result = ~operand_a;
      NAND: result = ~(operand_a & operand_b);
      NOR: result = ~(operand_a | operand_b);
      XNOR: result = ~(operand_a ^ operand_b);

      SHL: begin
        result = operand_a << operand_b[4:0];
        flag_carry = operand_b[4:0] != 0 ?
                     operand_a[32 - operand_b[4:0]] : 1'b0;
      end

      SHR: begin
        result = operand_a >> operand_b[4:0];
        flag_carry = operand_b[4:0] != 0 ? operand_a[operand_b[4:0] - 1] : 1'b0;
      end

      SAR: begin
        result = $signed(operand_a) >>> operand_b[4:0];
      end

      MOD: begin
        result = div_remainder;
        flag_overflow = div_by_zero;
      end

      PASS: result = operand_a;

      default: result = 32'b0;
    endcase
  end

  // -------------------------------------------------------------------------
  // flags derived from result
  // -------------------------------------------------------------------------
  assign flag_zero = (result == 32'b0);
  assign flag_neg  = result[31];

endmodule
