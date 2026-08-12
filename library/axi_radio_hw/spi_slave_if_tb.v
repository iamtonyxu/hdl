`timescale 1ns / 1ps
//////////////////////////////////////////////////////////////////////////////////
// Testbench: spi_slave_if_tb
//
// Verifies 64-bit MSB-first SPI-mode-0 slave interface.
// Each SPI transaction = one CS-low envelope containing exactly 64 SCLK cycles:
//   bit[63]     = R/W  (1=write, 0=read)
//   bit[62:32]  = 31-bit register address
//   bit[31:0]   = 32-bit data
//
// Tests:
//   1. Write 0xDEADBEEF -> addr 0x0010, read back
//   2. Write 0xCAFEBABE -> addr 0x0020, read back
//   3. Write 0x12345678 -> addr 0x0030, read back
//   4. Write 0x00000000 -> addr 0x0040, read back
//   5. Write 0xFFFFFFFF -> addr 0x0050, read back
//   6. Write 0xA5A5A5A5 -> addr 0x0060, read back
//   7. Read never-written addr 0x00F0 -> expect 0(x?)
//   8. Rapid-fire writes with short CS gap
//
// Run with ModelSim / Questa:
//   vlib work
//   vlog spi_slave_if.v   spi_slave_if_tb.v
//   vsim -c spi_slave_if_tb -do "run -all"
//
//   # With GUI and wave window:
//   vsim spi_slave_if_tb -do "add wave -r /*; run -all"
//
//   # Single-line (from shell):
//   vlib work && vlog spi_slave_if.v spi_slave_if_tb.v && vsim -c spi_slave_if_tb -do "run -all; quit"
//////////////////////////////////////////////////////////////////////////////////

module spi_slave_if_tb;

    //==========================================================================
    // Parameters
    //==========================================================================
    localparam AXI_ADDR_W    = 16;            // must match DUT default
    localparam UP_CLK_PERIOD = 10.0;          // 100 MHz  (ns)
    localparam SCLK_PERIOD   = 40.0;          //  25 MHz  (ns)
    localparam SCLK_HALF     = SCLK_PERIOD / 2.0;

    //==========================================================================
    // DUT signals
    //==========================================================================
    reg         up_rstn;
    reg         up_clk;
    wire        up_wreq;
    wire [AXI_ADDR_W-3:0] up_waddr;
    wire [31:0] up_wdata;
    reg         up_wack;
    wire        up_rreq;
    wire [AXI_ADDR_W-3:0] up_raddr;
    reg  [31:0] up_rdata;
    reg         up_rack;
    reg         sclk;
    reg         sdi;
    wire        sdo;
    reg         cs_n;

    //==========================================================================
    // DUT
    //==========================================================================
    spi_slave_if #(
        .AXI_ADDRESS_WIDTH(AXI_ADDR_W)
    ) dut (
        .up_rstn  (up_rstn),
        .up_clk   (up_clk),
        .up_wreq  (up_wreq),
        .up_waddr (up_waddr),
        .up_wdata (up_wdata),
        .up_wack  (up_wack),
        .up_rreq  (up_rreq),
        .up_raddr (up_raddr),
        .up_rdata (up_rdata),
        .up_rack  (up_rack),
        .sclk     (sclk),
        .sdi      (sdi),
        .sdo      (sdo),
        .cs_n     (cs_n)
    );

    //==========================================================================
    // 100 MHz free-running clock
    //==========================================================================
    initial up_clk = 0;
    always #(UP_CLK_PERIOD / 2.0) up_clk = ~up_clk;

    //==========================================================================
    // pcore model — simple register file with 1-cycle handshake
    //==========================================================================
    reg [31:0] pcore_mem [0:(1<<(AXI_ADDR_W-2))-1];

    always @(posedge up_clk or negedge up_rstn) begin
        if (!up_rstn) begin
            up_wack <= 1'b0;
            up_rack <= 1'b0;
        end else begin
            // write channel
            if (up_wreq && !up_wack) begin
                pcore_mem[up_waddr] <= up_wdata;
                up_wack <= 1'b1;
            end else begin
                up_wack <= 1'b0;
            end
            // read channel
            if (up_rreq && !up_rack) begin
                up_rdata <= pcore_mem[up_raddr];
                up_rack  <= 1'b1;
            end else begin
                up_rack  <= 1'b0;
            end
        end
    end

    //==========================================================================
    // SPI master task — mode 0, MSB-first, 64-bit frame, CS-enveloped
    //==========================================================================
    task automatic spi_transfer;
        input        rw;                     // 1 = write, 0 = read
        input [13:0] addr;                   // word address (pcore word addr)
        input [31:0] wdata;                  // write data (ignored on read)
        output reg [31:0] rdata;             // read data captured from SDO
        reg   [63:0]  frame;
        reg   [31:0]  sdo_buf;
        integer       i;
    begin
        // Build the 64-bit frame:
        //   bit 63        = rw
        //   bits 62:32    = {15'b0, addr, 2'b00}   (31-bit SPI addr)
        //   bits 31:0     = wdata
        //  1 + 15 + 14 + 2 + 32 = 64 bits total
        frame = {rw, {15{1'b0}}, addr, 2'b00, wdata};

        //---------- CS assertion, first-bit setup --------
        cs_n = 1'b0;
        sclk = 1'b0;
        sdi  = frame[63];                   // MSB first
        #(SCLK_HALF / 2.0);                 // CS-to-SCLK setup time

        //---------- 64 SCLK cycles  (bit 63 down to 0) ---
        sdo_buf = 32'd0;
        for (i = 63; i >= 0; i = i - 1) begin
            // Rising edge — slave samples SDI, master samples SDO
            sclk = 1'b1;
            if (!rw && i < 32)              // data phase of read
                sdo_buf[i] = sdo;
            #(SCLK_HALF);

            // Falling edge — slave updates SDO, master drives next SDI
            sclk = 1'b0;
            if (i > 0) sdi = frame[i-1];
            #(SCLK_HALF);
        end

        //---------- CS de-assertion -----------------------
        cs_n = 1'b1;
        sdi  = 1'b0;
        #(SCLK_HALF);

        rdata = sdo_buf;
    end
    endtask

    //==========================================================================
    // Test controller
    //==========================================================================
    reg  [31:0] rd_val;
    integer     err_cnt;
    integer     test_num;
    integer     log_fd;

    // Helper macro to cut boilerplate
    task automatic test_write;
        input [13:0] addr;
        input [31:0] data;
    begin
        test_num = test_num + 1;
        $display("--- Test %0d: WRITE  addr=0x%04h  data=0x%08h ---", test_num, addr, data);
        $fdisplay(log_fd, "--- Test %0d: WRITE  addr=0x%04h  data=0x%08h ---", test_num, addr, data);
        spi_transfer(1'b1, addr, data, rd_val);
        repeat (50) @(posedge up_clk);
    end
    endtask

    task automatic test_read;
        input [13:0] addr;
        input [31:0] expected;
    begin
        test_num = test_num + 1;
        $display("--- Test %0d: READ   addr=0x%04h  expect=0x%08h ---", test_num, addr, expected);
        $fdisplay(log_fd, "--- Test %0d: READ   addr=0x%04h  expect=0x%08h ---", test_num, addr, expected);
        spi_transfer(1'b0, addr, 32'd0, rd_val);
        if (rd_val === expected) begin
            $display("  PASS: SDO = 0x%08h", rd_val);
            $fdisplay(log_fd, "  PASS: SDO = 0x%08h", rd_val);
        end else begin
            $display("  FAIL: SDO = 0x%08h  (expected 0x%08h)", rd_val, expected);
            $fdisplay(log_fd, "  FAIL: SDO = 0x%08h  (expected 0x%08h)", rd_val, expected);
            err_cnt = err_cnt + 1;
        end
        repeat (20) @(posedge up_clk);
    end
    endtask

    //==========================================================================
    // Main
    //==========================================================================
    initial begin
        err_cnt  = 0;
        test_num = 0;
        cs_n     = 1'b1;
        sclk     = 1'b0;
        sdi      = 1'b0;

        //---------- Open log file --------------------------
        log_fd = $fopen("spi_slave_if_tb.log");

        //---------- Reset (active low) --------------------
        up_rstn = 1'b0;
        repeat (20) @(posedge up_clk);
        up_rstn = 1'b1;
        repeat (5)  @(posedge up_clk);

        $display("============================================================");
        $display("  SPI Slave Interface Testbench  (up_clk=100M, sclk=25M)");
        $display("============================================================");
        $fdisplay(log_fd, "============================================================");
        $fdisplay(log_fd, "  SPI Slave Interface Testbench  (up_clk=100M, sclk=25M)");
        $fdisplay(log_fd, "============================================================");

        //---------- Write / Read pairs ---------------------
        test_write(14'h0010, 32'hDEADBEEF);
        test_read (14'h0010, 32'hDEADBEEF);

        test_write(14'h0020, 32'hCAFEBABE);
        test_read (14'h0020, 32'hCAFEBABE);

        test_write(14'h0030, 32'h12345678);
        test_read (14'h0030, 32'h12345678);

        test_write(14'h0040, 32'h00000000);
        test_read (14'h0040, 32'h00000000);

        test_write(14'h0050, 32'hFFFFFFFF);
        test_read (14'h0050, 32'hFFFFFFFF);

        test_write(14'h0060, 32'hA5A5A5A5);
        test_read (14'h0060, 32'hA5A5A5A5);

        //---------- Read never-written address -------------
        test_read (14'h00F0, 32'hxxxxxxxx);

        //---------- Rapid-fire: short inter-frame gap ------
        // (Each frame is still CS-enveloped — the DUT requires
        //  CS toggling between frames to reset spi_cnt.)
        test_num = test_num + 1;
        $display("--- Test %0d: Rapid writes (short CS gap) ---", test_num);
        $fdisplay(log_fd, "--- Test %0d: Rapid writes (short CS gap) ---", test_num);
        spi_transfer(1'b1, 14'h0080, 32'h11111111, rd_val);
        repeat (5) @(posedge up_clk);        // minimal gap
        spi_transfer(1'b1, 14'h0084, 32'h22222222, rd_val);
        repeat (5) @(posedge up_clk);
        spi_transfer(1'b1, 14'h0088, 32'h33333333, rd_val);
        repeat (50) @(posedge up_clk);

        // Verify rapid-fire writes
        test_read (14'h0080, 32'h11111111);
        test_read (14'h0084, 32'h22222222);
        test_read (14'h0088, 32'h33333333);

        //---------- Report ----------------------------------
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

endmodule
