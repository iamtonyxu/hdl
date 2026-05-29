`timescale 1ns / 1ps
//////////////////////////////////////////////////////////////////////////////////
// Company:
// Engineer:
//
// Create Date: 2024/07/01 15:41:47
// Design Name:
// Module Name: read_ddr_data
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


module read_ddr_data(
           input                clk,
           input                w_tri_en,
           input                S_AXIS_MM2S_CMD_tready,
           input                M_AXIS_MM2S_STS_tvalid,

           output wire  [71:0]  S_AXIS_MM2S_CMD_tdata,
           output               S_AXIS_MM2S_CMD_tvalid,
           output               M_AXIS_MM2S_STS_tready,
           output			    m_axis_mm2s_tready

       );

assign  M_AXIS_MM2S_STS_tready = 1'b1;
assign m_axis_mm2s_tready = 1'b1;

reg r_S_AXIS_MM2S_CMD_tvalid = 'd0;
reg [31:0] r_addr_axi_base = 'h10000000;
reg [31:0] r_addr_axi = 'd0;

reg [1:0] r_tri_en_edge = 'd0;
always @(posedge clk) begin
    r_tri_en_edge <= {r_tri_en_edge[0],w_tri_en};
end

always @(posedge clk) begin
    if (r_tri_en_edge == 2'b01 & S_AXIS_MM2S_CMD_tready) begin
        r_S_AXIS_MM2S_CMD_tvalid <= 1'b1;
    end
    else begin
        if (S_AXIS_MM2S_CMD_tready&M_AXIS_MM2S_STS_tvalid) begin
            r_S_AXIS_MM2S_CMD_tvalid <= 1'b1;
        end
        else
            r_S_AXIS_MM2S_CMD_tvalid <= 1'b0;
    end
end

always @(posedge clk) begin
    if (M_AXIS_MM2S_STS_tvalid) begin
        if (r_addr_axi == 'd192) begin
            r_addr_axi <= 'd0;
        end
        else
            r_addr_axi <= r_addr_axi + 'd2048;
    end
end

wire [63:32]    w_SADDR;
wire [31:31]    w_DRR;
wire [30:30]    w_EOF;
wire [29:24]    w_DSA;
wire [23:23]    w_Type;
wire [22:0]     w_BTT;

assign w_SADDR = r_addr_axi + r_addr_axi_base;
assign w_DRR   = 'd0;
assign w_EOF   = 'd1;
assign w_DSA   = 'd0;
assign w_Type  = 'd1;
assign w_BTT   = 'd2048;

assign S_AXIS_MM2S_CMD_tdata = {
           8'd0,
           w_SADDR,
           w_DRR,
           w_EOF,
           w_DSA,
           w_Type,
           w_BTT
       };

assign S_AXIS_MM2S_CMD_tvalid = r_S_AXIS_MM2S_CMD_tvalid;
endmodule
