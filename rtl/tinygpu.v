// =============================================================================
// TinyGPU - Top Level
// =============================================================================
// Parameters:
//   NUM_THREADS = 4     (warp width — all 4 ALUs work simultaneously)
//   INSTR_DEPTH = 256   (max program size in instructions)
//
// Usage:
//   1. Assert rst_n low, then high to reset
//   2. Load instructions into memory (simulation: hierarchical path access)
//   3. Set start_pc, thread_mask, assert start for one clock
//   4. Poll warp_done or monitor busy
// =============================================================================

`timescale 1ns / 1ps

module tinygpu#(
  parameter NUM_THREADS = 4,
  parameter INSTR_DEPTH = 256,
  parameter INSTR_FILE  = ""      // Optional .hex program file
)(
  input  wire                       clk,
  input  wire                       rst_n,

  // GPU dispatch interface
  input  wire                       start,         // Start warp execution
  input  wire [7:0]                 start_pc,      // Starting program counter
  input  wire [NUM_THREADS-1:0]     thread_mask,   // Active thread mask

  // Status
  output wire                       warp_done,     // Execution complete
  output wire                       warp_active,   // GPU is running

  // Debug/Monitor Interface
  input  wire [3:0]                 dbg_reg_addr,  // Register to inspect
  output wire [(NUM_THREADS*32)-1:0] dbg_reg_data, // All threads' register values

  // Per-thread flags
  output wire [NUM_THREADS-1:0]     flag_zero,
  output wire [NUM_THREADS-1:0]     flag_neg,
  output wire [NUM_THREADS-1:0]     flag_overflow,
  output wire [NUM_THREADS-1:0]     flag_carry
);

  // -------------------------------------------------------------------------
  // Internal Connections
  // -------------------------------------------------------------------------
  wire [7:0]  pc;
  wire [31:0] instruction;
  wire        instr_valid;

  // -------------------------------------------------------------------------
  // Instruction Memory
  // -------------------------------------------------------------------------
  instruction_memory#(
    .DEPTH     (INSTR_DEPTH),
    .INIT_FILE (INSTR_FILE)
  )u_imem(
    .clk(clk),
    .rst_n(rst_n),
    .addr(pc),
    .instruction(instruction),
    .valid(instr_valid)
  );

  // -------------------------------------------------------------------------
  // Warp Controller (contains NUM_THREADS thread processors)
  // -------------------------------------------------------------------------
  warp_controller#(
    .NUM_THREADS (NUM_THREADS),
    .WARP_ID     (0)
  )u_warp(
    .clk(clk),
    .rst_n(rst_n),
    .start(start),
    .start_pc(start_pc),
    .thread_mask(thread_mask),
    .pc_out(pc),
    .instruction(instruction),
    .instr_valid(instr_valid),
    .warp_done(warp_done),
    .warp_active(warp_active),
    .t_flag_zero(flag_zero),
    .t_flag_neg(flag_neg),
    .t_flag_overflow(flag_overflow),
    .t_flag_carry(flag_carry),
    .dbg_reg_addr(dbg_reg_addr),
    .dbg_reg_data(dbg_reg_data)
  );

endmodule
