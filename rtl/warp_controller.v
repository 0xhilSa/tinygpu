// =============================================================================
// TinyGPU - Warp Controller
// =============================================================================
// A Warp executes NUM_THREADS threads in lockstep (SIMT).
// All threads receive the SAME instruction each cycle.
// Each thread has its own private register file (instantiated inside
// thread_processor).
//
// The warp controller:
//   1. Manages the Program Counter (PC)
//   2. Broadcasts instructions to all thread processors
//   3. Manages thread-active mask (which threads are running)
//   4. Detects when the warp is done (PC hits end-of-program marker)
//
// Simplified: no branching, no divergence — just straight-line execution.
// =============================================================================

`timescale 1ns / 1ps

module warp_controller#(
  parameter NUM_THREADS = 4,          // Threads per warp (SIMT width)
  parameter WARP_ID = 0           // Warp identifier
)(
  input  wire                       clk,
  input  wire                       rst_n,

  // Control
  input  wire                       start,       // Begin execution
  input  wire [7:0]                 start_pc,    // Starting PC address
  input  wire [NUM_THREADS-1:0]     thread_mask, // Which threads are active

  // Instruction memory interface
  output wire [7:0]                 pc_out,      // Current PC -> instr mem
  input  wire [31:0]                instruction, // Fetched instruction
  input  wire                       instr_valid, // Instruction valid

  // Status
  output wire                       warp_done,   // Warp finished
  output wire                       warp_active, // Warp running

  // Per-thread flags (for monitoring / conditional ops)
  output wire [NUM_THREADS-1:0]     t_flag_zero,
  output wire [NUM_THREADS-1:0]     t_flag_neg,
  output wire [NUM_THREADS-1:0]     t_flag_overflow,
  output wire [NUM_THREADS-1:0]     t_flag_carry,

  // Debug register reads (thread 0 only)
  input  wire [3:0]                  dbg_reg_addr,
  output wire [(NUM_THREADS*32)-1:0] dbg_reg_data  // All threads' reg values
);

  // -------------------------------------------------------------------------
  // State Machine
  // -------------------------------------------------------------------------
  localparam S_IDLE = 2'b00;
  localparam S_FETCH = 2'b01;
  localparam S_EXECUTE = 2'b10;
  localparam S_DONE = 2'b11;
  localparam HALT_INSTR = 32'hDEAD; // lower 16 bits pattern for HALT detect
  localparam HALT_OPCODE_PATTERN = 32'h0000_FFFF;

  reg [1:0] state, next_state;
  reg [7:0] pc;
  reg       active;

  // -------------------------------------------------------------------------
  // PC & State Register
  // -------------------------------------------------------------------------
  always @(posedge clk or negedge rst_n) begin
    if(!rst_n) begin
      state <= S_IDLE;
      pc <= 8'b0;
      active <= 1'b0;
    end else begin
      state <= next_state;
      if(state == S_IDLE && start) begin
        pc <= start_pc;
        active <= 1'b1;
      end else if(state == S_EXECUTE) begin
        if(instruction == HALT_OPCODE_PATTERN)
          active <= 1'b0;
        else
          pc <= pc + 8'd1;  // Advance PC every execute cycle
      end
    end
  end

  // -------------------------------------------------------------------------
  // Next-State Logic
  // -------------------------------------------------------------------------
  always @(*) begin
    case(state)
      S_IDLE: next_state = (start) ? S_FETCH : S_IDLE;
      S_FETCH: next_state = (instr_valid) ? S_EXECUTE : S_FETCH;
      S_EXECUTE: next_state = (instruction == HALT_OPCODE_PATTERN) ? S_DONE : S_FETCH;
      S_DONE: next_state = S_IDLE;
      default: next_state = S_IDLE;
    endcase
  end

  assign pc_out = pc;
  assign warp_active = active & (state == S_EXECUTE || state == S_FETCH);
  assign warp_done = (state == S_DONE);

  // -------------------------------------------------------------------------
  // thread processors: generate NUM_THREADS instances
  // -------------------------------------------------------------------------
  wire thread_instr_valid = (state == S_EXECUTE) & instr_valid;

  genvar t;
  generate
    for(t = 0; t < NUM_THREADS; t = t + 1) begin : gen_threads
      wire t_busy;
      wire [31:0] t_dbg_data;
      thread_processor#(
        .THREAD_ID(t)
      )u_thread(
        .clk(clk),
        .rst_n(rst_n),
        .instruction(instruction),
        .instr_valid(thread_instr_valid),
        .thread_en(thread_mask[t]),
        .busy(t_busy),
        .flag_zero(t_flag_zero[t]),
        .flag_neg(t_flag_neg[t]),
        .flag_overflow(t_flag_overflow[t]),
        .flag_carry(t_flag_carry[t]),
        .dbg_reg_addr(dbg_reg_addr),
        .dbg_reg_data(t_dbg_data)
      );
      assign dbg_reg_data[t*32 +: 32] = t_dbg_data;
    end
  endgenerate

endmodule
