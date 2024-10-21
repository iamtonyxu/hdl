`timescale 1ns/100ps

module axi_dpd_capture_tb;

    localparam DCLK_PERIOD = 4; // dpd_actuator clock = 122.88/245.76 MHz
    localparam ACLK_PERIOD = 10; //s_axi_aclk = 100 MHz
    localparam CAP_DEPTH = 12;

    // signal in/out
    reg                           data_clk;
    reg                           data_rstn;
    reg   [31:0]                  data_in_0;
    reg   [31:0]                  data_in_1;
    
    reg                           cap_trigger;
    wire                          cap_done;

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

    // don't care
    assign s_axi_awprot = 0;
    assign s_axi_arprot = 0;
    assign s_axi_wstrb = 0; 

    // data_clk
    initial begin
        data_clk = 1;
        forever #(DCLK_PERIOD/2) data_clk = ~data_clk;
    end

    // s_axi_aclk
    initial begin
        s_axi_aclk = 1;
        forever #(ACLK_PERIOD/2) s_axi_aclk = ~s_axi_aclk;
    end

    // rst_n
    initial begin
        data_rstn = 0;
        s_axi_aresetn = 0;
        #100
        data_rstn = 1;
        s_axi_aresetn = 1;
    end

    // sim process
    initial begin
        data_in_0 = 32'hdead;
        data_in_1 = 32'h1234;
        cap_trigger = 0;
        #1000;
        cap_trigger = 1;
        @(posedge data_clk);
        cap_trigger = 0;
    end

    axi_dpd_capture #(
        .CAP_DEPTH(CAP_DEPTH) 
    )
    dut (
        .data_clk(data_clk),
        .data_rstn(data_rstn),
        .data_in_0(data_in_0),
        .data_in_1(data_in_1),

    // capture trigger and done signal
        .cap_trigger(cap_trigger),
        .cap_done(cap_done),

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