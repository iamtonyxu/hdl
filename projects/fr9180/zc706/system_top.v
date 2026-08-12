`timescale 1ns / 1ps
//////////////////////////////////////////////////////////////////////////////////
// Module: system_top.v
//
// Top-level wrapper for radio_hw validation on ZC706.
//
// Layers:
//   system_top  (this file is FPGA top)
//     |--- system_wrapper  (auto-generated from block design)
//           |--- system.bd
//                  |--- sys_ps7 (ZYNQ PS, ZC706 preset)
//                  |--- sys_rstgen (prosessor system reset)
//                  |--- sys_concat_intc (IRQ concatenator)
//                  |--- axi_radio_hw (AXI interconnect)
//                  |--- radio_hw_wrapper
//                         |--- radio_hw
//////////////////////////////////////////////////////////////////////////////////

module system_top (

    // DDR3 — ZC706 PS DDR
    inout   [14:0]  ddr_addr,
    inout   [ 2:0]  ddr_ba,
    inout           ddr_cas_n,
    inout           ddr_ck_n,
    inout           ddr_ck_p,
    inout           ddr_cke,
    inout           ddr_cs_n,
    inout   [ 3:0]  ddr_dm,
    inout   [31:0]  ddr_dq,
    inout   [ 3:0]  ddr_dqs_n,
    inout   [ 3:0]  ddr_dqs_p,
    inout           ddr_odt,
    inout           ddr_ras_n,
    inout           ddr_reset_n,
    inout           ddr_we_n,

    // FIXED_IO — ZC706 PS MIO
    inout           fixed_io_ddr_vrn,
    inout           fixed_io_ddr_vrp,
    inout   [53:0]  fixed_io_mio,
    inout           fixed_io_ps_clk,
    inout           fixed_io_ps_porb,
    inout           fixed_io_ps_srstb,

    // SPI bus — external host via PMOD1
    input           spi_sclk,
    input           spi_sdi,
    output          spi_sdo,
    input           spi_csn

);

    system_wrapper i_system_wrapper (
        .ddr_addr          (ddr_addr),
        .ddr_ba            (ddr_ba),
        .ddr_cas_n         (ddr_cas_n),
        .ddr_ck_n          (ddr_ck_n),
        .ddr_ck_p          (ddr_ck_p),
        .ddr_cke           (ddr_cke),
        .ddr_cs_n          (ddr_cs_n),
        .ddr_dm            (ddr_dm),
        .ddr_dq            (ddr_dq),
        .ddr_dqs_n         (ddr_dqs_n),
        .ddr_dqs_p         (ddr_dqs_p),
        .ddr_odt           (ddr_odt),
        .ddr_ras_n         (ddr_ras_n),
        .ddr_reset_n       (ddr_reset_n),
        .ddr_we_n          (ddr_we_n),

        .fixed_io_ddr_vrn  (fixed_io_ddr_vrn),
        .fixed_io_ddr_vrp  (fixed_io_ddr_vrp),
        .fixed_io_mio      (fixed_io_mio),
        .fixed_io_ps_clk   (fixed_io_ps_clk),
        .fixed_io_ps_porb  (fixed_io_ps_porb),
        .fixed_io_ps_srstb (fixed_io_ps_srstb),

        .spi_sclk          (spi_sclk),
        .spi_sdi           (spi_sdi),
        .spi_sdo           (spi_sdo),
        .spi_csn           (spi_csn)
    );

endmodule
