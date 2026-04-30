# ip

source ../../scripts/adi_env.tcl
source $ad_hdl_dir/library/scripts/adi_ip_xilinx.tcl

adi_ip_create util_rx_data_capture
adi_ip_files util_rx_data_capture [list \
  "rx_data_capture.v" ]

adi_ip_properties_lite util_rx_data_capture

set_property company_url {https://wiki.analog.com/resources/fpga/docs/util_rx_data_capture} [ipx::current_core]

ipx::infer_bus_interface clk xilinx.com:signal:clock_rtl:1.0 [ipx::current_core]
ipx::infer_bus_interface rstn xilinx.com:signal:reset_rtl:1.0 [ipx::current_core]

ipx::save_core [ipx::current_core]


