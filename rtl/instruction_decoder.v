// =============================================================================
// TinyGPU - Instruction Decoder
// =============================================================================
// 32-bit fixed-width instruction encoding:
//
// R-Type (register-register):
//   [31:28] opcode  [27:24] rd  [23:20] rs1  [19:16] rs2  [15:0] unused
//
// I-Type (immediate):
//   [31:28] opcode  [27:24] rd  [23:20] rs1  [19:4] imm16  [3:0] unused
//
// Opcodes:
//   0000 = ADD    (R)   rd = rs1 + rs2
//   0001 = SUB    (R)   rd = rs1 - rs2
//   0010 = MUL    (R)   rd = rs1 * rs2
//   0011 = DIV    (R)   rd = rs1 / rs2
//   0100 = AND    (R)   rd = rs1 & rs2
//   0101 = OR     (R)   rd = rs1 | rs2
//   0110 = XOR    (R)   rd = rs1 ^ rs2
//   0111 = NOT    (R)   rd = ~rs1
//   1000 = SHL    (R)   rd = rs1 << rs2
//   1001 = SHR    (R)   rd = rs1 >> rs2
//   1010 = NAND   (R)   rd = ~(rs1 & rs2)
//   1011 = NOR    (R)   rd = ~(rs1 | rs2)
//   1100 = XNOR   (R)   rd = ~(rs1 ^ rs2)
//   1101 = MOD    (R)   rd = rs1 % rs2
//   1110 = ADDI   (I)   rd = rs1 + imm16
//   1111 = MOV    (I)   rd = imm16 (zero-extended)
// =============================================================================

`timescale 1ns / 1ps

module instruction_decoder (
  input  wire [31:0] instruction,   // 32-bit instruction word

  // decoded fields
  output wire [3:0]  opcode,        // Operation code
  output wire [3:0]  rd,            // Destination register
  output wire [3:0]  rs1,           // Source register 1
  output wire [3:0]  rs2,           // Source register 2
  output wire [15:0] imm16,         // 16-bit immediate
  output wire [31:0] imm32,         // Zero-extended immediate

  // instruction type flags
  output wire        is_r_type,     // Register-type operation
  output wire        is_i_type,     // Immediate-type operation
  output wire        uses_imm,      // Operand B is immediate

  // ALU control (maps opcode to alu_op)
  output wire [3:0]  alu_op,        // ALU operation code

  // write-back enable
  output wire        reg_wr_en      // Enable register file write
);

  // -------------------------------------------------------------------------
  // field extraction
  // -------------------------------------------------------------------------
  assign opcode = instruction[31:28];
  assign rd = instruction[27:24];
  assign rs1 = instruction[23:20];
  assign rs2 = instruction[19:16];
  assign imm16 = instruction[19:4];
  assign imm32 = {16'b0, imm16};   // zero-extend

  // -------------------------------------------------------------------------
  // instruction type detection
  // -------------------------------------------------------------------------
  // ADDI = 1110, MOV = 1111 are I-type
  assign is_i_type = (opcode[3:1] == 3'b111);   // opcodes 14,15
  assign is_r_type = ~is_i_type;
  assign uses_imm = is_i_type;

  // -------------------------------------------------------------------------
  // ALU Op Mapping
  // -------------------------------------------------------------------------
  // R-type: opcode directly maps to alu_op[3:0]
  // ADDI (0b1110): use ADD (0000)
  // MOV (0b1111): use PASS (1111) with immediate as operand_a
  reg [3:0] alu_op_r;

  always @(*) begin
    case (opcode)
      4'b0000: alu_op_r = 4'b0000; // ADD
      4'b0001: alu_op_r = 4'b0001; // SUB
      4'b0010: alu_op_r = 4'b0010; // MUL
      4'b0011: alu_op_r = 4'b0011; // DIV
      4'b0100: alu_op_r = 4'b0100; // AND
      4'b0101: alu_op_r = 4'b0101; // OR
      4'b0110: alu_op_r = 4'b0110; // XOR
      4'b0111: alu_op_r = 4'b0111; // NOT
      4'b1000: alu_op_r = 4'b1000; // SHL
      4'b1001: alu_op_r = 4'b1001; // SHR
      4'b1010: alu_op_r = 4'b1010; // NAND
      4'b1011: alu_op_r = 4'b1011; // NOR
      4'b1100: alu_op_r = 4'b1100; // XNOR
      4'b1101: alu_op_r = 4'b1101; // MOD
      4'b1110: alu_op_r = 4'b0000; // ADDI -> ADD
      4'b1111: alu_op_r = 4'b1111; // MOV  -> PASS
      default: alu_op_r = 4'b0000;
    endcase
  end

  assign alu_op = alu_op_r;
  assign reg_wr_en = 1'b1; // All current instructions write back

endmodule
