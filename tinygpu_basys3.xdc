## =============================================================================
## TinyGPU - Vivado XDC Constraints
## Target Board: Digilent Basys3 (Artix-7 XC7A35T-1CPG236C)
## =============================================================================

## ---- Clock ----
## 100 MHz system clock (W5 on Basys3)
set_property PACKAGE_PIN W5      [get_ports clk]
set_property IOSTANDARD  LVCMOS33 [get_ports clk]
create_clock -add -name sys_clk_pin -period 10.00 -waveform {0 5} [get_ports clk]

## ---- Reset (Active Low) ----
## Center button = CPU_RESET or BTN0 (T18 on Basys3)
set_property PACKAGE_PIN T18     [get_ports rst_n]
set_property IOSTANDARD  LVCMOS33 [get_ports rst_n]

## ---- Start Button ----
## BTNL (W19)
set_property PACKAGE_PIN W19     [get_ports start]
set_property IOSTANDARD  LVCMOS33 [get_ports start]

## ---- Thread Mask (SW[3:0]) ----
set_property PACKAGE_PIN V17     [get_ports {thread_mask[0]}]
set_property PACKAGE_PIN V16     [get_ports {thread_mask[1]}]
set_property PACKAGE_PIN W16     [get_ports {thread_mask[2]}]
set_property PACKAGE_PIN W17     [get_ports {thread_mask[3]}]
set_property IOSTANDARD LVCMOS33 [get_ports {thread_mask[*]}]

## ---- Start PC (SW[11:4]) ----
set_property PACKAGE_PIN W15     [get_ports {start_pc[0]}]
set_property PACKAGE_PIN V15     [get_ports {start_pc[1]}]
set_property PACKAGE_PIN W14     [get_ports {start_pc[2]}]
set_property PACKAGE_PIN W13     [get_ports {start_pc[3]}]
set_property PACKAGE_PIN V2      [get_ports {start_pc[4]}]
set_property PACKAGE_PIN T3      [get_ports {start_pc[5]}]
set_property PACKAGE_PIN T2      [get_ports {start_pc[6]}]
set_property PACKAGE_PIN R3      [get_ports {start_pc[7]}]
set_property IOSTANDARD LVCMOS33 [get_ports {start_pc[*]}]

## ---- Status LEDs ----
## LD0 = warp_active, LD1 = warp_done
set_property PACKAGE_PIN U16     [get_ports warp_active]
set_property PACKAGE_PIN E19     [get_ports warp_done]
set_property IOSTANDARD  LVCMOS33 [get_ports warp_active]
set_property IOSTANDARD  LVCMOS33 [get_ports warp_done]

## ---- Flag LEDs ----
## LD4-LD7 = thread 0 flags (zero, neg, overflow, carry)
set_property PACKAGE_PIN U19     [get_ports {flag_zero[0]}]
set_property PACKAGE_PIN V19     [get_ports {flag_neg[0]}]
set_property PACKAGE_PIN W18     [get_ports {flag_overflow[0]}]
set_property PACKAGE_PIN U15     [get_ports {flag_carry[0]}]
set_property IOSTANDARD LVCMOS33 [get_ports {flag_zero[*]}]
set_property IOSTANDARD LVCMOS33 [get_ports {flag_neg[*]}]
set_property IOSTANDARD LVCMOS33 [get_ports {flag_overflow[*]}]
set_property IOSTANDARD LVCMOS33 [get_ports {flag_carry[*]}]

## ---- Timing Constraints ----
set_max_delay -from [get_cells dut/u_imem/*] -to [get_cells dut/u_warp/*] 8.0
set_false_path -from [get_ports rst_n]

## =============================================================================
## Notes:
## - start_pc driven by switches for manual program selection
## - thread_mask bits enable/disable individual threads
## - dbg_reg_addr/data not mapped here (too many pins) — use ILA/ChipScope
## - Add Vivado ILA core on dbg_reg_data bus to observe register values live
## =============================================================================
