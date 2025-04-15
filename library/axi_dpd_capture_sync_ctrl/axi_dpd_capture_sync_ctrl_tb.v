`timescale 1ns/100ps

module axi_dpd_capture_sync_ctrl_tb;

    localparam DCLK_PERIOD = 10; // dpd_actuator clock = 122.88/245.76 MHz
    localparam ACLK_PERIOD = 4; //s_axi_aclk = 100 MHz

    // signal in/out
    reg                           data_clk;
    reg                           data_rstn;
    reg   [31:0]                  data_in_0;
    reg   [31:0]                  data_in_1;
    
    wire                          cap_trigger;
    reg   [2:0]                   cap_done;

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

    reg [31:0] cap_status;
    integer ii = 0;

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
        // wait for a moment
        #100;

        axi_write(16'h0000, 2'b11); // cap_control[1:0] = 2'b11, trigger a capture

        // check capture trigger is valid
        wait(cap_trigger == 1);

        ii = 0;
        repeat(8) begin
        // set cap_done
        cap_done = ii;
        #(3 * DCLK_PERIOD); // wait for 3 clock cycles
        axi_read(16'h0004, cap_status); // read capture status register
        if (cap_status[2:0] == ii) begin
            $display("Capture status = %d", cap_status[2:0]);
        end
        else begin
            $display("Capture status error, cap_status = %d", cap_status[2:0]);
        end
        ii = ii + 1;
        end
        $stop;
    end

    axi_dpd_capture_sync_ctrl
    dut (
        .data_clk(data_clk),
        .data_rstn(data_rstn),
        .ext_trigger(1'b0), 
        .cap_trigger(cap_trigger),
        .cap_done_0(cap_done[0]),
        .cap_done_1(cap_done[1]),
        .cap_done_2(cap_done[2]),

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