`timescale 1ns / 1ps
//////////////////////////////////////////////////////////////////////////////////
// Company:
// Engineer:
//
// Create Date: 2024/10/24 10:44:21
// Design Name:
// Module Name: tx_data_source
// Project Name:
// Target Devices:
// Tool Versions:
// Description:
//
// Dependencies:
//
// Revision:
// Revision 0.01 - File Created
// Additional Comments:
//
//////////////////////////////////////////////////////////////////////////////////


module tx_data_source(
           input  clk,

           input  wire [1:0] dds_ctrl,
           input  wire [31:0] dds_pinc_0,
           input  wire [31:0] dds_poff_0,
           input  wire [31:0] dds_pinc_1,
           input  wire [31:0] dds_poff_1,

           input  wire [31:0] const_data_0,
           input  wire [31:0] const_data_1,

           input  wire [63:0] ddr_data,

           input  wire [1:0] src_sel,

           output reg [16:0] ch1_sample0_i,
           output reg [16:0] ch1_sample1_i,
           output reg [16:0] ch1_sample0_q,
           output reg [16:0] ch1_sample1_q,
           output reg [16:0] ch2_sample0_i,
           output reg [16:0] ch2_sample1_i,
           output reg [16:0] ch2_sample0_q,
           output reg [16:0] ch2_sample1_q
       );

// dds signal generation

wire  [31:0] ddsdata0;
wire  [31:0] ddsdata1;
wire  [31:0] ddsdata2;
wire  [31:0] ddsdata3;

dds_compiler_0 u0_dds_compiler (
                   .aclk(clk),                                  // input wire aclk
                   .s_axis_config_tvalid(dds_ctrl[0]),  // input wire s_axis_config_tvalid
                   .s_axis_config_tdata({32'b0,dds_pinc_0}),    // input wire [63 : 0] s_axis_config_tdata{POFF(61:32),PINC(29:0)}
                   .m_axis_data_tvalid(),      // output wire m_axis_data_tvalid
                   .m_axis_data_tdata(ddsdata0)        // output wire [31 : 0] m_axis_data_tdata
               );
dds_compiler_0 u1_dds_compiler (
                   .aclk(clk),
                   .s_axis_config_tvalid(dds_ctrl[0]),
                   .s_axis_config_tdata({dds_poff_0,dds_pinc_0}),
                   .m_axis_data_tvalid(),
                   .m_axis_data_tdata(ddsdata1)
               );

dds_compiler_0 u2_dds_compiler (
                   .aclk(clk),
                   .s_axis_config_tvalid(dds_ctrl[1]),
                   .s_axis_config_tdata({32'b0,dds_pinc_1}),
                   .m_axis_data_tvalid(),
                   .m_axis_data_tdata(ddsdata2)
               );
dds_compiler_0 u3_dds_compiler (
                   .aclk(clk),
                   .s_axis_config_tvalid(dds_ctrl[1]),
                   .s_axis_config_tdata({dds_poff_1,dds_pinc_1}),
                   .m_axis_data_tvalid(),
                   .m_axis_data_tdata(ddsdata3)
               );


always @(*) begin
    case (src_sel)
        2'b00: begin
            ch1_sample0_i = ddsdata0[15:0];
            ch1_sample0_q = ddsdata0[31:16];
            ch1_sample1_i = ddsdata1[15:0];
            ch1_sample1_q = ddsdata1[31:16];

            ch2_sample0_i = ddsdata2[15:0];
            ch2_sample0_q = ddsdata2[31:16];
            ch2_sample1_i = ddsdata3[15:0];
            ch2_sample1_q = ddsdata3[31:16];
        end
        2'b01: begin
            ch1_sample0_i = ddr_data[15:0];
            ch1_sample0_q = ddr_data[31:16];
            ch1_sample1_i = ddr_data[47:32];
            ch1_sample1_q = ddr_data[63:48];

            ch2_sample0_i = ddr_data[15:0];
            ch2_sample0_q = ddr_data[31:16];
            ch2_sample1_i = ddr_data[47:32];
            ch2_sample1_q = ddr_data[63:48];
        end
        2'b10,
        2'b11: begin
            ch1_sample0_i = const_data_0[15:0];
            ch1_sample0_q = const_data_0[31:16];
            ch1_sample1_i = const_data_1[15:0];
            ch1_sample1_q = const_data_1[31:16];

            ch2_sample0_i = const_data_0[15:0];
            ch2_sample0_q = const_data_0[31:16];
            ch2_sample1_i = const_data_1[15:0];
            ch2_sample1_q = const_data_1[31:16];
        end
    endcase
end


endmodule
