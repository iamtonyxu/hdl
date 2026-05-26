# ip

source ../../scripts/adi_env.tcl
source $ad_hdl_dir/library/scripts/adi_ip_xilinx.tcl

adi_ip_create util_tx_data_pack

# Use Xilinx DDS Compiler instead of legacy ADI DDS RTL.
set dds_compiler_0 [create_ip -name dds_compiler -vendor xilinx.com -library ip -version 6.0 -module_name dds_compiler_0]
set_property -dict [list \
CONFIG.PartsPresent {Phase_Generator_and_SIN_COS_LUT} \
CONFIG.DDS_Clock_Rate {245.76} \
CONFIG.Channels {1} \
CONFIG.Mode_of_Operation {Standard} \
CONFIG.Parameter_Entry {System_Parameters} \
CONFIG.Spurious_Free_Dynamic_Range {90} \
CONFIG.Frequency_Resolution {0.4} \
CONFIG.Noise_Shaping {Auto} \
CONFIG.Phase_Width {30} \
CONFIG.Output_Width {15} \
CONFIG.Phase_Increment {Programmable} \
CONFIG.Resync {false} \
CONFIG.Phase_offset {Programmable} \
CONFIG.Output_Selection {Sine_and_Cosine} \
CONFIG.Negative_Sine {false} \
CONFIG.Negative_Cosine {false} \
CONFIG.Amplitude_Mode {Full_Range} \
CONFIG.Memory_Type {Auto} \
CONFIG.Optimization_Goal {Auto} \
CONFIG.DSP48_Use {Minimal} \
CONFIG.Has_Phase_Out {false} \
CONFIG.DATA_Has_TLAST {Not_Required} \
CONFIG.Has_TREADY {false} \
CONFIG.S_PHASE_Has_TUSER {Not_Required} \
CONFIG.M_DATA_Has_TUSER {Not_Required} \
CONFIG.M_PHASE_Has_TUSER {Not_Required} \
CONFIG.S_CONFIG_Sync_Mode {On_Vector} \
CONFIG.OUTPUT_FORM {Twos_Complement} \
CONFIG.Latency_Configuration {Auto} \
CONFIG.Has_ARESETn {false} \
CONFIG.Has_ACLKEN {false} \
] [get_ips dds_compiler_0]

generate_target {all} [get_files util_tx_data_pack.srcs/sources_1/ip/dds_compiler_0/dds_compiler_0.xci]

adi_ip_files util_tx_data_pack [list \
  "util_tx_data_pack.v" \
  "tx_data_mapper.v" \
  "tx_data_source.v" ]

adi_ip_properties_lite util_tx_data_pack

set_property company_url {https://wiki.analog.com/resources/fpga/docs/util_tx_data_pack} [ipx::current_core]

ipx::infer_bus_interface clk xilinx.com:signal:clock_rtl:1.0 [ipx::current_core]
ipx::infer_bus_interface rstn xilinx.com:signal:reset_rtl:1.0 [ipx::current_core]

ipx::save_core [ipx::current_core]


