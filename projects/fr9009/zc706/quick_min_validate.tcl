source ../../../scripts/adi_env.tcl
source $ad_hdl_dir/projects/scripts/adi_project_xilinx.tcl
source $ad_hdl_dir/projects/scripts/adi_board.tcl

# Minimal check: create project + BD, validate design only. No generate_target or synthesis.
set p_device "xc7z045ffg900-2"
set p_board [lindex [lsearch -all -inline [get_board_parts] *zc706*] end]

create_project fr9009_zc706_prj . -part $p_device -force
if {$p_board ne ""} {
  set_property board_part $p_board [current_project]
}

set_property ip_repo_paths $ad_hdl_dir/library [current_fileset]
update_ip_catalog

source $ad_hdl_dir/projects/scripts/adi_xilinx_msg.tcl

create_bd_design "system"
source system_bd.tcl
save_bd_design
validate_bd_design

puts "INFO: BD created and validated successfully."

add_files -norecurse [list \
  "system_top.v" \
  "jesd_clk.v" \
]
add_files -fileset constrs_1 -norecurse "system_constr.xdc"

puts "INFO: Source files added."

close_project
puts "INFO: Minimal validation PASSED."
exit 0
