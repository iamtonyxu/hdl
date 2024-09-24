`timescale 1ns / 1ps

module dpd_lut_v2_tb;

    localparam ID_MASK = 64'hFFFF_FFFF_FFFF_FFFF;
    localparam ID = 0;
    localparam DATA_WIDTH = 32;
    localparam ADDR_WIDTH = 3;

    localparam CLK_PERIOD = 10;

    // configuration port
    reg                         clk;
    reg                         rst_n;
    reg                         enc;
    reg                         wec;
    reg     [ADDR_WIDTH-1:0]    addrc;
    reg     [DATA_WIDTH-1:0]    dinc;
    wire    [DATA_WIDTH-1:0]    doutc;

    // ram port-A
    reg     [ADDR_WIDTH-1:0]    addra;
    wire    [DATA_WIDTH-1:0]    douta;
    
    // ram port-B
    reg     [ADDR_WIDTH-1:0]    addrb;
    wire    [DATA_WIDTH-1:0]    doutb;

    // internal signal
    integer                     i;
    reg     [DATA_WIDTH-1:0]    lut_dout;
    reg                         lut_updated;

task free_configuration;
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
        @(posedge clk); // latency = 2 clk periods
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
    // 3. input addra/addrb and check douta/doutb correct
    // 4. report result
    initial begin
        free_configuration;
        addra = 0;
        addrb = 0;
        lut_updated = 0;

        wait(rst_n == 1);
        #100;
        // write luts
        for(i = 0; i < 2**ADDR_WIDTH; i = i+1) begin
            write_lut(i, 32'h1111_1111 * i);
        end

        #100;
        // read luts
        for(i = 0; i < 2**ADDR_WIDTH; i = i+1) begin
            read_lut(i, lut_dout);
        end
        free_configuration;
        #100;

        // read data via port-A and port-B
        for(i = 0; i < 2**ADDR_WIDTH; i = i+1) begin
            addra = i;
            addrb = i;
            @(posedge clk);
        end
        #100;

    end

    // dpd_lut_v2
    dpd_lut_v2 #(
        .ID_MASK(ID_MASK),
        .ID(ID),
        .DATA_WIDTH(DATA_WIDTH),
        .ADDR_WIDTH(ADDR_WIDTH)
    )
    dut(
        // Configration port
        // with the same clk as port-A and port-B
        .clk(clk),
        .rst_n(rst_n),
        .enc(enc),
        .wec(wec),
        .addrc(addrc),
        .dinc(dinc),
        .doutc(doutc),

        // RAM port-A, only read
        .addra(addra),
        .douta(douta),

        // RAM port-B, only read
        .addrb(addrb),
        .doutb(doutb)
    );


endmodule
