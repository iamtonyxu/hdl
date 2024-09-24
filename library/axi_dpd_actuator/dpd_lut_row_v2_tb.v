`timescale 1ns / 1ps
`define EXTRA_BITS 4

module dpd_lut_row_v2_tb;

    localparam ID_MASK = 64'hFFFF_FFFF_FFFF_FFFF;
    parameter J_DELAY = 0;
    parameter I_DELAY_MAX = 8;
    parameter J_DELAY_MAX = 8;
    localparam DATA_WIDTH = 32;
    localparam ADDR_WIDTH = 3;

    localparam CLK_PERIOD = 10;

    // configuration port
    reg                         clk;
    reg                         rst_n;
    reg   [ADDR_WIDTH-1:0]    mag_odd; // 0, 2, 4 ...
    reg   [ADDR_WIDTH-1:0]    mag_even;// 1, 3, 5 ...
    wire  [DATA_WIDTH-1+`EXTRA_BITS*2:0] hout_odd;
    wire  [DATA_WIDTH-1+`EXTRA_BITS*2:0] hout_even;

    reg                         enc;
    reg     [I_DELAY_MAX-1:0]   lutIdc;
    reg                         wec;
    reg     [ADDR_WIDTH-1:0]    addrc;
    reg     [DATA_WIDTH-1:0]    dinc;
    wire    [DATA_WIDTH-1:0]    doutc;

    // internal signal
    integer                     i;
    integer                     lut_id;
    reg     [DATA_WIDTH-1:0]    lut_dout;

task free_lut; 
    begin
        enc = 0;
        wec = 0;
        addrc = 0;
        dinc = 0;
    end
endtask

task read_lut;
    input [ADDR_WIDTH-1:0]    lut_addr;
    output [DATA_WIDTH-1:0]   lut_dout;
    begin
        @(posedge clk);
        enc = 1;
        wec = 0;
        addrc = lut_addr;
        @(posedge clk);
        @(posedge clk);
        @(posedge clk); // 1 more period latency than dpd_lut_v2
        lut_dout = doutc;
        enc = 0;
        wec = 0;
    end
endtask

task write_lut;
    input [ADDR_WIDTH-1:0]    lut_addr;
    input [DATA_WIDTH-1:0]    lut_din;
    begin
        @(posedge clk);
        enc = 1;
        wec = 1;
        addrc = lut_addr;
        dinc = lut_din;
        @(posedge clk);
        enc = 0;
        wec = 0;
        addrc = 0;
        dinc = 0;
    end
endtask

    // clk
    initial begin
        clk = 1;
        forever #(CLK_PERIOD/2) clk = ~clk;
    end

    //rst_n
    initial begin
        rst_n = 0;
        #100
        rst_n = 1;
    end

    // test procedures
    // 1. write luts with known patterns
    // 2. read luts and check entries correct
    // 3. input mag_odd/mag_even and check hout_odd/hout_even correct
    // 4. report result
    initial begin
        // free luts
        free_lut;
        lutIdc = 0;
        wait(rst_n == 1);
        #100;

        for(lut_id = 0; lut_id < 8; lut_id = lut_id + 1) begin
            // select lut
            lutIdc = 2**lut_id;

            // write luts
            for(i = 0; i < 2**ADDR_WIDTH; i = i+1) begin
                write_lut(i, 32'h1111_1111 * i);
            end

            // free luts
            free_lut;

            #100;
            // read luts
            for(i = 0; i < 2**ADDR_WIDTH; i = i+1) begin
                read_lut(i, lut_dout);
            end
            #100;
        end
        i = 0;

        // free luts
        free_lut;
        lutIdc = 0;
        #100;

        // mag_even and mag_odd with fixed value
        mag_even = 1;
        mag_odd = 2;
        #1000;

        // mag_even and mag_odd with fixed value
        mag_even = 1;
        mag_odd = 1;
        #1000;

        // mag_even and mag_odd with varied value
        for(i = 0; i < 1000; i = i+1) begin
            @(posedge clk);
            mag_even = i & (2**ADDR_WIDTH-1);
            mag_odd = i & (2**ADDR_WIDTH-1);
        end
        #1000;

    end

    dpd_luts_row_v2 #(
        .ID_MASK(ID_MASK),
        .J_DELAY(J_DELAY),
        .I_DELAY_MAX(I_DELAY_MAX),
        .J_DELAY_MAX(J_DELAY_MAX),
        .DATA_WIDTH(DATA_WIDTH),
        .ADDR_WIDTH(ADDR_WIDTH)
    ) dut
    (
        // input and output of dpd_luts_row for same j-delay
        .clk(clk),
        .rst_n(rst_n),
        .mag_odd(mag_odd), // 0, 2, 4 ...
        .mag_even(mag_even),// 1, 3, 5 ...
        .hout_odd(hout_odd),
        .hout_even(hout_even),

        //configration port
        .enc(enc),
        .lutIdc(lutIdc),
        .wec(wec),
        .addrc(addrc),
        .dinc(dinc),
        .doutc(doutc)
    );


endmodule
