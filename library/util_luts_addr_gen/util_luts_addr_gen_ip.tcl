source ../../scripts/adi_env.tcl
source $ad_hdl_dir/library/scripts/adi_ip_xilinx.tcl

adi_ip_create util_luts_addr_gen

set cordic_sqrt [create_ip -name cordic -vendor xilinx.com -library ip -version 6.0 -module_name cordic_sqrt]
set_property -dict [list \
  CONFIG.Coarse_Rotation {false} \
  CONFIG.Component_Name {cordic_sqrt} \
  CONFIG.Data_Format {UnsignedFraction} \
  CONFIG.Functional_Selection {Square_Root} \
  CONFIG.Input_Width {33} \
  CONFIG.Output_Width {10} \
] [get_ips cordic_sqrt]

generate_target {all} [get_files util_luts_addr_gen.srcs/sources_1/ip/cordic_sqrt/cordic_sqrt.xci]

adi_ip_files luts_addr_gen [list \
    "util_luts_addr_gen.v" \
    "cpower_fixed.v" \
    "delay.v"]

adi_ip_properties_lite util_luts_addr_gen

ipx::save_core [ipx::current_core]
