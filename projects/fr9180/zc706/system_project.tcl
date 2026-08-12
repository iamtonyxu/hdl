source ../../../scripts/adi_env.tcl
source $ad_hdl_dir/projects/scripts/adi_project_xilinx.tcl
source $ad_hdl_dir/projects/scripts/adi_board.tcl

adi_project fr9180_zc706 0

adi_project_files fr9180_zc706 [list \
  "system_top.v" \
  "system_constr.xdc" \
]

adi_project_run fr9180_zc706
