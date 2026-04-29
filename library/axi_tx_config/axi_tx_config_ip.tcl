# ip

source ../../scripts/adi_env.tcl
source $ad_hdl_dir/library/scripts/adi_ip_xilinx.tcl

adi_ip_create axi_tx_config
adi_ip_files axi_tx_config [list \
  "$ad_hdl_dir/library/common/up_axi.v" \
  "axi_tx_config.v" \
  "data2fpga.v" ]

adi_ip_properties axi_tx_config

set_property company_url {https://wiki.analog.com/resources/fpga/docs/axi_tx_config} [ipx::current_core]

set cc [ipx::current_core]

ipx::save_core $cc