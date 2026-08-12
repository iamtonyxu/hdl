`timescale 1ns / 1ps
//////////////////////////////////////////////////////////////////////////////////
// Testbench: pcore_registers_tb
//
// Verifies the pcore_registers module:
//   1.  Reset values match the register map
//   2.  up_if_1 write / read  (single interface)
//   3.  up_if_2 write / read  (single interface)
//   4.  Read-only protection  (up_if_1 cannot write RO registers)
//   5.  arm_status R/W for up_if_2, R for up_if_1
//   6.  Mailbox IRQ — arm_cmd_0[31]==1 triggers pulse + auto-clear
//   7.  Priority — simultaneous requests, up_if_1 wins
//   8.  Unmapped addresses — read returns 0, write is ack'd but ignored
//
// Run with ModelSim / Questa:
//   vlib work
//   vlog pcore_registers.v   pcore_registers_tb.v
//   vsim -c pcore_registers_tb -do "run -all; quit"
//////////////////////////////////////////////////////////////////////////////////

module pcore_registers_tb;

    //==========================================================================
    // Parameters
    //==========================================================================
    localparam AXI_ADDR_W   = 16;
    localparam UP_CLK_PERIOD = 10.0;          // 100 MHz

    // Word-address aliases (same as DUT)
    localparam W_SRR          = 14'h0000;
    localparam W_SPICR        = 14'h0001;
    localparam W_SPISR        = 14'h0002;
    localparam W_DEV_CFG      = 14'h0003;
    localparam W_CHIP_TYPE    = 14'h0004;
    localparam W_PRODUCT_ID   = 14'h0005;
    localparam W_CHIP_GRADE   = 14'h0006;
    localparam W_SCRATCH      = 14'h0007;
    localparam W_VENDOR_ID    = 14'h0008;
    localparam W_ARM_CMD_0    = 14'h000C;
    localparam W_ARM_CMD_1    = 14'h000D;
    localparam W_ARM_CMD_2    = 14'h000E;
    localparam W_ARM_CMD_3    = 14'h000F;
    localparam W_ARM_CMD_4    = 14'h0010;
    localparam W_ARM_CMD_5    = 14'h0011;
    localparam W_ARM_CMD_6    = 14'h0012;
    localparam W_ARM_CMD_7    = 14'h0013;
    localparam W_ARM_STATUS_0 = 14'h0014;
    localparam W_ARM_STATUS_1 = 14'h0015;
    localparam W_ARM_STATUS_2 = 14'h0016;
    localparam W_ARM_STATUS_3 = 14'h0017;
    localparam W_ARM_STATUS_4 = 14'h0018;
    localparam W_ARM_STATUS_5 = 14'h0019;
    localparam W_ARM_STATUS_6 = 14'h001A;
    localparam W_ARM_STATUS_7 = 14'h001B;

    //==========================================================================
    // DUT signals
    //==========================================================================
    reg         up_rstn;
    reg         up_clk;

    reg         up_wreq1;
    reg  [13:0] up_waddr1;
    reg  [31:0] up_wdata1;
    wire        up_wack1;
    reg         up_rreq1;
    reg  [13:0] up_raddr1;
    wire [31:0] up_rdata1;
    wire        up_rack1;

    reg         up_wreq2;
    reg  [13:0] up_waddr2;
    reg  [31:0] up_wdata2;
    wire        up_wack2;
    reg         up_rreq2;
    reg  [13:0] up_raddr2;
    wire [31:0] up_rdata2;
    wire        up_rack2;

    wire        spi_mailbox_irq;

    //==========================================================================
    // DUT
    //==========================================================================
    pcore_registers #(
        .AXI_ADDRESS_WIDTH(AXI_ADDR_W)
    ) dut (
        .up_rstn         (up_rstn),
        .up_clk          (up_clk),
        .up_wreq1        (up_wreq1),
        .up_waddr1       (up_waddr1),
        .up_wdata1       (up_wdata1),
        .up_wack1        (up_wack1),
        .up_rreq1        (up_rreq1),
        .up_raddr1       (up_raddr1),
        .up_rdata1       (up_rdata1),
        .up_rack1        (up_rack1),
        .up_wreq2        (up_wreq2),
        .up_waddr2       (up_waddr2),
        .up_wdata2       (up_wdata2),
        .up_wack2        (up_wack2),
        .up_rreq2        (up_rreq2),
        .up_raddr2       (up_raddr2),
        .up_rdata2       (up_rdata2),
        .up_rack2        (up_rack2),
        .spi_mailbox_irq (spi_mailbox_irq)
    );

    //==========================================================================
    // 100 MHz free-running clock
    //==========================================================================
    initial up_clk = 0;
    always #(UP_CLK_PERIOD / 2.0) up_clk = ~up_clk;

    //==========================================================================
    // Upstream master tasks — mimic spi_slave_if/up_axi request protocol
    //
    // Protocol:  assert req + addr (+ data for write)
    //            wait one cycle for ack
    //            de-assert req
    //==========================================================================

    //------ up_if_1 tasks ----------------------------------------------------
    //
    // Handshake: assert req, wait for ack, capture data / de-assert.

    task automatic up_write1;
        input [13:0] addr;
        input [31:0] data;
    begin
        @(posedge up_clk);
        up_wreq1  <= 1'b1;
        up_waddr1 <= addr;
        up_wdata1 <= data;
        @(posedge up_clk);
        while (!up_wack1) @(posedge up_clk);  // wait for ack
        up_wreq1  <= 1'b0;
        up_waddr1 <= 14'd0;
        up_wdata1 <= 32'd0;
        @(posedge up_clk);                    // idle
    end
    endtask

    task automatic up_read1;
        input  [13:0] addr;
        output [31:0] data;
    begin
        @(posedge up_clk);
        up_rreq1  <= 1'b1;
        up_raddr1 <= addr;
        @(posedge up_clk);
        while (!up_rack1) @(posedge up_clk);  // wait for ack
        data      = up_rdata1;
        up_rreq1  <= 1'b0;
        up_raddr1 <= 14'd0;
        @(posedge up_clk);                    // idle
    end
    endtask

    //------ up_if_2 tasks ----------------------------------------------------

    task automatic up_write2;
        input [13:0] addr;
        input [31:0] data;
    begin
        @(posedge up_clk);
        up_wreq2  <= 1'b1;
        up_waddr2 <= addr;
        up_wdata2 <= data;
        @(posedge up_clk);
        while (!up_wack2) @(posedge up_clk);
        up_wreq2  <= 1'b0;
        up_waddr2 <= 14'd0;
        up_wdata2 <= 32'd0;
        @(posedge up_clk);
    end
    endtask

    task automatic up_read2;
        input  [13:0] addr;
        output [31:0] data;
    begin
        @(posedge up_clk);
        up_rreq2  <= 1'b1;
        up_raddr2 <= addr;
        @(posedge up_clk);
        while (!up_rack2) @(posedge up_clk);  // wait for ack
        data      = up_rdata2;
        up_rreq2  <= 1'b0;
        up_raddr2 <= 14'd0;
        @(posedge up_clk);
    end
    endtask

    //------ Simultaneous write (both interfaces fire at the same cycle) ------
    //
    // Priority: IF1 wins first, IF2 self-sequences after IF1 ack
    // (wreq2 = up_wreq2 && !up_wack2 && !wreq1).

    task automatic up_write_both;
        input [13:0] addr1;
        input [31:0] data1;
        input [13:0] addr2;
        input [31:0] data2;
    begin
        @(posedge up_clk);
        up_wreq1  <= 1'b1;
        up_waddr1 <= addr1;
        up_wdata1 <= data1;
        up_wreq2  <= 1'b1;
        up_waddr2 <= addr2;
        up_wdata2 <= data2;
        @(posedge up_clk);
        while (!up_wack1) @(posedge up_clk);  // IF1 ack
        // IF2 fires automatically once wreq1 clears (!wreq1 in wreq2 gate)
        while (!up_wack2) @(posedge up_clk);  // IF2 ack
        up_wreq1  <= 1'b0;
        up_waddr1 <= 14'd0;
        up_wdata1 <= 32'd0;
        up_wreq2  <= 1'b0;
        up_waddr2 <= 14'd0;
        up_wdata2 <= 32'd0;
        @(posedge up_clk);
    end
    endtask

    //==========================================================================
    // Mailbox IRQ monitor
    //==========================================================================
    reg        irq_seen;
    reg [31:0] irq_rdata;
    integer    irq_cycle;

    // Catch a 1-cycle IRQ pulse
    always @(posedge up_clk) begin
        if (spi_mailbox_irq) begin
            irq_seen  <= 1'b1;
            irq_rdata <= up_rdata2;           // snapshot rdata at IRQ time
            irq_cycle <= $time;
        end
    end

    //==========================================================================
    // Test controller
    //==========================================================================
    reg  [31:0] rd_val;
    reg  [31:0] rd_val2;
    integer     err_cnt;
    integer     test_num;
    integer     log_fd;

    initial begin
        err_cnt  = 0;
        test_num = 0;
        irq_seen = 1'b0;

        //---------- Init ------------------------------------
        up_wreq1  = 1'b0;  up_waddr1 = 14'd0;  up_wdata1 = 32'd0;
        up_rreq1  = 1'b0;  up_raddr1 = 14'd0;
        up_wreq2  = 1'b0;  up_waddr2 = 14'd0;  up_wdata2 = 32'd0;
        up_rreq2  = 1'b0;  up_raddr2 = 14'd0;

        //---------- Open log --------------------------------
        log_fd = $fopen("pcore_registers_tb.log");

        $display("============================================================");
        $display("  pcore_registers Testbench  (up_clk=100M)");
        $display("============================================================");
        $fdisplay(log_fd, "============================================================");
        $fdisplay(log_fd, "  pcore_registers Testbench  (up_clk=100M)");
        $fdisplay(log_fd, "============================================================");

        //---------- Reset (active low) ----------------------
        up_rstn = 1'b0;
        repeat (10) @(posedge up_clk);
        up_rstn = 1'b1;
        repeat (5)  @(posedge up_clk);

        //====================================================
        // Test 1 — Reset values (read via IF1)
        //====================================================
        test_num = test_num + 1;
        $display("--- Test %0d: Reset values ---", test_num);
        $fdisplay(log_fd, "--- Test %0d: Reset values ---", test_num);

        up_read1(W_SRR,        rd_val);  check("SRR",          rd_val, 32'h0000_0000);
        up_read1(W_SPICR,      rd_val);  check("SPICR",        rd_val, 32'h0000_0180);
        up_read1(W_SPISR,      rd_val);  check("SPISR",        rd_val, 32'h0000_00A5);
        up_read1(W_DEV_CFG,    rd_val);  check("DEV_CFG",      rd_val, 32'h0000_1234);
        up_read1(W_CHIP_TYPE,  rd_val);  check("CHIP_TYPE",    rd_val, 32'h0000_0001);
        up_read1(W_PRODUCT_ID, rd_val);  check("PRODUCT_ID",   rd_val, 32'h0000_0001);
        up_read1(W_CHIP_GRADE, rd_val);  check("CHIP_GRADE",   rd_val, 32'h0000_AAAA);
        up_read1(W_SCRATCH,    rd_val);  check("SCRATCH",      rd_val, 32'h0000_FFFF);
        up_read1(W_VENDOR_ID,  rd_val);  check("VENDOR_ID",    rd_val, 32'h0000_ABCD);
        up_read1(W_ARM_CMD_0,  rd_val);  check("ARM_CMD_0",    rd_val, 32'h0000_0000);
        up_read1(W_ARM_STATUS_0, rd_val); check("ARM_STATUS_0", rd_val, 32'h0000_0000);

        //====================================================
        // Test 2 — IF1 write / read (R/W registers)
        //====================================================
        test_num = test_num + 1;
        $display("--- Test %0d: IF1 write/read R/W registers ---", test_num);
        $fdisplay(log_fd, "--- Test %0d: IF1 write/read R/W registers ---", test_num);

        up_write1(W_SRR,       32'hAAAA_BBBB);  up_read1(W_SRR,       rd_val);  check("SRR",       rd_val, 32'hAAAA_BBBB);
        up_write1(W_SPICR,     32'h1234_5678);  up_read1(W_SPICR,     rd_val);  check("SPICR",     rd_val, 32'h1234_5678);
        up_write1(W_SCRATCH,   32'hDEAD_BEEF);  up_read1(W_SCRATCH,   rd_val);  check("SCRATCH",   rd_val, 32'hDEAD_BEEF);
        up_write1(W_ARM_CMD_1, 32'hCAFE_BABE);  up_read1(W_ARM_CMD_1, rd_val);  check("ARM_CMD_1", rd_val, 32'hCAFE_BABE);
        up_write1(W_ARM_CMD_7, 32'hFFFF_0000);  up_read1(W_ARM_CMD_7, rd_val);  check("ARM_CMD_7", rd_val, 32'hFFFF_0000);

        //====================================================
        // Test 3 — IF2 write / read (R/W registers)
        //====================================================
        test_num = test_num + 1;
        $display("--- Test %0d: IF2 write/read R/W registers ---", test_num);
        $fdisplay(log_fd, "--- Test %0d: IF2 write/read R/W registers ---", test_num);

        up_write2(W_SRR,       32'h1111_2222);  up_read2(W_SRR,       rd_val);  check("SRR via IF2",       rd_val, 32'h1111_2222);
        up_write2(W_SPICR,     32'h3333_4444);  up_read2(W_SPICR,     rd_val);  check("SPICR via IF2",     rd_val, 32'h3333_4444);
        up_write2(W_SCRATCH,   32'h5555_6666);  up_read2(W_SCRATCH,   rd_val);  check("SCRATCH via IF2",   rd_val, 32'h5555_6666);
        up_write2(W_ARM_CMD_2, 32'h7777_8888);  up_read2(W_ARM_CMD_2, rd_val);  check("ARM_CMD_2 via IF2", rd_val, 32'h7777_8888);

        // Verify IF1 can still read the same values (shared register file)
        up_read1(W_SRR,     rd_val);  check("SRR shared",     rd_val, 32'h1111_2222);
        up_read1(W_SCRATCH, rd_val);  check("SCRATCH shared", rd_val, 32'h5555_6666);

        //====================================================
        // Test 4 — Read-only protection (IF1 writes to RO registers)
        //====================================================
        test_num = test_num + 1;
        $display("--- Test %0d: Read-only protection (IF1) ---", test_num);
        $fdisplay(log_fd, "--- Test %0d: Read-only protection (IF1) ---", test_num);

        // Try to write RO registers via IF1 — should be ignored
        up_write1(W_SPISR,     32'hDEAD_0000);  up_read1(W_SPISR,      rd_val);  check("SPISR RO",      rd_val, 32'h0000_00A5);
        up_write1(W_DEV_CFG,   32'hDEAD_0000);  up_read1(W_DEV_CFG,    rd_val);  check("DEV_CFG RO",    rd_val, 32'h0000_1234);
        up_write1(W_CHIP_TYPE, 32'hDEAD_0000);  up_read1(W_CHIP_TYPE,  rd_val);  check("CHIP_TYPE RO",  rd_val, 32'h0000_0001);
        up_write1(W_VENDOR_ID, 32'hDEAD_0000);  up_read1(W_VENDOR_ID,  rd_val);  check("VENDOR_ID RO",  rd_val, 32'h0000_ABCD);

        //====================================================
        // Test 5 — arm_status: R/W for IF2, R for IF1
        //====================================================
        test_num = test_num + 1;
        $display("--- Test %0d: arm_status IF2-R/W  IF1-R ---", test_num);
        $fdisplay(log_fd, "--- Test %0d: arm_status IF2-R/W  IF1-R ---", test_num);

        // IF2 writes arm_status — should succeed
        up_write2(W_ARM_STATUS_0, 32'hCAFE_0000);
        up_read2(W_ARM_STATUS_0, rd_val);  check("ARM_STATUS_0 via IF2 write", rd_val, 32'hCAFE_0000);
        // IF1 reads — should see the updated value
        up_read1(W_ARM_STATUS_0, rd_val);  check("ARM_STATUS_0 via IF1 read",  rd_val, 32'hCAFE_0000);

        up_write2(W_ARM_STATUS_3, 32'hBABE_0003);
        up_write2(W_ARM_STATUS_7, 32'hDEAD_0007);
        up_read1(W_ARM_STATUS_3, rd_val);  check("ARM_STATUS_3 shared", rd_val, 32'hBABE_0003);
        up_read2(W_ARM_STATUS_7, rd_val);  check("ARM_STATUS_7 shared", rd_val, 32'hDEAD_0007);

        // IF1 tries to write arm_status — should be ignored
        up_write1(W_ARM_STATUS_0, 32'hFFFF_FFFF);
        up_read1(W_ARM_STATUS_0, rd_val);  check("ARM_STATUS_0 RO for IF1", rd_val, 32'hCAFE_0000);
        up_read2(W_ARM_STATUS_0, rd_val);  check("ARM_STATUS_0 RO for IF1 (IF2 view)", rd_val, 32'hCAFE_0000);

        //====================================================
        // Test 6 — Mailbox IRQ: arm_cmd_0[31]==1
        //====================================================
        test_num = test_num + 1;
        $display("--- Test %0d: Mailbox IRQ — arm_cmd_0[31]==1 ---", test_num);
        $fdisplay(log_fd, "--- Test %0d: Mailbox IRQ — arm_cmd_0[31]==1 ---", test_num);

        irq_seen = 1'b0;
        // Write arm_cmd_0 with bit31=1 via IF1 (the SPI master side)
        up_write1(W_ARM_CMD_0, 32'h8000_1234);
        repeat (2) @(posedge up_clk);
        // Check IRQ fired
        check_irq("IRQ on arm_cmd_0[31]==1", 1'b1);

        // Verify arm_cmd_0[31] was auto-cleared
        up_read1(W_ARM_CMD_0, rd_val);
        check("ARM_CMD_0[31] auto-clear", rd_val, 32'h0000_1234);

        //====================================================
        // Test 7 — Mailbox IRQ: arm_cmd_0[31]==0 → no IRQ
        //====================================================
        test_num = test_num + 1;
        $display("--- Test %0d: Mailbox IRQ — arm_cmd_0[31]==0 ---", test_num);
        $fdisplay(log_fd, "--- Test %0d: Mailbox IRQ — arm_cmd_0[31]==0 ---", test_num);

        irq_seen = 1'b0;
        up_write1(W_ARM_CMD_0, 32'h0000_5678);
        repeat (2) @(posedge up_clk);
        check_irq("No IRQ on arm_cmd_0[31]==0", 1'b0);

        // Also test via IF2
        irq_seen = 1'b0;
        up_write2(W_ARM_CMD_0, 32'h8000_9ABC);
        repeat (2) @(posedge up_clk);
        check_irq("IRQ via IF2", 1'b1);
        up_read2(W_ARM_CMD_0, rd_val);
        check("ARM_CMD_0 auto-clear via IF2", rd_val, 32'h0000_9ABC);

        //====================================================
        // Test 8 — Priority: simultaneous write requests
        //====================================================
        test_num = test_num + 1;
        $display("--- Test %0d: Priority — simultaneous writes ---", test_num);
        $fdisplay(log_fd, "--- Test %0d: Priority — simultaneous writes ---", test_num);

        // IF1 writes 0xAAAA to SRR, IF2 writes 0xBBBB to SRR simultaneously
        // IF1 should win: SRR = 0xAAAA
        up_write_both(W_SRR, 32'hAAAA_AAAA, W_SRR, 32'hBBBB_BBBB);
        up_read1(W_SRR, rd_val);
        check("Priority write: IF1 wins SRR", rd_val, 32'hAAAA_AAAA);

        // Same but different registers — both should succeed
        up_write_both(W_SPICR, 32'h1111_1111, W_SCRATCH, 32'h2222_2222);
        up_read1(W_SPICR,   rd_val);   check("Simul diff addr SPICR",   rd_val, 32'h1111_1111);
        up_read2(W_SCRATCH, rd_val);   check("Simul diff addr SCRATCH", rd_val, 32'h2222_2222);

        //====================================================
        // Test 9 — Unmapped addresses
        //====================================================
        test_num = test_num + 1;
        $display("--- Test %0d: Unmapped addresses ---", test_num);
        $fdisplay(log_fd, "--- Test %0d: Unmapped addresses ---", test_num);

        // Read unmapped — returns 0
        up_read1(14'h0009, rd_val);   check("Unmapped 0x0009 read",  rd_val, 32'd0);
        up_read1(14'h000A, rd_val);   check("Unmapped 0x000A read",  rd_val, 32'd0);
        up_read1(14'h001C, rd_val);   check("Unmapped 0x001C read",  rd_val, 32'd0);
        up_read1(14'h0100, rd_val);   check("Unmapped 0x0100 read",  rd_val, 32'd0);

        // Write unmapped — should be ack'd but no effect
        up_write1(14'h0009, 32'hDEAD_BEEF);   up_read1(14'h0009, rd_val);  check("Unmapped write ignored", rd_val, 32'd0);

        //====================================================
        // Test 10 — Back-to-back reads (same interface)
        //====================================================
        test_num = test_num + 1;
        $display("--- Test %0d: Back-to-back reads ---", test_num);
        $fdisplay(log_fd, "--- Test %0d: Back-to-back reads ---", test_num);

        // Prime some registers
        up_write1(W_SRR,     32'hB2B0_0001);
        up_write1(W_SCRATCH, 32'hB2B0_0002);
        // Read back-to-back (each task waits for its own ack)
        up_read1(W_SRR,     rd_val);   check("B2B read 1: SRR",     rd_val, 32'hB2B0_0001);
        up_read1(W_SCRATCH, rd_val);   check("B2B read 2: SCRATCH", rd_val, 32'hB2B0_0002);

        //====================================================
        // Report
        //====================================================
        $display("\n============================================================");
        $fdisplay(log_fd, "");
        $fdisplay(log_fd, "============================================================");
        if (err_cnt == 0) begin
            $display("  ALL %0d TESTS PASSED", test_num);
            $fdisplay(log_fd, "  ALL %0d TESTS PASSED", test_num);
        end else begin
            $display("  %0d / %0d TESTS FAILED", err_cnt, test_num);
            $fdisplay(log_fd, "  %0d / %0d TESTS FAILED", err_cnt, test_num);
        end
        $display("============================================================\n");
        $fdisplay(log_fd, "============================================================");

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
