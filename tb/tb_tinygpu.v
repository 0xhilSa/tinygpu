// =============================================================================
// TinyGPU - Comprehensive Self-Checking Testbench
// =============================================================================
// Tests ALL operations: ADD, SUB, MUL, DIV, AND, OR, XOR, NOT, SHL, SHR,
//                       NAND, NOR, XNOR, MOD, ADDI, MOV
//
// Strategy:
//   Each test loads a small program into instruction memory, fires the GPU,
//   waits for warp_done, then reads back register values and checks expected.
//
// A warp of 4 threads runs each program — all 4 ALUs execute in parallel,
// demonstrating true SIMT parallel execution.
//
// Instruction Encoding (quick reference):
//   [31:28] = opcode
//   [27:24] = rd   (dest register)
//   [23:20] = rs1  (source 1)
//   [19:16] = rs2  (source 2)      <- R-type
//   [19:4]  = imm16                <- I-type
//   [15:0]  = 0                    <- R-type unused
//
// HALT instruction: 32'h0000_FFFF
// =============================================================================

`timescale 1ns / 1ps

module tb_tinygpu;

    // -------------------------------------------------------------------------
    // Parameters
    // -------------------------------------------------------------------------
    localparam NUM_THREADS = 4;
    localparam CLK_PERIOD  = 10; // 10ns -> 100 MHz

    // Opcodes
    localparam OP_ADD  = 4'h0;
    localparam OP_SUB  = 4'h1;
    localparam OP_MUL  = 4'h2;
    localparam OP_DIV  = 4'h3;
    localparam OP_AND  = 4'h4;
    localparam OP_OR   = 4'h5;
    localparam OP_XOR  = 4'h6;
    localparam OP_NOT  = 4'h7;
    localparam OP_SHL  = 4'h8;
    localparam OP_SHR  = 4'h9;
    localparam OP_NAND = 4'hA;
    localparam OP_NOR  = 4'hB;
    localparam OP_XNOR = 4'hC;
    localparam OP_MOD  = 4'hD;
    localparam OP_ADDI = 4'hE;
    localparam OP_MOV  = 4'hF;

    localparam HALT = 32'h0000_FFFF;

    // -------------------------------------------------------------------------
    // DUT Signals
    // -------------------------------------------------------------------------
    reg                        clk;
    reg                        rst_n;
    reg                        start;
    reg  [7:0]                 start_pc;
    reg  [NUM_THREADS-1:0]     thread_mask;
    wire                       warp_done;
    wire                       warp_active;
    reg  [3:0]                 dbg_reg_addr;
    wire [(NUM_THREADS*32)-1:0] dbg_reg_data;
    wire [NUM_THREADS-1:0]     flag_zero, flag_neg, flag_overflow, flag_carry;

    // -------------------------------------------------------------------------
    // DUT Instantiation
    // -------------------------------------------------------------------------
    tinygpu #(
        .NUM_THREADS (NUM_THREADS),
        .INSTR_DEPTH (256),
        .INSTR_FILE  ("")
    ) dut (
        .clk           (clk),
        .rst_n         (rst_n),
        .start         (start),
        .start_pc      (start_pc),
        .thread_mask   (thread_mask),
        .warp_done     (warp_done),
        .warp_active   (warp_active),
        .dbg_reg_addr  (dbg_reg_addr),
        .dbg_reg_data  (dbg_reg_data),
        .flag_zero     (flag_zero),
        .flag_neg      (flag_neg),
        .flag_overflow (flag_overflow),
        .flag_carry    (flag_carry)
    );

    // -------------------------------------------------------------------------
    // Clock Generation: 100 MHz
    // -------------------------------------------------------------------------
    initial clk = 0;
    always #(CLK_PERIOD/2) clk = ~clk;

    // -------------------------------------------------------------------------
    // Test Tracking
    // -------------------------------------------------------------------------
    integer test_pass_count;
    integer test_fail_count;
    integer test_total;

    // -------------------------------------------------------------------------
    // Helper Tasks
    // -------------------------------------------------------------------------

    // Build R-type instruction
    function [31:0] r_instr;
        input [3:0] op, rd, rs1, rs2;
        r_instr = {op, rd, rs1, rs2, 16'h0000};
    endfunction

    // Build I-type instruction
    function [31:0] i_instr;
        input [3:0] op, rd, rs1;
        input [15:0] imm;
        i_instr = {op, rd, rs1, imm, 4'h0};
    endfunction

    // Load instruction at given address
    task load_instr;
        input [7:0]  addr;
        input [31:0] instr;
        begin
            dut.u_imem.mem[addr] = instr;
        end
    endtask

    // Reset the GPU
    task do_reset;
        begin
            rst_n = 0;
            start = 0;
            @(posedge clk); @(posedge clk);
            rst_n = 1;
            @(posedge clk);
        end
    endtask

    // Run GPU starting at given PC, wait for done
    task run_gpu;
        input [7:0] pc;
        integer timeout;
        begin
            start    = 1;
            start_pc = pc;
            thread_mask = 4'b1111; // all 4 threads active
            @(posedge clk);
            start = 0;
            timeout = 0;
            while (!warp_done && timeout < 200) begin
                @(posedge clk);
                timeout = timeout + 1;
            end
            if (timeout >= 200) begin
                $display("[TIMEOUT] GPU did not complete! PC=%0d", pc);
                test_fail_count = test_fail_count + 1;
            end
            @(posedge clk);
        end
    endtask

    // Read register value for a specific thread
    function [31:0] read_reg;
        input [1:0] thread_id;
        input [3:0] reg_addr;
        begin
            // dbg_reg_data is packed: [thread*32 +: 32]
            // We set dbg_reg_addr before calling this
            // The register file returns combinatorially
            read_reg = dbg_reg_data[thread_id*32 +: 32];
        end
    endfunction

    // Check a register value for ALL threads (all should have same result
    // since same instruction, different operands loaded the same way)
    task check_reg;
        input [3:0]  reg_addr;
        input [31:0] expected;
        input [63:0] test_name; // truncated for display
        reg [31:0] got;
        integer t;
        begin
            dbg_reg_addr = reg_addr;
            #1; // small delay for combinatorial settle
            for (t = 0; t < NUM_THREADS; t = t + 1) begin
                got = dbg_reg_data[t*32 +: 32];
                test_total = test_total + 1;
                if (got === expected) begin
                    $display("  [PASS] Thread%0d R%0d = 32'h%08h (expected 32'h%08h)",
                             t, reg_addr, got, expected);
                    test_pass_count = test_pass_count +  1;
                end else begin
                    $display("  [FAIL] Thread%0d R%0d = 32'h%08h (expected 32'h%08h) *** MISMATCH ***",
                             t, reg_addr, got, expected);
                    test_fail_count = test_fail_count + 1;
                end
            end
        end
    endtask

    // -------------------------------------------------------------------------
    // Clear instruction memory
    // -------------------------------------------------------------------------
    task clear_imem;
        integer i;
        begin
            for (i = 0; i < 256; i = i + 1)
                dut.u_imem.mem[i] = 32'h0000_FFFF; // HALT everywhere
        end
    endtask

    // =========================================================================
    // MAIN TEST SEQUENCE
    // =========================================================================
    initial begin
        $dumpfile("tinygpu_sim.vcd");
        $dumpvars(0, tb_tinygpu);

        test_pass_count = 0;
        test_fail_count = 0;
        test_total      = 0;

        $display("=============================================================");
        $display("  TinyGPU - Full Operation Testbench");
        $display("  4 Threads × 1 Warp | SIMT Parallel Execution");
        $display("=============================================================");

        do_reset;
        clear_imem;

        // =====================================================================
        // TEST 1: MOV (Load immediate into register)
        // =====================================================================
        $display("\n--- TEST 1: MOV (Load Immediate) ---");
        // R1 = 0x000A (10)
        // R2 = 0x0014 (20)
        // HALT
        load_instr(8'd0, i_instr(OP_MOV, 4'd1, 4'd0, 16'h000A)); // MOV R1, 10
        load_instr(8'd1, i_instr(OP_MOV, 4'd2, 4'd0, 16'h0014)); // MOV R2, 20
        load_instr(8'd2, HALT);

        do_reset;
        run_gpu(8'd0);
        check_reg(4'd1, 32'h0000_000A, "MOV_R1");
        check_reg(4'd2, 32'h0000_0014, "MOV_R2");

        // =====================================================================
        // TEST 2: ADD
        // =====================================================================
        $display("\n--- TEST 2: ADD (R3 = R1 + R2 = 10 + 20 = 30) ---");
        // Registers R1=10, R2=20 set up from test 1 via new program
        load_instr(8'd0, i_instr(OP_MOV, 4'd1, 4'd0, 16'h000A)); // MOV R1, 10
        load_instr(8'd1, i_instr(OP_MOV, 4'd2, 4'd0, 16'h0014)); // MOV R2, 20
        load_instr(8'd2, r_instr(OP_ADD, 4'd3, 4'd1, 4'd2));      // ADD R3, R1, R2
        load_instr(8'd3, HALT);

        do_reset;
        run_gpu(8'd0);
        check_reg(4'd3, 32'd30, "ADD_result");

        // =====================================================================
        // TEST 3: ADDI
        // =====================================================================
        $display("\n--- TEST 3: ADDI (R4 = R1 + 100 = 10 + 100 = 110) ---");
        load_instr(8'd0, i_instr(OP_MOV,  4'd1, 4'd0, 16'h000A)); // MOV R1, 10
        load_instr(8'd1, i_instr(OP_ADDI, 4'd4, 4'd1, 16'h0064)); // ADDI R4, R1, 100
        load_instr(8'd2, HALT);

        do_reset;
        run_gpu(8'd0);
        check_reg(4'd4, 32'd110, "ADDI_result");

        // =====================================================================
        // TEST 4: SUB
        // =====================================================================
        $display("\n--- TEST 4: SUB (R3 = R2 - R1 = 20 - 10 = 10) ---");
        load_instr(8'd0, i_instr(OP_MOV, 4'd1, 4'd0, 16'h000A)); // R1 = 10
        load_instr(8'd1, i_instr(OP_MOV, 4'd2, 4'd0, 16'h0014)); // R2 = 20
        load_instr(8'd2, r_instr(OP_SUB, 4'd3, 4'd2, 4'd1));      // R3 = R2-R1
        load_instr(8'd3, HALT);

        do_reset;
        run_gpu(8'd0);
        check_reg(4'd3, 32'd10, "SUB_result");

        // =====================================================================
        // TEST 5: MUL
        // =====================================================================
        $display("\n--- TEST 5: MUL (R3 = R1 * R2 = 10 * 20 = 200) ---");
        load_instr(8'd0, i_instr(OP_MOV, 4'd1, 4'd0, 16'h000A)); // R1 = 10
        load_instr(8'd1, i_instr(OP_MOV, 4'd2, 4'd0, 16'h0014)); // R2 = 20
        load_instr(8'd2, r_instr(OP_MUL, 4'd3, 4'd1, 4'd2));      // R3 = R1*R2
        load_instr(8'd3, HALT);

        do_reset;
        run_gpu(8'd0);
        check_reg(4'd3, 32'd200, "MUL_result");

        // =====================================================================
        // TEST 6: DIV
        // =====================================================================
        $display("\n--- TEST 6: DIV (R3 = R2 / R1 = 200 / 10 = 20) ---");
        load_instr(8'd0, i_instr(OP_MOV, 4'd1, 4'd0, 16'h000A));   // R1 = 10
        load_instr(8'd1, {OP_MOV, 4'd2, 4'd0, 16'hC800, 4'd0});    // R2 = 200
        load_instr(8'd1, i_instr(OP_MOV, 4'd2, 4'd0, 16'h00C8));   // R2 = 200
        load_instr(8'd2, r_instr(OP_DIV, 4'd3, 4'd2, 4'd1));        // R3 = R2/R1
        load_instr(8'd3, HALT);

        do_reset;
        run_gpu(8'd0);
        check_reg(4'd3, 32'd20, "DIV_result");

        // =====================================================================
        // TEST 7: AND (Bitwise)
        // =====================================================================
        $display("\n--- TEST 7: AND (R3 = 0xFF & 0x0F = 0x0F) ---");
        load_instr(8'd0, i_instr(OP_MOV, 4'd1, 4'd0, 16'h00FF)); // R1 = 0xFF
        load_instr(8'd1, i_instr(OP_MOV, 4'd2, 4'd0, 16'h000F)); // R2 = 0x0F
        load_instr(8'd2, r_instr(OP_AND, 4'd3, 4'd1, 4'd2));
        load_instr(8'd3, HALT);

        do_reset;
        run_gpu(8'd0);
        check_reg(4'd3, 32'h0000_000F, "AND_result");

        // =====================================================================
        // TEST 8: OR (Bitwise)
        // =====================================================================
        $display("\n--- TEST 8: OR (R3 = 0xF0 | 0x0F = 0xFF) ---");
        load_instr(8'd0, i_instr(OP_MOV, 4'd1, 4'd0, 16'h00F0)); // R1 = 0xF0
        load_instr(8'd1, i_instr(OP_MOV, 4'd2, 4'd0, 16'h000F)); // R2 = 0x0F
        load_instr(8'd2, r_instr(OP_OR,  4'd3, 4'd1, 4'd2));
        load_instr(8'd3, HALT);

        do_reset;
        run_gpu(8'd0);
        check_reg(4'd3, 32'h0000_00FF, "OR_result");

        // =====================================================================
        // TEST 9: XOR (Bitwise)
        // =====================================================================
        $display("\n--- TEST 9: XOR (R3 = 0xFF ^ 0x0F = 0xF0) ---");
        load_instr(8'd0, i_instr(OP_MOV, 4'd1, 4'd0, 16'h00FF)); // R1 = 0xFF
        load_instr(8'd1, i_instr(OP_MOV, 4'd2, 4'd0, 16'h000F)); // R2 = 0x0F
        load_instr(8'd2, r_instr(OP_XOR, 4'd3, 4'd1, 4'd2));
        load_instr(8'd3, HALT);

        do_reset;
        run_gpu(8'd0);
        check_reg(4'd3, 32'h0000_00F0, "XOR_result");

        // =====================================================================
        // TEST 10: NOT (Bitwise)
        // =====================================================================
        $display("\n--- TEST 10: NOT (R2 = ~R1 = ~0x0000_00FF = 0xFFFF_FF00) ---");
        load_instr(8'd0, i_instr(OP_MOV, 4'd1, 4'd0, 16'h00FF));  // R1 = 0xFF
        load_instr(8'd1, r_instr(OP_NOT, 4'd2, 4'd1, 4'd0));       // R2 = ~R1
        load_instr(8'd2, HALT);

        do_reset;
        run_gpu(8'd0);
        check_reg(4'd2, 32'hFFFF_FF00, "NOT_result");

        // =====================================================================
        // TEST 11: SHL (Shift Left)
        // =====================================================================
        $display("\n--- TEST 11: SHL (R3 = R1 << 3 = 1 << 3 = 8) ---");
        load_instr(8'd0, i_instr(OP_MOV, 4'd1, 4'd0, 16'h0001)); // R1 = 1
        load_instr(8'd1, i_instr(OP_MOV, 4'd2, 4'd0, 16'h0003)); // R2 = 3
        load_instr(8'd2, r_instr(OP_SHL, 4'd3, 4'd1, 4'd2));      // R3 = R1 << R2
        load_instr(8'd3, HALT);

        do_reset;
        run_gpu(8'd0);
        check_reg(4'd3, 32'd8, "SHL_result");

        // =====================================================================
        // TEST 12: SHR (Shift Right)
        // =====================================================================
        $display("\n--- TEST 12: SHR (R3 = 256 >> 3 = 32) ---");
        load_instr(8'd0, i_instr(OP_MOV, 4'd1, 4'd0, 16'h0100)); // R1 = 256
        load_instr(8'd1, i_instr(OP_MOV, 4'd2, 4'd0, 16'h0003)); // R2 = 3
        load_instr(8'd2, r_instr(OP_SHR, 4'd3, 4'd1, 4'd2));      // R3 = R1 >> R2
        load_instr(8'd3, HALT);

        do_reset;
        run_gpu(8'd0);
        check_reg(4'd3, 32'd32, "SHR_result");

        // =====================================================================
        // TEST 13: NAND
        // =====================================================================
        $display("\n--- TEST 13: NAND (R3 = ~(0xFF & 0xFF) = 0xFFFFFF00) ---");
        load_instr(8'd0, i_instr(OP_MOV,  4'd1, 4'd0, 16'h00FF)); // R1 = 0xFF
        load_instr(8'd1, i_instr(OP_MOV,  4'd2, 4'd0, 16'h00FF)); // R2 = 0xFF
        load_instr(8'd2, r_instr(OP_NAND, 4'd3, 4'd1, 4'd2));
        load_instr(8'd3, HALT);

        do_reset;
        run_gpu(8'd0);
        check_reg(4'd3, 32'hFFFF_FF00, "NAND_result");

        // =====================================================================
        // TEST 14: NOR
        // =====================================================================
        $display("\n--- TEST 14: NOR (R3 = ~(0xF0 | 0x0F) = 0xFFFFFF00) ---");
        load_instr(8'd0, i_instr(OP_MOV, 4'd1, 4'd0, 16'h00F0)); // R1 = 0xF0
        load_instr(8'd1, i_instr(OP_MOV, 4'd2, 4'd0, 16'h000F)); // R2 = 0x0F
        load_instr(8'd2, r_instr(OP_NOR, 4'd3, 4'd1, 4'd2));
        load_instr(8'd3, HALT);

        do_reset;
        run_gpu(8'd0);
        check_reg(4'd3, 32'hFFFF_FF00, "NOR_result");

        // =====================================================================
        // TEST 15: XNOR
        // =====================================================================
        $display("\n--- TEST 15: XNOR (R3 = ~(0xAA ^ 0x55) = ~0xFF = 0xFFFFFF00) ---");
        load_instr(8'd0, i_instr(OP_MOV,  4'd1, 4'd0, 16'h00AA)); // R1 = 0xAA
        load_instr(8'd1, i_instr(OP_MOV,  4'd2, 4'd0, 16'h0055)); // R2 = 0x55
        load_instr(8'd2, r_instr(OP_XNOR, 4'd3, 4'd1, 4'd2));
        load_instr(8'd3, HALT);

        do_reset;
        run_gpu(8'd0);
        check_reg(4'd3, 32'hFFFF_FF00, "XNOR_result");

        // =====================================================================
        // TEST 16: MOD (Remainder)
        // =====================================================================
        $display("\n--- TEST 16: MOD (R3 = 17 %% 5 = 2) ---");
        load_instr(8'd0, i_instr(OP_MOV, 4'd1, 4'd0, 16'h0011)); // R1 = 17
        load_instr(8'd1, i_instr(OP_MOV, 4'd2, 4'd0, 16'h0005)); // R2 = 5
        load_instr(8'd2, r_instr(OP_MOD, 4'd3, 4'd1, 4'd2));
        load_instr(8'd3, HALT);

        do_reset;
        run_gpu(8'd0);
        check_reg(4'd3, 32'd2, "MOD_result");

        // =====================================================================
        // TEST 17: Multi-instruction program (chain of ops)
        //          Compute: R5 = (10 + 20) * 3 = 90
        // =====================================================================
        $display("\n--- TEST 17: Chain Ops: R5 = (10+20)*3 = 90 ---");
        load_instr(8'd0, i_instr(OP_MOV,  4'd1, 4'd0, 16'h000A)); // R1 = 10
        load_instr(8'd1, i_instr(OP_MOV,  4'd2, 4'd0, 16'h0014)); // R2 = 20
        load_instr(8'd2, i_instr(OP_MOV,  4'd4, 4'd0, 16'h0003)); // R4 = 3
        load_instr(8'd3, r_instr(OP_ADD,  4'd3, 4'd1, 4'd2));      // R3 = R1+R2 = 30
        load_instr(8'd4, r_instr(OP_MUL,  4'd5, 4'd3, 4'd4));      // R5 = R3*R4 = 90
        load_instr(8'd5, HALT);

        do_reset;
        run_gpu(8'd0);
        check_reg(4'd5, 32'd90, "CHAIN_result");

        // =====================================================================
        // TEST 18: Parallel verification — all 4 threads compute same result
        //          Demonstrates SIMT: 4 ALUs fire at once
        // =====================================================================
        $display("\n--- TEST 18: SIMT Parallel Verify: 4 ALUs simultaneously ---");
        load_instr(8'd0, i_instr(OP_MOV, 4'd1, 4'd0, 16'h00FF)); // R1 = 255
        load_instr(8'd1, i_instr(OP_MOV, 4'd2, 4'd0, 16'h000F)); // R2 = 15
        load_instr(8'd2, r_instr(OP_AND, 4'd3, 4'd1, 4'd2));      // R3 = 255 & 15 = 15
        load_instr(8'd3, r_instr(OP_OR,  4'd4, 4'd1, 4'd2));      // R4 = 255 | 15 = 255
        load_instr(8'd4, r_instr(OP_XOR, 4'd5, 4'd1, 4'd2));      // R5 = 255 ^ 15 = 240
        load_instr(8'd5, r_instr(OP_NOT, 4'd6, 4'd2, 4'd0));      // R6 = ~15 = 0xFFFFFF0
        load_instr(8'd6, HALT);

        do_reset;
        run_gpu(8'd0);
        $display("  All 4 threads run in parallel — checking each:");
        check_reg(4'd3, 32'h0000_000F, "SIMT_AND");
        check_reg(4'd4, 32'h0000_00FF, "SIMT_OR");
        check_reg(4'd5, 32'h0000_00F0, "SIMT_XOR");
        check_reg(4'd6, 32'hFFFF_FFF0, "SIMT_NOT");

        // =====================================================================
        // TEST 19: Divide by zero (should return 0xFFFFFFFF, no hang)
        // =====================================================================
        $display("\n--- TEST 19: Divide by Zero (graceful handling) ---");
        load_instr(8'd0, i_instr(OP_MOV, 4'd1, 4'd0, 16'h000A)); // R1 = 10
        load_instr(8'd1, i_instr(OP_MOV, 4'd2, 4'd0, 16'h0000)); // R2 = 0
        load_instr(8'd2, r_instr(OP_DIV, 4'd3, 4'd1, 4'd2));      // R3 = 10/0
        load_instr(8'd3, HALT);

        do_reset;
        run_gpu(8'd0);
        check_reg(4'd3, 32'hFFFF_FFFF, "DIV_ZERO_result");

        // =====================================================================
        // TEST 20: Large multiply (check lower 32 bits)
        //          0xFFFF * 0xFFFF = 0xFFFE_0001
        // =====================================================================
        $display("\n--- TEST 20: Large MUL (0xFFFF * 0xFFFF = 0xFFFE0001) ---");
        load_instr(8'd0, i_instr(OP_MOV, 4'd1, 4'd0, 16'hFFFF)); // R1 = 0xFFFF
        load_instr(8'd1, i_instr(OP_MOV, 4'd2, 4'd0, 16'hFFFF)); // R2 = 0xFFFF
        load_instr(8'd2, r_instr(OP_MUL, 4'd3, 4'd1, 4'd2));
        load_instr(8'd3, HALT);

        do_reset;
        run_gpu(8'd0);
        check_reg(4'd3, 32'hFFFE_0001, "LARGE_MUL");

        // =====================================================================
        // SUMMARY
        // =====================================================================
        $display("\n=============================================================");
        $display("  TESTBENCH SUMMARY");
        $display("  Total Checks : %0d", test_total);
        $display("  PASSED       : %0d", test_pass_count);
        $display("  FAILED       : %0d", test_fail_count);
        if (test_fail_count == 0)
            $display("  *** ALL TESTS PASSED — TinyGPU VERIFIED! ***");
        else
            $display("  *** FAILURES DETECTED — CHECK ABOVE ***");
        $display("=============================================================");

        $finish;
    end

    // -------------------------------------------------------------------------
    // Timeout watchdog
    // -------------------------------------------------------------------------
    initial begin
        #1_000_000;
        $display("[WATCHDOG] Simulation timeout!");
        $finish;
    end

endmodule
