`timescale 1ns / 1ps
//////////////////////////////////////////////////////////////////////////////////
// Company: ZHFG
// Engineer: YalongXu
//
// Create Date: 2026/08/11
// Design Name:
// Module Name: axi2spi_bridge.v
// Project Name:
// Target Devices:
// Tool Versions:
// Description:
//
// This module works a bridge between axi4 and pcore registers.
// We name it as axi2spi_bridge because the pcore spi if is a slave, which is controlled
// by the external host with a spi master.
//
// Dependencies: up_axi.v
//
// Revision:
// Revision 0.01 - File Created
// Additional Comments:
//
//////////////////////////////////////////////////////////////////////////////////

module axi2spi_bridge #(
    parameter AXI_ADDRESS_WIDTH = 16
) (
    // reset and clocks
    input                               up_rstn,
    input                               up_clk,

    // axi4 interface
    input                               up_axi_awvalid,
    input   [(AXI_ADDRESS_WIDTH-1):0]   up_axi_awaddr,
    output                              up_axi_awready,
    input                               up_axi_wvalid,
    input   [31:0]                      up_axi_wdata,
    input   [ 3:0]                      up_axi_wstrb,
    output                              up_axi_wready,
    output                              up_axi_bvalid,
    output  [ 1:0]                      up_axi_bresp,
    input                               up_axi_bready,
    input                               up_axi_arvalid,
    input   [(AXI_ADDRESS_WIDTH-1):0]   up_axi_araddr,
    output                              up_axi_arready,
    output                              up_axi_rvalid,
    output  [ 1:0]                      up_axi_rresp,
    output  [31:0]                      up_axi_rdata,
    input                               up_axi_rready,

    // pcore interface
    output                              up_wreq,
    output  [(AXI_ADDRESS_WIDTH-3):0]   up_waddr,
    output  [31:0]                      up_wdata,
    input                               up_wack,
    output                              up_rreq,
    output  [(AXI_ADDRESS_WIDTH-3):0]   up_raddr,
    input   [31:0]                      up_rdata,
    input                               up_rack
);

    up_axi #(
        .AXI_ADDRESS_WIDTH(AXI_ADDRESS_WIDTH)
    ) i_up_axi (
        .up_rstn          (up_rstn),
        .up_clk           (up_clk),
        .up_axi_awvalid   (up_axi_awvalid),
        .up_axi_awaddr    (up_axi_awaddr),
        .up_axi_awready   (up_axi_awready),
        .up_axi_wvalid    (up_axi_wvalid),
        .up_axi_wdata     (up_axi_wdata),
        .up_axi_wstrb     (up_axi_wstrb),
        .up_axi_wready    (up_axi_wready),
        .up_axi_bvalid    (up_axi_bvalid),
        .up_axi_bresp     (up_axi_bresp),
        .up_axi_bready    (up_axi_bready),
        .up_axi_arvalid   (up_axi_arvalid),
        .up_axi_araddr    (up_axi_araddr),
        .up_axi_arready   (up_axi_arready),
        .up_axi_rvalid    (up_axi_rvalid),
        .up_axi_rresp     (up_axi_rresp),
        .up_axi_rdata     (up_axi_rdata),
        .up_axi_rready    (up_axi_rready),
        .up_wreq          (up_wreq),
        .up_waddr         (up_waddr),
        .up_wdata         (up_wdata),
        .up_wack          (up_wack),
        .up_rreq          (up_rreq),
        .up_raddr         (up_raddr),
        .up_rdata         (up_rdata),
        .up_rack          (up_rack)
    );

endmodule
