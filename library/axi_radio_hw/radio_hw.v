`timescale 1ns / 1ps
//////////////////////////////////////////////////////////////////////////////////
// Company: ZHFG
// Engineer: YalongXu
//
// Create Date: 2026/08/12
// Design Name:
// Module Name: radio_hw.v
// Project Name:
// Target Devices:
// Tool Versions:
// Description:
//
// This module is about radio hardware, which consists of module spi_slave_if,
// pcore_registers, up_axi and axi2spi_bridge.
// 1. External host (with spi master) can get access to radio_hw inner registers via spi bus.
// 2. Internal processor(with axi-4 interface, like xilinx zynq ps) can get access to radio_hw
//    inner registers via axi-4 bus.
// 3. spi_mailbox_irq goes to internal processor.
// 4. assign up_rstn = s_axi_aresetn, assign up_clk = s_axi_aclk
//
// Dependencies:
//   spi_slave_if.v, pcore_registers.v, up_axi.v, axi2spi_bridge.v
//
// Revision:
// Revision 0.1 - File Created
//
// Additional Comments:
//
//////////////////////////////////////////////////////////////////////////////////

module radio_hw #(
    parameter AXI_ADDRESS_WIDTH = 16
) (
    // reset and clocks
    input                               s_axi_aclk,
    input                               s_axi_aresetn,

    // axi4 interface
    input                               s_axi_awvalid,
    input   [(AXI_ADDRESS_WIDTH-1):0]   s_axi_awaddr,
    output                              s_axi_awready,
    input                               s_axi_wvalid,
    input   [31:0]                      s_axi_wdata,
    input   [ 3:0]                      s_axi_wstrb,
    output                              s_axi_wready,
    output                              s_axi_bvalid,
    output  [ 1:0]                      s_axi_bresp,
    input                               s_axi_bready,
    input                               s_axi_arvalid,
    input   [(AXI_ADDRESS_WIDTH-1):0]   s_axi_araddr,
    output                              s_axi_arready,
    output                              s_axi_rvalid,
    output  [ 1:0]                      s_axi_rresp,
    output  [31:0]                      s_axi_rdata,
    input                               s_axi_rready,

    // spi bus
    input                               sclk,
    input                               sdi,
    output                              sdo,
    input                               cs_n,

    // interrupt to internal processor
    output                              spi_mailbox_irq
);

    //--------------------------------------------------------------------------
    // Internal clock and reset
    //--------------------------------------------------------------------------
    wire up_rstn = s_axi_aresetn;
    wire up_clk  = s_axi_aclk;

    //--------------------------------------------------------------------------
    // up_if_1 — spi_slave_if ↔ pcore_registers  (higher priority)
    //--------------------------------------------------------------------------
    wire                                up_wreq1;
    wire  [(AXI_ADDRESS_WIDTH-3):0]     up_waddr1;
    wire  [31:0]                        up_wdata1;
    wire                                up_wack1;
    wire                                up_rreq1;
    wire  [(AXI_ADDRESS_WIDTH-3):0]     up_raddr1;
    wire  [31:0]                        up_rdata1;
    wire                                up_rack1;

    //--------------------------------------------------------------------------
    // up_if_2 — axi2spi_bridge ↔ pcore_registers  (lower priority)
    //--------------------------------------------------------------------------
    wire                                up_wreq2;
    wire  [(AXI_ADDRESS_WIDTH-3):0]     up_waddr2;
    wire  [31:0]                        up_wdata2;
    wire                                up_wack2;
    wire                                up_rreq2;
    wire  [(AXI_ADDRESS_WIDTH-3):0]     up_raddr2;
    wire  [31:0]                        up_rdata2;
    wire                                up_rack2;

    //==========================================================================
    // spi_slave_if — SPI slave translates SPI bus to up_if_1 handshake
    //==========================================================================
    spi_slave_if #(
        .AXI_ADDRESS_WIDTH(AXI_ADDRESS_WIDTH)
    ) i_spi_slave_if (
        .up_rstn   (up_rstn),
        .up_clk    (up_clk),
        .up_wreq   (up_wreq1),
        .up_waddr  (up_waddr1),
        .up_wdata  (up_wdata1),
        .up_wack   (up_wack1),
        .up_rreq   (up_rreq1),
        .up_raddr  (up_raddr1),
        .up_rdata  (up_rdata1),
        .up_rack   (up_rack1),
        .sclk      (sclk),
        .sdi       (sdi),
        .sdo       (sdo),
        .cs_n      (cs_n)
    );

    //==========================================================================
    // axi2spi_bridge — AXI-4 slave translates to up_if_2 handshake
    //   (internally instantiates up_axi for AXI->upstream conversion)
    //==========================================================================
    axi2spi_bridge #(
        .AXI_ADDRESS_WIDTH(AXI_ADDRESS_WIDTH)
    ) i_axi2spi_bridge (
        .up_rstn          (up_rstn),
        .up_clk           (up_clk),
        .up_axi_awvalid   (s_axi_awvalid),
        .up_axi_awaddr    (s_axi_awaddr),
        .up_axi_awready   (s_axi_awready),
        .up_axi_wvalid    (s_axi_wvalid),
        .up_axi_wdata     (s_axi_wdata),
        .up_axi_wstrb     (s_axi_wstrb),
        .up_axi_wready    (s_axi_wready),
        .up_axi_bvalid    (s_axi_bvalid),
        .up_axi_bresp     (s_axi_bresp),
        .up_axi_bready    (s_axi_bready),
        .up_axi_arvalid   (s_axi_arvalid),
        .up_axi_araddr    (s_axi_araddr),
        .up_axi_arready   (s_axi_arready),
        .up_axi_rvalid    (s_axi_rvalid),
        .up_axi_rresp     (s_axi_rresp),
        .up_axi_rdata     (s_axi_rdata),
        .up_axi_rready    (s_axi_rready),
        .up_wreq          (up_wreq2),
        .up_waddr         (up_waddr2),
        .up_wdata         (up_wdata2),
        .up_wack          (up_wack2),
        .up_rreq          (up_rreq2),
        .up_raddr         (up_raddr2),
        .up_rdata         (up_rdata2),
        .up_rack          (up_rack2)
    );

    //==========================================================================
    // pcore_registers — register file with dual upstream interfaces
    //   up_if_1 (from SPI) has priority over up_if_2 (from AXI)
    //==========================================================================
    pcore_registers #(
        .AXI_ADDRESS_WIDTH(AXI_ADDRESS_WIDTH)
    ) i_pcore_registers (
        .up_rstn           (up_rstn),
        .up_clk            (up_clk),
        .up_wreq1          (up_wreq1),
        .up_waddr1         (up_waddr1),
        .up_wdata1         (up_wdata1),
        .up_wack1          (up_wack1),
        .up_rreq1          (up_rreq1),
        .up_raddr1         (up_raddr1),
        .up_rdata1         (up_rdata1),
        .up_rack1          (up_rack1),
        .up_wreq2          (up_wreq2),
        .up_waddr2         (up_waddr2),
        .up_wdata2         (up_wdata2),
        .up_wack2          (up_wack2),
        .up_rreq2          (up_rreq2),
        .up_raddr2         (up_raddr2),
        .up_rdata2         (up_rdata2),
        .up_rack2          (up_rack2),
        .spi_mailbox_irq   (spi_mailbox_irq)
    );

endmodule
