`timescale 1ns / 100ps

//////////////////////////////////////////////////////////////////////////////////
// Company:
// Engineer: iamtony
//
// Create Date: 2026/04/29
// Design Name:
// Module Name: axi_tx_config
// Project Name:
// Target Devices:
// Tool Versions:
// Description: AXI-Lite control block for TX data source and mapper settings.
//
// Dependencies: up_axi, data2fpga.
//
// Revision:
// Revision 0.02 - Header refreshed and comments clarified.
// Additional Comments:
// Register space includes source select, DDR playback, constants, and DDS tones.
//////////////////////////////////////////////////////////////////////////////////

module axi_tx_config (
  // AXI-Lite interface
  input                           s_axi_aclk,
  input                           s_axi_aresetn,

  // AXI-Lite write channel
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

  // AXI-Lite read channel
  input                           s_axi_arvalid,
  input   [15:0]                  s_axi_araddr,
  input   [2:0]                   s_axi_arprot,
  output                          s_axi_arready,
  output                          s_axi_rvalid,
  output  [1:0]                   s_axi_rresp,
  output  [31:0]                  s_axi_rdata,
  input                           s_axi_rready,

  // Command interface to axi_datamover
    output  [71:0]                  s_axis_mm2s_cmd_tdata,
    input                           s_axis_mm2s_cmd_tready,
    output                          s_axis_mm2s_cmd_tvalid,
    output                          m_axis_mm2s_sts_tready,
    input                           m_axis_mm2s_tlast,
    output                          m_axis_afifo_tready,

    // Interface to tx_data_source
    output  [1:0]                   src_sel_o,
    output  [31:0]                  const_data_0_o,
    output  [31:0]                  const_data_1_o,
    output                          dds_sync_o,
    output  [15:0]                  tone_1_scale_o,
    output  [15:0]                  tone_1_freq_word_o,
    output  [15:0]                  tone_2_scale_o,
    output  [15:0]                  tone_2_freq_word_o,

    // Interface to tx_data_mapper
    output                          frame_mapper_sel_o
);

    localparam UP_ADDR_WIDTH = 14; // 16 - 2
    localparam UP_DATA_WIDTH = 32;

    // TX configuration registers
    reg   [1:0]                src_sel;
    reg                        mapper_sel;
    reg                        ddr_play_ctrl;
    reg   [31:0]               ddr_play_length;
    reg   [31:0]               const_data_0;
    reg   [31:0]               const_data_1;
    reg                        dds_sync;
    reg   [15:0]               tone_1_scale;
    reg   [15:0]               tone_1_freq_word;
    reg   [15:0]               tone_2_scale;
    reg   [15:0]               tone_2_freq_word;

    // Outputs toward tx_data_source
    assign src_sel_o         = src_sel;
    assign const_data_0_o    = const_data_0;
    assign const_data_1_o    = const_data_1;
    assign dds_sync_o        = dds_sync;
    assign tone_1_scale_o    = tone_1_scale;
    assign tone_1_freq_word_o = tone_1_freq_word;
    assign tone_2_scale_o    = tone_2_scale;
    assign tone_2_freq_word_o = tone_2_freq_word;

    // Output toward tx_data_mapper
    assign frame_mapper_sel_o = mapper_sel;

    // DDR playback command generator
    data2fpga i_data2fpga (
      .clk                    (s_axi_aclk),
      .rstn                   (s_axi_aresetn),
      .ctrl                   (ddr_play_ctrl),
      .cfg                    (ddr_play_length),
      .s_axis_mm2s_cmd_tready (s_axis_mm2s_cmd_tready),
      .s_axis_mm2s_cmd_tvalid (s_axis_mm2s_cmd_tvalid),
      .s_axis_mm2s_cmd_tdata  (s_axis_mm2s_cmd_tdata),
      .m_axis_mm2s_sts_tready (m_axis_mm2s_sts_tready),
      .m_axis_mm2s_tlast      (m_axis_mm2s_tlast),
      .m_axis_afifo_tready    (m_axis_afifo_tready)
    );

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

    // up_axi clock/reset bridge
    assign up_clk  = s_axi_aclk;
    assign up_rstn = s_axi_aresetn;

    up_axi #(
        .AXI_ADDRESS_WIDTH(16)
    ) i_up_axi (
        .up_rstn         (up_rstn),
        .up_clk          (up_clk),
        .up_axi_awvalid  (s_axi_awvalid),
        .up_axi_awaddr   (s_axi_awaddr),
        .up_axi_awready  (s_axi_awready),
        .up_axi_wvalid   (s_axi_wvalid),
        .up_axi_wdata    (s_axi_wdata),
        .up_axi_wstrb    (s_axi_wstrb),
        .up_axi_wready   (s_axi_wready),
        .up_axi_bvalid   (s_axi_bvalid),
        .up_axi_bresp    (s_axi_bresp),
        .up_axi_bready   (s_axi_bready),
        .up_axi_arvalid  (s_axi_arvalid),
        .up_axi_araddr   (s_axi_araddr),
        .up_axi_arready  (s_axi_arready),
        .up_axi_rvalid   (s_axi_rvalid),
        .up_axi_rresp    (s_axi_rresp),
        .up_axi_rdata    (s_axi_rdata),
        .up_axi_rready   (s_axi_rready),
        .up_wreq         (up_wreq_s),
        .up_waddr        (up_waddr_s),
        .up_wdata        (up_wdata_s),
        .up_wack         (up_wack),
        .up_rreq         (up_rreq_s),
        .up_raddr        (up_raddr_s),
        .up_rdata        (up_rdata_s),
        .up_rack         (up_rack_s)
    );

    // AXI register writes
    always @(posedge up_clk) begin
        if (up_rstn == 1'b0) begin
            src_sel          <= 2'd0;
            mapper_sel       <= 1'b0;
            ddr_play_ctrl    <= 1'b0;
            ddr_play_length  <= 32'd0;
            const_data_0     <= 32'd0;
            const_data_1     <= 32'd0;
            dds_sync         <= 1'b0;
            tone_1_scale     <= 16'd0;
            tone_1_freq_word <= 16'd0;
            tone_2_scale     <= 16'd0;
            tone_2_freq_word <= 16'd0;
        end else begin
            if ((up_wreq_s == 1'b1) && (up_waddr_s == 14'h00)) begin
                src_sel <= up_wdata_s[1:0];
            end
            if ((up_wreq_s == 1'b1) && (up_waddr_s == 14'h01)) begin
                mapper_sel <= up_wdata_s[0];
            end
            if ((up_wreq_s == 1'b1) && (up_waddr_s == 14'h02)) begin
                ddr_play_ctrl <= up_wdata_s[0];
            end
            if ((up_wreq_s == 1'b1) && (up_waddr_s == 14'h03)) begin
                ddr_play_length <= up_wdata_s;
            end
            if ((up_wreq_s == 1'b1) && (up_waddr_s == 14'h04)) begin
                const_data_0 <= up_wdata_s;
            end
            if ((up_wreq_s == 1'b1) && (up_waddr_s == 14'h05)) begin
                const_data_1 <= up_wdata_s;
            end
            if ((up_wreq_s == 1'b1) && (up_waddr_s == 14'h06)) begin
                dds_sync <= up_wdata_s[0];
            end
            if ((up_wreq_s == 1'b1) && (up_waddr_s == 14'h07)) begin
                tone_1_scale <= up_wdata_s[15:0];
            end
            if ((up_wreq_s == 1'b1) && (up_waddr_s == 14'h08)) begin
                tone_1_freq_word <= up_wdata_s[15:0];
            end
            if ((up_wreq_s == 1'b1) && (up_waddr_s == 14'h09)) begin
                tone_2_scale <= up_wdata_s[15:0];
            end
            if ((up_wreq_s == 1'b1) && (up_waddr_s == 14'h0a)) begin
                tone_2_freq_word <= up_wdata_s[15:0];
            end
        end
    end

    // Write acknowledge
    always @(posedge up_clk) begin
        if (s_axi_aresetn == 1'b0)
            up_wack <= 'd0;
        else
            up_wack <= up_wreq_s;
    end

    // AXI register reads
    always @(posedge up_clk) begin
        if (s_axi_aresetn == 1'b0) begin
            up_rack_s  <= 'd0;
            up_rdata_s <= 'd0;
        end else begin
            up_rack_s <= up_rreq_s;
            if (up_rreq_s == 1'b1) begin
                case (up_raddr_s)
                    14'h00: up_rdata_s <= {30'd0, src_sel};
                    14'h01: up_rdata_s <= {31'd0, mapper_sel};
                    14'h02: up_rdata_s <= {31'd0, ddr_play_ctrl};
                    14'h03: up_rdata_s <= ddr_play_length;
                    14'h04: up_rdata_s <= const_data_0;
                    14'h05: up_rdata_s <= const_data_1;
                    14'h06: up_rdata_s <= {31'd0, dds_sync};
                    14'h07: up_rdata_s <= {16'd0, tone_1_scale};
                    14'h08: up_rdata_s <= {16'd0, tone_1_freq_word};
                    14'h09: up_rdata_s <= {16'd0, tone_2_scale};
                    14'h0a: up_rdata_s <= {16'd0, tone_2_freq_word};
                    default: up_rdata_s <= 32'd0;
                endcase
            end else begin
                up_rdata_s <= 32'd0;
            end
        end
    end

endmodule
