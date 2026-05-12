#!/bin/bash
# =============================================================================
# TinyGPU - Simulation Script (Icarus Verilog)
# Run: chmod +x sim.sh && ./sim.sh
# =============================================================================

set -e

RTL="../rtl"
TB="../tb"
OUT="./out"

mkdir -p $OUT

echo "======================================================"
echo "  TinyGPU Simulation (Icarus Verilog)"
echo "======================================================"

# Compile all RTL + testbench
iverilog -g2012 \
  -I $RTL \
  $RTL/alu.v \
  $RTL/register_file.v \
  $RTL/instruction_decoder.v \
  $RTL/instruction_memory.v \
  $RTL/thread_processor.v \
  $RTL/warp_controller.v \
  $RTL/tinygpu.v \
  $TB/tb_tinygpu.v \
  -o $OUT/tinygpu_sim

echo "[OK] Compilation successful"

# Run simulation
echo ""
echo "Running simulation..."
echo ""
vvp $OUT/tinygpu_sim

echo ""
echo "======================================================"
echo "  VCD waveform written to: $OUT/tinygpu_sim.vcd"
echo "  Open with: gtkwave tinygpu_sim.vcd"
echo "======================================================"
