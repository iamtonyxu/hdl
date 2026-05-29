`timescale 1ns / 1ps
//////////////////////////////////////////////////////////////////////////////////
// Company:
// Engineer:
//
// Create Date: 2024/10/11 10:10:13
// Design Name:
// Module Name: data2fpga
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


module data2fpga(
           input  clk,
           input  rstn,
           input  wire ctrl,        // enable play
           input  wire [31:0] cfg,  //config play data length, [31] = 1 enable, [22:0] = data length bytes
           // datamover cmd
           input  wire s_axis_mm2s_cmd_tready,

           output reg s_axis_mm2s_cmd_tvalid,
           output  wire [71:0] s_axis_mm2s_cmd_tdata,
           output wire m_axis_mm2s_sts_tready,

           input  wire m_axis_mm2s_tlast,
           output wire m_axis_tready
           //    output reg continue_flag

       );

reg [1:0] ctrl_dly;
wire start_edge;

always @(negedge clk ) begin
    ctrl_dly[0] <= ctrl;
    ctrl_dly[1] <= ctrl_dly[0];
end

assign start_edge = (ctrl_dly == 2'b01)?(1'b1):(1'b0);

wire [63:32]    w_SADDR;
wire [31:31]    w_DRR;
wire [30:30]    w_EOF;
wire [29:24]    w_DSA;
wire [23:23]    w_Type;
reg  [22:0]     w_BTT;

assign w_SADDR = 'h3f000000;
assign w_DRR   = 'd0;
assign w_EOF   = 'd1;
assign w_DSA   = 'd0;
assign w_Type  = 'd1;
// assign w_BTT   = 'd4096; //1024*4

always @(posedge clk or negedge rstn) begin
    if (!rstn) begin
        w_BTT <= 'd32768;
    end
    else if(cfg[31]==1) begin
        w_BTT <= cfg[22:0];
    end
end


assign s_axis_mm2s_cmd_tdata  = {
           8'd0,
           w_SADDR,
           w_DRR,
           w_EOF,
           w_DSA,
           w_Type,
           w_BTT
       };

reg [22:0] clk_cnt;

reg start_flag;
always @(posedge clk or negedge rstn) begin
    if (!rstn) begin
        start_flag <= 1'b0;
        clk_cnt <= 'd0;
    end
    else if (start_edge) begin
        start_flag <= 1'b1;
    end
    else if(start_flag == 1) begin
        clk_cnt <= clk_cnt + 1'b1;
        if(clk_cnt == (w_BTT>>3)) begin
            clk_cnt <= 'd0;
        end
    end
end

always @(posedge clk) begin
    if ((clk_cnt == ((w_BTT>>3)- 'd256)) && s_axis_mm2s_cmd_tready) begin
        s_axis_mm2s_cmd_tvalid <= 1'b1;
    end
    else begin
        s_axis_mm2s_cmd_tvalid <= 1'b0;
    end
end


// reg [2:0] temp_cnt;
// always @(posedge clk or negedge rstn) begin
//     if (!rstn) begin
//         s_axis_mm2s_cmd_tvalid <= 1'b0;
//     end
//     else if(start_edge|continue_flag) begin
//         temp_cnt <= temp_cnt + 1'b1;
//     end
//     else if(temp_cnt == 1 && s_axis_mm2s_cmd_tready) begin
//         s_axis_mm2s_cmd_tvalid <= 1'b1;
//         temp_cnt <= temp_cnt + 1'b1;
//     end
//     else if(temp_cnt == 2) begin
//         s_axis_mm2s_cmd_tvalid <= 1'b0;
//         temp_cnt <= 0;
//     end
// end


assign m_axis_mm2s_sts_tready = 1'b1;

assign m_axis_tready = 1'b1;


endmodule
