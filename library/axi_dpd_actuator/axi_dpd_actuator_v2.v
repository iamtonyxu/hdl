`timescale 1ns / 100ps
/*
* this module is to wrap dpd_actuator with axi bus
*/

module axi_dpd_actuator_v2 #(
    parameter ID_MASK = 64'hFFFF_FFFF_FFFF_FFFF,
    parameter LUT_ADDR_WIDTH = 10
)
(
    // signal from tx_fir_interpolator, two samples per channel
    // data_in_0 = {tu_i[2n+1],tu_i[2n]}
    // data_in_1 = {tu_q[2n+1],tu_q[2n]}
    // data_in_2 = {mag[2n+1], mag[2n]}
    // data_in_enable_0/1/2 share one
    input                           data_clk,
    input                           data_rstn,
    input   [31:0]                  data_in_0,
    input   [31:0]                  data_in_1,
    input   [31:0]                  data_in_2,
    input                           data_in_enable_0,

    // signal to tx_adrv9009_tpl_core, two samples per channel
    // data_out_0 = {tx_i[2n+1],tx_i[2n]}
    // data_out_1 = {tx_q[2n+1],tx_q[2n]}
    output  [31:0]                  data_out_0,
    output                          data_out_valid_0,
    output  [31:0]                  data_out_1,
    output                          data_out_valid_1,

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

    localparam UP_ADDR_WIDTH = 14; // AXI_ADDR_WIDTH - 2
    localparam UP_DATA_WIDTH = 32; // AXI_DATA_WIDTH
    localparam IP_VERSION    = 32'h0001_0101;

////////////////////////////////////////////////////////////////////////////
// registers        axi-addr    up_addr     bit       R/W     Default
// IP_VERSION       0x0000      0x0000      [31:0]    R       32'h0001_0101
// ID_MASK_L        0x0004      0x0001      [31:0]    R       0xFFFF_FFFF
// ID_MASK_H        0x0008      0x0002      [31:0]    R       0xFFFF_FFFF
// scratch          0x000C      0x0003      [31:0]    R/W     0
// dpd_out_sel      0x0010      0x0004      [3:0]     R/W     0x0000_0000
// dpd_lutIdc_l     0x0014      0x0005      [31:0]    R/W     0x0000_0000
// dpd_lutIdc_h     0x0018      0x0006      [31:0]    R/W     0x0000_0000
////////////////////////////////////////////////////////////////////////////
// lut entries      axi-addr    up_addr     bit       R/W     Default
// lut[0]           0x8000      0x2000      [31:0]    R/W     0x0000_0000
// lut[1]           0x8004      0x2001      [31:0]    R/W     0x0000_0000
// ...              ...         ...         ...
// lut[1023]        0x83FF      0x20FF      [31:0]    R/W     0x0000_0000
////////////////////////////////////////////////////////////////////////////

    // internal registers
    reg   [31:0]                scratch;
    // dpd_out_sel[0] = 1, enable actuator, tx = dpd(tu)
    // dpd_out_sel[1] = 1, bypass actuator, tx = tu
    // dpd_out_sel[2] = 1, shutdown actuator, tx = 0
    // dpd_out_sel[3] = 1, freeze actuator, tx = 32'h1234_5678
    // otherwise, tx = dpd(tu)
    reg   [3:0]                 dpd_out_sel;
    reg   [31:0]                dpd_lutIdc_l;
    reg   [31:0]                dpd_lutIdc_h;

    // lutfifo_wr interface: from module up_axi to dpd_actuator 
    // wfifo_wdata[13:0] <= up_waddr_s | 14'h1000;
    // wfifo_wdata[29:16] <= up_raddr_s;
    // wfifo_wdata[63:32] <= up_wdata_s;
    // dpd_enc = wfifo_rdata[29] | wfifo_rdata[13];
    // dpd_wec = wfifo_rdata[12];
    // dpd_addrc = dpd_wec ? wfifo_rdata[9:0] : wfifo_rdata[25:16];
    // dpd_dinc = wfifo_rdata[63:32];
    reg                         wfifo_wr;
    reg   [63:0]                wfifo_wdata;
    wire                        wfifo_wfull;
    wire                        wfifo_rd;
    wire                        wfifo_rempty;
    wire  [63:0]                wfifo_rdata;

    //lutfifo_rd interface: from module dpd_actuator to up_axi
    // rfifo_wdata <= dpd_doutc
    // rfifo_rdata => up_rdata_s
    wire                        rfifo_wr;
    wire  [31:0]                rfifo_wdata;
    wire                        rfifo_wfull;
    wire                        rfifo_rd;
    wire                        rfifo_rempty;
    wire  [31:0]                rfifo_rdata;

    // up_axi interface
    wire                        up_clk;
    wire                        up_rstn;
    wire                        up_wreq_s;
    // up_waddr_s[13]: enc
    // up_waddr_s[9:0]: addrc
    wire  [UP_ADDR_WIDTH-1:0]   up_waddr_s;
    // up_wdata_s[31:0]: lut entry
    wire  [UP_DATA_WIDTH-1:0]   up_wdata_s;
    reg                         up_wack;
    
    wire                        up_rreq_s;
    wire  [UP_ADDR_WIDTH-1:0]   up_raddr_s;
    reg   [UP_DATA_WIDTH-1:0]   up_rdata_s;
    reg                         up_rack_s;
    reg                         up_rreq_s_d1;

    // dpd_actuator
    // signal in/out
    wire                        dpd_tu_enable;
    wire  [63:0]                dpd_tu;
    wire  [LUT_ADDR_WIDTH*2-1:0]dpd_mag;
    wire  [63:0]                dpd_tx;
    wire                        dpd_tx_valid;
    // from lutfifo_wr
    reg                         dpd_enc;
    reg                         dpd_wec;
    wire  [63:0]                dpd_lutIdc;
    reg   [LUT_ADDR_WIDTH-1:0]  dpd_addrc;
    reg   [UP_DATA_WIDTH-1:0]   dpd_dinc;
    // to lutfifo_rd
    wire  [UP_DATA_WIDTH-1:0]   dpd_doutc;
    wire                        dpd_validc;
    
    // tu input
    assign dpd_tu_enable =  data_in_enable_0;
    assign dpd_tu = {data_in_0[15:0], 
                     data_in_1[15:0], 
                     data_in_0[31:16], 
                     data_in_1[31:16]};
    assign dpd_mag = {data_in_2[LUT_ADDR_WIDTH-1:0], 
                      data_in_2[16+LUT_ADDR_WIDTH-1:16]};

    // lut config
    assign dpd_lutIdc = {dpd_lutIdc_h, dpd_lutIdc_l};
/*
    assign dpd_enc = wfifo_rdata[29] | wfifo_rdata[13];
    assign dpd_wec = wfifo_rdata[12];
    assign dpd_addrc = dpd_wec ? wfifo_rdata[9:0] : wfifo_rdata[25:16];
    assign dpd_dinc = wfifo_rdata[63:32];
*/
    always@(posedge data_clk or negedge data_rstn)
        if(~data_rstn) begin
            dpd_enc <= 0;
            dpd_wec <= 0;
            dpd_addrc <= 0;
            dpd_dinc <= 0;
        end
        else begin
            if(wfifo_rd) begin
                dpd_enc <= wfifo_rdata[29] | wfifo_rdata[13];
                dpd_wec <= wfifo_rdata[12];
                dpd_dinc <= wfifo_rdata[63:32];

                if(wfifo_rdata[12])
                    dpd_addrc <= wfifo_rdata[9:0];
                else
                    dpd_addrc <= wfifo_rdata[25:16];

            end
            else begin
                dpd_enc <= 0;
                dpd_wec <= 0;
                dpd_addrc <= 0;
                dpd_dinc <= 0;
            end
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
    
    // lutfifo_wr: from up_axi to dpd_actuator
    // writing luts has higher priority than reading luts
    always @(posedge up_clk or negedge up_rstn)
    if(~up_rstn) begin
        wfifo_wr <= 0;
        wfifo_wdata <= 0;
    end
    else begin
        if(up_wreq_s && up_waddr_s[13]) begin
            wfifo_wr <= 1;
            wfifo_wdata[13:0] <= up_waddr_s | 14'h1000;
            wfifo_wdata[29:16] <= 0;
            wfifo_wdata[63:32] <= up_wdata_s;
        end
        else if(up_rreq_s && up_raddr_s[13]) begin
            wfifo_wr <= 1;
            wfifo_wdata[13:0] <= 0;
            wfifo_wdata[29:16] <= up_raddr_s;
            wfifo_wdata[63:32] <= 0;
        end
        else begin
            wfifo_wr <= 0;
            wfifo_wdata <= 0;
        end
    end
        
    assign wfifo_rd = ~wfifo_rempty;
    
    afifo #(
        .DSIZE(64),
        .ASIZE(8)
    )
    lutfifo_wr(
        .i_wclk(up_clk),
        .i_wrst_n(up_rstn),
        .i_wr(wfifo_wr),
        .i_wdata(wfifo_wdata),
        .o_wfull(wfifo_wfull),
		.i_rclk(data_clk),
        .i_rrst_n(data_rstn),
        .i_rd(wfifo_rd),
        .o_rdata(wfifo_rdata),
        .o_rempty(wfifo_rempty)
    );

    // lutfifo_rd: from dpd_actuator to up_axi
    assign rfifo_wr = dpd_validc;
    assign rfifo_wdata = dpd_doutc;
    assign rfifo_rd = ~rfifo_rempty;
    
    afifo #(
        .DSIZE(32),
        .ASIZE(8)
    )
    lutfifo_rd(
        .i_wclk(data_clk),
        .i_wrst_n(data_rstn),
        .i_wr(rfifo_wr),
        .i_wdata(rfifo_wdata),
        .o_wfull(rfifo_wfull),
		.i_rclk(up_clk),
        .i_rrst_n(up_rstn),
        .i_rd(rfifo_rd),
        .o_rdata(rfifo_rdata),
        .o_rempty(rfifo_rempty)
    );


    // writing registers
    always @(posedge up_clk)
        if(~up_rstn) begin
            scratch <= 0;
            dpd_out_sel <= 0;
            dpd_lutIdc_l <= 0;
            dpd_lutIdc_h <= 0;
        end
        else begin
            if(up_wreq_s && ~up_waddr_s[13]) begin
                // writing registers
                if(up_waddr_s[3:0] == 3)
                    scratch <= up_wdata_s;

                if(up_waddr_s[3:0] == 4)
                    dpd_out_sel <= up_wdata_s;

                if(up_waddr_s[3:0] == 5)
                    dpd_lutIdc_l <= up_wdata_s;

                if(up_waddr_s[3:0] == 6)
                    dpd_lutIdc_h <= up_wdata_s;
            end
        end

    //delaying data read with 1 tck to compensate for the ROM latency
    always @(posedge up_clk)
        if(~up_rstn)
            up_rreq_s_d1 <= 0;
        else
            up_rreq_s_d1 <= up_rreq_s;

    // reading registers & lutfifo_rd
    always @(posedge up_clk) begin
        if (~up_rstn) begin
            up_rack_s <= 0;
            up_rdata_s <= 0;
        end
        else begin
            // reading lut entries
            if(rfifo_rd) begin
                    up_rack_s <= 1;
                    up_rdata_s <= rfifo_rdata;
            end
            // reading registers
            else if (up_rreq_s_d1 & ~up_raddr_s[UP_ADDR_WIDTH-1]) begin
                up_rack_s <= 1;
                if(up_raddr_s[3:0] == 0)
                    up_rdata_s <= IP_VERSION;
                else if(up_raddr_s[3:0] == 1)
                    up_rdata_s <= ID_MASK[31:0];
                else if(up_raddr_s[3:0] == 2)
                    up_rdata_s <= ID_MASK[63:32];                   
                else if(up_raddr_s[3:0] == 3)
                    up_rdata_s <= scratch;
                else if(up_raddr_s[3:0] == 4)
                    up_rdata_s <= dpd_out_sel;
                else if(up_raddr_s[3:0] == 5)
                    up_rdata_s <= dpd_lutIdc_l;
                else if(up_raddr_s[3:0] == 6)
                    up_rdata_s <= dpd_lutIdc_h;
                else
                    up_rdata_s <= 0;
            end
            else begin
                up_rack_s <= 0;
                up_rdata_s <= 32'd0;
            end
        end
    end

    // dpd_actuator
    dpd_actuator_v2 #(
        .ID_MASK(ID_MASK),
        .DATA_WIDTH(32),
        .ADDR_WIDTH(LUT_ADDR_WIDTH)
    )
    inst(
        // signal in/out
        .clk(data_clk),
        .rst_n(data_rstn),
        .tu_enable(dpd_tu_enable),
        .tu(dpd_tu),
        .mag(dpd_mag),
        .tx(dpd_tx),
        .tx_valid(dpd_tx_valid),

        // configuration
        .enc(dpd_enc),
        .lutIdc(dpd_lutIdc),
        .wec(dpd_wec),
        .addrc(dpd_addrc),
        .dinc(dpd_dinc),
        .doutc(dpd_doutc),
        .validc(dpd_validc)
    );

    // data_out_0 = {tx_i[2n+1],tx_i[2n]}
    // data_out_1 = {tx_q[2n+1],tx_q[2n]}
    assign data_out_0 = dpd_out_sel[0] ? {dpd_tx[47:32], dpd_tx[15:0]} :
                        dpd_out_sel[1] ? data_in_0     :
                        dpd_out_sel[2] ? 32'h0000_0000 :
                        dpd_out_sel[3] ? 32'h1234_5678 :
                        data_in_0;

    assign data_out_1 = dpd_out_sel[0] ? {dpd_tx[63:48], dpd_tx[31:16]} :
                        dpd_out_sel[1] ? data_in_1     :
                        dpd_out_sel[2] ? 32'h0000_0000 :
                        dpd_out_sel[3] ? 32'h9abc_def0 :
                        data_in_1;

    assign data_out_valid_0 = dpd_tx_valid;
    assign data_out_valid_1 = dpd_tx_valid;

endmodule