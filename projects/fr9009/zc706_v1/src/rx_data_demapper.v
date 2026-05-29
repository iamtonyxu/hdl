`timescale 1ns / 1ps
//////////////////////////////////////////////////////////////////////////////////
// Company:
// Engineer:
//
// Create Date: 2024/10/24 14:40:11
// Design Name:
// Module Name: rx_demapper
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


module rx_data_demapper(
           input  clk,
           input  wire [127:0] rx_tdata_0,
           output reg [31:0] rx_lane_0,
           output reg [31:0] rx_lane_1,
           output reg [31:0] rx_lane_2,
           output reg [31:0] rx_lane_3
       );

always @(posedge clk) begin
    rx_lane_0 <= rx_tdata_0[31:0];
    rx_lane_1 <= rx_tdata_0[63:32];
    rx_lane_2 <= rx_tdata_0[95:64];
    rx_lane_3 <= rx_tdata_0[127:96];
end
endmodule
