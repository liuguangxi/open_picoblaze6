set DESIGN_TOP opb6_sys
set_param general.maxThreads 8

create_project $DESIGN_TOP -part xc7k325tffg900-2

set_property verilog_define {SPM_SIZE=256} [current_fileset]

add_files ../../rtl/opb6/opb6_alu.v
add_files ../../rtl/opb6/opb6_core.v
add_files ../../rtl/opb6/opb6_gpr.v
add_files ../../rtl/opb6/opb6_main_ctrl.v
add_files ../../rtl/opb6/opb6_sp_ram.v
add_files ../../rtl/opb6/opb6.v
add_files ../src/fpga_sp_ram.v
add_files ../src/opb6_sys.v

read_xdc ../src/top.xdc
read_xdc script/top_syn.xdc

set_property top $DESIGN_TOP [current_fileset]
