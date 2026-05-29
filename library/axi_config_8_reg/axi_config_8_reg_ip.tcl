# ip

source ../../scripts/adi_env.tcl
source $ad_hdl_dir/library/scripts/adi_ip_xilinx.tcl

adi_ip_create axi_config_8_reg
adi_ip_files axi_config_8_reg [list \
  "$ad_hdl_dir/library/common/up_axi.v" \
  "axi_config_8_reg.v"]

adi_ip_properties axi_config_8_reg

set_property company_url {https://wiki.analog.com/resources/fpga/docs/axi_config_8_reg} [ipx::current_core]

set cc [ipx::current_core]

ipx::save_core $cc