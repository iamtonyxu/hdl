# ip

source ../../scripts/adi_env.tcl
source $ad_hdl_dir/library/scripts/adi_ip_xilinx.tcl

adi_ip_create axi_dpd_waveform
adi_ip_files axi_dpd_waveform [list \
  "$ad_hdl_dir/library/common/up_axi.v" \
  "axi_dpd_waveform.v"]

adi_ip_properties axi_dpd_waveform
adi_ip_bd axi_dpd_waveform "bd/bd.tcl"

set_property company_url {https://wiki.analog.com/resources/fpga/docs/axi_dpd_waveform} [ipx::current_core]

set cc [ipx::current_core]

ipx::save_core $cc
