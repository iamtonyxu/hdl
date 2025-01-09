`timescale 1ns / 100ps

module axi_rxqec
(
    input                           clk,
    input                           rst_n,
    
    // interface to util_luts_addr_gen
    input   [31:0]                  din_i,
    input   [31:0]                  din_q,
    output  [31:0]                  dout_i,
    output  [31:0]                  dout_q,

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
    localparam IP_VERSION    = 32'h2025_0109;

////////////////////////////////////////////////////////////////////////////
// registers        axi-addr    up_addr     bit       R/W     Default
// IP_VERSION       0x0000      0x0000      [31:0]    R       32'h2025_0109
// scratch          0x0004      0x0001      [31:0]    R/W     32'h0000_0000
// enable           0x0008      0x0002      [0:0]     R/W     1'b0
// reserved         0x000C      0x0003      [31:0]    R/W     16'h0000
// hi0              0x0010      0x0004      [15:0]    R/W     16'h0000
// hi1              0x0014      0x0005      [15:0]    R/W     16'h0000
// hi2              0x0018      0x0006      [15:0]    R/W     16'h0000
// hi3              0x001C      0x0007      [15:0]    R/W     16'h0000
// hq0              0x0020      0x0008      [15:0]    R/W     16'h0000
// hq1              0x0024      0x0009      [15:0]    R/W     16'h0000
// hq2              0x0028      0x000A      [15:0]    R/W     16'h0000
// hq3              0x002C      0x000B      [15:0]    R/W     16'h0000
// hq4              0x0030      0x000C      [15:0]    R/W     16'h0000
// hq5              0x0034      0x000D      [15:0]    R/W     16'h0000
// hq6              0x0038      0x000E      [15:0]    R/W     16'h0000
// hq7              0x003C      0x000F      [15:0]    R/W     16'h0000
////////////////////////////////////////////////////////////////////////////

    // internal registers
    reg   [31:0]                scratch;
    reg   [31:0]                enable;
    reg   [31:0]                reserved;
    reg   [15:0]                hi0, hi1, hi2, hi3;
    reg   [15:0]                hq0, hq1, hq2, hq3, hq4, hq5, hq6, hq7;

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

    // registers writing
    always @(posedge up_clk or negedge up_rstn)
    if(~up_rstn) begin
        scratch     <= 0;
        enable      <= 0;
        reserved    <= 0;
        hi0         <= 0;
        hi1         <= 0;
        hi2         <= 0;
        hi3         <= 0;
        hq0         <= 0;
        hq1         <= 0;
        hq2         <= 0;
        hq3         <= 0;
        hq4         <= 0;
        hq5         <= 0;
        hq6         <= 0;
        hq7         <= 0;
    end
    else begin
        if(up_wreq_s) begin
            // writing registers
            if(up_waddr_s[4:0] == 5'h01)
                scratch  <=  up_wdata_s;

            if(up_waddr_s[4:0] == 5'h02)
                enable   <=  up_wdata_s;

            if(up_waddr_s[4:0] == 5'h03)
                reserved <=  up_wdata_s;

            if(up_waddr_s[4:0] == 5'h04)
                hi0      <=  up_wdata_s;

            if(up_waddr_s[4:0] == 5'h05)
                hi1      <=  up_wdata_s;

            if(up_waddr_s[4:0] == 5'h06)
                hi2      <=  up_wdata_s;

            if(up_waddr_s[4:0] == 5'h07)
                hi3      <=  up_wdata_s;

            if(up_waddr_s[4:0] == 5'h08)
                hq0      <=  up_wdata_s;

            if(up_waddr_s[4:0] == 5'h09)
                hq1      <=  up_wdata_s;

            if(up_waddr_s[4:0] == 5'h0A)
                hq2      <=  up_wdata_s;

            if(up_waddr_s[4:0] == 5'h0B)
                hq3      <=  up_wdata_s;

            if(up_waddr_s[4:0] == 5'h0C)
                hq4      <=  up_wdata_s;

            if(up_waddr_s[4:0] == 5'h0D)
                hq5      <=  up_wdata_s;

            if(up_waddr_s[4:0] == 5'h0E)
                hq6      <=  up_wdata_s;

            if(up_waddr_s[4:0] == 5'h0F)
                hq7      <=  up_wdata_s;
        end
    end

    //delaying data read with 1 tck to compensate for the ROM latency
    always @(posedge up_clk)
        if(~up_rstn)
            up_rreq_s_d1 <= 0;
        else
            up_rreq_s_d1 <= up_rreq_s;

    // registers reading
    always @(posedge up_clk) begin
        if (~up_rstn) begin
            up_rack_s <= 0;
            up_rdata_s <= 0;
        end
        else begin
            // reading registers
            if (up_rreq_s_d1) begin
                up_rack_s <= 1;
                case(up_raddr_s[4:0])
                    5'h00: up_rdata_s <= IP_VERSION;
                    5'h01: up_rdata_s <= scratch;
                    5'h02: up_rdata_s <= enable;
                    5'h03: up_rdata_s <= reserved;
                    5'h04: up_rdata_s <= {16'd0, hi0};
                    5'h05: up_rdata_s <= {16'd0, hi1};
                    5'h06: up_rdata_s <= {16'd0, hi2};
                    5'h07: up_rdata_s <= {16'd0, hi3};
                    5'h08: up_rdata_s <= {16'd0, hq0};
                    5'h09: up_rdata_s <= {16'd0, hq1};
                    5'h0A: up_rdata_s <= {16'd0, hq2};
                    5'h0B: up_rdata_s <= {16'd0, hq3};
                    5'h0C: up_rdata_s <= {16'd0, hq4};
                    5'h0D: up_rdata_s <= {16'd0, hq5};
                    5'h0E: up_rdata_s <= {16'd0, hq6};
                    5'h0F: up_rdata_s <= {16'd0, hq7};
                    default: up_rdata_s <= 0;
                endcase
            end
            else begin
                up_rack_s <= 0;
                up_rdata_s <= 32'd0;
            end
        end
    end
    
    rxqec_core i_rxqec
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
        .hq0(hq0),
        .hq1(hq1),
        .hq2(hq2),
        .hq3(hq3),
        .hq4(hq4),
        .hq5(hq5),
        .hq6(hq6),
        .hq7(hq7),
        .debug_bus()
    );

endmodule
