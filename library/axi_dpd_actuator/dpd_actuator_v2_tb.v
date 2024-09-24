`timescale 1ns / 1ps
`define EXTRA_BITS 3

module dpd_actuator_v2_tb;

    localparam ID_MASK = 64'hFFFF_FFFF_FFFF_FFFF;
    localparam DATA_WIDTH = 32;
    localparam ADDR_WIDTH = 4;
    localparam ID_MAX = 64;
    localparam CLK_PERIOD = 10;

    // signal in/out port
    reg                         clk;
    reg                         rst_n;
    reg                         tu_enable;
    reg     [DATA_WIDTH*2-1:0]  tu;
    reg     [ADDR_WIDTH*2-1:0]  mag;
    wire    [DATA_WIDTH*2-1:0]  tx;
    wire                        tx_valid;

    // configuration port
    reg                         enc;
    reg     [ID_MAX-1:0]        lutIdc;
    reg                         wec;
    reg     [ADDR_WIDTH-1:0]    addrc;
    reg     [DATA_WIDTH-1:0]    dinc;
    wire    [DATA_WIDTH-1:0]    doutc;
    wire                        validc;

    // internal signal
    integer                     i;
    reg     [DATA_WIDTH-1:0]    lut_dout;

task free_lut; 
    begin
        lutIdc = 0;
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
        enc = 0;
        wec = 0;
        addrc = 0;
        wait(validc == 1);
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

    // configuration
    initial begin
        // free luts
        free_lut;
        wait(rst_n == 1);
        #100;
        // select lut-0
        lutIdc = 1;

        // write luts
        for(i = 0; i < 2**ADDR_WIDTH; i = i+1) begin
            write_lut(i, 32'h1111_1111 * i);
        end

        // free luts
        free_lut;
        // select lut-0
        lutIdc = 1;

        #100;
        // read luts
        for(i = 0; i < 2**ADDR_WIDTH; i = i+1) begin
            read_lut(i, lut_dout);
        end

        // free luts
        free_lut;

    end

    // dpd_actuator
    dpd_actuator_v2 #(
        .ID_MASK(ID_MASK),
        .DATA_WIDTH(DATA_WIDTH),
        .ADDR_WIDTH(ADDR_WIDTH)
    )
    dut(
        // signal in/out
        .clk(clk),
        .rst_n(rst_n),
        .tu_enable(tu_enable),
        .tu(tu),
        .mag(mag),
        .tx(tx),
        .tx_valid(tx_valid),

        // configuration
        .enc(enc),
        .lutIdc(lutIdc),
        .wec(wec),
        .addrc(addrc),
        .dinc(dinc),
        .doutc(doutc),
        .validc(validc)
    );

endmodule
