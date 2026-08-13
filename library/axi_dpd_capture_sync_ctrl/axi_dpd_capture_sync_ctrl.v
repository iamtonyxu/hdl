`timescale 1ns / 100ps
/*
* this module is used to sync multi-capture tu/tx/orx
*/

module axi_dpd_capture_sync_ctrl
(
    // interface to dpd_capture
    input                           data_clk,
    input                           data_rstn,
    input                           ext_trigger,

    // capture trigger and done signal, according to s_axi_aclk
    output                           cap_trigger,
    input                            cap_done_0,
    input                            cap_done_1,
    input                            cap_done_2,

    // axis interface
    input                           s_axi_aclk,
    input                           s_axi_aresetn,
    //  axis write
    input                           s_axi_awvalid,
    input   [15:0]                  s_axi_awaddr,
    input   [2:0]                   s_axi_awprot,
    output                          s_axi_awready,
    input                           s_axi_wvalid,
    input   [31:0]                  s_axi_wdata,
    input   [3:0]                   s_axi_wstrb,
    output                          s_axi_wready,
    output                          s_axi_bvalid,
    output  [1:0]                   s_axi_bresp,
    input                           s_axi_bready,
    // axis read
    input                           s_axi_arvalid,
    input   [15:0]                  s_axi_araddr,
    input   [2:0]                   s_axi_arprot,
    output                          s_axi_arready,
    output                          s_axi_rvalid,
    output  [1:0]                   s_axi_rresp,
    output  [31:0]                  s_axi_rdata,
    input                           s_axi_rready    
);

    localparam UP_ADDR_WIDTH = 14; // 16 - 2
    localparam UP_DATA_WIDTH = 32;

    // mem          addr_start  addr_end    width   default
    // cap_control  14'h0000    14'h0000    32      0
    // cap_status   14'h0001    14'h0001    32      0

    // internal register
    // cap_control[0]: trigger mode, 1: internal trigger, 0: external gpio trigger (rising edge)
    // cap_control[1]: internal trigger, rising edge is valid, 1 write self clear
    // cap_control[31:2]: reserved
    reg   [31:0]                cap_control;
    // cap_status[0] = 1'b1, tu capture done, otherwise, not finished.
    // cap_status[1] = 1'b1, tx capture done, otherwise, not finished.
    // cap_status[2] = 1'b1, orx capture done, otherwise, not finished.
    reg   [31:0]                cap_status;

    // up_axi interface
    wire                        up_clk;
    wire                        up_rstn;
    wire                        up_wreq_s;
    wire  [UP_ADDR_WIDTH-1:0]   up_waddr_s;
    wire  [UP_DATA_WIDTH-1:0]   up_wdata_s;
    reg                         up_wack;  
    wire                        up_rreq_s;
    wire  [UP_ADDR_WIDTH-1:0]   up_raddr_s;
    reg   [UP_DATA_WIDTH-1:0]   up_rdata_s;
    reg                         up_rack_s;
    reg                         up_rreq_s_d1;

    // afifo: signal cross different clock domains
    wire tfifo_wr, tfifo_rd, tfifo_wfull, tfifo_rempty;
    afifo #(
    .DSIZE(8),
    .ASIZE(8)
    )
    tfifo(
        .i_wclk(s_axi_aclk),
        .i_wrst_n(s_axi_aresetn),
        .i_wr(tfifo_wr),
        .i_wdata(8'h5a),
        .o_wfull(tfifo_wfull),
		.i_rclk(data_clk),
        .i_rrst_n(data_rstn),
        .i_rd(tfifo_rd),
        .o_rdata(),
        .o_rempty(tfifo_rempty)
    );

    assign tfifo_wr = cap_control[0] ? cap_control[1] : ext_trigger;
    assign tfifo_rd = ~tfifo_rempty;
    assign cap_trigger = ~tfifo_rempty;

    // cap_status
    always@(posedge data_clk or negedge data_rstn)
        if(~data_rstn)
            cap_status <= 0;
        else begin
            cap_status[2:0] <= {cap_done_2, cap_done_1, cap_done_0};
        end


    // up_axi
    assign up_clk = s_axi_aclk;
    assign up_rstn = s_axi_aresetn;

    up_axi #(
        .AXI_ADDRESS_WIDTH(16)
    ) 
    i_up_axi (
        .up_rstn (up_rstn),
        .up_clk (up_clk),
        .up_axi_awvalid (s_axi_awvalid),
        .up_axi_awaddr (s_axi_awaddr),
        .up_axi_awready (s_axi_awready),
        .up_axi_wvalid (s_axi_wvalid),
        .up_axi_wdata (s_axi_wdata),
        .up_axi_wstrb (s_axi_wstrb),
        .up_axi_wready (s_axi_wready),
        .up_axi_bvalid (s_axi_bvalid),
        .up_axi_bresp (s_axi_bresp),
        .up_axi_bready (s_axi_bready),
        .up_axi_arvalid (s_axi_arvalid),
        .up_axi_araddr (s_axi_araddr),
        .up_axi_arready (s_axi_arready),
        .up_axi_rvalid (s_axi_rvalid),
        .up_axi_rresp (s_axi_rresp),
        .up_axi_rdata (s_axi_rdata),
        .up_axi_rready (s_axi_rready),
        .up_wreq (up_wreq_s),
        .up_waddr (up_waddr_s),
        .up_wdata (up_wdata_s),
        .up_wack (up_wack),
        .up_rreq (up_rreq_s),
        .up_raddr (up_raddr_s),
        .up_rdata (up_rdata_s),
        .up_rack (up_rack_s)
    );
    
    // up_wack
    always @(posedge up_clk)
        if(~up_rstn)
            up_wack <= 'd0;
        else
            up_wack <= up_wreq_s;

    // update cap_control register
    always @(posedge up_clk or negedge up_rstn)
    if(~up_rstn) begin
        cap_control <= 0;
    end
    else begin
        if(up_wreq_s) begin
            if(up_waddr_s[13:0] == 0) begin
                cap_control <= up_wdata_s;
            end
        end
        else begin
            // internal trigger, rising edge is valid, 1 write self-clear
            if(cap_control[1]) begin
                cap_control[1] <= 1'b0;
            end
        end
    end

    //delaying data read with 1 tck to compensate for the ROM latency
    always @(posedge up_clk)
        if(~up_rstn)
            up_rreq_s_d1 <= 0;
        else
            up_rreq_s_d1 <= up_rreq_s;

    // reading internal registers
    always @(posedge up_clk) begin
        if (~up_rstn) begin
            up_rack_s <= 0;
            up_rdata_s <= 0;
        end
        else begin
            if (up_rreq_s_d1) begin
                up_rack_s <= 1;
                if(up_raddr_s[13:0]==14'd0) begin
                    up_rdata_s <= cap_control;
                end
                else if(up_raddr_s[13:0]==14'd1) begin
                    up_rdata_s <= cap_status;
                end
                else begin
                    up_rdata_s <= 32'd0;
                end
            end
            else begin
                up_rack_s <= 0;
                up_rdata_s <= 32'd0;
            end
        end
    end

endmodule

