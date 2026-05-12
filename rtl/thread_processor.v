// =============================================================================
// TinyGPU - Thread Processor
// =============================================================================
// one thread = one ALU + one register file + instruction fetch/execute
// threads share the instruction stream but have private register files
// (SIMT: Single Instruction Multiple Threads)
//
// pipeline: single-cycle (fetch+decode+execute+writeback in one clock)
// =============================================================================

`timescale 1ns / 1ps

module thread_processor#(
  parameter THREAD_ID = 0     // thread ID (used for debug & thread-specific ops)
)(
  input  wire        clk,
  input  wire        rst_n,

  // instruction Interface (from instruction memory / warp dispatcher)
  input  wire [31:0] instruction,   // Current instruction (broadcast from warp)
  input  wire        instr_valid,   // Instruction is valid / thread is active

  // thread control
  input  wire        thread_en,     // Thread enable (mask for divergence handling)

  // status outputs
  output wire        busy,          // Thread is executing
  output wire        flag_zero,     // ALU zero flag
  output wire        flag_neg,      // ALU negative flag
  output wire        flag_overflow, // ALU overflow flag
  output wire        flag_carry,    // ALU carry flag

  // debug: expose register file read for monitoring
  input  wire [3:0]  dbg_reg_addr,
  output wire [31:0] dbg_reg_data
);

  // -------------------------------------------------------------------------
  // internal wires
  // -------------------------------------------------------------------------
  wire [3:0]  opcode;
  wire [3:0]  rd, rs1, rs2;
  wire [15:0] imm16;
  wire [31:0] imm32;
  wire        is_r_type, is_i_type, uses_imm;
  wire [3:0]  alu_op;
  wire        reg_wr_en;

  wire [31:0] rs1_data, rs2_data;
  wire [31:0] alu_a, alu_b;
  wire [31:0] alu_result;

  // -------------------------------------------------------------------------
  // instruction decoder
  // -------------------------------------------------------------------------
  instruction_decoder u_decoder(
    .instruction(instruction),
    .opcode(opcode),
    .rd(rd),
    .rs1(rs1),
    .rs2(rs2),
    .imm16(imm16),
    .imm32(imm32),
    .is_r_type(is_r_type),
    .is_i_type(is_i_type),
    .uses_imm(uses_imm),
    .alu_op(alu_op),
    .reg_wr_en(reg_wr_en)
  );

  // -------------------------------------------------------------------------
  // register file
  // -------------------------------------------------------------------------
  register_file u_regfile(
    .clk(clk),
    .rst_n(rst_n),
    .rd_addr_a(rs1),
    .rd_data_a(rs1_data),
    .rd_addr_b(rd_addr_b_mux),
    .rd_data_b(rd_data_b_raw),
    .wr_en(reg_wr_en & instr_valid & thread_en),
    .wr_addr(rd),
    .wr_data(alu_result)
  );

  // mux port B between rs2 and debug address
  wire [3:0]  rd_addr_b_mux;
  wire [31:0] rd_data_b_raw;
  assign rd_addr_b_mux = rs2;   // normal operation
  assign rs2_data = rd_data_b_raw;

  // debug port via second register file read (uses separate read)
  register_file u_regfile_dbg(
    .clk(clk),
    .rst_n(rst_n),
    .rd_addr_a(dbg_reg_addr),
    .rd_data_a(dbg_reg_data),
    .rd_addr_b(4'b0),
    .rd_data_b(),
    .wr_en(reg_wr_en & instr_valid & thread_en),
    .wr_addr(rd),
    .wr_data(alu_result)
  );

  // -------------------------------------------------------------------------
  // operand muxes
  // -------------------------------------------------------------------------
  // for MOV (opcode 1111): alu_a = imm32, alu_op = PASS -> result = imm32
  // for ADDI (opcode 1110): alu_a = rs1_data, alu_b = imm32
  // for R-type: alu_a = rs1_data, alu_b = rs2_data

  assign alu_a = (opcode == 4'b1111) ? imm32 : rs1_data;
  assign alu_b = uses_imm ? imm32 : rs2_data;

  // -------------------------------------------------------------------------
  // ALU
  // -------------------------------------------------------------------------
  alu u_alu(
    .operand_a(alu_a),
    .operand_b(alu_b),
    .alu_op(alu_op),
    .result(alu_result),
    .flag_zero(flag_zero),
    .flag_neg(flag_neg),
    .flag_overflow(flag_overflow),
    .flag_carry(flag_carry)
  );

  assign busy = instr_valid & thread_en;

endmodule
