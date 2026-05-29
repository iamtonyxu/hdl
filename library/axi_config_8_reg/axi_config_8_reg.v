`timescale 1ns / 100ps

module axi_config_8_reg#(
    parameter DATA_WIDTH = 32
)
(
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
    input                           s_axi_rready,

	// Users to add ports here
    output reg  [DATA_WIDTH-1:0]    sreg0,
    output reg  [DATA_WIDTH-1:0]    sreg1,
    output reg  [DATA_WIDTH-1:0]    sreg2,
    output reg  [DATA_WIDTH-1:0]    sreg3,
    output reg  [DATA_WIDTH-1:0]    sreg4,
    output reg  [DATA_WIDTH-1:0]    sreg5,
    output reg  [DATA_WIDTH-1:0]    sreg6,
    output reg  [DATA_WIDTH-1:0]    sreg7
);

    localparam UP_ADDR_WIDTH = 14; // 16 - 2
    localparam UP_DATA_WIDTH = DATA_WIDTH;
    
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

  //axi registers write
  always @(posedge up_clk) begin
    if (up_rstn == 1'b0) begin
        sreg0 <= {DATA_WIDTH{1'b0}};
        sreg1 <= {DATA_WIDTH{1'b0}};
        sreg2 <= {DATA_WIDTH{1'b0}};
        sreg3 <= {DATA_WIDTH{1'b0}};
        sreg4 <= {DATA_WIDTH{1'b0}};
        sreg5 <= {DATA_WIDTH{1'b0}};
        sreg6 <= {DATA_WIDTH{1'b0}};
        sreg7 <= {DATA_WIDTH{1'b0}};
    end else begin
      if ((up_wreq_s == 1'b1) && (up_waddr_s == 8'h00)) begin
        sreg0 <= up_wdata_s;
      end
      if ((up_wreq_s == 1'b1) && (up_waddr_s == 8'h01)) begin
        sreg1 <= up_wdata_s;
      end
      if ((up_wreq_s == 1'b1) && (up_waddr_s == 8'h02)) begin
        sreg2 <= up_wdata_s;
      end
      if ((up_wreq_s == 1'b1) && (up_waddr_s == 8'h03)) begin
        sreg3 <= up_wdata_s;
      end
      if ((up_wreq_s == 1'b1) && (up_waddr_s == 8'h04)) begin
        sreg4 <= up_wdata_s;
      end
      if ((up_wreq_s == 1'b1) && (up_waddr_s == 8'h05)) begin
        sreg5 <= up_wdata_s;
      end
      if ((up_wreq_s == 1'b1) && (up_waddr_s == 8'h06)) begin
        sreg6 <= up_wdata_s;
      end
      if ((up_wreq_s == 1'b1) && (up_waddr_s == 8'h07)) begin
        sreg7 <= up_wdata_s;
      end
    end
  end

  //up_wack
  always @(posedge up_clk) begin
    if (s_axi_aresetn == 1'b0)
      up_wack <= 'd0;
    else
      up_wack <= up_wreq_s;
  end

  //axi registers read
  always @(posedge up_clk) begin
    if (s_axi_aresetn == 1'b0) begin
      up_rack_s <= 'd0;
      up_rdata_s <= 'd0;
    end else begin
      up_rack_s <= up_rreq_s;
      if (up_rreq_s == 1'b1) begin
        case (up_raddr_s)
          8'h00: up_rdata_s <= sreg0;
          8'h01: up_rdata_s <= sreg1;
          8'h02: up_rdata_s <= sreg2;
          8'h03: up_rdata_s <= sreg3;
          8'h04: up_rdata_s <= sreg4;
          8'h05: up_rdata_s <= sreg5;
          8'h06: up_rdata_s <= sreg6;
          8'h07: up_rdata_s <= sreg7;

          default: up_rdata_s <= 0;
        endcase
      end else begin
        up_rdata_s <= 32'd0;
      end
    end
  end

endmodule
