`timescale 1ns / 1ps
//////////////////////////////////////////////////////////////////////////////////
// Company:
// Engineer: iamtony
//
// Create Date: 2026/04/29
// Design Name:
// Module Name: tx_data_mapper
// Project Name:
// Target Devices:
// Tool Versions:
// Description: JESD transmit sample mapper.
//
// Dependencies: None.
//
// Revision:
// Revision 0.02 - Header refreshed.
// Additional Comments:
// Keeps lane packing local to this block.
//////////////////////////////////////////////////////////////////////////////////


module tx_data_mapper (
    input               clk,
    input  wire [15:0]  ch1_sample0_i,
    input  wire [15:0]  ch1_sample0_q,
    input  wire [15:0]  ch1_sample1_i,
    input  wire [15:0]  ch1_sample1_q,
    input  wire [15:0]  ch2_sample0_i,
    input  wire [15:0]  ch2_sample0_q,
    input  wire [15:0]  ch2_sample1_i,
    input  wire [15:0]  ch2_sample1_q,
    input  wire         sel,
    output reg  [127:0] tx_tdata
);

reg [127:0] mapper_mode0_tdata;
reg [127:0] mapper_mode1_tdata;

// jesd tx mapper QI L=4,M=4,S=2 DAC = 491.52MHz
always @(posedge clk) begin
    mapper_mode0_tdata <= {ch1_sample1_q[7:0], ch1_sample1_q[15:8], ch1_sample0_q[7:0], ch1_sample0_q[15:8],  // fpga dac lane3 -> 3109 dac lane1
                           ch2_sample1_i[7:0], ch2_sample1_i[15:8], ch2_sample0_i[7:0], ch2_sample0_i[15:8],  // fpga dac lane2 -> 3109 dac lane2
                           ch2_sample1_q[7:0], ch2_sample1_q[15:8], ch2_sample0_q[7:0], ch2_sample0_q[15:8],  // fpga dac lane1 -> 3109 dac lane3
                           ch1_sample1_i[7:0], ch1_sample1_i[15:8], ch1_sample0_i[7:0], ch1_sample0_i[15:8]}; // fpga dac lane0 -> 3109 dac lane0
end

// jesd tx mapper QI L=2,M=4,S=1 DAC = 245.76MHz
always @(posedge clk) begin
    mapper_mode1_tdata <= {ch2_sample1_q[7:0], ch2_sample1_q[15:8], ch2_sample1_i[7:0], ch2_sample1_i[15:8],  // fpga dac lane3 -> 3109 dac lane1
                           32'b0,                                                                              // fpga dac lane2 -> 3109 dac lane2
                           32'b0,                                                                              // fpga dac lane1 -> 3109 dac lane3
                           ch1_sample0_q[7:0], ch1_sample0_q[15:8], ch1_sample0_i[7:0], ch1_sample0_i[15:8]}; // fpga dac lane0 -> 3109 dac lane0
end

always @(*) begin
    case (sel)
        1'b0: tx_tdata = mapper_mode0_tdata;
        1'b1: tx_tdata = mapper_mode1_tdata;
    endcase
end

endmodule
