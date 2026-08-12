`timescale 1ns / 1ps
//////////////////////////////////////////////////////////////////////////////////
// Company: ZHFG
// Engineer: YalongXu
//
// Create Date: 2026/08/11
// Design Name:
// Module Name: spi_slave_if
// Project Name:
// Target Devices:
// Tool Versions:
// Description:
//
// This module works as a spi slave and help the external spi master to get access pcore registers.
// It's a simple version with below limitation:
// 1. the spi slave only supports 4-wire mode
// 2. only need to work with spi mode 0, it means data sampled on rising edge and shifted out on the falling edge
//      |SPI Mode    |   CPOL    |   CPHA    |   Clock Polarity in Idle  |
//      |0           |   0       |   0       |   Logic low               |
//      |1           |   0       |   1       |   Logic low               |
//      |2           |   1       |   0       |   Logic high              |
//      |3           |   1       |   1       |   Logic high              |
// 3. only supports MSB first format
// 4. each spi write/read operation always transfers 32+32=64 bits, and the bit field as below:
// - D[63]: W/Rb, 1 indicates a write operation; 0 indicates a read operation. Let's assume spi_wr = D[63]
// - D[62:32]: the read/write register Address, suppose spi_addr[30:0]=D[62:32]
// - D[31:0]: value of the read/write register, suppose spi_data[31:0]=D[31:0]. Note sdo is used with 4-wire mode.
// 5. the design has to over-sample the spi bus using up_clk
// - sclk is 25MHz, and up_clk is 100MHz
// 6. pcore interface works under up_clk and up_rst_n
// 7. timing of spi write
// - spi_cnt counts sclk cycles(or rising edge) from 0 to 64 during each spi write
// - up_waddr[13:0] <= spi_addr[15:2] if spi_cnt reaches 32
// - up_wdata[31:0] <= spi_data[31:0] if spi_cnt reaches 64
// - up_wreq <= 1 if spi_cnt reaches 64, hold until up_wack asserted
// 8. timing of spi read
// - spi_cnt counts sclk cycles from 0 to 64 during each spi read
// - up_raddr[13:0] <= spi_addr[15:2] if spi_cnt reaches (32-2)
// - up_rreq <= 1 if spi_cnt reaches (32-2), hold until up_rack asserted
// 9. sdo during spi read — shifts out up_rdata[31:0] MSB-first on sclk falling edges
//    during the data phase (spi_cnt = 32..63), so the master samples on rising edges
//
// Dependencies: None
//
// Revision:
// Revision 0.1 - design a simple version and run the simulation, see the limitation in the Description above.
//
// Additional Comments:
//
//////////////////////////////////////////////////////////////////////////////////

module spi_slave_if #(
    parameter AXI_ADDRESS_WIDTH = 16
) (
    // reset and clocks
    input                               up_rstn,
    input                               up_clk,

    // pcore interface
    output  reg                         up_wreq,
    output  reg  [(AXI_ADDRESS_WIDTH-3):0] up_waddr,
    output  reg  [31:0]                 up_wdata,
    input                               up_wack,
    output  reg                         up_rreq,
    output  reg  [(AXI_ADDRESS_WIDTH-3):0] up_raddr,
    input   [31:0]                      up_rdata,
    input                               up_rack,

    // spi bus
    input                               sclk,
    input                               sdi,
    output  reg                         sdo,
    input                               cs_n
);

    //--------------------------------------------------------------------------
    // Local parameters
    //--------------------------------------------------------------------------
    localparam SPI_FRAME_BITS  = 64;            // total bits per transaction
    localparam SPI_ADDR_END    = 32;            // address phase ends at bit 32
    localparam SPI_READ_ADDR   = 30;            // read-address latch (2 cycles early)
    localparam SPI_SDO_START   = 31;            // activate SDO shifter one cycle ahead

    //--------------------------------------------------------------------------
    // Synchronizers — 3-stage for metastability mitigation
    //--------------------------------------------------------------------------
    reg [2:0] sclk_sync;
    reg [2:0] sdi_sync;
    reg [2:0] cs_n_sync;

    //--------------------------------------------------------------------------
    // SPI internal registers
    //--------------------------------------------------------------------------
    reg [63:0] spi_shift;                       // 64-bit receive shift register
    reg [6:0]  spi_cnt;                         // bit counter, 0 .. SPI_FRAME_BITS
    reg [31:0] sdo_shift;                       // parallel-loaded read-data word
    reg        sdo_shift_active;                // high during read data phase
    reg        spi_wr;                          // R/W bit captured on 1st SCLK rising edge
    reg        up_wreq_sent;                    // one-shot: wreq asserted this transaction
    reg        up_rreq_sent;                    // one-shot: rreq asserted this transaction

    //--------------------------------------------------------------------------
    // Edge detection (derived from synchronized SCLK)
    //
    // sclk_rising/sclk_falling detect edges at the sclk_sync[1] level.
    // But sdi_sync[2] and cs_n_sync[2] are one stage further delayed.
    // Registering the edge flags by one more cycle aligns them with the
    // 3-stage-synchronized data/control signals.
    //--------------------------------------------------------------------------
    wire sclk_rising_pre  = (sclk_sync[2:1] == 2'b01);
    wire sclk_falling_pre = (sclk_sync[2:1] == 2'b10);
    reg  sclk_rising;
    reg  sclk_falling;

    //--------------------------------------------------------------------------
    // Decoded data field from the 64-bit shift register (valid after full frame)
    //--------------------------------------------------------------------------
    wire [31:0] spi_data  = spi_shift[31:0];     // write / read data

    //==========================================================================
    // Synchronizer chains
    //==========================================================================
    always @(posedge up_clk or negedge up_rstn) begin
        if (!up_rstn) begin
            sclk_sync <= 3'b0;
            sdi_sync  <= 3'b0;
            cs_n_sync <= 3'b111;
        end else begin
            sclk_sync <= {sclk_sync[1:0], sclk};
            sdi_sync  <= {sdi_sync[1:0],  sdi};
            cs_n_sync <= {cs_n_sync[1:0], cs_n};
        end
    end

    //==========================================================================
    // Edge-delay registers — align rising/falling flags with _sync[2] stage
    //==========================================================================
    always @(posedge up_clk or negedge up_rstn) begin
        if (!up_rstn) begin
            sclk_rising  <= 1'b0;
            sclk_falling <= 1'b0;
        end else begin
            sclk_rising  <= sclk_rising_pre;
            sclk_falling <= sclk_falling_pre;
        end
    end

    //==========================================================================
    // SPI receive path — SDI sampling, shift register, bit counter, R/W capture
    //==========================================================================
    always @(posedge up_clk or negedge up_rstn) begin
        if (!up_rstn) begin
            spi_shift <= 64'd0;
            spi_cnt   <= 7'd0;
            spi_wr    <= 1'b0;
        end else if (!cs_n_sync[2]) begin
            if (sclk_rising) begin
                spi_shift <= {spi_shift[62:0], sdi_sync[2]};
                if (spi_cnt < SPI_FRAME_BITS)
                    spi_cnt <= spi_cnt + 7'd1;
                if (spi_cnt == 7'd0)
                    spi_wr <= sdi_sync[2];
            end
        end else begin
            // Transaction idle
            spi_cnt   <= 7'd0;
            spi_shift <= 64'd0;
            spi_wr    <= 1'b0;
        end
    end

    //==========================================================================
    // SPI transmit path — SDO output shifter + load read-data from pcore
    //==========================================================================
    always @(posedge up_clk or negedge up_rstn) begin
        if (!up_rstn) begin
            sdo       <= 1'b0;
            sdo_shift <= 32'd0;
        end else if (!cs_n_sync[2]) begin
            if (sclk_falling) begin
                if (sdo_shift_active && spi_cnt < SPI_FRAME_BITS) begin
                    sdo       <= sdo_shift[31];
                    sdo_shift <= {sdo_shift[30:0], 1'b0};
                end else begin
                    sdo <= 1'b0;
                end
            end
            // Load read-data from pcore when handshake completes
            if (!spi_wr && up_rack)
                sdo_shift <= up_rdata;
        end else begin
            sdo <= 1'b0;
        end
    end

    //==========================================================================
    // Upstream write channel — waddr, wdata, wreq + wack handshake
    //==========================================================================
    always @(posedge up_clk or negedge up_rstn) begin
        if (!up_rstn) begin
            up_waddr     <= {(AXI_ADDRESS_WIDTH-2){1'b0}};
            up_wdata     <= 32'd0;
            up_wreq      <= 1'b0;
            up_wreq_sent <= 1'b0;
        end else begin
            if (!cs_n_sync[2]) begin
                // Latch write address at end of address phase (spi_cnt==32).
                // 32 frame-bits in spi_shift: frame-bit F -> spi_shift[F-32].
                // addr[ADDR_W-1:2] = frame bits [ADDR_W+31:34] -> spi_shift[(ADDR_W-1):2].
                if (spi_cnt == SPI_ADDR_END && spi_wr)
                    up_waddr <= spi_shift[(AXI_ADDRESS_WIDTH-1) : 2];

                // Latch write data and assert up_wreq at end of frame (one-shot)
                if (spi_cnt == SPI_FRAME_BITS && spi_wr && !up_wreq_sent) begin
                    up_wdata     <= spi_data;
                    up_wreq      <= 1'b1;
                    up_wreq_sent <= 1'b1;
                end
            end else begin
                up_wreq_sent <= 1'b0;
            end

            // Handshake: de-assert up_wreq on up_wack (any time)
            if (up_wack) begin
                up_wreq <= 1'b0;
            end
        end
    end

    //==========================================================================
    // Upstream read channel — raddr, rreq + rack handshake, SDO activation
    //==========================================================================
    always @(posedge up_clk or negedge up_rstn) begin
        if (!up_rstn) begin
            up_raddr         <= {(AXI_ADDRESS_WIDTH-2){1'b0}};
            up_rreq          <= 1'b0;
            up_rreq_sent     <= 1'b0;
            sdo_shift_active <= 1'b0;
        end else begin
            if (!cs_n_sync[2]) begin
                // Latch read address early (spi_cnt==30, one-shot).
                // 30 frame-bits in spi_shift: frame-bit F -> spi_shift[F-34].
                // addr[ADDR_W-1:2] = frame bits [ADDR_W+31:34] -> spi_shift[(ADDR_W-3):0].
                if (spi_cnt == SPI_READ_ADDR && !spi_wr && !up_rreq_sent) begin
                    up_raddr     <= spi_shift[(AXI_ADDRESS_WIDTH-3) : 0];
                    up_rreq      <= 1'b1;
                    up_rreq_sent <= 1'b1;
                end

                // Activate SDO data phase one cycle before first data bit
                if (spi_cnt == SPI_SDO_START && !spi_wr) begin
                    sdo_shift_active <= 1'b1;
                end
            end else begin
                up_rreq_sent     <= 1'b0;
                sdo_shift_active <= 1'b0;
            end
        
            // Handshake: de-assert up_rreq on up_rack (any time)
            if (up_rack) begin
                up_rreq <= 1'b0;
            end
        end
    end

endmodule
