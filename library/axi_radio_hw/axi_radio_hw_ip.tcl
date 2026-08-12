# ip

source ../../scripts/adi_env.tcl
source $ad_hdl_dir/library/scripts/adi_ip_xilinx.tcl

adi_ip_create axi_radio_hw
adi_ip_files axi_radio_hw [list \
  "axi2spi_bridge.v" \
  "pcore_registers.v" \
  "radio_hw.v" \
  "spi_slave_if.v" \
  "up_axi.v"]

adi_ip_properties axi_radio_hw

set_property company_url {https://wiki.analog.com/resources/fpga/docs/axi_radio_hw} [ipx::current_core]

set cc [ipx::current_core]

ipx::save_core $cc
