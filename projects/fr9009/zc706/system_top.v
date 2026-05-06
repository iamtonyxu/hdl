`timescale 1ns / 1ps
//////////////////////////////////////////////////////////////////////////////////
// Company:
// Engineer: iamtonyxu
//
// Create Date: 2026/05/06
// Design Name:
// Module Name: system_top
// Project Name:
// Target Devices:
// Tool Versions:
// Description: Top-level integration for FR9009 on ZC706.
//
// Dependencies:
//
// Revision:
// Revision 0.02 - Cleanup and formatting update
// Additional Comments: Remove legacy commented blocks and keep active logic concise.
//
//////////////////////////////////////////////////////////////////////////////////


module system_top (
    inout  [14:0] ddr_addr,
    inout  [ 2:0] ddr_ba,
    inout         ddr_cas_n,
    inout         ddr_ck_n,
    inout         ddr_ck_p,
    inout         ddr_cke,
    inout         ddr_cs_n,
    inout  [ 3:0] ddr_dm,
    inout  [31:0] ddr_dq,
    inout  [ 3:0] ddr_dqs_n,
    inout  [ 3:0] ddr_dqs_p,
    inout         ddr_odt,
    inout         ddr_ras_n,
    inout         ddr_reset_n,
    inout         ddr_we_n,
    inout         fixed_io_ddr_vrn,
    inout         fixed_io_ddr_vrp,
    inout  [53:0] fixed_io_mio,
    inout         fixed_io_ps_clk,
    inout         fixed_io_ps_porb,
    inout         fixed_io_ps_srstb,
    output        spi0_clk_o,
    output        spi0_csn_0_o,
    output        spi0_csn_1_o,
    output        spi0_sdo_o,
    output        spi1_clk_o,
    output        spi1_csn_0_o,
    output        spi1_csn_1_o,
    output        spi1_sdo_o,
    input         spi0_sdi_i,
    input         spi1_sdi_i,
    output        fr9009_0_rst,
    output        ad9528_0_rst,
    output        ad9528_sysref_req,
    output        fr9009_gpio_0,
    output        fr9009_gpio_1,
    output        fr9009_gpio_2,
    output        fr9009_gpio_3,
    input  [ 3:0] rxn_in_0,
    input  [ 3:0] rxp_in_0,
    output [ 3:0] txn_out_0,
    output [ 3:0] txp_out_0,
    input         gt_clk_i_p,
    input         gt_clk_i_n,
    input         sysref_i_p,
    input         sysref_i_n,
    input         tx0_sync_i_p,
    input         tx0_sync_i_n,
    output        rx0_sync_o_p,
    output        rx0_sync_o_n
);


    wire         qpll_refclk;
    wire         core_clk;

    wire [ 11:0] gpio_o;
    wire         jesd_rx_reset;
    wire         jesd_tx_reset;
    wire [127:0] rx_tdata_0;

    (*mark_debug = "true"*)wire         sysref_in;
    (*mark_debug = "true"*)wire         tx_sync_0;
    (*mark_debug = "true"*)wire         rx_sync_0;
    (*mark_debug = "true"*)wire         tx_tready_0;
    (*mark_debug = "true"*)wire         rx_tvalid_0;
    (*mark_debug = "true"*)wire [127:0] tx_tdata_0;
    (*mark_debug = "true"*)wire [  3:0] rx_start_of_multiframe_0;
    (*mark_debug = "true"*)wire [  3:0] tx_start_of_multiframe_0;

    assign fr9009_0_rst      = gpio_o[0];
    assign ad9528_0_rst      = gpio_o[1];
    assign ad9528_sysref_req = gpio_o[4];
    assign jesd_rx_reset     = gpio_o[5];
    assign jesd_tx_reset     = gpio_o[6];

    assign fr9009_gpio_0     = gpio_o[7];
    assign fr9009_gpio_1     = gpio_o[8];
    assign fr9009_gpio_2     = gpio_o[9];
    assign fr9009_gpio_3     = gpio_o[10];

    wire         rstn;

    system_wrapper u_system (
        .core_clk       (core_clk),
        .qpll_refclk    (qpll_refclk),
        .rx_reset       (jesd_rx_reset),
        .rxn_in_0       (rxn_in_0),
        .rxp_in_0       (rxp_in_0),
        .spi0_csn_i     (1'b1),
        .spi0_sdi_i     (spi0_sdi_i),
        .spi1_csn_i     (1'b1),
        .spi1_sdi_i     (spi1_sdi_i),
        .sysref_in      (sysref_in),
        .tx_reset       (jesd_tx_reset),
        .tx_sync_0      (tx_sync_0),
        .tx_tdata_0     (tx_tdata_0),

        .gpio_o                  (gpio_o),
        .rstn                    (rstn),
        .rx_aresetn_0            (),
        .rx_start_of_frame_0     (),
        .rx_start_of_multiframe_0(rx_start_of_multiframe_0),
        .rx_sync_0               (rx_sync_0),
        .rx_tdata_0              (rx_tdata_0),
        .rx_tvalid_0             (rx_tvalid_0),
        .spi0_clk_o              (spi0_clk_o),
        .spi0_csn_0_o            (spi0_csn_0_o),
        .spi0_csn_1_o            (spi0_csn_1_o),
        .spi0_csn_2_o            (),
        .spi0_sdo_o              (spi0_sdo_o),
        .spi1_clk_o              (spi1_clk_o),
        .spi1_csn_0_o            (spi1_csn_0_o),
        .spi1_csn_1_o            (spi1_csn_1_o),
        .spi1_csn_2_o            (),
        .spi1_sdo_o              (spi1_sdo_o),
        .tx_aresetn_0            (),
        .tx_start_of_frame_0     (),
        .tx_start_of_multiframe_0(tx_start_of_multiframe_0),
        .tx_tready_0             (tx_tready_0),
        .txn_out_0               (txn_out_0),
        .txp_out_0               (txp_out_0),

        .ddr_addr         (ddr_addr),
        .ddr_ba           (ddr_ba),
        .ddr_cas_n        (ddr_cas_n),
        .ddr_ck_n         (ddr_ck_n),
        .ddr_ck_p         (ddr_ck_p),
        .ddr_cke          (ddr_cke),
        .ddr_cs_n         (ddr_cs_n),
        .ddr_dm           (ddr_dm),
        .ddr_dq           (ddr_dq),
        .ddr_dqs_n        (ddr_dqs_n),
        .ddr_dqs_p        (ddr_dqs_p),
        .ddr_odt          (ddr_odt),
        .ddr_ras_n        (ddr_ras_n),
        .ddr_reset_n      (ddr_reset_n),
        .ddr_we_n         (ddr_we_n),
        .fixed_io_ddr_vrn (fixed_io_ddr_vrn),
        .fixed_io_ddr_vrp (fixed_io_ddr_vrp),
        .fixed_io_mio     (fixed_io_mio),
        .fixed_io_ps_clk  (fixed_io_ps_clk),
        .fixed_io_ps_porb (fixed_io_ps_porb),
        .fixed_io_ps_srstb(fixed_io_ps_srstb)
    );

    jesd_clk u_jesd_clk (
        .gt_clk_i_p  (gt_clk_i_p),
        .gt_clk_i_n  (gt_clk_i_n),
        .sysref_i_p  (sysref_i_p),
        .sysref_i_n  (sysref_i_n),
        .rx0_sync_i  (rx_sync_0),
        .rx1_sync_i  (),
        .tx0_sync_i_p(tx0_sync_i_p),
        .tx0_sync_i_n(tx0_sync_i_n),
        .tx1_sync_i_p(),
        .tx1_sync_i_n(),

        .gt_clk_o    (qpll_refclk),
        .core_clk_o  (core_clk),
        .sysref_o    (sysref_in),
        .rx0_sync_o_p(rx0_sync_o_p),
        .rx0_sync_o_n(rx0_sync_o_n),
        .rx1_sync_o_p(),
        .rx1_sync_o_n(),
        .tx0_sync_o  (tx_sync_0),
        .tx1_sync_o  ()
    );

endmodule
