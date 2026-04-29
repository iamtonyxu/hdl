`timescale 1ns / 1ps
//////////////////////////////////////////////////////////////////////////////////
// Company:
// Engineer: iamtony
//
// Create Date: 2026/04/29
// Design Name:
// Module Name: tx_data_source
// Project Name:
// Target Devices:
// Tool Versions:
// Description: Selects DDS, DDR, or constant samples.
//
// Dependencies: ad_dds.
//
// Revision:
// Revision 0.02 - Header refreshed.
// Additional Comments:
// DDS mode mirrors channel 1 into channel 2.
//////////////////////////////////////////////////////////////////////////////////

module tx_data_source (
    input               clk,
    input               rstn,
    input  wire         dds_sync,
    input  wire [15:0]  tone_1_scale,
    input  wire [15:0]  tone_1_freq_word,
    input  wire [15:0]  tone_2_scale,
    input  wire [15:0]  tone_2_freq_word,
    input  wire [31:0]  const_data_0,
    input  wire [31:0]  const_data_1,
    input  wire [63:0]  ddr_data,
    input  wire         ddr_tvalid,
    input  wire [1:0]   src_sel,
    output reg  [15:0]  ch1_sample0_i,
    output reg  [15:0]  ch1_sample1_i,
    output reg  [15:0]  ch1_sample0_q,
    output reg  [15:0]  ch1_sample1_q,
    output reg  [15:0]  ch2_sample0_i,
    output reg  [15:0]  ch2_sample1_i,
    output reg  [15:0]  ch2_sample0_q,
    output reg  [15:0]  ch2_sample1_q
);

localparam [15:0] DDS_ZERO = 16'h0000;
localparam [15:0] DDS_QUAD_OFFSET = 16'h4000;
localparam DDS_DISABLE = 0;
localparam DDS_DW = 16;
localparam PHASE_DW = 16;
localparam DDS_TYPE = 1;
localparam CORDIC_DW = 16;
localparam CORDIC_PHASE_DW = 15;
localparam CLK_RATIO = 1;

// DDS sample generation.

wire [15:0] ddsdata0_i;
wire [15:0] ddsdata0_q;
wire [15:0] ddsdata1_i;
wire [15:0] ddsdata1_q;

wire [15:0] tone_1_sample0_i_offset;
wire [15:0] tone_2_sample0_i_offset;
wire [15:0] tone_1_sample0_q_offset;
wire [15:0] tone_2_sample0_q_offset;
wire [15:0] tone_1_sample1_i_offset;
wire [15:0] tone_2_sample1_i_offset;
wire [15:0] tone_1_sample1_q_offset;
wire [15:0] tone_2_sample1_q_offset;

assign tone_1_sample0_i_offset = DDS_ZERO;
assign tone_2_sample0_i_offset = DDS_ZERO;
assign tone_1_sample0_q_offset = DDS_QUAD_OFFSET;
assign tone_2_sample0_q_offset = DDS_QUAD_OFFSET;
assign tone_1_sample1_i_offset = tone_1_freq_word;
assign tone_2_sample1_i_offset = tone_2_freq_word;
assign tone_1_sample1_q_offset = DDS_QUAD_OFFSET + tone_1_freq_word;
assign tone_2_sample1_q_offset = DDS_QUAD_OFFSET + tone_2_freq_word;

ad_dds #(
    .DISABLE          (DDS_DISABLE),
    .DDS_DW           (DDS_DW),
    .PHASE_DW         (PHASE_DW),
    .DDS_TYPE         (DDS_TYPE),
    .CORDIC_DW        (CORDIC_DW),
    .CORDIC_PHASE_DW  (CORDIC_PHASE_DW),
    .CLK_RATIO        (CLK_RATIO)
) u0_dds_i (
    .clk                (clk),
    .dac_dds_format     (1'b0),
    .dac_data_sync      (dds_sync),
    .dac_valid          (1'b1),
    .tone_1_scale       (tone_1_scale),
    .tone_2_scale       (tone_2_scale),
    .tone_1_init_offset (tone_1_sample0_i_offset),
    .tone_2_init_offset (tone_2_sample0_i_offset),
    .tone_1_freq_word   (tone_1_freq_word),
    .tone_2_freq_word   (tone_2_freq_word),
    .dac_dds_data       (ddsdata0_i)
);

ad_dds #(
    .DISABLE          (DDS_DISABLE),
    .DDS_DW           (DDS_DW),
    .PHASE_DW         (PHASE_DW),
    .DDS_TYPE         (DDS_TYPE),
    .CORDIC_DW        (CORDIC_DW),
    .CORDIC_PHASE_DW  (CORDIC_PHASE_DW),
    .CLK_RATIO        (CLK_RATIO)
) u0_dds_q (
    .clk                (clk),
    .dac_dds_format     (1'b0),
    .dac_data_sync      (dds_sync),
    .dac_valid          (1'b1),
    .tone_1_scale       (tone_1_scale),
    .tone_2_scale       (tone_2_scale),
    .tone_1_init_offset (tone_1_sample0_q_offset),
    .tone_2_init_offset (tone_2_sample0_q_offset),
    .tone_1_freq_word   (tone_1_freq_word),
    .tone_2_freq_word   (tone_2_freq_word),
    .dac_dds_data       (ddsdata0_q)
);

ad_dds #(
    .DISABLE          (DDS_DISABLE),
    .DDS_DW           (DDS_DW),
    .PHASE_DW         (PHASE_DW),
    .DDS_TYPE         (DDS_TYPE),
    .CORDIC_DW        (CORDIC_DW),
    .CORDIC_PHASE_DW  (CORDIC_PHASE_DW),
    .CLK_RATIO        (CLK_RATIO)
) u1_dds_i (
    .clk                (clk),
    .dac_dds_format     (1'b0),
    .dac_data_sync      (dds_sync),
    .dac_valid          (1'b1),
    .tone_1_scale       (tone_1_scale),
    .tone_2_scale       (tone_2_scale),
    .tone_1_init_offset (tone_1_sample1_i_offset),
    .tone_2_init_offset (tone_2_sample1_i_offset),
    .tone_1_freq_word   (tone_1_freq_word),
    .tone_2_freq_word   (tone_2_freq_word),
    .dac_dds_data       (ddsdata1_i)
);

ad_dds #(
    .DISABLE          (DDS_DISABLE),
    .DDS_DW           (DDS_DW),
    .PHASE_DW         (PHASE_DW),
    .DDS_TYPE         (DDS_TYPE),
    .CORDIC_DW        (CORDIC_DW),
    .CORDIC_PHASE_DW  (CORDIC_PHASE_DW),
    .CLK_RATIO        (CLK_RATIO)
) u1_dds_q (
    .clk                (clk),
    .dac_dds_format     (1'b0),
    .dac_data_sync      (dds_sync),
    .dac_valid          (1'b1),
    .tone_1_scale       (tone_1_scale),
    .tone_2_scale       (tone_2_scale),
    .tone_1_init_offset (tone_1_sample1_q_offset),
    .tone_2_init_offset (tone_2_sample1_q_offset),
    .tone_1_freq_word   (tone_1_freq_word),
    .tone_2_freq_word   (tone_2_freq_word),
    .dac_dds_data       (ddsdata1_q)
);

always @(posedge clk) begin
    if (~rstn) begin
        ch1_sample0_i <= 16'b0;
        ch1_sample1_i <= 16'b0;
        ch1_sample0_q <= 16'b0;
        ch1_sample1_q <= 16'b0;
        ch2_sample0_i <= 16'b0;
        ch2_sample1_i <= 16'b0;
        ch2_sample0_q <= 16'b0;
        ch2_sample1_q <= 16'b0;
    end else begin
        case (src_sel)
            2'b00: begin
                ch1_sample0_i <= ddsdata0_i;
                ch1_sample1_i <= ddsdata1_i;
                ch1_sample0_q <= ddsdata0_q;
                ch1_sample1_q <= ddsdata1_q;

                ch2_sample0_i <= ddsdata0_i;
                ch2_sample1_i <= ddsdata1_i;
                ch2_sample0_q <= ddsdata0_q;
                ch2_sample1_q <= ddsdata1_q;
            end

            2'b01: begin
                if (ddr_tvalid) begin
                    ch1_sample0_i <= ddr_data[15:0];
                    ch1_sample0_q <= ddr_data[31:16];
                    ch1_sample1_i <= ddr_data[47:32];
                    ch1_sample1_q <= ddr_data[63:48];

                    ch2_sample0_i <= ddr_data[15:0];
                    ch2_sample0_q <= ddr_data[31:16];
                    ch2_sample1_i <= ddr_data[47:32];
                    ch2_sample1_q <= ddr_data[63:48];
                end else begin
                    ch1_sample0_i <= 16'h12;
                    ch1_sample0_q <= 16'h34;
                    ch1_sample1_i <= 16'h56;
                    ch1_sample1_q <= 16'h78;

                    ch2_sample0_i <= 16'h9a;
                    ch2_sample0_q <= 16'hbc;
                    ch2_sample1_i <= 16'hde;
                    ch2_sample1_q <= 16'hf0;
                end
            end

            2'b10,
            2'b11: begin
                ch1_sample0_i <= const_data_0[15:0];
                ch1_sample0_q <= const_data_0[31:16];
                ch1_sample1_i <= const_data_1[15:0];
                ch1_sample1_q <= const_data_1[31:16];

                ch2_sample0_i <= const_data_0[15:0];
                ch2_sample0_q <= const_data_0[31:16];
                ch2_sample1_i <= const_data_1[15:0];
                ch2_sample1_q <= const_data_1[31:16];
            end
        endcase
    end
end

endmodule
