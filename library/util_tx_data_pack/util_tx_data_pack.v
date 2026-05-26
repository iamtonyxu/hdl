`timescale 1ns / 1ps
//////////////////////////////////////////////////////////////////////////////////
// Company:
// Engineer: iamtony
//
// Create Date: 2026/04/29
// Design Name:
// Module Name: util_tx_data_pack
// Project Name:
// Target Devices:
// Tool Versions:
// Description: Top-level wrapper for sample generation and mapping.
//
// Dependencies: tx_data_source, tx_data_mapper.
//
// Revision:
// Revision 0.02 - Header refreshed.
// Additional Comments:
// Keeps source selection separate from JESD packing.
//////////////////////////////////////////////////////////////////////////////////

module util_tx_data_pack (
    input  wire         clk,
    input  wire         rstn,

    // interface to axi_fr9009_config
    input  wire [1:0]   src_sel,
    input  wire [31:0]  const_data_0,
    input  wire [31:0]  const_data_1,
    input  wire [1:0]   dds_ctrl,
    input  wire [31:0]  dds_pinc_0,
    input  wire [31:0]  dds_poff_0,
    input  wire [31:0]  dds_pinc_1,
    input  wire [31:0]  dds_poff_1,
    input  wire         frame_mapper_sel,

    // interface to axi4_stream_afifo
    input  wire [63:0]  afifo_ddr_data,
    input  wire         afifo_ddr_tvalid,

    // interface to jesd tx
    output wire [127:0] tx_tdata
);

    wire [15:0] ch1_sample0_i;
    wire [15:0] ch1_sample1_i;
    wire [15:0] ch1_sample0_q;
    wire [15:0] ch1_sample1_q;
    wire [15:0] ch2_sample0_i;
    wire [15:0] ch2_sample1_i;
    wire [15:0] ch2_sample0_q;
    wire [15:0] ch2_sample1_q;

tx_data_source i_tx_data_source (
    .clk              (clk),
    .dds_ctrl         (dds_ctrl),
    .dds_pinc_0       (dds_pinc_0),
    .dds_poff_0       (dds_poff_0),
    .dds_pinc_1       (dds_pinc_1),
    .dds_poff_1       (dds_poff_1),
    .const_data_0     (const_data_0),
    .const_data_1     (const_data_1),
    .ddr_data         (afifo_ddr_data),
    .src_sel          (src_sel),
    .ch1_sample0_i    (ch1_sample0_i),
    .ch1_sample1_i    (ch1_sample1_i),
    .ch1_sample0_q    (ch1_sample0_q),
    .ch1_sample1_q    (ch1_sample1_q),
    .ch2_sample0_i    (ch2_sample0_i),
    .ch2_sample1_i    (ch2_sample1_i),
    .ch2_sample0_q    (ch2_sample0_q),
    .ch2_sample1_q    (ch2_sample1_q)
);

tx_data_mapper i_tx_data_mapper (
    .clk           (clk),
    .sel           (frame_mapper_sel),
    .ch1_sample0_i (ch1_sample0_i),
    .ch1_sample1_i (ch1_sample1_i),
    .ch1_sample0_q (ch1_sample0_q),
    .ch1_sample1_q (ch1_sample1_q),
    .ch2_sample0_i (ch2_sample0_i),
    .ch2_sample1_i (ch2_sample1_i),
    .ch2_sample0_q (ch2_sample0_q),
    .ch2_sample1_q (ch2_sample1_q),
    .tx_tdata      (tx_tdata)
);

endmodule