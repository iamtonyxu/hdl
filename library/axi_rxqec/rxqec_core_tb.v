`timescale 1ns/100ps
module rxqec_core_tb;

    localparam CLK_PERIOD = 10;
    localparam DATA_LENGTH = 512;
    localparam QFIR_TAPS = 15;
    localparam IFIR_TAPS = 7;

    reg clk;
    reg rst_n;
    integer fileID, ii;
    reg done;

    reg   [31:0] din_i;
    reg   [31:0] din_q;
    wire  [31:0] dout_i;
    wire  [31:0] dout_q;
    
    reg signed [15:0]hi0;
    reg signed [15:0]hi1;
    reg signed [15:0]hi2;
    reg signed [15:0]hi3;
    reg signed [15:0]hi4;
    reg signed [15:0]hi5;
    reg signed [15:0]hi6;

    reg signed [15:0]hq0;
    reg signed [15:0]hq1;
    reg signed [15:0]hq2;
    reg signed [15:0]hq3;
    reg signed [15:0]hq4;
    reg signed [15:0]hq5;
    reg signed [15:0]hq6;
    reg signed [15:0]hq7;
    reg signed [15:0]hq8;
    reg signed [15:0]hq9;
    reg signed [15:0]hq10;
    reg signed [15:0]hq11;
    reg signed [15:0]hq12;
    reg signed [15:0]hq13;
    reg signed [15:0]hq14;
    
    reg [31:0] mem_din_i[0:DATA_LENGTH-1];
    reg [31:0] mem_din_q[0:DATA_LENGTH-1];
    reg [31:0] mem_dout_i[0:DATA_LENGTH-1];
    reg [31:0] mem_dout_q[0:DATA_LENGTH-1];
    reg [15:0] mem_hq[0:QFIR_TAPS-1];
    reg [15:0] mem_hi[0:IFIR_TAPS-1];

    // clk
    initial begin
        clk = 1;
        forever #(CLK_PERIOD/2) clk = ~clk;
    end

    //rst_n
    initial begin
        rst_n = 0;
        $readmemh("mt_din_i.txt", mem_din_i);
        $readmemh("mt_din_q.txt", mem_din_q);
        $readmemh("mt_hq.txt", mem_hq);
        $readmemh("mt_hi.txt", mem_hi);

        #100;
        rst_n = 1;
    end
    
    // filter coeffs
    initial begin
        hq0 = 0; hi0 = 0;
        hq1 = 0; hi1 = 0;
        hq2 = 0; hi2 = 0;
        hq3 = 0; hi3 = 0;
        hq4 = 0; hi4 = 0;
        hq5 = 0; hi5 = 0;
        hq6 = 0; hi6 = 0;
        hq7 = 0;
        hq8 = 0;
        hq9 = 0;
        hq10 = 0;
        hq11 = 0;
        hq12 = 0;
        hq13 = 0;
        hq14 = 0;

        wait (rst_n == 1);
        hq0 = mem_hq[0]; hi0 = mem_hi[0];
        hq1 = mem_hq[1]; hi1 = mem_hi[1];
        hq2 = mem_hq[2]; hi2 = mem_hi[2];
        hq3 = mem_hq[3]; hi3 = mem_hi[3];
        hq4 = mem_hq[4]; hi4 = mem_hi[4];
        hq5 = mem_hq[5]; hi5 = mem_hi[5];
        hq6 = mem_hq[6]; hi6 = mem_hi[6];
        hq7 = mem_hq[7];
        hq8 = mem_hq[8];
        hq9 = mem_hq[9];
        hq10 =mem_hq[10];
        hq11 =mem_hq[11];
        hq12 =mem_hq[12];
        hq13 =mem_hq[13];
        hq14 =mem_hq[14];
    end

    // data input
    initial begin
        din_i = 0;
        din_q = 0;
        wait (rst_n == 1);
        for(ii = 0; ii < DATA_LENGTH; ii = ii + 1) begin
            din_i = mem_din_i[ii];
            din_q = mem_din_q[ii];
            //din_i = 32'h2222_1111;
            //din_q = 32'h4444_3333;
            @(posedge clk);
        end
        done = 1;

    end

rxqec_core dut
(
    .clk(clk),
    .rst_n(rst_n),
    .din_i(din_i),
    .din_q(din_q),
    .dout_i(dout_i),
    .dout_q(dout_q),
    .hi0(hi0),
    .hi1(hi1),
    .hi2(hi2),
    .hi3(hi3),
    .hi4(hi4),
    .hi5(hi5),
    .hi6(hi6),

    .hq0(hq0),
    .hq1(hq1),
    .hq2(hq2),
    .hq3(hq3),
    .hq4(hq4),
    .hq5(hq5),
    .hq6(hq6),
    .hq7(hq7),
    .hq8(hq8),
    .hq9(hq9),
    .hq10(hq10),
    .hq11(hq11),
    .hq12(hq12),
    .hq13(hq13),
    .hq14(hq14),
    .debug_bus()
);

endmodule
