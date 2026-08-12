`timescale 1ns / 1ps
//////////////////////////////////////////////////////////////////////////////////
// Company: ZHFG
// Engineer: YalongXu
//
// Create Date: 2026/08/11
// Design Name:
// Module Name: pcore_registers.v
// Project Name:
// Target Devices:
// Tool Versions:
// Description:
//
// This module defines a set of inner registers for debug purpose.
// 1. Both module spi_slave_if and axi2spi_bridge can get access to these registers via up_if_1 and up_if_2.
// 2. Both up_if_1 and up_if_2 run under the same up_clk and up_rstn, and the priority of up_if_1 is higher than up_if_2.
// 3. Invoke spi_mailbox_irq interrupt Only if the host (spi master) writes arm_cmd_0.
// 4. Register Map is defined as below:
// |    addr        |   Name            |   Reset   |   Access  |   Description             |
// |    16'h0000    |   SRR             |   0x0000  |   R/W     |   Software reset register |
// |    16'h0004    |   SPICR           |   0x0180  |   R/W     |   SPI Control register    |
// |    16'h0008    |   SPISR           |   0x00a5  |   R       |   SPI Status register     |
// |    16'h000C    |   Device_config   |   0x1234  |   R       |   Device configuration    |
// |    16'h0010    |   chip_type       |   0x0001  |   R       |   chip type               |
// |    16'h0014    |   product_id      |   0x0001  |   R       |   product Id              |
// |    16'h0018    |   chip_grade      |   0xAAAA  |   R       |   chip grade              |
// |    16'h001C    |   scratch_pad     |   0xFFFF  |   R/W     |   scratch pad register    |
// |    16'h0020    |   vendor_id       |   0xABCD  |   R       |   vendor Id               |
// |    16'h0030    |   arm_cmd_0       |   0x0000  |   R/W     |   arm command 0           |
// |    16'h0034    |   arm_cmd_1       |   0x0000  |   R/W     |   arm command 1           |
// |    16'h0038    |   arm_cmd_2       |   0x0000  |   R/W     |   arm command 2           |
// |    16'h003C    |   arm_cmd_3       |   0x0000  |   R/W     |   arm command 3           |
// |    16'h0040    |   arm_cmd_4       |   0x0000  |   R/W     |   arm command 4           |
// |    16'h0044    |   arm_cmd_5       |   0x0000  |   R/W     |   arm command 5           |
// |    16'h0048    |   arm_cmd_6       |   0x0000  |   R/W     |   arm command 6           |
// |    16'h004C    |   arm_cmd_7       |   0x0000  |   R/W     |   arm command 7           |
// |    16'h0050    |   arm_status_0    |   0x0000  |   R       |   arm status 0            |
// |    16'h0054    |   arm_status_1    |   0x0000  |   R       |   arm status 1            |
// |    16'h0058    |   arm_status_2    |   0x0000  |   R       |   arm status 2            |
// |    16'h005C    |   arm_status_3    |   0x0000  |   R       |   arm status 3            |
// |    16'h0060    |   arm_status_4    |   0x0000  |   R       |   arm status 4            |
// |    16'h0064    |   arm_status_5    |   0x0000  |   R       |   arm status 5            |
// |    16'h0068    |   arm_status_6    |   0x0000  |   R       |   arm status 6            |
// |    16'h006C    |   arm_status_7    |   0x0000  |   R       |   arm status 7            |
//
// 5. Access property is for both up_if_1 and up_if_2, except arm_status_0/1/2/3/4/5/6/7 registers are R/W for up_if_2.
//
// Dependencies: None
//
// Revision:
// Revision 0.1 - This version is a simple demo about a bunch of registers defined in radio hw.
//
// Additional Comments:
//
//////////////////////////////////////////////////////////////////////////////////

module pcore_registers #(
    parameter AXI_ADDRESS_WIDTH = 16
) (
    // reset and clocks
    input                               up_rstn,
    input                               up_clk,

    // up_if_1 to module spi_slave_if  (higher priority)
    input                               up_wreq1,
    input  [(AXI_ADDRESS_WIDTH-3):0]    up_waddr1,
    input  [31:0]                       up_wdata1,
    output  reg                         up_wack1,
    input                               up_rreq1,
    input  [(AXI_ADDRESS_WIDTH-3):0]    up_raddr1,
    output  reg  [31:0]                 up_rdata1,
    output  reg                         up_rack1,

    // up_if_2 to module axi2spi_bridge  (lower priority)
    input                               up_wreq2,
    input  [(AXI_ADDRESS_WIDTH-3):0]    up_waddr2,
    input  [31:0]                       up_wdata2,
    output  reg                         up_wack2,
    input                               up_rreq2,
    input  [(AXI_ADDRESS_WIDTH-3):0]    up_raddr2,
    output  reg  [31:0]                 up_rdata2,
    output  reg                         up_rack2,

    output  reg                         spi_mailbox_irq
);

    //--------------------------------------------------------------------------
    // Local parameters -- word-address aliases for the register map
    //  (word_addr = byte_addr >> 2)
    //--------------------------------------------------------------------------
    localparam W_SRR          = 14'h0000;   // byte 0x0000
    localparam W_SPICR        = 14'h0001;   // byte 0x0004
    localparam W_SPISR        = 14'h0002;   // byte 0x0008
    localparam W_DEV_CFG      = 14'h0003;   // byte 0x000C
    localparam W_CHIP_TYPE    = 14'h0004;   // byte 0x0010
    localparam W_PRODUCT_ID   = 14'h0005;   // byte 0x0014
    localparam W_CHIP_GRADE   = 14'h0006;   // byte 0x0018
    localparam W_SCRATCH      = 14'h0007;   // byte 0x001C
    localparam W_VENDOR_ID    = 14'h0008;   // byte 0x0020
    localparam W_ARM_CMD_0    = 14'h000C;   // byte 0x0030
    localparam W_ARM_CMD_1    = 14'h000D;   // byte 0x0034
    localparam W_ARM_CMD_2    = 14'h000E;   // byte 0x0038
    localparam W_ARM_CMD_3    = 14'h000F;   // byte 0x003C
    localparam W_ARM_CMD_4    = 14'h0010;   // byte 0x0040
    localparam W_ARM_CMD_5    = 14'h0011;   // byte 0x0044
    localparam W_ARM_CMD_6    = 14'h0012;   // byte 0x0048
    localparam W_ARM_CMD_7    = 14'h0013;   // byte 0x004C
    localparam W_ARM_STATUS_0 = 14'h0014;   // byte 0x0050
    localparam W_ARM_STATUS_1 = 14'h0015;   // byte 0x0054
    localparam W_ARM_STATUS_2 = 14'h0016;   // byte 0x0058
    localparam W_ARM_STATUS_3 = 14'h0017;   // byte 0x005C
    localparam W_ARM_STATUS_4 = 14'h0018;   // byte 0x0060
    localparam W_ARM_STATUS_5 = 14'h0019;   // byte 0x0064
    localparam W_ARM_STATUS_6 = 14'h001A;   // byte 0x0068
    localparam W_ARM_STATUS_7 = 14'h001B;   // byte 0x006C

    //--------------------------------------------------------------------------
    // Register definitions -- one reg per register-map entry
    //--------------------------------------------------------------------------
    reg [31:0] srr;             // 0x0000  R/W   Software reset register
    reg [31:0] spicr;           // 0x0004  R/W   SPI Control register
    reg [31:0] spisr;           // 0x0008  R     SPI Status register
    reg [31:0] device_config;   // 0x000C  R     Device configuration
    reg [31:0] chip_type;       // 0x0010  R     chip type
    reg [31:0] product_id;      // 0x0014  R     product Id
    reg [31:0] chip_grade;      // 0x0018  R     chip grade
    reg [31:0] scratch_pad;     // 0x001C  R/W   scratch pad register
    reg [31:0] vendor_id;       // 0x0020  R     vendor Id
    reg [31:0] arm_cmd_0;       // 0x0030  R/W   arm command 0
    reg [31:0] arm_cmd_1;       // 0x0034  R/W   arm command 1
    reg [31:0] arm_cmd_2;       // 0x0038  R/W   arm command 2
    reg [31:0] arm_cmd_3;       // 0x003C  R/W   arm command 3
    reg [31:0] arm_cmd_4;       // 0x0040  R/W   arm command 4
    reg [31:0] arm_cmd_5;       // 0x0044  R/W   arm command 5
    reg [31:0] arm_cmd_6;       // 0x0048  R/W   arm command 6
    reg [31:0] arm_cmd_7;       // 0x004C  R/W   arm command 7
    reg [31:0] arm_status_0;    // 0x0050  R     arm status 0
    reg [31:0] arm_status_1;    // 0x0054  R     arm status 1
    reg [31:0] arm_status_2;    // 0x0058  R     arm status 2
    reg [31:0] arm_status_3;    // 0x005C  R     arm status 3
    reg [31:0] arm_status_4;    // 0x0060  R     arm status 4
    reg [31:0] arm_status_5;    // 0x0064  R     arm status 5
    reg [31:0] arm_status_6;    // 0x0068  R     arm status 6
    reg [31:0] arm_status_7;    // 0x006C  R     arm status 7

    //--------------------------------------------------------------------------
    // Internal wires -- write / read request gating
    //--------------------------------------------------------------------------
    wire wreq1, wreq2, wfire1, wfire2, rreq1, rreq2;

    assign wreq1  = up_wreq1 && !up_wack1;
    assign wreq2  = up_wreq2 && !up_wack2 && !wreq1;   // if_1 blocks if_2
    assign wfire1 = wreq1;                              // one-cycle write strobe
    assign wfire2 = wreq2;
    assign rreq1  = up_rreq1 && !up_rack1;
    assign rreq2  = up_rreq2 && !up_rack2 && !rreq1;

    //==========================================================================
    // Read-only registers -- reset initialisation only, never written
    //   (R for both interfaces)
    //==========================================================================
    always @(posedge up_clk or negedge up_rstn) begin
        if (!up_rstn) begin
            spisr         <= 32'h0000_00A5;
            device_config <= 32'h0000_1234;
            chip_type     <= 32'h0000_0001;
            product_id    <= 32'h0000_0001;
            chip_grade    <= 32'h0000_AAAA;
            vendor_id     <= 32'h0000_ABCD;
        end
    end

    //==========================================================================
    // R/W registers -- reset + write datapath
    //   arm_status_0~7 are R/W for up_if_2 only (up_if_1 reads only).
    //   Priority: reset > wfire1 > wfire2
    //==========================================================================
    always @(posedge up_clk or negedge up_rstn) begin
        if (!up_rstn) begin
            srr          <= 32'h0000_0000;
            spicr        <= 32'h0000_0180;
            scratch_pad  <= 32'h0000_FFFF;
            arm_cmd_0    <= 32'h0000_0000;
            arm_cmd_1    <= 32'h0000_0000;
            arm_cmd_2    <= 32'h0000_0000;
            arm_cmd_3    <= 32'h0000_0000;
            arm_cmd_4    <= 32'h0000_0000;
            arm_cmd_5    <= 32'h0000_0000;
            arm_cmd_6    <= 32'h0000_0000;
            arm_cmd_7    <= 32'h0000_0000;
            arm_status_0 <= 32'h0000_0000;
            arm_status_1 <= 32'h0000_0000;
            arm_status_2 <= 32'h0000_0000;
            arm_status_3 <= 32'h0000_0000;
            arm_status_4 <= 32'h0000_0000;
            arm_status_5 <= 32'h0000_0000;
            arm_status_6 <= 32'h0000_0000;
            arm_status_7 <= 32'h0000_0000;
        end else if (wfire1) begin
            case (up_waddr1)
                W_SRR:        srr         <= up_wdata1;
                W_SPICR:      spicr       <= up_wdata1;
                W_SCRATCH:    scratch_pad <= up_wdata1;
                W_ARM_CMD_0:  arm_cmd_0   <= {1'b0, up_wdata1[30:0]};
                W_ARM_CMD_1:  arm_cmd_1   <= up_wdata1;
                W_ARM_CMD_2:  arm_cmd_2   <= up_wdata1;
                W_ARM_CMD_3:  arm_cmd_3   <= up_wdata1;
                W_ARM_CMD_4:  arm_cmd_4   <= up_wdata1;
                W_ARM_CMD_5:  arm_cmd_5   <= up_wdata1;
                W_ARM_CMD_6:  arm_cmd_6   <= up_wdata1;
                W_ARM_CMD_7:  arm_cmd_7   <= up_wdata1;
                // arm_status: R for up_if_1
                default:      ;
            endcase
        end else if (wfire2) begin
            case (up_waddr2)
                W_SRR:          srr          <= up_wdata2;
                W_SPICR:        spicr        <= up_wdata2;
                W_SCRATCH:      scratch_pad  <= up_wdata2;
                W_ARM_CMD_0:    arm_cmd_0    <= {1'b0, up_wdata2[30:0]};
                W_ARM_CMD_1:    arm_cmd_1    <= up_wdata2;
                W_ARM_CMD_2:    arm_cmd_2    <= up_wdata2;
                W_ARM_CMD_3:    arm_cmd_3    <= up_wdata2;
                W_ARM_CMD_4:    arm_cmd_4    <= up_wdata2;
                W_ARM_CMD_5:    arm_cmd_5    <= up_wdata2;
                W_ARM_CMD_6:    arm_cmd_6    <= up_wdata2;
                W_ARM_CMD_7:    arm_cmd_7    <= up_wdata2;
                W_ARM_STATUS_0: arm_status_0 <= up_wdata2;
                W_ARM_STATUS_1: arm_status_1 <= up_wdata2;
                W_ARM_STATUS_2: arm_status_2 <= up_wdata2;
                W_ARM_STATUS_3: arm_status_3 <= up_wdata2;
                W_ARM_STATUS_4: arm_status_4 <= up_wdata2;
                W_ARM_STATUS_5: arm_status_5 <= up_wdata2;
                W_ARM_STATUS_6: arm_status_6 <= up_wdata2;
                W_ARM_STATUS_7: arm_status_7 <= up_wdata2;
                default:        ;
            endcase
        end
    end

    //--------------------------------------------------------------------------
    // Write handshake -- one-cycle ack per request
    //--------------------------------------------------------------------------
    always @(posedge up_clk) begin
        up_wack1 <= wfire1;
        up_wack2 <= wfire2;
    end

    //==========================================================================
    // Read channel -- priority: up_if_1 > up_if_2
    //==========================================================================

    always @(posedge up_clk) begin
        //---- up_if_1 read ------------------------------------------------
        if (rreq1) begin
            case (up_raddr1)
                W_SRR:          up_rdata1 <= srr;
                W_SPICR:        up_rdata1 <= spicr;
                W_SPISR:        up_rdata1 <= spisr;
                W_DEV_CFG:      up_rdata1 <= device_config;
                W_CHIP_TYPE:    up_rdata1 <= chip_type;
                W_PRODUCT_ID:   up_rdata1 <= product_id;
                W_CHIP_GRADE:   up_rdata1 <= chip_grade;
                W_SCRATCH:      up_rdata1 <= scratch_pad;
                W_VENDOR_ID:    up_rdata1 <= vendor_id;
                W_ARM_CMD_0:    up_rdata1 <= arm_cmd_0;
                W_ARM_CMD_1:    up_rdata1 <= arm_cmd_1;
                W_ARM_CMD_2:    up_rdata1 <= arm_cmd_2;
                W_ARM_CMD_3:    up_rdata1 <= arm_cmd_3;
                W_ARM_CMD_4:    up_rdata1 <= arm_cmd_4;
                W_ARM_CMD_5:    up_rdata1 <= arm_cmd_5;
                W_ARM_CMD_6:    up_rdata1 <= arm_cmd_6;
                W_ARM_CMD_7:    up_rdata1 <= arm_cmd_7;
                W_ARM_STATUS_0: up_rdata1 <= arm_status_0;
                W_ARM_STATUS_1: up_rdata1 <= arm_status_1;
                W_ARM_STATUS_2: up_rdata1 <= arm_status_2;
                W_ARM_STATUS_3: up_rdata1 <= arm_status_3;
                W_ARM_STATUS_4: up_rdata1 <= arm_status_4;
                W_ARM_STATUS_5: up_rdata1 <= arm_status_5;
                W_ARM_STATUS_6: up_rdata1 <= arm_status_6;
                W_ARM_STATUS_7: up_rdata1 <= arm_status_7;
                default:        up_rdata1 <= 32'd0;
            endcase
            up_rack1 <= 1'b1;
        end else begin
            up_rack1 <= 1'b0;
        end

        //---- up_if_2 read ------------------------------------------------
        if (rreq2) begin
            case (up_raddr2)
                W_SRR:          up_rdata2 <= srr;
                W_SPICR:        up_rdata2 <= spicr;
                W_SPISR:        up_rdata2 <= spisr;
                W_DEV_CFG:      up_rdata2 <= device_config;
                W_CHIP_TYPE:    up_rdata2 <= chip_type;
                W_PRODUCT_ID:   up_rdata2 <= product_id;
                W_CHIP_GRADE:   up_rdata2 <= chip_grade;
                W_SCRATCH:      up_rdata2 <= scratch_pad;
                W_VENDOR_ID:    up_rdata2 <= vendor_id;
                W_ARM_CMD_0:    up_rdata2 <= arm_cmd_0;
                W_ARM_CMD_1:    up_rdata2 <= arm_cmd_1;
                W_ARM_CMD_2:    up_rdata2 <= arm_cmd_2;
                W_ARM_CMD_3:    up_rdata2 <= arm_cmd_3;
                W_ARM_CMD_4:    up_rdata2 <= arm_cmd_4;
                W_ARM_CMD_5:    up_rdata2 <= arm_cmd_5;
                W_ARM_CMD_6:    up_rdata2 <= arm_cmd_6;
                W_ARM_CMD_7:    up_rdata2 <= arm_cmd_7;
                W_ARM_STATUS_0: up_rdata2 <= arm_status_0;
                W_ARM_STATUS_1: up_rdata2 <= arm_status_1;
                W_ARM_STATUS_2: up_rdata2 <= arm_status_2;
                W_ARM_STATUS_3: up_rdata2 <= arm_status_3;
                W_ARM_STATUS_4: up_rdata2 <= arm_status_4;
                W_ARM_STATUS_5: up_rdata2 <= arm_status_5;
                W_ARM_STATUS_6: up_rdata2 <= arm_status_6;
                W_ARM_STATUS_7: up_rdata2 <= arm_status_7;
                default:        up_rdata2 <= 32'd0;
            endcase
            up_rack2 <= 1'b1;
        end else begin
            up_rack2 <= 1'b0;
        end
    end

    //==========================================================================
    // spi_mailbox_irq -- one-cycle pulse when arm_cmd_0 is written with bit[31]==1
    //   arm_cmd_0[31] is auto-cleared in the write case above.
    //==========================================================================

    always @(posedge up_clk) begin
        if ((wfire1 && up_waddr1 == W_ARM_CMD_0 && up_wdata1[31]) ||
            (wfire2 && up_waddr2 == W_ARM_CMD_0 && up_wdata2[31]))
            spi_mailbox_irq <= 1'b1;
        else
            spi_mailbox_irq <= 1'b0;
    end

endmodule
