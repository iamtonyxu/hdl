set this_dir [file dirname [file normalize [info script]]]
set bd_tcl [file join $this_dir system.tcl]

if {![file exists $bd_tcl]} {
  error "Cannot find block design script: $bd_tcl"
}

# Use the generated BD script as the project BD source.
source $bd_tcl
