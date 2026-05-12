// =============================================================================
// TinyGPU - Instruction Memory
// =============================================================================
// Simple synchronous ROM, 256 x 32-bit words
// Initialized via parameter or $readmemh
// =============================================================================

`timescale 1ns / 1ps

module instruction_memory#(
  parameter DEPTH = 256,           // Number of instructions
  parameter INIT_FILE = ""         // Optional hex init file
)(
  input  wire        clk,
  input  wire        rst_n,
  input  wire [7:0]  addr,            // Program counter (byte-addressed, word-aligned)
  output reg  [31:0] instruction,     // Instruction output
  output wire        valid            // Address in range
);

  // -------------------------------------------------------------------------
  // Memory Array
  // -------------------------------------------------------------------------
  reg [31:0] mem [0:DEPTH-1];

  integer i;

  // -------------------------------------------------------------------------
  // Initialization
  // -------------------------------------------------------------------------
  initial begin
    // Zero out all memory first
    for(i = 0; i < DEPTH; i = i + 1)
      mem[i] = 32'b0;

    // Load hex file if provided
    if(INIT_FILE != "")
      $readmemh(INIT_FILE, mem);
  end

  // -------------------------------------------------------------------------
  // Synchronous Read
  // -------------------------------------------------------------------------
  always @(posedge clk or negedge rst_n) begin
    if(!rst_n)
      instruction <= 32'b0;
    else
      instruction <= mem[addr];
  end

  assign valid = (addr < DEPTH);

endmodule
