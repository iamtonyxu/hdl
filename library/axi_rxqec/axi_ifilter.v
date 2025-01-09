/*
* Parallel I-Filter
* Taps = 7, latency = 14 clk periods
* y[n] = x[n-3]h[3] + x[n-2]h[2] + x[n-1]h[1] + x[n]h[0] + x[n+1]h[1] + x[n+2]h[2] + x[n+3]h[3]
*/
`timescale 1ns/100ps
module axi_ifilter
(
    input   clk,
    input   rst_n,

    // Taps = 2*3 + 1 = 7
    input signed [15:0]h0,
    input signed [15:0]h1,
    input signed [15:0]h2,
    input signed [15:0]h3,

    input   [31:0]din,
    output  [31:0]dout

);

    reg signed [15:0] x0, x1, x2, x3, x4, x5, x6, x7;
    reg signed [31:0] am0_d1, am1_d1, am2_d1, am3_d1, am4_d1, am5_d1, am6_d1;
    reg signed [18:0] am0_d2, am1_d2, am2_d2, am3_d2, am4_d2, am5_d2, am6_d2;
    reg signed [18:0] am0_d3, am1_d3, am2_d3, am3_d3, am4_d3, am5_d3, am6_d3;
    reg signed [18:0] am0, am1, am2, am3, am4, am5, am6;

    reg signed [31:0] bm0_d1, bm1_d1, bm2_d1, bm3_d1, bm4_d1, bm5_d1, bm6_d1;
    reg signed [18:0] bm0_d2, bm1_d2, bm2_d2, bm3_d2, bm4_d2, bm5_d2, bm6_d2;
    reg signed [18:0] bm0_d3, bm1_d3, bm2_d3, bm3_d3, bm4_d3, bm5_d3, bm6_d3;
    reg signed [18:0] bm0, bm1, bm2, bm3, bm4, bm5, bm6;

    reg [15:0] ay, ayy, by;
    reg signed [18:0] ay_d1, ay_d2, ay_d3, ay_d4, ay_d5, ay_d6;
    reg signed [18:0] by_d1, by_d2, by_d3, by_d4, by_d5, by_d6;

    always@(posedge clk or negedge rst_n)
        if(~rst_n) begin
            x0 <= 0; x2 <= 0; x4 <= 0; x6 <= 0;
            x1 <= 0; x3 <= 0; x5 <= 0; x7 <= 0;
        end
        else begin
            x0 <= din[31:16]; x2 <= x0; x4 <= x2; x6 <= x4;
            x1 <= din[15:0];  x3 <= x1; x5 <= x3; x7 <= x5;
        end

    always@(posedge clk or negedge rst_n)
        if(~rst_n) begin
            am0_d1 <= 0; bm0_d1 <= 0; 
            am1_d1 <= 0; bm1_d1 <= 0;
            am2_d1 <= 0; bm2_d1 <= 0;
            am3_d1 <= 0; bm3_d1 <= 0;
            am4_d1 <= 0; bm4_d1 <= 0;
            am5_d1 <= 0; bm5_d1 <= 0;
            am6_d1 <= 0; bm6_d1 <= 0;
        end
        else begin
            am0_d1 <= x0*h3; bm0_d1 <= x1*h3; 
            am1_d1 <= x1*h2; bm1_d1 <= x2*h2;
            am2_d1 <= x2*h1; bm2_d1 <= x3*h1;
            am3_d1 <= x3*h0; bm3_d1 <= x4*h0;
            am4_d1 <= x4*h1; bm4_d1 <= x5*h1;
            am5_d1 <= x5*h2; bm5_d1 <= x6*h2;
            am6_d1 <= x6*h3; bm6_d1 <= x7*h3;
        end

    // am_delay, bm_delay
    always@(posedge clk) begin
        am0_d2 <= am0_d1[30:12]; am0_d3 <= am0_d2; am0 <= am0_d3;
        am1_d2 <= am1_d1[30:12]; am1_d3 <= am1_d2; am1 <= am1_d3;
        am2_d2 <= am2_d1[30:12]; am2_d3 <= am2_d2; am2 <= am2_d3;
        am3_d2 <= am3_d1[30:12]; am3_d3 <= am3_d2; am3 <= am3_d3;
        am4_d2 <= am4_d1[30:12]; am4_d3 <= am4_d2; am4 <= am4_d3;
        am5_d2 <= am5_d1[30:12]; am5_d3 <= am5_d2; am5 <= am5_d3;
        am6_d2 <= am6_d1[30:12]; am6_d3 <= am6_d2; am6 <= am6_d3;
        bm0_d2 <= bm0_d1[30:12]; bm0_d3 <= bm0_d2; bm0 <= bm0_d3;
        bm1_d2 <= bm1_d1[30:12]; bm1_d3 <= bm1_d2; bm1 <= bm1_d3;
        bm2_d2 <= bm2_d1[30:12]; bm2_d3 <= bm2_d2; bm2 <= bm2_d3;
        bm3_d2 <= bm3_d1[30:12]; bm3_d3 <= bm3_d2; bm3 <= bm3_d3;
        bm4_d2 <= bm4_d1[30:12]; bm4_d3 <= bm4_d2; bm4 <= bm4_d3;
        bm5_d2 <= bm5_d1[30:12]; bm5_d3 <= bm5_d2; bm5 <= bm5_d3;
        bm6_d2 <= bm6_d1[30:12]; bm6_d3 <= bm6_d2; bm6 <= bm6_d3;
    end

    always@(posedge clk or negedge rst_n)
        if(~rst_n) begin
            ay_d1 <= 0; by_d1 <= 0;
            ay_d2 <= 0; by_d2 <= 0;
            ay_d3 <= 0; by_d3 <= 0; 
            ay_d4 <= 0; by_d4 <= 0; 
            ay_d5 <= 0; by_d5 <= 0; 
            ay_d6 <= 0; by_d6 <= 0;
        end
        else begin
            ay_d1 <= am0 + am1 + am2 + am3 + am4 + am5 + am6;
            by_d1 <= bm0 + bm1 + bm2 + bm3 + bm4 + bm5 + bm6;
            ay_d2 <= ay_d1; ay_d3 <= ay_d2; ay_d4 <= ay_d3; ay_d5 <= ay_d4; ay_d6 <= ay_d5;
            by_d2 <= by_d1; by_d3 <= by_d2; by_d4 <= by_d3; by_d5 <= by_d4; by_d6 <= by_d5;           
        end

    always@(posedge clk or negedge rst_n)
        if(~rst_n) begin
            ay <= 0; ayy <= 0;
            by <= 0;
        end
        else begin
            ay <= ay_d6[18:3]; ayy <= ay;
            by <= by_d6[18:3];
        end

    assign dout = {by, ayy};

endmodule