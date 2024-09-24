# ip

source ../../scripts/adi_env.tcl
source $ad_hdl_dir/library/scripts/adi_ip_xilinx.tcl

adi_ip_create axi_dpd_actuator
adi_ip_files axi_dpd_actuator [list \
  "$ad_hdl_dir/library/common/up_axi.v" \
  "afifo.v" \
  "cadder.v" \
  "cmult_fixed_v2.v" \
  "delay.v" \
  "dpd_lut_v2.v" \
  "dpd_lut_row_v2.v" \
  "dpd_actuator_v2.v" \
  "axi_dpd_actuator_v2.v"]

adi_ip_properties axi_dpd_actuator

set_property company_url {https://wiki.analog.com/resources/fpga/docs/axi_fan_control} [ipx::current_core]

ipx::infer_bus_interface clk xilinx.com:signal:clock_rtl:1.0 [ipx::current_core]
ipx::infer_bus_interface rst_n xilinx.com:signal:reset_rtl:1.0 [ipx::current_core]
ipx::infer_bus_interface s_axi_aclk xilinx.com:signal:clock_rtl:1.0 [ipx::current_core]
ipx::infer_bus_interface s_axi_aresetn xilinx.com:signal:reset_rtl:1.0 [ipx::current_core]

ipx::save_core [ipx::current_core]

