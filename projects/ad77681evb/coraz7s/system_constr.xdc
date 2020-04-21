
# SPI interface

set_property -dict {PACKAGE_PIN  G15 IOSTANDARD LVCMOS33 IOB TRUE}                  [get_ports ad77681_spi_sclk]    ; ## CK_IO13
set_property -dict {PACKAGE_PIN  J18 IOSTANDARD LVCMOS33 IOB TRUE PULLTYPE PULLUP}  [get_ports ad77681_spi_miso]    ; ## CK_IO12
set_property -dict {PACKAGE_PIN  K18 IOSTANDARD LVCMOS33 IOB TRUE PULLTYPE PULLUP}  [get_ports ad77681_spi_mosi]    ; ## CK_IO11
set_property -dict {PACKAGE_PIN  U15 IOSTANDARD LVCMOS33}                           [get_ports ad77681_spi_cs]      ; ## CK_IO10

# reset and GPIO signals

set_property -dict {PACKAGE_PIN  M18 IOSTANDARD LVCMOS33}                           [get_ports ad77681_shutdown]    ; ## CK_IO9
set_property -dict {PACKAGE_PIN  R14 IOSTANDARD LVCMOS33}                           [get_ports ad77681_reset_adc]   ; ## CK_IO7
set_property -dict {PACKAGE_PIN  V18 IOSTANDARD LVCMOS33}                           [get_ports ad77681_csb_aux]     ; ## CK_IO5
set_property -dict {PACKAGE_PIN  V17 IOSTANDARD LVCMOS33}                           [get_ports ad77681_sw_ff]       ; ## CK_IO4
set_property -dict {PACKAGE_PIN  T15 IOSTANDARD LVCMOS33}                           [get_ports ad77681_drdy_aux]    ; ## CK_IO3
set_property -dict {PACKAGE_PIN  V13 IOSTANDARD LVCMOS33}                           [get_ports ad77681_blue_led]    ; ## CK_IO1
set_property -dict {PACKAGE_PIN  U14 IOSTANDARD LVCMOS33}                           [get_ports ad77681_yellow_led]  ; ## CK_IO0


# syncronization and timing

set_property -dict {PACKAGE_PIN  R17 IOSTANDARD LVCMOS33}                           [get_ports ad77681_sync_in]     ; ## CK_IO6
set_property -dict {PACKAGE_PIN  T14 IOSTANDARD LVCMOS33}                           [get_ports ad77681_drdy]        ; ## CK_IO2
