`timescale 1ns / 1ps
`define EXTRA_BITS 3
`define I_DELAY_MAX 8
`define J_DELAY_MAX 8
`define EXT_LATENCY 9  //latency of dpd_lut_row(1+1+7)
`define ACT_LATENCY 22  //latency of dpd actuator (dpd_lut_row(1+1+7) + cmult(6) + cadder(7))

module dpd_actuator #(
    parameter ID_MASK = 64'hFFFF_FFFF_FFFF_FFFF,
    parameter DATA_WIDTH = 32,
    parameter ADDR_WIDTH = 9
)
(
    input clk,
    input rst_n,

    input tu_enable,
    input bypass,
    input [DATA_WIDTH-1:0] tu,
    input [ADDR_WIDTH-1:0] mag, // mag = abs(tu)
    output [DATA_WIDTH-1:0] tx, // postDPD
    output tx_valid,

    // configuration port
    input config_clk,
    input [ADDR_WIDTH-1:0] config_addr,
    input [DATA_WIDTH-1:0] config_din,
    output [DATA_WIDTH-1:0] config_dout,
    input [`I_DELAY_MAX*`J_DELAY_MAX-1:0] config_lutId,
    input config_web
);

    localparam ABZ_WIDTH = DATA_WIDTH + `EXTRA_BITS*2;
    localparam ABP_WIDTH = ABZ_WIDTH + DATA_WIDTH;
    localparam ABPSUM_WIDTH = ABP_WIDTH + `EXTRA_BITS*2;

    reg [`I_DELAY_MAX*`J_DELAY_MAX-1:0]config_lutId_d;
    wire [DATA_WIDTH-1:0] tu_wire;
    wire [DATA_WIDTH-1:0] tu_aligned;
    reg [DATA_WIDTH*`J_DELAY_MAX-1:0]tu_delay;
    wire [ABZ_WIDTH*`J_DELAY_MAX-1:0] abz_out_delay;
    wire [ABP_WIDTH*`J_DELAY_MAX-1:0]abp; // abp = tu_delay * abz_out
    wire [ABPSUM_WIDTH-1:0]abp_sum;

    wire [DATA_WIDTH*`J_DELAY_MAX-1:0] config_dout_bus;

    assign tu_wire = tu_enable ? tu : 0;

    delay #(
        .TAPS(`EXT_LATENCY-1), // 1 clk period is reserved for tu_aligned to tu_delay
        .DWIDTH(DATA_WIDTH)
    )tu_aligned_delay
    (
        .clk(clk),
        .din(tu_wire),
        .dout(tu_aligned)
    );

    delay #(
        .TAPS(`ACT_LATENCY),
        .DWIDTH(1)
    )tx_valid_delay
    (
        .clk(clk),
        .din(tu_enable),
        .dout(tx_valid)
    );


    genvar jj;
    generate
        for (jj=0; jj < `J_DELAY_MAX; jj=jj+1)
        begin: TX_J_DELAY
            always@(posedge clk or negedge rst_n)
            begin
                if(jj == 0) begin
                    if(~rst_n)
                        tu_delay[DATA_WIDTH-1:0] <= 0;
                    else
                        tu_delay[DATA_WIDTH-1:0] <= tu_aligned;
                end
                else begin
                    if(~rst_n)
                        tu_delay[DATA_WIDTH*(jj+1)-1:DATA_WIDTH*jj] <= 0;
                    else
                        tu_delay[DATA_WIDTH*(jj+1)-1:DATA_WIDTH*jj] <= tu_delay[DATA_WIDTH*jj-1:DATA_WIDTH*(jj-1)];
                end
            end
        end
    endgenerate

    // abp
    genvar j_delay;
    generate
        for (j_delay=0; j_delay < `J_DELAY_MAX; j_delay=j_delay+1)
        begin: COL_PRODUCT
            cmult_fixed_v2 #
            (
            .AWIDTH(DATA_WIDTH/2),
            .BWIDTH(ABZ_WIDTH/2),
            .CWIDTH(ABP_WIDTH/2)
            )inst
            (
            .clk(clk),
            .rst_n(rst_n),
            .dina(tu_delay[DATA_WIDTH*(j_delay+1)-1 : DATA_WIDTH*j_delay]),
            .dinb(abz_out_delay[ABZ_WIDTH*(j_delay+1)-1 : ABZ_WIDTH*j_delay]),
            .doutp(abp[ABP_WIDTH*(j_delay+1)-1 : ABP_WIDTH*j_delay])
            );
        end
    endgenerate

    // tx = sum(abp)
    localparam START1_BIT = ABPSUM_WIDTH-7-1;
    localparam END1_BIT = ABPSUM_WIDTH-7-1-DATA_WIDTH/2+1;
    localparam START2_BIT = ABPSUM_WIDTH/2-7-1;
    localparam END2_BIT = ABPSUM_WIDTH/2-7-1-DATA_WIDTH/2+1;
    assign tx = bypass ? tu : {abp_sum[START1_BIT:END1_BIT], abp_sum[START2_BIT:END2_BIT]};

    cadder8#(
        .DWIDTH(ABP_WIDTH/2)
    )abp_cadder
    (
        .clk(clk),
        .rst_n(rst_n),
        .din_enable(1'b1),
        .dout_valid(),
        .din0(abp[(ABP_WIDTH*(0+1)-1):(ABP_WIDTH*0)]), // {din0_i, din0_q}
        .din1(abp[(ABP_WIDTH*(1+1)-1):(ABP_WIDTH*1)]), // {din1_i, din1_q}
        .din2(abp[(ABP_WIDTH*(2+1)-1):(ABP_WIDTH*2)]), // {din2_i, din2_q}
        .din3(abp[(ABP_WIDTH*(3+1)-1):(ABP_WIDTH*3)]), // {din3_i, din3_q}
        .din4(abp[(ABP_WIDTH*(4+1)-1):(ABP_WIDTH*4)]), // {din4_i, din4_q}
        .din5(abp[(ABP_WIDTH*(5+1)-1):(ABP_WIDTH*5)]), // {din5_i, din5_q}
        .din6(abp[(ABP_WIDTH*(6+1)-1):(ABP_WIDTH*6)]), // {din6_i, din6_q}
        .din7(abp[(ABP_WIDTH*(7+1)-1):(ABP_WIDTH*7)]), // {din7_i, din7_q}
        .dout(abp_sum) // {dout_i, dout_q}
    );

    always @(posedge config_clk or negedge rst_n)
        if(~rst_n)
            config_lutId_d <= 0;
        else
            config_lutId_d <= config_lutId;

    assign config_dout = (config_lutId_d[`I_DELAY_MAX*1-1:`I_DELAY_MAX*0] !=0) ? config_dout_bus[DATA_WIDTH*1-1:DATA_WIDTH*0] :
                         (config_lutId_d[`I_DELAY_MAX*2-1:`I_DELAY_MAX*1] !=0) ? config_dout_bus[DATA_WIDTH*2-1:DATA_WIDTH*1] :
                         (config_lutId_d[`I_DELAY_MAX*3-1:`I_DELAY_MAX*2] !=0) ? config_dout_bus[DATA_WIDTH*3-1:DATA_WIDTH*2] :
                         (config_lutId_d[`I_DELAY_MAX*4-1:`I_DELAY_MAX*3] !=0) ? config_dout_bus[DATA_WIDTH*4-1:DATA_WIDTH*3] :
                         (config_lutId_d[`I_DELAY_MAX*5-1:`I_DELAY_MAX*4] !=0) ? config_dout_bus[DATA_WIDTH*5-1:DATA_WIDTH*4] :
                         (config_lutId_d[`I_DELAY_MAX*6-1:`I_DELAY_MAX*5] !=0) ? config_dout_bus[DATA_WIDTH*6-1:DATA_WIDTH*5] :
                         (config_lutId_d[`I_DELAY_MAX*7-1:`I_DELAY_MAX*6] !=0) ? config_dout_bus[DATA_WIDTH*7-1:DATA_WIDTH*6] :
                         (config_lutId_d[`I_DELAY_MAX*8-1:`I_DELAY_MAX*7] !=0) ? config_dout_bus[DATA_WIDTH*8-1:DATA_WIDTH*7] :
                         0;

    genvar row;
    generate
        for (row=0; row < `J_DELAY_MAX; row=row+1)
        begin: DPD_LUT_ROW
            dpd_luts_row #(
            .ID_MASK(ID_MASK),
            .ROW(row),
            .I_DELAY_MAX(`I_DELAY_MAX),
            .J_DELAY_MAX(`J_DELAY_MAX),
            .DATA_WIDTH(DATA_WIDTH),
            .ADDR_WIDTH(ADDR_WIDTH)
            ) inst
            (
            .clk(clk),
            .rst_n(rst_n),

            // input and output of dpd_luts_row for same j-delay
            .mag(mag),
            .abz_out(abz_out_delay[(ABZ_WIDTH)*(row+1)-1:(ABZ_WIDTH)*row]),

            // configuration port
            .config_clk(config_clk),
            .config_addr(config_addr),
            .config_din(config_din),
            .config_dout(config_dout_bus[DATA_WIDTH*(row+1)-1:DATA_WIDTH*row]),
            .config_lutId(config_lutId[`I_DELAY_MAX*(row+1)-1:`I_DELAY_MAX*row]),
            .config_web(config_web)
            );
        end
    endgenerate

endmodule
