`timescale 1ns / 1ps
// p = (i^2 + q^2), latency is 5
module cpower_fixed#(
    parameter DATA_IN_WIDTH = 16
)
(
    input                               clk,
    input                               rst_n,
    input   signed [DATA_IN_WIDTH-1:0]  signal_i,
    input   signed [DATA_IN_WIDTH-1:0]  signal_q,
    output  signed [2*DATA_IN_WIDTH:0]  signal_p    
);

reg signed [2*DATA_IN_WIDTH-1:0] i2_reg1, i2_reg2, i2_reg3;
reg signed [2*DATA_IN_WIDTH-1:0] q2_reg1, q2_reg2, q2_reg3;
reg signed [2*DATA_IN_WIDTH:0] p_reg1, p_reg2;

// i2_reg1, i2_reg2, i2_reg3
always @(posedge clk or negedge rst_n)
    if(~rst_n) begin
        i2_reg1 <= 0;
        i2_reg2 <= 0;
        i2_reg3 <= 0;
    end
    else begin
        i2_reg1 <= signal_i * signal_i;
        i2_reg2 <= i2_reg1;
        i2_reg3 <= i2_reg2;
    end

// q2_reg1, q2_reg2, q2_reg3
always @(posedge clk or negedge rst_n)
    if(~rst_n) begin
        q2_reg1 <= 0;
        q2_reg2 <= 0;
        q2_reg3 <= 0;
    end
    else begin
        q2_reg1 <= signal_q * signal_q;
        q2_reg2 <= q2_reg1;
        q2_reg3 <= q2_reg2;
    end

// p_reg
always @(posedge clk or negedge rst_n)
    if(~rst_n) begin
        p_reg1 <= 0;
        p_reg2 <= 0;
    end
    else begin
        p_reg1 <= i2_reg3 + q2_reg3;
        p_reg2 <= p_reg1;
    end

assign signal_p = p_reg2;

endmodule