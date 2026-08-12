###############################################################################
# system_bd.tcl — Block Design for fr9180 radio_hw validation on ZC706
#
# Architecture:
#   sys_ps7 (ZYNQ PS, ZC706 preset)
#     ├── FCLK_CLK0 (100MHz)  → sys_rstgen → sys_cpu_resetn
#     ├── M_AXI_GP0           → axi_cpu_interconnect → axi_radio_hw_0
#     └── IRQ_F2P             ← sys_concat_intc ← spi_mailbox_irq
#
#   axi_radio_hw_0
#     ├── s_axi_* (AXI4-Lite, auto-detected)
#     ├── sclk/sdi/sdo/cs_n   → external SPI ports
#     └── spi_mailbox_irq     → sys_concat_intc In0
###############################################################################

#--------------------------------------------------------------------------
# BD interface ports — DDR, FIXED_IO (for PS)
#--------------------------------------------------------------------------
create_bd_intf_port -mode Master -vlnv xilinx.com:interface:ddrx_rtl:1.0 ddr
create_bd_intf_port -mode Master -vlnv xilinx.com:display_processing_system7:fixedio_rtl:1.0 fixed_io

#--------------------------------------------------------------------------
# BD ports — external SPI slave interface (PMOD1 header)
#   sclk  = PMOD1_0_LS = J58-1  (input)
#   sdi   = PMOD1_1_LS = J58-3  (input)
#   sdo   = PMOD1_2_LS = J58-5  (output)
#   cs_n  = PMOD1_3_LS = J58-7  (input)
#--------------------------------------------------------------------------
create_bd_port -dir I  spi_sclk
create_bd_port -dir I  spi_sdi
create_bd_port -dir O  spi_sdo
create_bd_port -dir I  spi_csn

#--------------------------------------------------------------------------
# sys_ps7 — ZYNQ7 Processing System (ZC706 board preset)
#--------------------------------------------------------------------------
ad_ip_instance processing_system7 sys_ps7
ad_ip_parameter sys_ps7 CONFIG.preset ZC706
ad_ip_parameter sys_ps7 CONFIG.PCW_FPGA0_PERIPHERAL_FREQMHZ 100.0
ad_ip_parameter sys_ps7 CONFIG.PCW_USE_FABRIC_INTERRUPT 1
ad_ip_parameter sys_ps7 CONFIG.PCW_IRQ_F2P_INTR 1
ad_ip_parameter sys_ps7 CONFIG.PCW_IRQ_F2P_MODE REVERSE

#--------------------------------------------------------------------------
# sys_rstgen — Processor System Reset
#   FCLK_CLK0     → slowest_sync_clk
#   FCLK_RESET0_N → ext_reset_in
#--------------------------------------------------------------------------
ad_ip_instance proc_sys_reset sys_rstgen
ad_ip_parameter sys_rstgen CONFIG.C_EXT_RST_WIDTH 1

#--------------------------------------------------------------------------
# sys_concat_intc — interrupt concatenator (16 → 1)
#   In0  = spi_mailbox_irq
#   In1..15 = GND
#   dout → PS IRQ_F2P
#--------------------------------------------------------------------------
ad_ip_instance xlconcat sys_concat_intc
ad_ip_parameter sys_concat_intc CONFIG.NUM_PORTS 16

#--------------------------------------------------------------------------
# Clock and reset connections
#--------------------------------------------------------------------------
ad_connect sys_cpu_clk sys_ps7/FCLK_CLK0
ad_connect sys_cpu_clk sys_rstgen/slowest_sync_clk
ad_connect sys_rstgen/ext_reset_in sys_ps7/FCLK_RESET0_N
ad_connect sys_cpu_reset sys_rstgen/peripheral_reset
ad_connect sys_cpu_resetn sys_rstgen/peripheral_aresetn

# Store as named nets for later use by ad_cpu_interconnect
set sys_cpu_clk    [get_bd_nets sys_cpu_clk]
set sys_cpu_resetn [get_bd_nets sys_cpu_resetn]

#--------------------------------------------------------------------------
# DDR and FIXED_IO connections
#--------------------------------------------------------------------------
ad_connect ddr sys_ps7/DDR
ad_connect fixed_io sys_ps7/FIXED_IO

#--------------------------------------------------------------------------
# axi_radio_hw_0 — Radio Hardware IP with SPI slave and AXI4-Lite
#--------------------------------------------------------------------------
ad_ip_instance axi_radio_hw axi_radio_hw_0

# SPI bus connections
ad_connect spi_sclk axi_radio_hw_0/sclk
ad_connect spi_sdi  axi_radio_hw_0/sdi
ad_connect axi_radio_hw_0/sdo  spi_sdo
ad_connect spi_csn  axi_radio_hw_0/cs_n

# Clock and reset
ad_connect sys_cpu_clk    axi_radio_hw_0/s_axi_aclk
ad_connect sys_cpu_resetn axi_radio_hw_0/s_axi_aresetn

#--------------------------------------------------------------------------
# Interrupt connections
#--------------------------------------------------------------------------
ad_connect sys_concat_intc/dout sys_ps7/IRQ_F2P
ad_connect sys_concat_intc/In0  axi_radio_hw_0/spi_mailbox_irq
ad_connect sys_concat_intc/In1  GND
ad_connect sys_concat_intc/In2  GND
ad_connect sys_concat_intc/In3  GND
ad_connect sys_concat_intc/In4  GND
ad_connect sys_concat_intc/In5  GND
ad_connect sys_concat_intc/In6  GND
ad_connect sys_concat_intc/In7  GND
ad_connect sys_concat_intc/In8  GND
ad_connect sys_concat_intc/In9  GND
ad_connect sys_concat_intc/In10 GND
ad_connect sys_concat_intc/In11 GND
ad_connect sys_concat_intc/In12 GND
ad_connect sys_concat_intc/In13 GND
ad_connect sys_concat_intc/In14 GND
ad_connect sys_concat_intc/In15 GND

#--------------------------------------------------------------------------
# AXI Interconnect — connect axi_radio_hw_0 to PS M_AXI_GP0
#   Address: 0x43C00000 (64K)
#--------------------------------------------------------------------------
ad_cpu_interconnect 0x43C00000 axi_radio_hw_0

#--------------------------------------------------------------------------
# Validate and save
#--------------------------------------------------------------------------
validate_bd_design
save_bd_design
