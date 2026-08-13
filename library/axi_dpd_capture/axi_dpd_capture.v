`timescale 1ns / 100ps
/*
* this module is used to capture tu/tx
*/

module axi_dpd_capture #(
    parameter CAP_DEPTH = 12
)
(
    // signal from pre or post DPD, two samples per channel
    // data_in_0 = {tu_i[2n+1],tu_i[2n]}
    // data_in_1 = {tu_q[2n+1],tu_q[2n]}
    input                           data_clk,
    input                           data_rstn,
    input   [31:0]                  data_in_0,
    input   [31:0]                  data_in_1,

    // capture trigger and done signal, according to s_axi_aclk
    input                           cap_trigger,
    output                          cap_done,

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
    
    // internal register
    // cap_status = 0, idle
    // cap_status = 1, capture ongoing after new trigger signal arrives
    // cap_status = 2, capture done after the last trigger
    reg [1:0]          cap_status;
    reg [15:0]         cap_count;
    wire               cap_trigger_d;

    // afifo
    wire tfifo_wr, tfifo_rd, tfifo_wfull, tfifo_rempty;

    // cap_mem
    // ram[0]: {data_in_0[15:0], data_in_1[15:0]}
    // ram[1]: {data_in_0[31:16], data_in_1[31:15]}
    //...
    // ram[2n]: {data_in_0[15:0], data_in_1[15:0]}
    // ram[2n+1]: {data_in_0[31:16], data_in_1[31:16]}
    (* rom_style="{distributed | block}" *)
    reg  [63:0]                 ram[0:2**(CAP_DEPTH-1)-1];
    wire                        wea;
    wire [CAP_DEPTH-2:0]        waddr;
    wire [63:0]                 wdata;
    wire [CAP_DEPTH-2:0]        raddr;
    wire [63:0]                 rdata;


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

    // internal registers
    // cap_control[0]: trigger mode, 1: internal trigger, 0: gpio trigger (rising edge)
    // cap_control[1]: internal trigger, rising edge is valid, 1 write self clear
    // cap_control[2]: reset cap_status, 1 write self clear, reserved
    // cap_control[31:8]: delay capture after triggering, reserved
    reg   [31:0]                cap_control;

    // mem          addr_start  addr_end    width   default
    // cap_ram      14'h0000    14'h1fff    32      0
    // cap_control  14'h2000    14'h2000    32      0

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

    assign tfifo_wr = cap_control[0] ? cap_control[1] : cap_trigger;
    assign tfifo_rd = ~tfifo_rempty;
    assign cap_trigger_d = ~tfifo_rempty;

    // cap_status
    always@(posedge data_clk or negedge data_rstn)
        if(~data_rstn)
            cap_status <= 2'd0;
        else begin
            if(cap_trigger_d)
                cap_status <= 2'd1;
            else if(cap_count == 2**(CAP_DEPTH-1) - 1)
                cap_status <= 2'd2;
        end

    // cap_done
    assign cap_done = cap_status[1];

    // cap_count
    always@(posedge data_clk or negedge data_rstn)
        if(~data_rstn)
            cap_count <= 0;
        else begin
            if(cap_status == 2'd1)
                cap_count <= cap_count + 1;
            else
                cap_count <= 0;
        end
    
    assign waddr = cap_count[CAP_DEPTH-2:0];
    assign wea = cap_status == (2'd1);
    assign wdata = {data_in_0, data_in_1};

    ///////////////////////
    // only for simulation
    integer i;
    initial begin
        for(i=0; i<2**(CAP_DEPTH-1); i=i+1) begin
            ram[i] = 0;
        end
    end
    ///////////////////////

    // ram write
    always@(posedge data_clk)
        if(wea)
            ram[waddr] <= wdata;

    // ram read
    assign rdata = ram[raddr];
    assign raddr = up_raddr_s[CAP_DEPTH-1:1];

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
        if(up_wreq_s && up_waddr_s[13]) begin
            if(up_waddr_s[7:0] == 0) begin
                cap_control <= up_wdata_s;
            end
        end
        else begin
            // internal trigger, rising edge is valid, 1 write self-clear
            if(cap_control[1]) begin
                cap_control[1] <= 1'b0;
            end
            // reset cap_status, 1 write self-clear
            if(cap_control[2]) begin
                cap_control[2] <= 1'b0;
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
                if(up_raddr_s[13]) begin
                    if(up_raddr_s[7:0]==8'd0)
                        up_rdata_s <= cap_control;
                    else if(up_raddr_s[7:0]==8'd1)
                        up_rdata_s <= cap_status[1] ? 32'd1 : 32'd0;
                    else
                        up_rdata_s <= 32'd0;
                end
                else begin
                if(up_raddr_s[0])
                    up_rdata_s <= rdata[31:0];
                else
                    up_rdata_s <= rdata[63:32];
                end
            end
            else begin
                up_rack_s <= 0;
                up_rdata_s <= 32'd0;
            end
        end
    end

endmodule

