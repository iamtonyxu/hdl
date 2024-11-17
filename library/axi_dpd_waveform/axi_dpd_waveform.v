`timescale 1ns / 100ps

module axi_dpd_waveform #(
    parameter MEM_ADDR_WIDTH = 14 //MAX = 14
)
(
    input                           data_clk,
    input                           data_rstn,
    
    // interface to util_luts_addr_gen
    output  [31:0]                  data_out,
    output                          data_out_valid,

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
    
    // waveform_mem
    // ram[0]: {data_in_0[31:16], data_in_0[15:0]}
    // ram[1]: {data_in_0[31:16], data_in_0[15:0]}
    // ...
    // ram[n]: {data_in_0[31:16], data_in_0[15:0]}
    (* rom_style="{distributed | block}" *)
    reg [31:0]                 ram[0:(2**MEM_ADDR_WIDTH-1)];
    // wclk = up_clk
    reg                        wea;
    reg [MEM_ADDR_WIDTH-1:0]   waddr;
    reg [31:0]                 wdata;
    //rclk = data_clk
    reg [MEM_ADDR_WIDTH-1:0]   raddr;
    reg [31:0]                 rdata;
    
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

    ///////////////////////
    // only for simulation
    integer i;
    initial begin
        for(i=0; i<(2**MEM_ADDR_WIDTH-1); i=i+1) begin
            ram[i] = 0;
        end
    end
    ///////////////////////

    assign data_out = rdata;
    assign data_out_valid = 1;

    // ram read
    always@(posedge data_clk or negedge data_rstn)
        if(~data_rstn)
            rdata <= 0;
        else
            rdata <= ram[raddr];

    always@(posedge data_clk or negedge data_rstn)
        if(~data_rstn)
            raddr <= 0;
        else
            raddr <= raddr + 1;

    // ram write
    always@(posedge up_clk)
        if(wea)
            ram[waddr] <= wdata;

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

    // wea, wdata
    always @(posedge up_clk or negedge up_rstn)
    if(~up_rstn) begin
        wea <= 0;
        waddr <= 0;
        wdata <= 0;
    end
    else begin
        if(up_wreq_s) begin
            wea <= 1;
            waddr <= up_waddr_s[MEM_ADDR_WIDTH-1:0];
            wdata <= up_wdata_s;
        end
        else begin
            wea <= 0;
            waddr <= 0;
            wdata <= 0;
        end
    end

endmodule
