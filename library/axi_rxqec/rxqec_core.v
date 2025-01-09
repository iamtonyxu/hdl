/*
*   rxqec_core
*   Latency = 25 clk periods
*/
`timescale 1ns/100ps
module rxqec_core
(
    input   clk,
    input   rst_n,
    
    input   [31:0] din_i,
    input   [31:0] din_q,
    output  [31:0] dout_i,
    output  [31:0] dout_q,
    
    // ITaps = 2*3 + 1 = 7
    input signed [15:0]hi0,
    input signed [15:0]hi1,
    input signed [15:0]hi2,
    input signed [15:0]hi3,

    // QTaps = 2*7 + 1 = 15
    input signed [15:0]hq0,
    input signed [15:0]hq1,
    input signed [15:0]hq2,
    input signed [15:0]hq3,
    input signed [15:0]hq4,
    input signed [15:0]hq5,
    input signed [15:0]hq6,
    input signed [15:0]hq7,

    output [31:0] debug_bus
);
    localparam LATENCY = 25;
    localparam GAP_DELAY = 10;

    wire [31:0] qfir_out;
    wire [31:0] ifir_out, ifir_outd;
    wire signed [15:0] qfir_out1, qfir_out2;
    wire signed [15:0] ifir_out1, ifir_out2;
    reg signed [16:0] qfir_out1d, qfir_out2d;

    axi_qfilter qfir
    (
        .clk(clk),
        .rst_n(rst_n),
        .h0(hq0),
        .h1(hq1),
        .h2(hq2),
        .h3(hq3),
        .h4(hq4),
        .h5(hq5),
        .h6(hq6),
        .h7(hq7),
        .din(din_q),
        .dout(qfir_out)
    );
    assign qfir_out1 = qfir_out[15:0];
    assign qfir_out2 = qfir_out[31:16];

    axi_ifilter ifir
    (
        .clk(clk),
        .rst_n(rst_n),
        .h0(hi0),
        .h1(hi1),
        .h2(hi2),
        .h3(hi3),
        .din(din_i),
        .dout(ifir_out)
    );

    delay #(
        .TAPS(GAP_DELAY),
        .DWIDTH(32)
    )delay_block1
    (
        .clk(clk),
        .din(ifir_out),
        .dout(ifir_outd)
    );
    assign ifir_out1 = ifir_outd[15:0];
    assign ifir_out2 = ifir_outd[31:16];

    always@(posedge clk or negedge rst_n)
        if(~rst_n) begin
            qfir_out1d <= 0;
            qfir_out2d <= 0;
        end
        else begin
            qfir_out1d <= qfir_out1 + ifir_out1;
            qfir_out2d <= qfir_out2 + ifir_out2;
        end
    
    assign dout_q = {qfir_out2d[15:0], qfir_out1d[15:0]};

    delay #(
        .TAPS(LATENCY),
        .DWIDTH(32)
    )delay_block2
    (
        .clk(clk),
        .din(din_i),
        .dout(dout_i)
    );
    
    assign debug_bus = 0; // reserved
    
endmodule