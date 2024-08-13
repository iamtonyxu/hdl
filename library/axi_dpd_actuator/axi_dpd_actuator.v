`timescale 1ns / 1ps
`define EXTRA_BITS 3
`define I_DELAY_MAX 8
`define J_DELAY_MAX 8
`define EXT_LATENCY 9  //latency of dpd_lut_row(1+1+7)
`define ACT_LATENCY 22  //latency of dpd actuator (dpd_lut_row(1+1+7) + cmult(6) + cadder(7))

module axi_dpd_actuator #(
    parameter ID_MASK = 64'hFFFF_FFFF_FFFF_FFFF, //TODO: IP user can read ID_MASK
    parameter LUT_DATA_WIDTH = 32,
    parameter LUT_ADDR_WIDTH = 10,
    parameter AXI_DATA_WIDTH = 32,
    parameter AXI_ADDR_WIDTH = 18 //AXI_ADDR_WIDTH=LUT_ADDR_WIDTH+6+2
)
(
    input                           clk,
    input                           rst_n,

    // signal from tx_fir_interpolator, two samples per channel
    input   [31:0]                  data_in_0,
    input                           data_in_enable_0,
    input   [31:0]                  data_in_1,
    input                           data_in_enable_1,

    // signal to tx_adrv9009_tpl_core, two samples per channel
    output  [31:0]                  data_out_0,
    output                          data_out_valid_0,
    output  [31:0]                  data_out_1,
    output                          data_out_valid_1,

    //axis interface
    input                           s_axi_aclk,
    input                           s_axi_aresetn,

    input                           s_axi_awvalid,
    input   [AXI_ADDR_WIDTH-1:0]    s_axi_awaddr,
    input   [2:0]                   s_axi_awprot,
    output                          s_axi_awready,
    input                           s_axi_wvalid,
    input   [AXI_DATA_WIDTH-1:0]    s_axi_wdata,
    input   [3:0]                   s_axi_wstrb,
    output                          s_axi_wready,
    output                          s_axi_bvalid,
    output  [1:0]                   s_axi_bresp,
    input                           s_axi_bready,

    input                           s_axi_arvalid,
    input   [AXI_ADDR_WIDTH-1:0]    s_axi_araddr,
    input   [2:0]                   s_axi_arprot,
    output                          s_axi_arready,
    output                          s_axi_rvalid,
    output  [1:0]                   s_axi_rresp,
    output  [AXI_DATA_WIDTH-1:0]    s_axi_rdata,
    input                           s_axi_rready

);

    localparam UP_ADDR_WIDTH = AXI_ADDR_WIDTH - 2;
    localparam UP_DATA_WIDTH = AXI_DATA_WIDTH;

    localparam  [31:0]  IP_VERSION  = {16'h0001,    /* MAJOR */
                                        8'h01,      /* MINOR */
                                        8'h61};     /* PATCH */

    // configuration port
    reg [LUT_ADDR_WIDTH-1:0] config_addr_wreq;
    wire [LUT_ADDR_WIDTH-1:0] config_addr_rreq, config_addr;
    reg [LUT_DATA_WIDTH-1:0] config_din;
    wire [LUT_DATA_WIDTH-1:0] config_dout;
    reg [`I_DELAY_MAX*`J_DELAY_MAX-1:0] config_lutId;
    reg config_web;
    
    // internal registers
    reg [AXI_DATA_WIDTH-1:0] up_scratch;
    reg [AXI_DATA_WIDTH-1:0] up_bypass;
    wire bypass;

    //axi interface
    reg                         up_wack;
    reg   [UP_DATA_WIDTH-1:0]   up_rdata_s;
    reg                         up_rack_s;
    reg                         up_rreq_s_d;
    wire                        up_clk;
    wire                        up_rstn;
    wire                        up_rreq_s;
    wire  [UP_ADDR_WIDTH-1:0]   up_raddr_s;
    wire                        up_wreq_s;
    wire  [UP_ADDR_WIDTH-1:0]   up_waddr_s;
    wire  [UP_DATA_WIDTH-1:0]   up_wdata_s;

    //interface to adrv9009_zc706 project
    reg                         clkdiv2;
    reg                         tu_enable;
    reg [LUT_DATA_WIDTH-1:0]    tu;
    wire [LUT_DATA_WIDTH-1:0]   tu_aligned;
    wire[LUT_DATA_WIDTH-1:0]    tx;
    wire                        tx_valid;
    wire[LUT_ADDR_WIDTH-1:0]    mag; // mag = abs(tu)

    reg [LUT_DATA_WIDTH-1:0]    tx_i;
    reg [LUT_DATA_WIDTH-1:0]    tx_q;
    reg                         data_out_valid;

    assign up_clk = s_axi_aclk;
    assign up_rstn = s_axi_aresetn;
    
    up_axi #(
        .AXI_ADDRESS_WIDTH(AXI_ADDR_WIDTH)
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
    //config_web, config_addr_wreq, config_din
    always @(posedge up_clk) begin
        if (up_rstn == 1'b0) begin
            up_wack <= 'd0;
            config_web <= 0;
            config_addr_wreq <= 0;
            config_din <= 0;
            up_scratch <= 0;
            up_bypass <= 0;
        end 
        else begin
            up_wack <= up_wreq_s;
            if (up_wreq_s == 1'b1) begin
                if (up_waddr_s[UP_ADDR_WIDTH-1] == 1'b1) begin
                    config_web <= 1'b1;
                    config_addr_wreq <= up_waddr_s[LUT_ADDR_WIDTH-1:0];
                    config_din <= up_wdata_s;
                end
                else begin
                    if(up_waddr_s[UP_ADDR_WIDTH-2:0] == 1) begin
                        up_scratch <= up_wdata_s;
                    end
                    if(up_waddr_s[UP_ADDR_WIDTH-2:0] == 2) begin
                        up_bypass <= up_wdata_s;
                    end
                end
            end
            else begin
                config_web <= 0;
                config_addr_wreq <= 0;
                config_din <= 0;
            end
        end
    end

    //axi registers write    
    //config_lutId
    always@(posedge up_clk) begin
        if(~up_rstn) begin
            config_lutId <= 0;
        end
        else begin
            if((up_wreq_s==1) && (up_waddr_s[UP_ADDR_WIDTH-1]==1)) begin
                case(up_waddr_s[UP_ADDR_WIDTH-2:UP_ADDR_WIDTH-7])
                    6'b000000: config_lutId <= 64'h0000_0000_0000_0001;
                    6'b000001: config_lutId <= 64'h0000_0000_0000_0002;
                    6'b000010: config_lutId <= 64'h0000_0000_0000_0004;
                    6'b000011: config_lutId <= 64'h0000_0000_0000_0008;
                    6'b000100: config_lutId <= 64'h0000_0000_0000_0010;
                    6'b000101: config_lutId <= 64'h0000_0000_0000_0020;
                    6'b000110: config_lutId <= 64'h0000_0000_0000_0040;
                    6'b000111: config_lutId <= 64'h0000_0000_0000_0080;
                    6'b001000: config_lutId <= 64'h0000_0000_0000_0100;
                    6'b001001: config_lutId <= 64'h0000_0000_0000_0200;
                    6'b001010: config_lutId <= 64'h0000_0000_0000_0400;
                    6'b001011: config_lutId <= 64'h0000_0000_0000_0800;
                    6'b001100: config_lutId <= 64'h0000_0000_0000_1000;
                    6'b001101: config_lutId <= 64'h0000_0000_0000_2000;
                    6'b001110: config_lutId <= 64'h0000_0000_0000_4000;
                    6'b001111: config_lutId <= 64'h0000_0000_0000_8000;  
                    6'b010000: config_lutId <= 64'h0000_0000_0001_0000;
                    6'b010001: config_lutId <= 64'h0000_0000_0002_0000;
                    6'b010010: config_lutId <= 64'h0000_0000_0004_0000;
                    6'b010011: config_lutId <= 64'h0000_0000_0008_0000;
                    6'b010100: config_lutId <= 64'h0000_0000_0010_0000;
                    6'b010101: config_lutId <= 64'h0000_0000_0020_0000;
                    6'b010110: config_lutId <= 64'h0000_0000_0040_0000;
                    6'b010111: config_lutId <= 64'h0000_0000_0080_0000;
                    6'b011000: config_lutId <= 64'h0000_0000_0100_0000;
                    6'b011001: config_lutId <= 64'h0000_0000_0200_0000;
                    6'b011010: config_lutId <= 64'h0000_0000_0400_0000;
                    6'b011011: config_lutId <= 64'h0000_0000_0800_0000;
                    6'b011100: config_lutId <= 64'h0000_0000_1000_0000;
                    6'b011101: config_lutId <= 64'h0000_0000_2000_0000;
                    6'b011110: config_lutId <= 64'h0000_0000_4000_0000;
                    6'b011111: config_lutId <= 64'h0000_0000_8000_0000; 
                    6'b100000: config_lutId <= 64'h0000_0001_0000_0000;
                    6'b100001: config_lutId <= 64'h0000_0002_0000_0000;
                    6'b100010: config_lutId <= 64'h0000_0004_0000_0000;
                    6'b100011: config_lutId <= 64'h0000_0008_0000_0000;
                    6'b100100: config_lutId <= 64'h0000_0010_0000_0000;
                    6'b100101: config_lutId <= 64'h0000_0020_0000_0000;
                    6'b100110: config_lutId <= 64'h0000_0040_0000_0000;
                    6'b100111: config_lutId <= 64'h0000_0080_0000_0000;
                    6'b101000: config_lutId <= 64'h0000_0100_0000_0000;
                    6'b101001: config_lutId <= 64'h0000_0200_0000_0000;
                    6'b101010: config_lutId <= 64'h0000_0400_0000_0000;
                    6'b101011: config_lutId <= 64'h0000_0800_0000_0000;
                    6'b101100: config_lutId <= 64'h0000_1000_0000_0000;
                    6'b101101: config_lutId <= 64'h0000_2000_0000_0000;
                    6'b101110: config_lutId <= 64'h0000_4000_0000_0000;
                    6'b101111: config_lutId <= 64'h0000_8000_0000_0000;
                    6'b110000: config_lutId <= 64'h0001_0000_0000_0000;
                    6'b110001: config_lutId <= 64'h0002_0000_0000_0000;
                    6'b110010: config_lutId <= 64'h0004_0000_0000_0000;
                    6'b110011: config_lutId <= 64'h0008_0000_0000_0000;
                    6'b110100: config_lutId <= 64'h0010_0000_0000_0000;
                    6'b110101: config_lutId <= 64'h0020_0000_0000_0000;
                    6'b110110: config_lutId <= 64'h0040_0000_0000_0000;
                    6'b110111: config_lutId <= 64'h0080_0000_0000_0000;
                    6'b111000: config_lutId <= 64'h0100_0000_0000_0000;
                    6'b111001: config_lutId <= 64'h0200_0000_0000_0000;
                    6'b111010: config_lutId <= 64'h0400_0000_0000_0000;
                    6'b111011: config_lutId <= 64'h0800_0000_0000_0000;
                    6'b111100: config_lutId <= 64'h1000_0000_0000_0000;
                    6'b111101: config_lutId <= 64'h2000_0000_0000_0000;
                    6'b111110: config_lutId <= 64'h4000_0000_0000_0000;
                    6'b111111: config_lutId <= 64'h8000_0000_0000_0000; 
                    default:   config_lutId <= 64'h0000_0000_0000_0000;
                endcase
            end
            else if(up_raddr_s[UP_ADDR_WIDTH-1]==1) begin
                case(up_raddr_s[UP_ADDR_WIDTH-2:UP_ADDR_WIDTH-7])
                    6'b000000: config_lutId <= 64'h0000_0000_0000_0001;
                    6'b000001: config_lutId <= 64'h0000_0000_0000_0002;
                    6'b000010: config_lutId <= 64'h0000_0000_0000_0004;
                    6'b000011: config_lutId <= 64'h0000_0000_0000_0008;
                    6'b000100: config_lutId <= 64'h0000_0000_0000_0010;
                    6'b000101: config_lutId <= 64'h0000_0000_0000_0020;
                    6'b000110: config_lutId <= 64'h0000_0000_0000_0040;
                    6'b000111: config_lutId <= 64'h0000_0000_0000_0080;
                    6'b001000: config_lutId <= 64'h0000_0000_0000_0100;
                    6'b001001: config_lutId <= 64'h0000_0000_0000_0200;
                    6'b001010: config_lutId <= 64'h0000_0000_0000_0400;
                    6'b001011: config_lutId <= 64'h0000_0000_0000_0800;
                    6'b001100: config_lutId <= 64'h0000_0000_0000_1000;
                    6'b001101: config_lutId <= 64'h0000_0000_0000_2000;
                    6'b001110: config_lutId <= 64'h0000_0000_0000_4000;
                    6'b001111: config_lutId <= 64'h0000_0000_0000_8000;  
                    6'b010000: config_lutId <= 64'h0000_0000_0001_0000;
                    6'b010001: config_lutId <= 64'h0000_0000_0002_0000;
                    6'b010010: config_lutId <= 64'h0000_0000_0004_0000;
                    6'b010011: config_lutId <= 64'h0000_0000_0008_0000;
                    6'b010100: config_lutId <= 64'h0000_0000_0010_0000;
                    6'b010101: config_lutId <= 64'h0000_0000_0020_0000;
                    6'b010110: config_lutId <= 64'h0000_0000_0040_0000;
                    6'b010111: config_lutId <= 64'h0000_0000_0080_0000;
                    6'b011000: config_lutId <= 64'h0000_0000_0100_0000;
                    6'b011001: config_lutId <= 64'h0000_0000_0200_0000;
                    6'b011010: config_lutId <= 64'h0000_0000_0400_0000;
                    6'b011011: config_lutId <= 64'h0000_0000_0800_0000;
                    6'b011100: config_lutId <= 64'h0000_0000_1000_0000;
                    6'b011101: config_lutId <= 64'h0000_0000_2000_0000;
                    6'b011110: config_lutId <= 64'h0000_0000_4000_0000;
                    6'b011111: config_lutId <= 64'h0000_0000_8000_0000; 
                    6'b100000: config_lutId <= 64'h0000_0001_0000_0000;
                    6'b100001: config_lutId <= 64'h0000_0002_0000_0000;
                    6'b100010: config_lutId <= 64'h0000_0004_0000_0000;
                    6'b100011: config_lutId <= 64'h0000_0008_0000_0000;
                    6'b100100: config_lutId <= 64'h0000_0010_0000_0000;
                    6'b100101: config_lutId <= 64'h0000_0020_0000_0000;
                    6'b100110: config_lutId <= 64'h0000_0040_0000_0000;
                    6'b100111: config_lutId <= 64'h0000_0080_0000_0000;
                    6'b101000: config_lutId <= 64'h0000_0100_0000_0000;
                    6'b101001: config_lutId <= 64'h0000_0200_0000_0000;
                    6'b101010: config_lutId <= 64'h0000_0400_0000_0000;
                    6'b101011: config_lutId <= 64'h0000_0800_0000_0000;
                    6'b101100: config_lutId <= 64'h0000_1000_0000_0000;
                    6'b101101: config_lutId <= 64'h0000_2000_0000_0000;
                    6'b101110: config_lutId <= 64'h0000_4000_0000_0000;
                    6'b101111: config_lutId <= 64'h0000_8000_0000_0000;
                    6'b110000: config_lutId <= 64'h0001_0000_0000_0000;
                    6'b110001: config_lutId <= 64'h0002_0000_0000_0000;
                    6'b110010: config_lutId <= 64'h0004_0000_0000_0000;
                    6'b110011: config_lutId <= 64'h0008_0000_0000_0000;
                    6'b110100: config_lutId <= 64'h0010_0000_0000_0000;
                    6'b110101: config_lutId <= 64'h0020_0000_0000_0000;
                    6'b110110: config_lutId <= 64'h0040_0000_0000_0000;
                    6'b110111: config_lutId <= 64'h0080_0000_0000_0000;
                    6'b111000: config_lutId <= 64'h0100_0000_0000_0000;
                    6'b111001: config_lutId <= 64'h0200_0000_0000_0000;
                    6'b111010: config_lutId <= 64'h0400_0000_0000_0000;
                    6'b111011: config_lutId <= 64'h0800_0000_0000_0000;
                    6'b111100: config_lutId <= 64'h1000_0000_0000_0000;
                    6'b111101: config_lutId <= 64'h2000_0000_0000_0000;
                    6'b111110: config_lutId <= 64'h4000_0000_0000_0000;
                    6'b111111: config_lutId <= 64'h8000_0000_0000_0000; 
                    default:   config_lutId <= 64'h0000_0000_0000_0000;
                endcase           
            end
            else begin
                config_lutId <= 0;
            end
        end
    end

    //delaying data read with 1 tck to compensate for the ROM latency
    always @(posedge up_clk) begin
        up_rreq_s_d <= up_rreq_s;
    end

    //axi registers read    
    always @(posedge up_clk) begin
        if (~up_rstn) begin
            up_rack_s <= 0;
            up_rdata_s <= 0;
        end
        else begin
            up_rack_s <= up_rreq_s_d;
            if (up_rreq_s_d == 1'b1) begin
                if(up_raddr_s[UP_ADDR_WIDTH-1]) begin
                    up_rdata_s <= config_dout;
                end
                else begin
                    if(up_raddr_s[UP_ADDR_WIDTH-2:0] == 0) begin
                        up_rdata_s <= IP_VERSION;
                    end
                    else if(up_raddr_s[UP_ADDR_WIDTH-2:0] == 1) begin
                        up_rdata_s <= ID_MASK[31:0];
                    end
                    else if(up_raddr_s[UP_ADDR_WIDTH-2:0] == 2) begin
                        up_rdata_s <= ID_MASK[63:32];
                    end                    
                    else if(up_raddr_s[UP_ADDR_WIDTH-2:0] == 3) begin
                        up_rdata_s <= up_scratch;
                    end
                    else if(up_raddr_s[UP_ADDR_WIDTH-2:0] == 4) begin
                        up_rdata_s <= up_bypass;
                    end
                    else begin
                        up_rdata_s <= 0;
                    end
                end
            end
            else begin
                up_rdata_s <= 32'd0;
            end
        end
    end

    assign config_addr_rreq = up_raddr_s[LUT_ADDR_WIDTH-1:0];
    assign config_addr = (config_web==1'b1) ? config_addr_wreq : config_addr_rreq;
    assign bypass = up_bypass[0];

    //interface to tx_fir_interpolator
    //clkdiv2, tu_enable
    always@(posedge clk or negedge rst_n)
        if(~rst_n) begin
            clkdiv2 <= 0;
            tu_enable <= 0;
        end
        else begin
            clkdiv2 <= ~clkdiv2;
            tu_enable <= data_in_enable_0 & data_in_enable_1;
        end

    //tu
    always@(posedge clk or negedge rst_n)
        if(~rst_n) begin
            tu <= 0;
        end
        else begin
            if(~clkdiv2) begin
                tu <= {data_in_0[LUT_DATA_WIDTH-1:LUT_DATA_WIDTH/2], data_in_1[LUT_DATA_WIDTH-1:LUT_DATA_WIDTH/2]};
            end
            else begin
                tu <= {data_in_0[LUT_DATA_WIDTH/2-1:0], data_in_1[LUT_DATA_WIDTH/2-1:0]};
            end
        end

    //interface to tx_adrv9009_tpl_core
    assign data_out_valid_0 = data_out_valid;
    assign data_out_valid_1 = data_out_valid;
    assign data_out_0 = tx_i;
    assign data_out_1 = tx_q;

    //tx_i, tx_q
    always@(posedge clk or negedge rst_n)
        if(~rst_n) begin
            tx_i <= 0;
            tx_q <= 0;
            data_out_valid <= 0;
        end
        else begin
            tx_i <= {tx_i[LUT_DATA_WIDTH/2-1:0], tx[LUT_DATA_WIDTH-1:LUT_DATA_WIDTH/2]};
            tx_q <= {tx_q[LUT_DATA_WIDTH/2-1:0], tx[LUT_DATA_WIDTH/2-1:0]};
            data_out_valid <= tx_valid;
        end

    cmag_fixed#(
        .LUT_DATA_WIDTH(LUT_DATA_WIDTH),
        .LUT_ADDR_WIDTH(LUT_ADDR_WIDTH)
    )
    i_cmag(
        .clk(clk),
        .rst_n(rst_n),
        .tu(tu),
        .mag(mag)
    );

    delay #(
        .TAPS(16), // latency of module cmag_fixed
        .DWIDTH(LUT_DATA_WIDTH)
    )tu_delay
    (
        .clk(clk),
        .din(tu),
        .dout(tu_aligned)
    );

    dpd_actuator #(
        .ID_MASK(ID_MASK),
        .DATA_WIDTH(LUT_DATA_WIDTH),
        .ADDR_WIDTH(LUT_ADDR_WIDTH)
    )
    i_dpd_actuator(
        .clk(clk),
        .rst_n(rst_n),

        .tu_enable(tu_enable),
        .bypass(bypass),
        .tu(tu_aligned),
        .mag(mag), // mag = abs(tu)
        .tx(tx), // postDPD
        .tx_valid(tx_valid),

        // configuration port
        .config_clk(up_clk),
        .config_addr(config_addr),
        .config_din(config_din),
        .config_dout(config_dout),
        .config_lutId(config_lutId),
        .config_web(config_web)
    );

endmodule