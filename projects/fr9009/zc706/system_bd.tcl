set this_dir [file dirname [file normalize [info script]]]
set legacy_compat_tcl [file join $this_dir system_legacy_compat.tcl]

if {![file exists $legacy_compat_tcl]} {
  error "Cannot find legacy compatibility script: $legacy_compat_tcl"
}

# The generated legacy script recreates the full BD via Tcl commands.
source $legacy_compat_tcl
