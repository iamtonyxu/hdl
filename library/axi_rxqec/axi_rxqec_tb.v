`timescale 1ns / 100ps

module axi_rxqec_tb;

    localparam CLK_PERIOD = 10;
    localparam DATA_LENGTH = 512;
    localparam QFIR_TAPS = 15;
    localparam IFIR_TAPS = 7;

    reg clk;
    reg rst_n;
    integer fileID, ii;
    reg config_done, sim_done;

    reg   [31:0] din_i;
    reg   [31:0] din_q;
    wire  [31:0] dout_i;
    wire  [31:0] dout_q;

    reg signed [15:0]hi0;
    reg signed [15:0]hi1;
    reg signed [15:0]hi2;
    reg signed [15:0]hi3;

    reg signed [15:0]hq0;
    reg signed [15:0]hq1;
    reg signed [15:0]hq2;
    reg signed [15:0]hq3;
    reg signed [15:0]hq4;
    reg signed [15:0]hq5;
    reg signed [15:0]hq6;
    reg signed [15:0]hq7;

    reg [31:0] mem_din_i[0:DATA_LENGTH-1];
    reg [31:0] mem_din_q[0:DATA_LENGTH-1];
    reg [31:0] mem_dout_i[0:DATA_LENGTH-1];
    reg [31:0] mem_dout_q[0:DATA_LENGTH-1];
    reg [15:0] mem_hq[0:QFIR_TAPS-1];
    reg [15:0] mem_hi[0:IFIR_TAPS-1];

    // axi interface
    reg                           s_axi_aclk;
    reg                           s_axi_aresetn;
    //  axis write
    reg                           s_axi_awvalid;
    reg   [15:0]                  s_axi_awaddr;
    wire   [2:0]                  s_axi_awprot;
    wire                          s_axi_awready;
    reg                           s_axi_wvalid;
    reg   [31:0]                  s_axi_wdata;
    wire  [3:0]                   s_axi_wstrb;
    wire                          s_axi_wready;
    wire                          s_axi_bvalid;
    wire  [1:0]                   s_axi_bresp; // don't care
    reg                           s_axi_bready;
    // axis read
    reg                           s_axi_arvalid;
    reg   [15:0]                  s_axi_araddr;
    wire  [2:0]                   s_axi_arprot;
    wire                          s_axi_arready;
    wire                           s_axi_rvalid;
    wire  [1:0]                   s_axi_rresp; // don't care
    wire  [31:0]                  s_axi_rdata;
    reg                           s_axi_rready;
    reg  [31:0]                   axi_rdata;
    
    // don't care
    assign s_axi_awprot = 0;
    assign s_axi_arprot = 0;
    assign s_axi_wstrb = 0; 

    // axi_write
    task axi_write;
        // user inteface
        input    [15:0]           axi_addr;
        input    [31:0]           axi_wdata;

        // write operation
        begin
            // driving external Global Reg            
            @(posedge s_axi_aclk); // wait rising edge of axi_clk
            s_axi_awaddr = axi_addr;
            s_axi_wdata = axi_wdata;
            s_axi_awvalid = 1;
            s_axi_wvalid = 1;
            s_axi_bready = 1;

            wait((s_axi_awready == 1) & 
                 (s_axi_wready  == 1));
            @(posedge s_axi_aclk); 
            s_axi_awvalid = 0;
            s_axi_wvalid = 0;
            s_axi_awaddr = 0;
            s_axi_wdata = 0;

            wait(s_axi_bvalid  == 1);
            @(posedge s_axi_aclk);
            s_axi_bready = 0;            
            
        end
    endtask

    // axi_read
    task axi_read;
        // user interface
        input   [15:0]          axi_addr;
        output  [31:0]          axi_rdata;

        // read operation
        begin
            s_axi_arvalid = 0;
            @(posedge s_axi_aclk); // wait rising edge of axi_clk
            s_axi_araddr = axi_addr;
            // read addr channel
            s_axi_arvalid = 1;
            wait(s_axi_arready == 1);
            @(posedge s_axi_aclk);
            s_axi_arvalid = 0;

            //read data channel
            s_axi_rready = 1;
            wait(s_axi_rvalid == 1);
            @(posedge s_axi_aclk);
            axi_rdata = s_axi_rdata;
            s_axi_rready = 0;
        end
    endtask

    // clk
    initial begin
        clk = 1;
        forever #(CLK_PERIOD/2) clk = ~clk;
    end

    // s_axi_aclk
    initial begin
        s_axi_aclk = 1;
        forever #(CLK_PERIOD/2) s_axi_aclk = ~s_axi_aclk;
    end

    //rst_n, s_axi_aresetn
    initial begin
        rst_n = 0;
        s_axi_aresetn = 0;
        $readmemh("mt_din_i.txt", mem_din_i);
        $readmemh("mt_din_q.txt", mem_din_q);
        $readmemh("mt_hq.txt", mem_hq);
        $readmemh("mt_hi.txt", mem_hi);

        #100;
        rst_n = 1;
        s_axi_aresetn = 1;
    end

    // filter coeffs
    initial begin
        hq0 = 0; hi0 = 0;
        hq1 = 0; hi1 = 0;
        hq2 = 0; hi2 = 0;
        hq3 = 0; hi3 = 0;
        hq4 = 0;
        hq5 = 0;
        hq6 = 0;
        hq7 = 0;
        config_done = 0;
        s_axi_arvalid = 0;
        s_axi_araddr = 0;
        s_axi_rready = 0;
        
        wait (s_axi_aresetn == 1);

        hq0 = mem_hq[7]; hi0 = mem_hi[3];
        hq1 = mem_hq[6]; hi1 = mem_hi[2];
        hq2 = mem_hq[5]; hi2 = mem_hi[1];
        hq3 = mem_hq[4]; hi3 = mem_hi[0];
        hq4 = mem_hq[3];
        hq5 = mem_hq[2];
        hq6 = mem_hq[1];
        hq7 = mem_hq[0];
        
        // write internal registers
        axi_write(16'h0004, 32'h1111_1111); // scratch
        axi_write(16'h0008, 32'h0000_0001); // enable
        axi_write(16'h0010, {16'h0, hi0});  // hi0
        axi_write(16'h0014, {16'h0, hi1});  // hi1
        axi_write(16'h0018, {16'h0, hi2});  // hi2
        axi_write(16'h001C, {16'h0, hi3});  // hi3
        axi_write(16'h0020, {16'h0, hq0});  // hq0
        axi_write(16'h0024, {16'h0, hq1});  // hq1
        axi_write(16'h0028, {16'h0, hq2});  // hq2
        axi_write(16'h002C, {16'h0, hq3});  // hq3
        axi_write(16'h0030, {16'h0, hq4});  // hq4
        axi_write(16'h0034, {16'h0, hq5});  // hq5
        axi_write(16'h0038, {16'h0, hq6});  // hq6
        axi_write(16'h003C, {16'h0, hq7});  // hq7
        #100;
        
        // read internal registers
        axi_read(16'h0000, axi_rdata); // ip_version
        axi_read(16'h0004, axi_rdata); // scratch
        axi_read(16'h0010, axi_rdata); // hi0
        axi_read(16'h0014, axi_rdata); // hi1
        axi_read(16'h0018, axi_rdata); // hi2
        axi_read(16'h001C, axi_rdata); // hi3
        axi_read(16'h0020, axi_rdata); // hq0
        axi_read(16'h0024, axi_rdata); // hq1
        axi_read(16'h0028, axi_rdata); // hq2
        axi_read(16'h002C, axi_rdata); // hq3
        axi_read(16'h0030, axi_rdata); // hq4
        axi_read(16'h0034, axi_rdata); // hq5
        axi_read(16'h0038, axi_rdata); // hq6
        axi_read(16'h003C, axi_rdata); // hq7
        #100;

        // axi write coeffs
        config_done = 1;
    end

    // data input
    initial begin
        din_i = 0;
        din_q = 0;
        sim_done = 0;
        wait (config_done == 1);

        for(ii = 0; ii < DATA_LENGTH; ii = ii + 1) begin
            din_i = mem_din_i[ii];
            din_q = mem_din_q[ii];
            @(posedge clk);
        end
        sim_done = 1;

    end    

axi_rxqec dut
(
    .clk(clk),
    .rst_n(rst_n),
    .din_i(din_i),
    .din_q(din_q),
    .dout_i(dout_i),
    .dout_q(dout_q),

    // axis interface
    .s_axi_aclk(s_axi_aclk),
    .s_axi_aresetn(s_axi_aresetn),
    //  axis write
    .s_axi_awvalid(s_axi_awvalid),
    .s_axi_awaddr(s_axi_awaddr),
    .s_axi_awprot(s_axi_awprot),
    .s_axi_awready(s_axi_awready),
    .s_axi_wvalid(s_axi_wvalid),
    .s_axi_wdata(s_axi_wdata),
    .s_axi_wstrb(s_axi_wstrb),
    .s_axi_wready(s_axi_wready),
    .s_axi_bvalid(s_axi_bvalid),
    .s_axi_bresp(s_axi_bresp),
    .s_axi_bready(s_axi_bready),
    // axis read
    .s_axi_arvalid(s_axi_arvalid),
    .s_axi_araddr(s_axi_araddr),
    .s_axi_arprot(s_axi_arprot),
    .s_axi_arready(s_axi_arready),
    .s_axi_rvalid(s_axi_rvalid),
    .s_axi_rresp(s_axi_rresp),
    .s_axi_rdata(s_axi_rdata),
    .s_axi_rready(s_axi_rready)
);

endmodule
