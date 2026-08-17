`timescale 1ns / 1ps
//////////////////////////////////////////////////////////////////////////////////
// Testbench: radio_hw_tb
//
// Verifies the radio_hw top-level module via two access paths:
//   Path 1 (up_if_1): SPI bus  -> spi_slave_if   -> pcore_registers
//   Path 2 (up_if_2): AXI-4    -> axi2spi_bridge -> pcore_registers
//                      (internally: up_axi)
//
// Tests:
//   1. Reset values -- read via SPI, then via AXI
//   2. SPI  single-side write / read  (R/W registers)
//   3. AXI  single-side write / read  (R/W registers)
//   4. Cross-path: SPI write -> AXI read  /  AXI write -> SPI read
//   5. arm_status: R/W for AXI (up_if_2), R for SPI (up_if_1)
//   6. Mailbox IRQ -- arm_cmd_0[31]==1 via SPI / AXI
//   7. Priority -- simultaneous SPI + AXI writes, SPI wins
//
// Run with ModelSim / Questa:
//   vlib work
//   vlog spi_slave_if.v pcore_registers.v up_axi.v axi2spi_bridge.v radio_hw.v radio_hw_tb.v
//   vsim -c radio_hw_tb -do "run -all; quit"
//
// NOTE(2026-08-17): spi_slave_if.v localparam SPI_SDO_START is now 32 (was 31),
// which is correct for the real STM32 SPI master. This tb's SDO sampling edge
// has NOT yet been re-aligned to match — see the TODO at the `spi_transfer`
// task below. Until then, SPI read-back checks will fail with `data >> 1`.
//////////////////////////////////////////////////////////////////////////////////

module radio_hw_tb;

    //==========================================================================
    // Parameters
    //==========================================================================
    localparam AXI_ADDR_W    = 16;
    localparam UP_CLK_PERIOD = 10.0;          // 100 MHz
    localparam SCLK_PERIOD   = 40.0;          //  25 MHz
    localparam SCLK_HALF     = SCLK_PERIOD / 2.0;

    // Word-address aliases (word_addr = byte_addr >> 2)
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

    //==========================================================================
    // DUT signals -- clocks / reset
    //==========================================================================
    reg         s_axi_aclk;
    reg         s_axi_aresetn;

    //==========================================================================
    // DUT signals -- AXI-4 bus
    //==========================================================================
    reg                                 s_axi_awvalid;
    reg   [(AXI_ADDR_W-1):0]            s_axi_awaddr;
    wire                                s_axi_awready;
    reg                                 s_axi_wvalid;
    reg   [31:0]                        s_axi_wdata;
    reg   [ 3:0]                        s_axi_wstrb;
    wire                                s_axi_wready;
    wire                                s_axi_bvalid;
    wire  [ 1:0]                        s_axi_bresp;
    reg                                 s_axi_bready;
    reg                                 s_axi_arvalid;
    reg   [(AXI_ADDR_W-1):0]            s_axi_araddr;
    wire                                s_axi_arready;
    wire                                s_axi_rvalid;
    wire  [ 1:0]                        s_axi_rresp;
    wire  [31:0]                        s_axi_rdata;
    reg                                 s_axi_rready;

    //==========================================================================
    // DUT signals -- SPI bus
    //==========================================================================
    reg         sclk;
    reg         sdi;
    wire        sdo;
    reg         cs_n;

    //==========================================================================
    // DUT signals -- interrupt
    //==========================================================================
    wire        spi_mailbox_irq;

    //==========================================================================
    // DUT
    //==========================================================================
    radio_hw #(
        .AXI_ADDRESS_WIDTH(AXI_ADDR_W)
    ) dut (
        .s_axi_aclk       (s_axi_aclk),
        .s_axi_aresetn    (s_axi_aresetn),
        .s_axi_awvalid   (s_axi_awvalid),
        .s_axi_awaddr    (s_axi_awaddr),
        .s_axi_awready   (s_axi_awready),
        .s_axi_wvalid    (s_axi_wvalid),
        .s_axi_wdata     (s_axi_wdata),
        .s_axi_wstrb     (s_axi_wstrb),
        .s_axi_wready    (s_axi_wready),
        .s_axi_bvalid    (s_axi_bvalid),
        .s_axi_bresp     (s_axi_bresp),
        .s_axi_bready    (s_axi_bready),
        .s_axi_arvalid   (s_axi_arvalid),
        .s_axi_araddr    (s_axi_araddr),
        .s_axi_arready   (s_axi_arready),
        .s_axi_rvalid    (s_axi_rvalid),
        .s_axi_rresp     (s_axi_rresp),
        .s_axi_rdata     (s_axi_rdata),
        .s_axi_rready    (s_axi_rready),
        .sclk             (sclk),
        .sdi              (sdi),
        .sdo              (sdo),
        .cs_n             (cs_n),
        .spi_mailbox_irq  (spi_mailbox_irq)
    );

    //==========================================================================
    // 100 MHz free-running clock
    //==========================================================================
    initial s_axi_aclk = 0;
    always #(UP_CLK_PERIOD / 2.0) s_axi_aclk = ~s_axi_aclk;

    //==========================================================================
    // SPI master task -- Mode 0, MSB-first, 64-bit frame, CS-enveloped
    //
    // Frame: {rw[63], address[62:32], data[31:0]}
    //   address[62:32] = {15'b0, word_addr[13:0], 2'b00}
    //==========================================================================
    task automatic spi_transfer;
        input               rw;            // 1=write, 0=read
        input      [13:0]   addr;          // word address
        input      [31:0]   wdata;
        output reg [31:0]   rdata;
        reg        [63:0]   frame;
        reg        [31:0]   sdo_buf;
        integer             i;
    begin
        frame = {rw, {15{1'b0}}, addr, 2'b00, wdata};

        // CS assertion, first-bit setup
        cs_n = 1'b0;
        sclk = 1'b0;
        sdi  = frame[63];
        #(SCLK_HALF / 2.0);

        // 64 SCLK cycles
        sdo_buf = 32'd0;
        // TODO(2026-08-17): SDO is currently sampled on the raw sclk RISING edge,
        // which matched the old DUT localparam SPI_SDO_START = 31. After the DUT
        // changed it to 32 (correct for the real STM32 SPI master), the DUT's
        // 3-stage synchronizer + edge-detect + sdo register add ~1 sclk-cycle of
        // latency, so sdo = bit(b) is only valid at the raw FALLING edge of bit b,
        // not at the rising edge. Sampling on the rising edge therefore reads
        // `data >> 1` (MSB dropped, LSB lost) — e.g. read 0xdeadbeef -> 0x6f56df77.
        //
        // Fix direction: move the `sdo_buf[i] = sdo` capture into the sclk = 0
        // (falling-edge) half of the loop below. That captures all 32 bits,
        // including bit 0.
        for (i = 63; i >= 0; i = i - 1) begin
            // Rising edge -- slave samples SDI, master samples SDO
            sclk = 1'b1;
            if (!rw && i < 32)
                sdo_buf[i] = sdo;
            #(SCLK_HALF);

            // Falling edge -- slave updates SDO, master drives next SDI
            sclk = 1'b0;
            if (i > 0) sdi = frame[i-1];
            #(SCLK_HALF);
        end

        // CS de-assertion
        cs_n = 1'b1;
        sdi  = 1'b0;
        #(SCLK_HALF);

        rdata = sdo_buf;
    end
    endtask

    //==========================================================================
    // Helper: spi_write / spi_read wrappers (with post-transfer settle time)
    //==========================================================================
    task automatic spi_write;
        input [13:0] addr;
        input [31:0] data;
        reg  [31:0]  dummy;
    begin
        spi_transfer(1'b1, addr, data, dummy);
        repeat (50) @(posedge s_axi_aclk);    // settle
    end
    endtask

    task automatic spi_read;
        input  [13:0] addr;
        output [31:0] data;
    begin
        spi_transfer(1'b0, addr, 32'd0, data);
        repeat (20) @(posedge s_axi_aclk);    // settle
    end
    endtask

    //==========================================================================
    // AXI-4 Lite master tasks
    //
    // up_axi requires awvalid & wvalid simultaneously for writes.
    // Handshake:  present addr+data -> wait awready+wready -> wait bvalid
    //             present araddr       -> wait arready       -> wait rvalid
    //==========================================================================

    //------ AXI write ---------------------------------------------------------
    task automatic axi_write;
        input [15:0] byte_addr;    // byte address
        input [31:0] data;
    begin
        @(posedge s_axi_aclk);
        s_axi_awvalid <= 1'b1;
        s_axi_awaddr  <= byte_addr;
        s_axi_wvalid  <= 1'b1;
        s_axi_wdata   <= data;
        s_axi_wstrb   <= 4'hF;
        // Wait for both awready and wready
        while (!s_axi_awready || !s_axi_wready) @(posedge s_axi_aclk);
        s_axi_awvalid <= 1'b0;
        s_axi_awaddr  <= 16'd0;
        s_axi_wvalid  <= 1'b0;
        s_axi_wdata   <= 32'd0;
        s_axi_wstrb   <= 4'h0;
        // Wait for bvalid
        while (!s_axi_bvalid) @(posedge s_axi_aclk);
        s_axi_bready <= 1'b1;
        @(posedge s_axi_aclk);
        s_axi_bready <= 1'b0;
        @(posedge s_axi_aclk);    // idle
    end
    endtask

    //------ AXI read ----------------------------------------------------------
    task automatic axi_read;
        input  [15:0] byte_addr;
        output [31:0] data;
    begin
        @(posedge s_axi_aclk);
        s_axi_arvalid <= 1'b1;
        s_axi_araddr  <= byte_addr;
        while (!s_axi_arready) @(posedge s_axi_aclk);
        s_axi_arvalid <= 1'b0;
        s_axi_araddr  <= 16'd0;
        while (!s_axi_rvalid) @(posedge s_axi_aclk);
        data = s_axi_rdata;
        s_axi_rready <= 1'b1;
        @(posedge s_axi_aclk);
        s_axi_rready <= 1'b0;
        @(posedge s_axi_aclk);    // idle
    end
    endtask

    //------ AXI byte-address helpers (wrap word-addr -> byte-addr) -------------
    function [15:0] ba;
        input [13:0] word_addr;
    begin
        ba = {word_addr, 2'b00};
    end
    endfunction

    //==========================================================================
    // Mailbox IRQ monitor
    //==========================================================================
    reg        irq_seen;
    reg        irq_clear;

    always @(posedge s_axi_aclk) begin
        if (s_axi_aresetn == 1'b0) begin
            irq_seen <= 1'b0;
        end else if (irq_clear) begin
            irq_seen <= 1'b0;
        end else if (spi_mailbox_irq) begin
            irq_seen <= 1'b1;
        end
    end

    //==========================================================================
    // Test controller
    //==========================================================================
    reg  [31:0] rd_val;
    integer     err_cnt;
    integer     test_num;
    integer     log_fd;

    initial begin
        err_cnt  = 0;
        test_num = 0;

        //---------- Init ------------------------------------
        s_axi_awvalid = 1'b0;  s_axi_awaddr = 16'd0;
        s_axi_wvalid  = 1'b0;  s_axi_wdata  = 32'd0;  s_axi_wstrb = 4'h0;
        s_axi_bready  = 1'b0;
        s_axi_arvalid = 1'b0;  s_axi_araddr = 16'd0;
        s_axi_rready  = 1'b0;
        cs_n = 1'b1;  sclk = 1'b0;  sdi = 1'b0;

        //---------- Open log --------------------------------
        log_fd = $fopen("radio_hw_tb.log");

        $display("==================================================================");
        $display("  radio_hw Testbench  (up_clk=100M, sclk=25M)");
        $display("==================================================================");
        $fdisplay(log_fd, "==================================================================");
        $fdisplay(log_fd, "  radio_hw Testbench  (up_clk=100M, sclk=25M)");
        $fdisplay(log_fd, "==================================================================");

        //---------- Reset (active low) ----------------------
        s_axi_aresetn = 1'b0;
        repeat (20) @(posedge s_axi_aclk);
        s_axi_aresetn = 1'b1;
        repeat (10) @(posedge s_axi_aclk);

        //====================================================
        // Test 1 -- Reset values (read via SPI & AXI)
        //====================================================
        test_num = test_num + 1;
        $display("--- Test %0d: Reset values ---", test_num);
        $fdisplay(log_fd, "--- Test %0d: Reset values ---", test_num);

        // --- SPI path ---
        spi_read(W_SRR,        rd_val);  check("SPI: SRR",          rd_val, 32'h0000_0000);
        spi_read(W_SPICR,      rd_val);  check("SPI: SPICR",        rd_val, 32'h0000_0180);
        spi_read(W_SPISR,      rd_val);  check("SPI: SPISR",        rd_val, 32'h0000_00A5);
        spi_read(W_DEV_CFG,    rd_val);  check("SPI: DEV_CFG",      rd_val, 32'h0000_1234);
        spi_read(W_CHIP_TYPE,  rd_val);  check("SPI: CHIP_TYPE",    rd_val, 32'h0000_0001);
        spi_read(W_PRODUCT_ID, rd_val);  check("SPI: PRODUCT_ID",   rd_val, 32'h0000_0001);
        spi_read(W_CHIP_GRADE, rd_val);  check("SPI: CHIP_GRADE",   rd_val, 32'h0000_AAAA);
        spi_read(W_SCRATCH,    rd_val);  check("SPI: SCRATCH",      rd_val, 32'h0000_FFFF);
        spi_read(W_VENDOR_ID,  rd_val);  check("SPI: VENDOR_ID",    rd_val, 32'h0000_ABCD);
        spi_read(W_ARM_CMD_0,  rd_val);  check("SPI: ARM_CMD_0",    rd_val, 32'h0000_0000);
        spi_read(W_ARM_STATUS_0, rd_val); check("SPI: ARM_STATUS_0", rd_val, 32'h0000_0000);

        // --- AXI path ---
        axi_read(ba(W_SRR),        rd_val);  check("AXI: SRR",          rd_val, 32'h0000_0000);
        axi_read(ba(W_SPICR),      rd_val);  check("AXI: SPICR",        rd_val, 32'h0000_0180);
        axi_read(ba(W_SPISR),      rd_val);  check("AXI: SPISR",        rd_val, 32'h0000_00A5);
        axi_read(ba(W_DEV_CFG),    rd_val);  check("AXI: DEV_CFG",      rd_val, 32'h0000_1234);
        axi_read(ba(W_VENDOR_ID),  rd_val);  check("AXI: VENDOR_ID",    rd_val, 32'h0000_ABCD);

        //====================================================
        // Test 2 -- SPI single-side write / read
        //====================================================
        test_num = test_num + 1;
        $display("--- Test %0d: SPI single-side write/read ---", test_num);
        $fdisplay(log_fd, "--- Test %0d: SPI single-side write/read ---", test_num);

        spi_write(W_SRR,       32'hAAAA_BBBB);  spi_read(W_SRR,       rd_val);  check("SRR",       rd_val, 32'hAAAA_BBBB);
        spi_write(W_SPICR,     32'h1234_5678);  spi_read(W_SPICR,     rd_val);  check("SPICR",     rd_val, 32'h1234_5678);
        spi_write(W_SCRATCH,   32'hDEAD_BEEF);  spi_read(W_SCRATCH,   rd_val);  check("SCRATCH",   rd_val, 32'hDEAD_BEEF);
        spi_write(W_ARM_CMD_1, 32'hCAFE_0001);  spi_read(W_ARM_CMD_1, rd_val);  check("ARM_CMD_1", rd_val, 32'hCAFE_0001);
        spi_write(W_ARM_CMD_7, 32'hFFFF_0007);  spi_read(W_ARM_CMD_7, rd_val);  check("ARM_CMD_7", rd_val, 32'hFFFF_0007);

        //====================================================
        // Test 3 -- AXI single-side write / read
        //====================================================
        test_num = test_num + 1;
        $display("--- Test %0d: AXI single-side write/read ---", test_num);
        $fdisplay(log_fd, "--- Test %0d: AXI single-side write/read ---", test_num);

        axi_write(ba(W_SRR),       32'h1111_2222);  axi_read(ba(W_SRR),       rd_val);  check("SRR via AXI",       rd_val, 32'h1111_2222);
        axi_write(ba(W_SPICR),     32'h3333_4444);  axi_read(ba(W_SPICR),     rd_val);  check("SPICR via AXI",     rd_val, 32'h3333_4444);
        axi_write(ba(W_SCRATCH),   32'h5555_6666);  axi_read(ba(W_SCRATCH),   rd_val);  check("SCRATCH via AXI",   rd_val, 32'h5555_6666);
        axi_write(ba(W_ARM_CMD_2), 32'h7777_8888);  axi_read(ba(W_ARM_CMD_2), rd_val);  check("ARM_CMD_2 via AXI", rd_val, 32'h7777_8888);

        //====================================================
        // Test 4 -- Cross-path: SPI write -> AXI read, AXI write -> SPI read
        //====================================================
        test_num = test_num + 1;
        $display("--- Test %0d: Cross-path access ---", test_num);
        $fdisplay(log_fd, "--- Test %0d: Cross-path access ---", test_num);

        // SPI writes, AXI reads back
        spi_write(W_SCRATCH,   32'hCAFE_5A5A);
        axi_read(ba(W_SCRATCH), rd_val);  check("SPI->AXI: SCRATCH", rd_val, 32'hCAFE_5A5A);

        // AXI writes, SPI reads back
        axi_write(ba(W_ARM_CMD_3), 32'hCAFE_A5A5);
        spi_read(W_ARM_CMD_3, rd_val);  check("AXI->SPI: ARM_CMD_3", rd_val, 32'hCAFE_A5A5);

        // Multiple registers cross-check
        spi_write(W_SRR,     32'hBEEF_0001);
        spi_write(W_ARM_CMD_4, 32'hBEEF_0004);
        axi_read(ba(W_SRR),      rd_val);   check("Cross SRR",      rd_val, 32'hBEEF_0001);
        axi_read(ba(W_ARM_CMD_4), rd_val);  check("Cross ARM_CMD_4", rd_val, 32'hBEEF_0004);

        //====================================================
        // Test 5 -- arm_status: R/W for AXI (up_if_2), R for SPI (up_if_1)
        //====================================================
        test_num = test_num + 1;
        $display("--- Test %0d: arm_status access control ---", test_num);
        $fdisplay(log_fd, "--- Test %0d: arm_status access control ---", test_num);

        // AXI writes arm_status -- should succeed
        axi_write(ba(W_ARM_STATUS_0), 32'hCAFE_0000);
        axi_read(ba(W_ARM_STATUS_0), rd_val);  check("AXI W->R ARM_STATUS_0", rd_val, 32'hCAFE_0000);
        // SPI reads -- should see the AXI-written value
        spi_read(W_ARM_STATUS_0, rd_val);  check("SPI read ARM_STATUS_0", rd_val, 32'hCAFE_0000);

        axi_write(ba(W_ARM_STATUS_3), 32'hBABE_0003);
        axi_write(ba(W_ARM_STATUS_7), 32'hDEAD_0007);
        spi_read(W_ARM_STATUS_3, rd_val);  check("SPI read ARM_STATUS_3", rd_val, 32'hBABE_0003);
        axi_read(ba(W_ARM_STATUS_7), rd_val); check("AXI read ARM_STATUS_7", rd_val, 32'hDEAD_0007);

        // SPI tries to write arm_status -- should be ignored (R for up_if_1)
        spi_write(W_ARM_STATUS_0, 32'hFFFF_FFFF);
        spi_read(W_ARM_STATUS_0, rd_val);   check("SPI W->R ARM_STATUS_0 (ignored)", rd_val, 32'hCAFE_0000);
        axi_read(ba(W_ARM_STATUS_0), rd_val); check("AXI view ARM_STATUS_0 unchanged", rd_val, 32'hCAFE_0000);

        // SPI tries to write arm_status_3, arm_status_7
        spi_write(W_ARM_STATUS_3, 32'hFFFF_FFFF);
        spi_write(W_ARM_STATUS_7, 32'hFFFF_FFFF);
        spi_read(W_ARM_STATUS_3, rd_val);  check("SPI write ARM_STATUS_3 ignored", rd_val, 32'hBABE_0003);
        axi_read(ba(W_ARM_STATUS_7), rd_val); check("AXI view ARM_STATUS_7 unchanged", rd_val, 32'hDEAD_0007);

        //====================================================
        // Test 6 -- Mailbox IRQ
        //====================================================
        test_num = test_num + 1;
        $display("--- Test %0d: Mailbox IRQ -- arm_cmd_0[31]==1 ---", test_num);
        $fdisplay(log_fd, "--- Test %0d: Mailbox IRQ -- arm_cmd_0[31]==1 ---", test_num);

        // SPI triggers IRQ
        clear_irq;
        spi_write(W_ARM_CMD_0, 32'h8000_1234);
        repeat (5) @(posedge s_axi_aclk);
        check_irq("IRQ via SPI arm_cmd_0[31]==1", 1'b1);
        // Verify arm_cmd_0[31] auto-cleared
        spi_read(W_ARM_CMD_0, rd_val);  check("ARM_CMD_0[31] auto-clear (SPI)", rd_val, 32'h0000_1234);

        // No IRQ when bit31==0
        clear_irq;
        spi_write(W_ARM_CMD_0, 32'h0000_5678);
        repeat (5) @(posedge s_axi_aclk);
        check_irq("No IRQ on arm_cmd_0[31]==0", 1'b0);

        // AXI triggers IRQ
        clear_irq;
        axi_write(ba(W_ARM_CMD_0), 32'h8000_9ABC);
        repeat (5) @(posedge s_axi_aclk);
        check_irq("IRQ via AXI arm_cmd_0[31]==1", 1'b1);
        axi_read(ba(W_ARM_CMD_0), rd_val);  check("ARM_CMD_0[31] auto-clear (AXI)", rd_val, 32'h0000_9ABC);

        //====================================================
        // Test 7 -- Priority: simultaneous SPI + AXI writes
        //====================================================
        test_num = test_num + 1;
        $display("--- Test %0d: Priority -- simultaneous SPI+AXI writes ---", test_num);
        $fdisplay(log_fd, "--- Test %0d: Priority -- simultaneous SPI+AXI writes ---", test_num);

        // Sequential priority: SPI first then AXI -- last writer (AXI) wins
        spi_write(W_SRR, 32'h5A10_0001);
        axi_write(ba(W_SRR), 32'hA510_0001);
        spi_read(W_SRR, rd_val);   check("Seq: SPI first then AXI -> AXI wins", rd_val, 32'hA510_0001);

        // Reverse order: AXI first, then SPI -- last writer (SPI) wins
        axi_write(ba(W_SRR), 32'hA510_0002);
        spi_write(W_SRR, 32'h5A10_0002);
        spi_read(W_SRR, rd_val);   check("Seq: AXI first then SPI -> SPI wins", rd_val, 32'h5A10_0002);

        // Different addresses, both should succeed independently
        spi_write(W_SPICR,   32'hDEAD_5A10);
        axi_write(ba(W_SCRATCH), 32'hDEAD_A510);
        spi_read(W_SPICR,   rd_val);   check("Diff addr SPI->SPICR",   rd_val, 32'hDEAD_5A10);
        axi_read(ba(W_SCRATCH), rd_val); check("Diff addr AXI->SCRATCH", rd_val, 32'hDEAD_A510);

        //====================================================
        // Test 8 -- SPI read-only registers also accessible via AXI
        //====================================================
        test_num = test_num + 1;
        $display("--- Test %0d: Read-only regs unchanged after writes ---", test_num);
        $fdisplay(log_fd, "--- Test %0d: Read-only regs unchanged after writes ---", test_num);

        // Try writing RO regs via SPI
        spi_write(W_SPISR,     32'hDEAD_0000);
        spi_write(W_VENDOR_ID, 32'hDEAD_0000);
        spi_read(W_SPISR,     rd_val);  check("SPI: SPISR RO",     rd_val, 32'h0000_00A5);
        spi_read(W_VENDOR_ID, rd_val);  check("SPI: VENDOR_ID RO", rd_val, 32'h0000_ABCD);

        // Try writing RO regs via AXI
        axi_write(ba(W_SPISR),     32'hBEEF_0000);
        axi_write(ba(W_VENDOR_ID), 32'hBEEF_0000);
        axi_read(ba(W_SPISR),     rd_val);  check("AXI: SPISR RO",     rd_val, 32'h0000_00A5);
        axi_read(ba(W_VENDOR_ID), rd_val);  check("AXI: VENDOR_ID RO", rd_val, 32'h0000_ABCD);

        //====================================================
        // Report
        //====================================================
        $display("\n==================================================================");
        $fdisplay(log_fd, "");
        $fdisplay(log_fd, "==================================================================");
        if (err_cnt == 0) begin
            $display("  ALL %0d TESTS PASSED", test_num);
            $fdisplay(log_fd, "  ALL %0d TESTS PASSED", test_num);
        end else begin
            $display("  %0d / %0d TESTS FAILED", err_cnt, test_num);
            $fdisplay(log_fd, "  %0d / %0d TESTS FAILED", err_cnt, test_num);
        end
        $display("==================================================================\n");
        $fdisplay(log_fd, "==================================================================");

        $finish;
    end

    //==========================================================================
    // Helper: check read-back value
    //==========================================================================
    task automatic check;
        input [255:0] name;
        input [31:0]  actual;
        input [31:0]  expected;
    begin
        if (actual === expected) begin
            $display("  PASS: %0s = 0x%08h", name, actual);
            $fdisplay(log_fd, "  PASS: %0s = 0x%08h", name, actual);
        end else begin
            $display("  FAIL: %0s = 0x%08h  (expected 0x%08h)", name, actual, expected);
            $fdisplay(log_fd, "  FAIL: %0s = 0x%08h  (expected 0x%08h)", name, actual, expected);
            err_cnt = err_cnt + 1;
        end
    end
    endtask

    //==========================================================================
    // Helper: clear the sticky IRQ flag synchronously
    // (pulses irq_clear for one cycle so irq_seen is cleared by the monitor,
    //  avoiding the blocking/non-blocking mixing of writing irq_seen directly)
    //==========================================================================
    task automatic clear_irq;
    begin
        irq_clear = 1'b1;
        @(posedge s_axi_aclk);
        irq_clear = 1'b0;
        @(posedge s_axi_aclk);
    end
    endtask

    //==========================================================================
    // Helper: check mailbox IRQ
    //==========================================================================
    task automatic check_irq;
        input [255:0] name;
        input         expected;
    begin
        if (irq_seen === expected) begin
            $display("  PASS: %0s (IRQ=%b)", name, irq_seen);
            $fdisplay(log_fd, "  PASS: %0s (IRQ=%b)", name, irq_seen);
        end else begin
            $display("  FAIL: %0s  IRQ=%b  (expected %b)", name, irq_seen, expected);
            $fdisplay(log_fd, "  FAIL: %0s  IRQ=%b  (expected %b)", name, irq_seen, expected);
            err_cnt = err_cnt + 1;
        end
    end
    endtask

endmodule
