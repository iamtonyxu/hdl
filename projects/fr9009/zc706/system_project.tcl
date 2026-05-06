source ../../../scripts/adi_env.tcl
source $ad_hdl_dir/projects/scripts/adi_project_xilinx.tcl
source $ad_hdl_dir/projects/scripts/adi_board.tcl

# adi_project_create internally calls make_wrapper which can fail on imported BDs.
# Catch the error; if system_wrapper.v was already generated, import it and continue.
if {[catch {adi_project fr9009_zc706_prj 0} adi_err]} {
  if {[regexp {make_wrapper|BD 41-1031} $adi_err]} {
    puts "WARNING: make_wrapper error caught; importing pre-generated wrapper: $adi_err"
    # In Vivado 2022.2 generated files go to .gen, not .srcs
    set wrapper_v [file normalize fr9009_zc706_prj.gen/sources_1/bd/system/hdl/system_wrapper.v]
    if {![file exists $wrapper_v]} {
      error "make_wrapper failed and system_wrapper.v not found. $adi_err"
    }
    import_files -force -norecurse -fileset sources_1 $wrapper_v
  } else {
    error $adi_err
  }
}

adi_project_files fr9009_zc706_prj [list \
  "system_top.v" \
  "jesd_clk.v" \
  "system_constr.xdc" \
]

adi_project_run fr9009_zc706_prj
