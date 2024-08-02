`timescale 1ns / 1ps
`define EXTRA_BITS 3

module cadder8#(
    parameter DWIDTH = 16
)
(
    input clk,
    input rst_n,
    input din_enable,
    output dout_valid,
    input [DWIDTH*2-1:0] din0, // {din0_i, din0_q}
    input [DWIDTH*2-1:0] din1, // {din1_i, din1_q}
    input [DWIDTH*2-1:0] din2, // {din2_i, din2_q}
    input [DWIDTH*2-1:0] din3, // {din3_i, din3_q}
    input [DWIDTH*2-1:0] din4, // {din4_i, din4_q}
    input [DWIDTH*2-1:0] din5, // {din5_i, din5_q}
    input [DWIDTH*2-1:0] din6, // {din6_i, din6_q}
    input [DWIDTH*2-1:0] din7, // {din7_i, din7_q}
    output [(DWIDTH+`EXTRA_BITS)*2-1:0] dout // {dout_i, dout_q}
);

    wire signed [DWIDTH-1:0] din0_i,din1_i,din2_i,din3_i,din4_i,din5_i,din6_i,din7_i;
    wire signed [DWIDTH-1:0] din0_q,din1_q,din2_q,din3_q,din4_q,din5_q,din6_q,din7_q;
    wire signed [DWIDTH+`EXTRA_BITS-1:0] dout_i, dout_q;
    
    assign din0_i = din0[DWIDTH*2-1:DWIDTH*1];
    assign din0_q = din0[DWIDTH-1:0];
    assign din1_i = din1[DWIDTH*2-1:DWIDTH*1];
    assign din1_q = din1[DWIDTH-1:0];
    assign din2_i = din2[DWIDTH*2-1:DWIDTH*1];
    assign din2_q = din2[DWIDTH-1:0];
    assign din3_i = din3[DWIDTH*2-1:DWIDTH*1];
    assign din3_q = din3[DWIDTH-1:0];
    assign din4_i = din4[DWIDTH*2-1:DWIDTH*1];
    assign din4_q = din4[DWIDTH-1:0];
    assign din5_i = din5[DWIDTH*2-1:DWIDTH*1];
    assign din5_q = din5[DWIDTH-1:0];
    assign din6_i = din6[DWIDTH*2-1:DWIDTH*1];
    assign din6_q = din6[DWIDTH-1:0];
    assign din7_i = din7[DWIDTH*2-1:DWIDTH*1];
    assign din7_q = din7[DWIDTH-1:0];

    assign dout = {dout_i, dout_q};

    adder8#(
        .DWIDTH(DWIDTH)
    )adder_i
    (
        .clk(clk),
        .rst_n(rst_n),
        .din_enable(din_enable),
        .dout_valid(dout_valid),
        .din0(din0_i),
        .din1(din1_i),
        .din2(din2_i),
        .din3(din3_i),
        .din4(din4_i),
        .din5(din5_i),
        .din6(din6_i),
        .din7(din7_i),
        .dout(dout_i)
    );

    adder8#(
        .DWIDTH(DWIDTH)
    )adder_q
    (
        .clk(clk),
        .rst_n(rst_n),
        .din_enable(din_enable),
        .dout_valid(),
        .din0(din0_q),
        .din1(din1_q),
        .din2(din2_q),
        .din3(din3_q),
        .din4(din4_q),
        .din5(din5_q),
        .din6(din6_q),
        .din7(din7_q),
        .dout(dout_q)
    );

endmodule


module adder8#(
    parameter DWIDTH = 16
)
(
    input clk,
    input rst_n,
    input din_enable,
    output dout_valid,
    input signed [DWIDTH-1:0] din0,
    input signed [DWIDTH-1:0] din1,
    input signed [DWIDTH-1:0] din2,
    input signed [DWIDTH-1:0] din3,
    input signed [DWIDTH-1:0] din4,
    input signed [DWIDTH-1:0] din5,
    input signed [DWIDTH-1:0] din6,
    input signed [DWIDTH-1:0] din7,
    output signed [DWIDTH+`EXTRA_BITS-1:0] dout
    );

    localparam BWIDTH = DWIDTH+`EXTRA_BITS;
    
    wire signed [DWIDTH-1:0] din2_delay,din3_delay,din4_delay,din5_delay,din6_delay,din7_delay;
    reg signed [BWIDTH-1:0] sum1, sum2, sum3, sum4, sum5, sum6, sum7; 

    assign dout = sum7;

    //sum1-7
    always@(posedge clk or negedge rst_n)
        if(~rst_n) begin
            sum1 <= 0;
            sum2 <= 0;
            sum3 <= 0;
            sum4 <= 0;
            sum5 <= 0;
            sum6 <= 0;
            sum7 <= 0;
        end
        else begin
            sum1 <= din0 + din1;
            sum2 <= sum1 + din2_delay;
            sum3 <= sum2 + din3_delay;
            sum4 <= sum3 + din4_delay;
            sum5 <= sum4 + din5_delay;
            sum6 <= sum5 + din6_delay;
            sum7 <= sum6 + din7_delay;
        end

        delay #(
            .TAPS(2-1),
            .DWIDTH(DWIDTH)
        )d1
        (
            .clk(clk),
            .din(din2),
            .dout(din2_delay)
        );

        delay #(
            .TAPS(3-1),
            .DWIDTH(DWIDTH)
        )d2
        (
            .clk(clk),
            .din(din3),
            .dout(din3_delay)
        );

        delay #(
            .TAPS(4-1),
            .DWIDTH(DWIDTH)
        )d3
        (
            .clk(clk),
            .din(din4),
            .dout(din4_delay)
        );
        
        delay #(
            .TAPS(5-1),
            .DWIDTH(DWIDTH)
        )d4
        (
            .clk(clk),
            .din(din5),
            .dout(din5_delay)
        );

        delay #(
            .TAPS(6-1),
            .DWIDTH(DWIDTH)
        )d5
        (
            .clk(clk),
            .din(din6),
            .dout(din6_delay)
        );

        delay #(
            .TAPS(7-1),
            .DWIDTH(DWIDTH)
        )d6
        (
            .clk(clk),
            .din(din7),
            .dout(din7_delay)
        );

        delay #(
            .TAPS(7),
            .DWIDTH(1)
        )d7
        (
            .clk(clk),
            .din(din_enable),
            .dout(dout_valid)
        );

endmodule

