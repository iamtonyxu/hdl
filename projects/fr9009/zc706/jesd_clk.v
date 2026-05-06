`timescale 1ns / 1ps
//////////////////////////////////////////////////////////////////////////////////
// Company:
// Engineer:
//
// Create Date: 2024/05/10 15:16:25
// Design Name:
// Module Name: jesd_sub
// Project Name:
// Target Devices:
// Tool Versions:
// Description:
//
// Dependencies:
//
// Revision:
// Revision 0.01 - File Created
// Additional Comments:
//
//////////////////////////////////////////////////////////////////////////////////


module jesd_clk(
        input gt_clk_i_p,
        input gt_clk_i_n,
        input sysref_i_p,
        input sysref_i_n,
        input rx0_sync_i,
        input rx1_sync_i,
        input tx0_sync_i_p,
        input tx0_sync_i_n,
        input tx1_sync_i_p,
        input tx1_sync_i_n,

        output gt_clk_o,
        output core_clk_o,
        output sysref_o,
        output rx0_sync_o_p,
        output rx0_sync_o_n,
        output rx1_sync_o_p,
        output rx1_sync_o_n,
        output tx0_sync_o,
        output tx1_sync_o
    );

    IBUFDS_GTE2 #(
                    .CLKCM_CFG("TRUE"),   // Refer to Transceiver User Guide
                    .CLKRCV_TRST("TRUE"), // Refer to Transceiver User Guide
                    .CLKSWING_CFG(2'b11)  // Refer to Transceiver User Guide
                )
                IBUFDS_GTE2_gtclk (
                    .O(gt_clk_o),         // 1-bit output: Refer to Transceiver User Guide
                    .ODIV2(ODIV2), // 1-bit output: Refer to Transceiver User Guide
                    .CEB(1'b0),     // 1-bit input: Refer to Transceiver User Guide
                    .I(gt_clk_i_p),         // 1-bit input: Refer to Transceiver User Guide
                    .IB(gt_clk_i_n)        // 1-bit input: Refer to Transceiver User Guide
                );
    BUFG BUFG_coreclk (
             .O(core_clk_o), // 1-bit output: Clock output
             .I(gt_clk_o)  // 1-bit input: Clock input
         );

    IBUFDS #(
               .DIFF_TERM("FALSE"),       // Differential Termination
               .IBUF_LOW_PWR("TRUE"),     // Low power="TRUE", Highest performance="FALSE"
               .IOSTANDARD("DEFAULT")     // Specify the input I/O standard
           ) IBUFDS_sysref (
               .O(sysref_o),  // Buffer output
               .I(sysref_i_p),  // Diff_p buffer input (connect directly to top-level port)
               .IB(sysref_i_n) // Diff_n buffer input (connect directly to top-level port)
           );
    OBUFDS #(
               .IOSTANDARD("DEFAULT"), // Specify the output I/O standard
               .SLEW("SLOW")           // Specify the output slew rate
           ) OBUFDS_rx0_sync (
               .O(rx0_sync_o_p),     // Diff_p output (connect directly to top-level port)
               .OB(rx0_sync_o_n),   // Diff_n output (connect directly to top-level port)
               .I(rx0_sync_i)      // Buffer input
           );
    OBUFDS #(
               .IOSTANDARD("DEFAULT"), // Specify the output I/O standard
               .SLEW("SLOW")           // Specify the output slew rate
           ) OBUFDS_rx1_sync (
               .O(rx1_sync_o_p),     // Diff_p output (connect directly to top-level port)
               .OB(rx1_sync_o_n),   // Diff_n output (connect directly to top-level port)
               .I(rx1_sync_i)      // Buffer input
           );
    IBUFDS #(
               .DIFF_TERM("FALSE"),       // Differential Termination
               .IBUF_LOW_PWR("TRUE"),     // Low power="TRUE", Highest performance="FALSE"
               .IOSTANDARD("DEFAULT")     // Specify the input I/O standard
           ) IBUFDS_tx0_sync (
               .O(tx0_sync_o),  // Buffer output
               .I(tx0_sync_i_p),  // Diff_p buffer input (connect directly to top-level port)
               .IB(tx0_sync_i_n) // Diff_n buffer input (connect directly to top-level port)
           );
    IBUFDS #(
               .DIFF_TERM("FALSE"),       // Differential Termination
               .IBUF_LOW_PWR("TRUE"),     // Low power="TRUE", Highest performance="FALSE"
               .IOSTANDARD("DEFAULT")     // Specify the input I/O standard
           ) IBUFDS_tx1_sync (
               .O(tx1_sync_o),  // Buffer output
               .I(tx1_sync_i_p),  // Diff_p buffer input (connect directly to top-level port)
               .IB(tx1_sync_i_n) // Diff_n buffer input (connect directly to top-level port)
           );
endmodule
