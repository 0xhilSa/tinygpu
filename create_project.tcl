# =============================================================================
# TinyGPU - Vivado Project Creation & Synthesis Script
# Run: vivado -mode batch -source create_project.tcl
# =============================================================================

set project_name "TinyGPU"
set project_dir  "./vivado_project"
set rtl_dir      "../rtl"
set tb_dir       "../tb"
set xdc_file     "../tinygpu_basys3.xdc"

# Target: Basys3 (Artix-7)
set part "xc7a35tcpg236-1"

# ---- Create Project ----
create_project $project_name $project_dir -part $part
set_property board_part digilentinc.com:basys3:part0:1.1 [current_project]

# ---- Add RTL Sources ----
add_files -norecurse [list \
  $rtl_dir/alu.v \
  $rtl_dir/register_file.v \
  $rtl_dir/instruction_decoder.v \
  $rtl_dir/instruction_memory.v \
  $rtl_dir/thread_processor.v \
  $rtl_dir/warp_controller.v \
  $rtl_dir/tinygpu.v \
]
set_property file_type {Verilog} [get_files *.v]

# ---- Add Testbench ----
add_files -fileset sim_1 -norecurse $tb_dir/tb_tinygpu.v
set_property top tb_tinygpu [get_filesets sim_1]

# ---- Add Constraints ----
add_files -fileset constrs_1 -norecurse $xdc_file

# ---- Set Top Module ----
set_property top tinygpu [current_fileset]

# ---- Synthesis Settings ----
set_property strategy "Vivado Synthesis Defaults" [get_runs synth_1]
set_property STEPS.SYNTH_DESIGN.ARGS.DIRECTIVE "Default" [get_runs synth_1]

# ---- Implementation Settings ----
set_property strategy "Vivado Implementation Defaults" [get_runs impl_1]

puts "========================================================"
puts "  Project created: $project_dir/$project_name.xpr"
puts ""
puts "  To synthesize:   launch_runs synth_1 -wait"
puts "  To implement:    launch_runs impl_1  -wait"
puts "  To generate bit: launch_runs impl_1 -to_step write_bitstream -wait"
puts "  To simulate:     launch_simulation"
puts "========================================================"

# Optionally run synthesis immediately:
# launch_runs synth_1 -wait
# open_run synth_1 -name synth_1
# report_utilization -file utilization.rpt
# report_timing_summary -file timing.rpt
