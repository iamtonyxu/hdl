/*
* Parallel I-Filter
* Taps = 15, latency = 24 clk periods
*
*/
`timescale 1ns/100ps
module axi_qfilter
(
    input   clk,
    input   rst_n,
    
    // Taps = 2*7 + 1 = 15
    input signed [15:0]h0,
    input signed [15:0]h1,
    input signed [15:0]h2,
    input signed [15:0]h3,
    input signed [15:0]h4,
    input signed [15:0]h5,
    input signed [15:0]h6,
    input signed [15:0]h7,
    input signed [15:0]h8,
    input signed [15:0]h9,
    input signed [15:0]h10,
    input signed [15:0]h11,
    input signed [15:0]h12,
    input signed [15:0]h13,
    input signed [15:0]h14,

    input   [31:0]din,
    output  [31:0]dout

);

    reg signed [15:0] x0, x1, x2, x3, x4, x5, x6, x7, x8, x9, x10, x11, x12, x13, x14, x15;
    reg signed [31:0] am0_d1, am1_d1, am2_d1, am3_d1, am4_d1, am5_d1, am6_d1, am7_d1, am8_d1, am9_d1, am10_d1, am11_d1, am12_d1, am13_d1, am14_d1;
    reg signed [18:0] am0_d2, am1_d2, am2_d2, am3_d2, am4_d2, am5_d2, am6_d2, am7_d2, am8_d2, am9_d2, am10_d2, am11_d2, am12_d2, am13_d2, am14_d2;
    reg signed [18:0] am0_d3, am1_d3, am2_d3, am3_d3, am4_d3, am5_d3, am6_d3, am7_d3, am8_d3, am9_d3, am10_d3, am11_d3, am12_d3, am13_d3, am14_d3;
    reg signed [18:0] am0, am1, am2, am3, am4, am5, am6, am7, am8, am9, am10, am11, am12, am13, am14;

    reg signed [31:0] bm0_d1, bm1_d1, bm2_d1, bm3_d1, bm4_d1, bm5_d1, bm6_d1, bm7_d1, bm8_d1, bm9_d1, bm10_d1, bm11_d1, bm12_d1, bm13_d1, bm14_d1;
    reg signed [18:0] bm0_d2, bm1_d2, bm2_d2, bm3_d2, bm4_d2, bm5_d2, bm6_d2, bm7_d2, bm8_d2, bm9_d2, bm10_d2, bm11_d2, bm12_d2, bm13_d2, bm14_d2;
    reg signed [18:0] bm0_d3, bm1_d3, bm2_d3, bm3_d3, bm4_d3, bm5_d3, bm6_d3, bm7_d3, bm8_d3, bm9_d3, bm10_d3, bm11_d3, bm12_d3, bm13_d3, bm14_d3;
    reg signed [18:0] bm0, bm1, bm2, bm3, bm4, bm5, bm6, bm7, bm8, bm9, bm10, bm11, bm12, bm13, bm14;

    reg signed [15:0] ay, ayy, by;
    reg signed [18:0] ay_d1, ay_d2, ay_d3, ay_d4, ay_d5, ay_d6, ay_d7, ay_d8, ay_d9, ay_d10, ay_d11, ay_d12, ay_d13, ay_d14;
    reg signed [18:0] by_d1, by_d2, by_d3, by_d4, by_d5, by_d6, by_d7, by_d8, by_d9, by_d10, by_d11, by_d12, by_d13, by_d14;

    always@(posedge clk or negedge rst_n)
        if(~rst_n) begin
            x0 <= 0; x2 <= 0; x4 <= 0; x6 <= 0; x8 <= 0; x10 <= 0; x12 <= 0; x14 <= 0;
            x1 <= 0; x3 <= 0; x5 <= 0; x7 <= 0; x9 <= 0; x11 <= 0; x13 <= 0; x15 <= 0;
        end
        else begin
            x0 <= din[31:16]; x2 <= x0; x4 <= x2; x6 <= x4; x8 <= x6; x10 <= x8; x12 <= x10; x14 <= x12;
            x1 <= din[15:0];  x3 <= x1; x5 <= x3; x7 <= x5; x9 <= x7; x11 <= x9; x13 <= x11; x15 <= x13;
        end

    always@(posedge clk or negedge rst_n)
        if(~rst_n) begin
            am0_d1  <= 0; bm0_d1  <= 0; 
            am1_d1  <= 0; bm1_d1  <= 0;
            am2_d1  <= 0; bm2_d1  <= 0;
            am3_d1  <= 0; bm3_d1  <= 0;
            am4_d1  <= 0; bm4_d1  <= 0;
            am5_d1  <= 0; bm5_d1  <= 0;
            am6_d1  <= 0; bm6_d1  <= 0;
            am7_d1  <= 0; bm7_d1  <= 0; 
            am8_d1  <= 0; bm8_d1  <= 0;
            am9_d1  <= 0; bm9_d1  <= 0;
            am10_d1 <= 0; bm10_d1 <= 0;
            am11_d1 <= 0; bm11_d1 <= 0;
            am12_d1 <= 0; bm12_d1 <= 0;
            am13_d1 <= 0; bm13_d1 <= 0;
            am14_d1 <= 0; bm14_d1 <= 0;
        end
        else begin
            am0_d1  <= x0*h0;   bm0_d1  <= x1*h0;  
            am1_d1  <= x1*h1;   bm1_d1  <= x2*h1;  
            am2_d1  <= x2*h2;   bm2_d1  <= x3*h2;  
            am3_d1  <= x3*h3;   bm3_d1  <= x4*h3;  
            am4_d1  <= x4*h4;   bm4_d1  <= x5*h4;  
            am5_d1  <= x5*h5;   bm5_d1  <= x6*h5;  
            am6_d1  <= x6*h6;   bm6_d1  <= x7*h6;  
            am7_d1  <= x7*h7;   bm7_d1  <= x8*h7;  
            am8_d1  <= x8*h8;   bm8_d1  <= x9*h8;  
            am9_d1  <= x9*h9;   bm9_d1  <= x10*h9;  
            am10_d1 <= x10*h10; bm10_d1 <= x11*h10;
            am11_d1 <= x11*h11; bm11_d1 <= x12*h11;
            am12_d1 <= x12*h12; bm12_d1 <= x13*h12;
            am13_d1 <= x13*h13; bm13_d1 <= x14*h13;
            am14_d1 <= x14*h14; bm14_d1 <= x15*h14;
        end

    // am_delay, bm_delay
    always@(posedge clk) begin
        am0_d2  <= am0_d1[30:12];  am0_d3  <= am0_d2;  am0 <= am0_d3;
        am1_d2  <= am1_d1[30:12];  am1_d3  <= am1_d2;  am1 <= am1_d3;
        am2_d2  <= am2_d1[30:12];  am2_d3  <= am2_d2;  am2 <= am2_d3;
        am3_d2  <= am3_d1[30:12];  am3_d3  <= am3_d2;  am3 <= am3_d3;
        am4_d2  <= am4_d1[30:12];  am4_d3  <= am4_d2;  am4 <= am4_d3;
        am5_d2  <= am5_d1[30:12];  am5_d3  <= am5_d2;  am5 <= am5_d3;
        am6_d2  <= am6_d1[30:12];  am6_d3  <= am6_d2;  am6 <= am6_d3;
        am7_d2  <= am7_d1[30:12];  am7_d3  <= am7_d2;  am7 <= am7_d3;
        am8_d2  <= am8_d1[30:12];  am8_d3  <= am8_d2;  am8 <= am8_d3;
        am9_d2  <= am9_d1[30:12];  am9_d3  <= am9_d2;  am9 <= am9_d3;
        am10_d2 <= am10_d1[30:12]; am10_d3 <= am10_d2; am10 <= am10_d3;
        am11_d2 <= am11_d1[30:12]; am11_d3 <= am11_d2; am11 <= am11_d3;
        am12_d2 <= am12_d1[30:12]; am12_d3 <= am12_d2; am12 <= am12_d3;
        am13_d2 <= am13_d1[30:12]; am13_d3 <= am13_d2; am13 <= am13_d3;
        am14_d2 <= am14_d1[30:12]; am14_d3 <= am14_d2; am14 <= am14_d3;
        
        bm0_d2  <= bm0_d1[30:12];  bm0_d3  <= bm0_d2;  bm0  <= bm0_d3;
        bm1_d2  <= bm1_d1[30:12];  bm1_d3  <= bm1_d2;  bm1  <= bm1_d3;
        bm2_d2  <= bm2_d1[30:12];  bm2_d3  <= bm2_d2;  bm2  <= bm2_d3;
        bm3_d2  <= bm3_d1[30:12];  bm3_d3  <= bm3_d2;  bm3  <= bm3_d3;
        bm4_d2  <= bm4_d1[30:12];  bm4_d3  <= bm4_d2;  bm4  <= bm4_d3;
        bm5_d2  <= bm5_d1[30:12];  bm5_d3  <= bm5_d2;  bm5  <= bm5_d3;
        bm6_d2  <= bm6_d1[30:12];  bm6_d3  <= bm6_d2;  bm6  <= bm6_d3;
        bm7_d2  <= bm7_d1[30:12];  bm7_d3  <= bm7_d2;  bm7  <= bm7_d3;
        bm8_d2  <= bm8_d1[30:12];  bm8_d3  <= bm8_d2;  bm8  <= bm8_d3;
        bm9_d2  <= bm9_d1[30:12];  bm9_d3  <= bm9_d2;  bm9  <= bm9_d3;
        bm10_d2 <= bm10_d1[30:12]; bm10_d3 <= bm10_d2; bm10 <= bm10_d3;
        bm11_d2 <= bm11_d1[30:12]; bm11_d3 <= bm11_d2; bm11 <= bm11_d3;
        bm12_d2 <= bm12_d1[30:12]; bm12_d3 <= bm12_d2; bm12 <= bm12_d3;
        bm13_d2 <= bm13_d1[30:12]; bm13_d3 <= bm13_d2; bm13 <= bm13_d3;
        bm14_d2 <= bm14_d1[30:12]; bm14_d3 <= bm14_d2; bm14 <= bm14_d3;
    end

    always@(posedge clk or negedge rst_n)
        if(~rst_n) begin
            ay_d1  <= 0; by_d1  <= 0;
            ay_d2  <= 0; by_d2  <= 0;    
            ay_d3  <= 0; by_d3  <= 0; 
            ay_d4  <= 0; by_d4  <= 0; 
            ay_d5  <= 0; by_d5  <= 0; 
            ay_d6  <= 0; by_d6  <= 0;
            ay_d7  <= 0; by_d7  <= 0;
            ay_d8  <= 0; by_d8  <= 0;
            ay_d9  <= 0; by_d9  <= 0; 
            ay_d10 <= 0; by_d10 <= 0; 
            ay_d11 <= 0; by_d11 <= 0; 
            ay_d12 <= 0; by_d12 <= 0;
            ay_d13 <= 0; by_d13 <= 0; 
            ay_d14 <= 0; by_d14 <= 0;
        end
        else begin
            ay_d1 <= am0 + am1 + am2 + am3 + am4 + am5 + am6 + am7 + am8 + am9 + am10 + am11 + am12 + am13 + am14;
            by_d1 <= bm0 + bm1 + bm2 + bm3 + bm4 + bm5 + bm6 + bm7 + bm8 + bm9 + bm10 + bm11 + bm12 + bm13 + bm14;
            
            ay_d2  <= ay_d1;  by_d2  <= by_d1;
            ay_d3  <= ay_d2;  by_d3  <= by_d2;
            ay_d4  <= ay_d3;  by_d4  <= by_d3;
            ay_d5  <= ay_d4;  by_d5  <= by_d4;
            ay_d6  <= ay_d5;  by_d6  <= by_d5;
            ay_d6  <= ay_d5;  by_d6  <= by_d5;
            ay_d7  <= ay_d6;  by_d7  <= by_d6; 
            ay_d8  <= ay_d7;  by_d8  <= by_d7;
            ay_d9  <= ay_d8;  by_d9  <= by_d8;
            ay_d10 <= ay_d9;  by_d10 <= by_d9;
            ay_d11 <= ay_d10; by_d11 <= by_d10;
            ay_d12 <= ay_d11; by_d12 <= by_d11;
            ay_d13 <= ay_d12; by_d13 <= by_d12;
            ay_d14 <= ay_d13; by_d14 <= by_d13;
        end

    always@(posedge clk or negedge rst_n) 
        if(~rst_n) begin
            ay <= 0; ayy <= 0;
            by <= 0;
        end
        else begin
            ay <= ay_d14[18:3]; ayy <= ay;
            by <= by_d14[18:3];
        end

    assign dout = {by, ayy};

endmodule