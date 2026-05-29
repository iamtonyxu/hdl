source ../../../scripts/adi_env.tcl
source $ad_hdl_dir/projects/scripts/adi_project_xilinx.tcl
source $ad_hdl_dir/projects/scripts/adi_board.tcl

set project_name fr9009_zc706_v1_prj

# Create the Vivado project and build the BD from system_bd.tcl/system.tcl.
if {[catch {adi_project $project_name 0} adi_err]} {
  if {[regexp {make_wrapper|BD 41-1031} $adi_err]} {
    puts "WARNING: make_wrapper error caught; importing pre-generated wrapper: $adi_err"
    set wrapper_v [file normalize ${project_name}.gen/sources_1/bd/system/hdl/system_wrapper.v]
    if {![file exists $wrapper_v]} {
      error "make_wrapper failed and system_wrapper.v not found. $adi_err"
    }
    import_files -force -norecurse -fileset sources_1 $wrapper_v
  } else {
    error $adi_err
  }
}

# Collect all local HDL/constraint inputs from src/ and constraints/.
set project_files [list]
foreach pattern [list "src/*.v" "src/*.sv" "src/*.vh" "src/*.vhd" "src/*.xci" "src/*.xdc" "src/*.coe" "constraints/*.xdc"] {
  foreach f [lsort [glob -nocomplain $pattern]] {
    set fname [file tail $f]
    # Skip common backup/temp artifacts to prevent duplicate module definitions.
    if {[regexp {(_bak\.|\.bak$|~$|^\.#)} $fname]} {
      continue
    }
    lappend project_files $f
  }
}

if {[llength $project_files] == 0} {
  error "No source or constraint files found under src/ or constraints/."
}

adi_project_files $project_name $project_files
adi_project_run $project_name
