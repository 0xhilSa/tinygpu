# TinyGPU — Design and Implementation Using Verilog and Xilinx Vivado

> A fully functional SIMT GPU core implementing parallel arithmetic, logic, and bitwise operations across 4 simultaneous threads.

---

## Project Overview

TinyGPU is a minimal but architecturally complete GPU core written in synthesizable Verilog. It demonstrates the fundamental concept behind real GPUs: **SIMT (Single Instruction, Multiple Threads)** — one instruction broadcast to many execution units simultaneously, each operating on its own private register file.

All 4 ALUs fire **in the same clock cycle**, performing operations in true parallel.

---

## Architecture

```
┌───────────────────────────────────────────────────────────────┐
│                            TinyGPU Top                        │
│                             ┌──────────────────────────────┐  │
│                             │         Warp Controller      │  │
│                             │  PC + FSM + Thread Dispatch  │  │
│                             │                              │  │
│                             │  ┌──────────┐  ┌──────────┐  │  │
│                             │  │ Thread 0 │  │ Thread 1 │  │  │
│  ┌──────────────────┐       │  │ ┌──────┐ │  │ ┌──────┐ │  │  │
│  │  Instruction Mem │ ────▶ │  │ │ ALU  │ │  │ │ ALU  │ │  │  │
│  │  (256 × 32-bit)  │       │  │ │ REG  │ │  │ │ REG  │ │  │  │
│  └──────────────────┘       │  │ └──────┘ │  │ └──────┘ │  │  │
│                             │  └──────────┘  └──────────┘  │  │
│                             │  ┌──────────┐  ┌──────────┐  │  │
│                             │  │ Thread 2 │  │ Thread 3 │  │  │
│                             │  │ ┌──────┐ │  │ ┌──────┐ │  │  │
│                             │  │ │ ALU  │ │  │ │ ALU  │ │  │  │
│                             │  │ │ REG  │ │  │ │ REG  │ │  │  │
│                             │  │ └──────┘ │  │ └──────┘ │  │  │
│                             │  └──────────┘  └──────────┘  │  │
│                             └──────────────────────────────┘  │
│                                                               │
└───────────────────────────────────────────────────────────────┘
```

---

## Module Hierarchy

```
tinygpu.v                    ← Top-level GPU
├── instruction_memory.v     ← 256×32-bit synchronous ROM
└── warp_controller.v        ← SIMT warp: PC + FSM + 4 threads
    └── thread_processor.v  ← Per-thread: decode + regfile + ALU
        ├── instruction_decoder.v  ← 32-bit instruction decode
        ├── register_file.v        ← 16×32-bit dual-read regfile
        └── alu.v                  ← Full arithmetic + logic unit
```

---

## Supported Operations

| Opcode | Mnemonic | Operation              | Type   |
|--------|----------|------------------------|--------|
| 0000   | ADD      | rd = rs1 + rs2         | R      |
| 0001   | SUB      | rd = rs1 - rs2         | R      |
| 0010   | MUL      | rd = rs1 × rs2 (lo32)  | R      |
| 0011   | DIV      | rd = rs1 ÷ rs2         | R      |
| 0100   | AND      | rd = rs1 & rs2         | R      |
| 0101   | OR       | rd = rs1 \| rs2        | R      |
| 0110   | XOR      | rd = rs1 ^ rs2         | R      |
| 0111   | NOT      | rd = ~rs1              | R      |
| 1000   | SHL      | rd = rs1 << rs2[4:0]   | R      |
| 1001   | SHR      | rd = rs1 >> rs2[4:0]   | R      |
| 1010   | NAND     | rd = ~(rs1 & rs2)      | R      |
| 1011   | NOR      | rd = ~(rs1 \| rs2)     | R      |
| 1100   | XNOR     | rd = ~(rs1 ^ rs2)      | R      |
| 1101   | MOD      | rd = rs1 % rs2         | R      |
| 1110   | ADDI     | rd = rs1 + imm16       | I      |
| 1111   | MOV      | rd = imm16             | I      |

**Special:** `0x0000_FFFF` = HALT (end of program)

---

## Instruction Encoding (32-bit fixed-width)

### R-Type (register operands)
```
 31      28 27    24 23    20 19    16 15         0
┌──────────┬────────┬────────┬────────┬─────────────┐
│  opcode  │   rd   │  rs1   │  rs2   │  (unused)   │
│  [4-bit] │[4-bit] │[4-bit] │[4-bit] │  [16-bit]   │
└──────────┴────────┴────────┴────────┴─────────────┘
```

### I-Type (immediate operand)
```
 31      28 27    24 23    20 19              4 3    0
┌──────────┬────────┬────────┬────────────────┬──────┐
│  opcode  │   rd   │  rs1   │    imm16       │  0   │
│  [4-bit] │[4-bit] │[4-bit] │   [16-bit]     │[4-b] │
└──────────┴────────┴────────┴────────────────┴──────┘
```

---

## File Structure

```
tinygpu/
├── rtl/
│   ├── alu.v                  ALU: all arithmetic + logic ops + flags
│   ├── register_file.v        16×32-bit dual-read register file
│   ├── instruction_decoder.v  32-bit instruction field extraction
│   ├── instruction_memory.v   256-word synchronous program ROM
│   ├── thread_processor.v     Single SIMT thread (ALU + regfile)
│   ├── warp_controller.v      4-thread warp + PC + state machine
│   └── tinygpu.v              Top-level integration
├── tb/
│   └── tb_tinygpu.v           Self-checking testbench (20 tests, 96 checks)
├── sim/
│   ├── sim.sh                 Icarus Verilog simulation script
│   └── demo_all_ops.hex       Demo program (all operations)
├── tinygpu_basys3.xdc         Vivado constraints (Basys3 board)
├── create_project.tcl         Vivado project creation script
└── README.md                  This file
```

---

## Simulation (Icarus Verilog — Free, Fast)

```bash
cd sim/
chmod +x sim.sh
./sim.sh
```

Or manually:
```bash
iverilog -g2012 \
  rtl/alu.v rtl/register_file.v rtl/instruction_decoder.v \
  rtl/instruction_memory.v rtl/thread_processor.v \
  rtl/warp_controller.v rtl/tinygpu.v tb/tb_tinygpu.v \
  -o sim/tinygpu_sim

vvp sim/tinygpu_sim

# View waveforms:
gtkwave sim/tinygpu_sim.vcd
```

**Expected output:**
```
Total Checks : 96
PASSED       : 96
FAILED       : 0
*** ALL TESTS PASSED — TinyGPU VERIFIED! ***
```

---

## Vivado Synthesis (Xilinx)

### Method 1: TCL Script (Recommended)
```
vivado -mode batch -source create_project.tcl
```
Then open `vivado_project/TinyGPU.xpr` in the GUI.

### Method 2: GUI
1. New Project → RTL Project
2. Add Sources: all files in `rtl/`
3. Add Constraints: `tinygpu_basys3.xdc`
4. Target Part: `xc7a35tcpg236-1` (Basys3)
5. Run Synthesis → Implementation → Generate Bitstream

---

## How to Write a GPU Program

Each instruction is a 32-bit hex word. Example: compute `R3 = (10 + 20) * 5`:

```
// MOV R1, 10   → F1 00 00A 0 → F100_00A0
// MOV R2, 20   → F2 00 014 0 → F200_0140
// MOV R4, 5    → F4 00 005 0 → F400_0050
// ADD R3,R1,R2 → 03 12 0000  → 03120000
// MUL R5,R3,R4 → 25 34 0000  → 25340000
// HALT                        → 0000FFFF
```

In Verilog testbench:
```verilog
dut.u_imem.mem[0] = 32'hF100_00A0;  // MOV R1, 10
dut.u_imem.mem[1] = 32'hF200_0140;  // MOV R2, 20
dut.u_imem.mem[2] = 32'hF400_0050;  // MOV R4, 5
dut.u_imem.mem[3] = 32'h0312_0000;  // ADD R3, R1, R2
dut.u_imem.mem[4] = 32'h2534_0000;  // MUL R5, R3, R4
dut.u_imem.mem[5] = 32'h0000_FFFF;  // HALT
```

---

## Design Decisions & Key Concepts

### SIMT Parallelism
All 4 threads share one instruction stream but have **private register files**. Every clock cycle when a valid instruction is issued, **4 ALUs compute simultaneously** — this is the same principle used in NVIDIA/AMD GPUs.

### Thread Mask
The `thread_mask[3:0]` input allows disabling specific threads (for handling divergence in future extensions). With `4'b1111`, all 4 threads run.

### Single-Cycle Execution
TinyGPU uses a single-cycle pipeline: fetch, decode, execute, and write-back all happen within one clock cycle. This maximizes simplicity while demonstrating correct parallel behavior.

### Register File (R0 = Zero)
R0 is hardwired to 0 (writes to R0 are ignored), consistent with RISC design conventions.

### Divide-by-Zero Handling
`DIV` and `MOD` by zero return `0xFFFFFFFF` and `flag_overflow` is asserted — the GPU does not hang or produce undefined behavior.

---

## Resource Estimates (Artix-7 XC7A35T)

| Resource | Estimated Usage | Available |
|----------|----------------|-----------|
| LUT      | ~850           | 20,800    |
| FF       | ~320           | 41,600    |
| BRAM     | 0              | 50        |
| DSP48    | 4 (for MUL)    | 90        |

The design easily fits even on the smallest Artix-7 devices.

---

## Testbench Coverage

| Test | Operation | Threads Verified |
|------|-----------|-----------------|
| 1    | MOV       | 4 × 2 checks    |
| 2    | ADD       | 4 checks        |
| 3    | ADDI      | 4 checks        |
| 4    | SUB       | 4 checks        |
| 5    | MUL       | 4 checks        |
| 6    | DIV       | 4 checks        |
| 7    | AND       | 4 checks        |
| 8    | OR        | 4 checks        |
| 9    | XOR       | 4 checks        |
| 10   | NOT       | 4 checks        |
| 11   | SHL       | 4 checks        |
| 12   | SHR       | 4 checks        |
| 13   | NAND      | 4 checks        |
| 14   | NOR       | 4 checks        |
| 15   | XNOR      | 4 checks        |
| 16   | MOD       | 4 checks        |
| 17   | Chain ops | 4 checks        |
| 18   | SIMT parallel | 16 checks   |
| 19   | Div-by-zero   | 4 checks    |
| 20   | Large MUL     | 4 checks    |
| **Total** | | **96 checks, 100% pass** |

---

## Author Notes

This implementation faithfully captures the core GPU execution model:
- **SIMT**: threads run in lockstep, each with private state
- **ISA**: RISC-style fixed-width 32-bit encoding
- **ALU**: complete set of arithmetic, logical, bitwise, and shift operations
- **Parallelism**: 4× speedup on data-parallel workloads vs sequential CPU

The design is intentionally lean — no cache, no shared memory, no VRAM — making it ideal for understanding the GPU execution model without complexity.
