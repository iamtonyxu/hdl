# ip

source ../../scripts/adi_env.tcl
source $ad_hdl_dir/library/scripts/adi_ip_xilinx.tcl

adi_ip_create axi_rxqec
adi_ip_files axi_rxqec [list \
  "$ad_hdl_dir/library/common/up_axi.v" \
  "axi_rxqec.v" \
  "rxqec_core.v" \
  "axi_ifilter.v" \
  "axi_qfilter.v" \
  "delay.v"]

adi_ip_properties axi_rxqec
adi_ip_bd axi_rxqec "bd/bd.tcl"

set cc [ipx::current_core]

ipx::save_core $cc
