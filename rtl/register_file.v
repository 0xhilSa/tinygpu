// =============================================================================
// TinyGPU - Register File
// =============================================================================
// 16 x 32-bit general purpose registers
// 2 asynchronous read ports, 1 synchronous write port
// R0 is always zero (hardwired), writes to R0 are ignored
// =============================================================================

`timescale 1ns / 1ps

module register_file(
  input  wire        clk,
  input  wire        rst_n,

  // read port A
  input  wire [3:0]  rd_addr_a,    // register address A
  output wire [31:0] rd_data_a,    // register data A

  // read port B
  input  wire [3:0]  rd_addr_b,    // register address B
  output wire [31:0] rd_data_b,    // register data B

  // write port
  input  wire        wr_en,        // write enable
  input  wire [3:0]  wr_addr,      // write address
  input  wire [31:0] wr_data       // write data
);

  // -------------------------------------------------------------------------
  // register Array: 16 registers × 32 bits
  // -------------------------------------------------------------------------
  reg [31:0] regs [0:15];
  integer i;

  // -------------------------------------------------------------------------
  // reset and write logic
  // -------------------------------------------------------------------------
  always @(posedge clk or negedge rst_n) begin
    if(!rst_n) begin
      for (i = 0; i < 16; i = i + 1)
        regs[i] <= 32'b0;
    end else begin
      // R0 is hardwired to zero — never write
      if(wr_en && (wr_addr != 4'b0000))
        regs[wr_addr] <= wr_data;
    end
  end

  // -------------------------------------------------------------------------
  // asynchronous read ports
  // write-through: if reading the same reg being written, return new data
  // -------------------------------------------------------------------------
  assign rd_data_a = (rd_addr_a == 4'b0000) ? 32'b0 :
                     (wr_en && (wr_addr == rd_addr_a)) ? wr_data :
                     regs[rd_addr_a];

  assign rd_data_b = (rd_addr_b == 4'b0000) ? 32'b0 :
                     (wr_en && (wr_addr == rd_addr_b)) ? wr_data :
                     regs[rd_addr_b];

endmodule
