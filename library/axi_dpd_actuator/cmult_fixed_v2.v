`timescale 1ns / 1ps
//////////////////////////////////////////////////////////////////////////////////
// Company: 
// Engineer: 
// 
// Create Date: 2024/06/05
// Design Name: 
// Module Name: cmult_fixed
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
// latency = 6
//////////////////////////////////////////////////////////////////////////////////

module cmult_fixed_v2 #
(
    parameter AWIDTH = 16,
    parameter BWIDTH = 16,
    parameter CWIDTH = 32
)
(
    input clk,
    input rst_n,
    input [AWIDTH*2-1:0] dina, // {dina_i, dina_q}
    input [BWIDTH*2-1:0] dinb, // {dinb_i, dinb_q}
    output [CWIDTH*2-1:0] doutp// {doutp_i, doutp_q}
    );

wire signed [AWIDTH-1:0] ar;
wire signed [AWIDTH-1:0] ai;
wire signed [BWIDTH-1:0] br;
wire signed [BWIDTH-1:0] bi;
wire signed [CWIDTH-1:0] pr;
wire signed [CWIDTH-1:0] pi;

reg signed [AWIDTH-1:0]	ai_d, ai_dd, ai_ddd, ai_dddd;
reg signed [AWIDTH-1:0]	ar_d, ar_dd, ar_ddd, ar_dddd;
reg signed [BWIDTH-1:0]	bi_d, bi_dd, bi_ddd, br_d, br_dd, br_ddd;
reg signed [AWIDTH-1:0]		addcommon;
reg signed [BWIDTH-1:0]		addr, addi;
reg signed [CWIDTH-1:0]	mult0, multr, multi, pr_int, pi_int;
reg signed [CWIDTH-1:0]	common, commonr1, commonr2;

assign ar = dina[AWIDTH*2-1:AWIDTH];
assign ai = dina[AWIDTH-1:0];
assign br = dinb[BWIDTH*2-1:BWIDTH];
assign bi = dinb[BWIDTH-1:0];

assign doutp = {pr, pi};

always @(posedge clk)
    if(~rst_n) begin
        ar_d   <= 0;
        ar_dd  <= 0;
        ai_d   <= 0;
        ai_dd  <= 0;
        br_d   <= 0;
        br_dd  <= 0;
        br_ddd <= 0;
        bi_d   <= 0;
        bi_dd  <= 0;
        bi_ddd <= 0;
    end
    else begin
        ar_d   <= ar;
        ar_dd  <= ar_d;
        ai_d   <= ai;
        ai_dd  <= ai_d;
        br_d   <= br;
        br_dd  <= br_d;
        br_ddd <= br_dd;
        bi_d   <= bi;
        bi_dd  <= bi_d;
        bi_ddd <= bi_dd;
    end

// Common factor (ar ai) x bi, shared for the calculations of the real and imaginary final products
always @(posedge clk)
    begin
        addcommon <= ar_d - ai_d;
        mult0     <= addcommon * bi_dd;
        common    <= mult0;
    end

// Real product
always @(posedge clk)
    begin
        ar_ddd   <= ar_dd;
        ar_dddd  <= ar_ddd;
        addr     <= br_ddd - bi_ddd;
        multr    <= addr * ar_dddd;
        commonr1 <= common;
        pr_int   <= multr + commonr1;
    end

   // Imaginary product
always @(posedge clk)
    begin
        ai_ddd   <= ai_dd;
        ai_dddd  <= ai_ddd;
        addi     <= br_ddd + bi_ddd;
        multi    <= addi * ai_dddd;
        commonr2 <= common;
        pi_int   <= multi + commonr2;
    end

assign pr = pr_int;
assign pi = pi_int;

endmodule