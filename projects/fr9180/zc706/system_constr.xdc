###############################################################################
# system_constr.xdc — Pin constraints for fr9180 radio_hw on ZC706
#
# SPI slave interface on PMOD1:
#   Signal  |  FPGA Pin   |  Connector  |  Direction
#   --------|-------------|-------------|-----------
#   sclk    |  PMOD1_0_LS |  J58-1      |  input
#   sdi     |  PMOD1_1_LS |  J58-3      |  input
#   sdo     |  PMOD1_2_LS |  J58-5      |  output
#   cs_n    |  PMOD1_3_LS |  J58-7      |  input
#
# Pin names from ZC706 schematic:
#   PMOD1_0_LS → AJ21   IO_L3P_T0_DQS_11
#   PMOD1_1_LS → AK21   IO_L3N_T0_DQS_11
#   PMOD1_2_LS → AB21   IO_L19P_T3_11
#   PMOD1_3_LS → AB16   IO_L24N_T3_10
###############################################################################

#========== SPI bus (PMOD1) ===================================================

set_property -dict {PACKAGE_PIN AJ21  IOSTANDARD LVCMOS25}  [get_ports spi_sclk]
set_property -dict {PACKAGE_PIN AK21  IOSTANDARD LVCMOS25}  [get_ports spi_sdi]
set_property -dict {PACKAGE_PIN AB21  IOSTANDARD LVCMOS25}  [get_ports spi_sdo]
set_property -dict {PACKAGE_PIN AB16  IOSTANDARD LVCMOS25}  [get_ports spi_csn]

#========== SPI SCLK clock constraint =========================================
# External SPI master provides 25 MHz SCLK (period = 40 ns)
create_clock -name spi_sclk -period 40.000 [get_ports spi_sclk]

#========== CDC path guidance =================================================
# SPI bus is asynchronous to up_clk (100 MHz).
# spi_slave_if uses 3-stage synchronizers — standard CDC practice.
set_property ASYNC_REG TRUE [get_cells -hier -regexp ".*(sclk_sync|sdi_sync|cs_n_sync).*"]

#========== Relaxed timing on SPI inputs (already synchronized internally) ====
set_false_path -from [get_ports {spi_sclk spi_sdi spi_csn}]
