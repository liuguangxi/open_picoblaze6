set DESIGN_TOP kcpsm6_sys
set_param general.maxThreads 8

create_project $DESIGN_TOP -part xc7k325tffg900-2

set_property verilog_define {SPM_SIZE=256} [current_fileset]

add_files ../../rtl/kcpsm6/kcpsm6.v
add_files ../src/fpga_sp_ram.v
add_files ../src/kcpsm6_sys.v

read_xdc ../src/top.xdc
read_xdc script/top_syn.xdc

set_property top $DESIGN_TOP [current_fileset]
