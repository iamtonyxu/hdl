`timescale 1ns / 1ps
`define EXTRA_BITS 3
`define I_DELAY_MAX 8
`define J_DELAY_MAX 8
`define ID_MAX  (`I_DELAY_MAX*`J_DELAY_MAX)
`define EXT_LATENCY 9  //latency of dpd_lut_row(1+1+7)
`define ACT_LATENCY 22  //latency of dpd actuator (dpd_lut_row(1+1+7) + cmult(6) + cadder(7))

module dpd_actuator_v2 #(
    parameter ID_MASK = 64'hFFFF_FFFF_FFFF_FFFF,
    parameter DATA_WIDTH = 32,
    parameter ADDR_WIDTH = 10
)
(
    // signal in/out port
    input                       clk,
    input                       rst_n,
    input                       tu_enable,
    input   [DATA_WIDTH*2-1:0]  tu,
    input   [ADDR_WIDTH*2-1:0]  mag,
    output  [DATA_WIDTH*2-1:0]  tx,
    output                      tx_valid,

    // configuration port
    input                       enc,
    input   [`ID_MAX-1:0]       lutIdc,
    input                       wec,
    input   [ADDR_WIDTH-1:0]    addrc,
    input   [DATA_WIDTH-1:0]    dinc,
    output  [DATA_WIDTH-1:0]    doutc,
    output                      validc

);

    localparam HOUT_WIDTH = DATA_WIDTH + `EXTRA_BITS*2;
    localparam ABP_WIDTH = HOUT_WIDTH + DATA_WIDTH;
    localparam ABPSUM_WIDTH = ABP_WIDTH + `EXTRA_BITS*2;
    
    // mag signal
    wire [ADDR_WIDTH-1:0] mag_odd, mag_even;
    // tu signal
    wire [DATA_WIDTH*2-1:0] tu_wire;
    wire [DATA_WIDTH*2-1:0] tu_aligned;
    wire [DATA_WIDTH-1:0] tu_aligned_odd, tu_aligned_even;
    reg [DATA_WIDTH*`J_DELAY_MAX/2-1:0] tu_delay_odd, tu_delay_even;    
    wire [DATA_WIDTH*(`J_DELAY_MAX+1)-1:0]tu_delay;
    // fir signal
    wire [HOUT_WIDTH*`J_DELAY_MAX-1:0] hout_odd_delay, hout_even_delay;
    wire [ABP_WIDTH*`J_DELAY_MAX-1:0]abp_odd, abp_even; // abp = tu_delay *hout_delay
    wire [ABPSUM_WIDTH-1:0]abp_sum_odd, abp_sum_even;
    // tx signal
    wire [DATA_WIDTH-1:0] tx_odd, tx_even;
    // configration
    wire [DATA_WIDTH*`J_DELAY_MAX-1:0] doutc_bus;
    reg [DATA_WIDTH-1:0]doutc_r;
    //reg enc;
    reg  [`ID_MAX-1:0] lutIdc_r;

    assign mag_odd =mag[ADDR_WIDTH-1:0];
    assign mag_even = mag[ADDR_WIDTH*2-1:ADDR_WIDTH];
    assign tu_wire = tu_enable ? tu : 0;
    assign tu_aligned_odd = tu_aligned[DATA_WIDTH-1:0];
    assign tu_aligned_even = tu_aligned[DATA_WIDTH*2-1:DATA_WIDTH*1];

    delay #(
        .TAPS(`EXT_LATENCY-1), // 1 clk period is reserved for tu_aligned to tu_delay
        .DWIDTH(DATA_WIDTH*2)
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

    // tu_delay
    assign tu_delay = { tu_delay_odd[DATA_WIDTH*4-1 : DATA_WIDTH*3],
                        tu_delay_even[DATA_WIDTH*3-1 : DATA_WIDTH*2],
                        tu_delay_odd[DATA_WIDTH*3-1 : DATA_WIDTH*2],
                        tu_delay_even[DATA_WIDTH*2-1 : DATA_WIDTH*1],
                        tu_delay_odd[DATA_WIDTH*2-1 : DATA_WIDTH*1],
                        tu_delay_even[DATA_WIDTH*1-1 : DATA_WIDTH*0],
                        tu_delay_odd[DATA_WIDTH*1-1 : DATA_WIDTH*0],
                        tu_aligned_even,
                        tu_aligned_odd
                        };

    // tu_delay_odd
    genvar ii;
    generate
        for (ii=0; ii < `J_DELAY_MAX/2; ii=ii+1)
        begin: TU_ODD_DELAY
            always@(posedge clk or negedge rst_n)
            begin
                if(ii == 0) begin
                    if(~rst_n)
                        tu_delay_odd[DATA_WIDTH-1:0] <= 0;
                    else
                        tu_delay_odd[DATA_WIDTH-1:0] <= tu_aligned_odd;
                end
                else begin
                    if(~rst_n)
                        tu_delay_odd[DATA_WIDTH*(ii+1)-1:DATA_WIDTH*ii] <= 0;
                    else
                        tu_delay_odd[DATA_WIDTH*(ii+1)-1:DATA_WIDTH*ii] <= tu_delay_odd[DATA_WIDTH*ii-1:DATA_WIDTH*(ii-1)];
                end
            end
        end
    endgenerate

    // tu_delay_even
    genvar jj;
    generate
        for (jj=0; jj < `J_DELAY_MAX/2; jj=jj+1)
        begin: TU_EVEN_DELAY
            always@(posedge clk or negedge rst_n)
            begin
                if(jj == 0) begin
                    if(~rst_n)
                        tu_delay_even[DATA_WIDTH-1:0] <= 0;
                    else
                        tu_delay_even[DATA_WIDTH-1:0] <= tu_aligned_even;
                end
                else begin
                    if(~rst_n)
                        tu_delay_even[DATA_WIDTH*(jj+1)-1:DATA_WIDTH*jj] <= 0;
                    else
                        tu_delay_even[DATA_WIDTH*(jj+1)-1:DATA_WIDTH*jj] <= tu_delay_even[DATA_WIDTH*jj-1:DATA_WIDTH*(jj-1)];
                end
            end
        end
    endgenerate

    // dpd_lut_row instantiation
    genvar row;
    generate
        for (row=0; row < `J_DELAY_MAX; row=row+1)
        begin: DPD_LUT_ROW
            dpd_luts_row_v2 #(
                .ID_MASK(ID_MASK),
                .J_DELAY(row),
                .I_DELAY_MAX(`I_DELAY_MAX),
                .J_DELAY_MAX(`J_DELAY_MAX),
                .DATA_WIDTH(DATA_WIDTH),
                .ADDR_WIDTH(ADDR_WIDTH)
            ) inst
            (
                // input and output of dpd_luts_row for same j-delay
                .clk(clk),
                .rst_n(rst_n),
                .mag_odd(mag_odd), // 0, 2, 4 ...
                .mag_even(mag_even),// 1, 3, 5 ...
                .hout_odd(hout_odd_delay[(HOUT_WIDTH)*(row+1)-1:(HOUT_WIDTH)*row]),
                .hout_even(hout_even_delay[(HOUT_WIDTH)*(row+1)-1:(HOUT_WIDTH)*row]),

                //configration port
                .enc(enc),
                .lutIdc(lutIdc[`I_DELAY_MAX*(row+1)-1:`I_DELAY_MAX*row]),
                .wec(wec),
                .addrc(addrc),
                .dinc(dinc),
                .doutc(doutc_bus[DATA_WIDTH*(row+1)-1:DATA_WIDTH*row])
            );
        end
    endgenerate

    // abp_even
    genvar kk;
    generate
        for (kk=0; kk < `J_DELAY_MAX; kk=kk+1)
        begin: COL_PRODUCT_ODD
            cmult_fixed_v2 #
            (
                .AWIDTH(DATA_WIDTH/2),
                .BWIDTH(HOUT_WIDTH/2),
                .CWIDTH(ABP_WIDTH/2)
            )inst_odd
            (
                .clk(clk),
                .rst_n(rst_n),
                .dina(tu_delay[DATA_WIDTH*(kk+2)-1 : DATA_WIDTH*(kk+1)]),
                .dinb(hout_even_delay[HOUT_WIDTH*(kk+1)-1 : HOUT_WIDTH*kk]),
                .doutp(abp_even[ABP_WIDTH*(kk+1)-1 : ABP_WIDTH*kk])
            );
        end
    endgenerate

    // abp_odd
    genvar ll;
    generate
        for (ll=0; ll < `J_DELAY_MAX; ll=ll+1)
        begin: COL_PRODUCT_EVEN
            cmult_fixed_v2 #
            (
                .AWIDTH(DATA_WIDTH/2),
                .BWIDTH(HOUT_WIDTH/2),
                .CWIDTH(ABP_WIDTH/2)
            )inst_even
            (
                .clk(clk),
                .rst_n(rst_n),
                .dina(tu_delay[DATA_WIDTH*(ll+1)-1 : DATA_WIDTH*(ll+0)]),
                .dinb(hout_odd_delay[HOUT_WIDTH*(ll+1)-1 : HOUT_WIDTH*ll]),
                .doutp(abp_odd[ABP_WIDTH*(ll+1)-1 : ABP_WIDTH*ll])
            );
        end
    endgenerate
    
    // tx = sum(abp)
    localparam START1_BIT = ABPSUM_WIDTH-7-1;
    localparam END1_BIT = ABPSUM_WIDTH-7-1-DATA_WIDTH/2+1;
    localparam START2_BIT = ABPSUM_WIDTH/2-7-1;
    localparam END2_BIT = ABPSUM_WIDTH/2-7-1-DATA_WIDTH/2+1;
    
    assign tx = {tx_odd, tx_even};
    assign tx_odd = {abp_sum_odd[START1_BIT:END1_BIT], abp_sum_odd[START2_BIT:END2_BIT]};
    assign tx_even = {abp_sum_even[START1_BIT:END1_BIT], abp_sum_even[START2_BIT:END2_BIT]};

    // abp_sum_odd
    cadder8#(
        .DWIDTH(ABP_WIDTH/2)
    )abp_cadder_odd
    (
        .clk(clk),
        .rst_n(rst_n),
        .din_enable(1'b1),
        .dout_valid(),
        .din0(abp_odd[(ABP_WIDTH*(0+1)-1):(ABP_WIDTH*0)]), // {din0_i, din0_q}
        .din1(abp_odd[(ABP_WIDTH*(1+1)-1):(ABP_WIDTH*1)]), // {din1_i, din1_q}
        .din2(abp_odd[(ABP_WIDTH*(2+1)-1):(ABP_WIDTH*2)]), // {din2_i, din2_q}
        .din3(abp_odd[(ABP_WIDTH*(3+1)-1):(ABP_WIDTH*3)]), // {din3_i, din3_q}
        .din4(abp_odd[(ABP_WIDTH*(4+1)-1):(ABP_WIDTH*4)]), // {din4_i, din4_q}
        .din5(abp_odd[(ABP_WIDTH*(5+1)-1):(ABP_WIDTH*5)]), // {din5_i, din5_q}
        .din6(abp_odd[(ABP_WIDTH*(6+1)-1):(ABP_WIDTH*6)]), // {din6_i, din6_q}
        .din7(abp_odd[(ABP_WIDTH*(7+1)-1):(ABP_WIDTH*7)]), // {din7_i, din7_q}
        .dout(abp_sum_odd)
    );

    // abp_sum_even
    cadder8#(
        .DWIDTH(ABP_WIDTH/2)
    )abp_cadder_even
    (
        .clk(clk),
        .rst_n(rst_n),
        .din_enable(1'b1),
        .dout_valid(),
        .din0(abp_even[(ABP_WIDTH*(0+1)-1):(ABP_WIDTH*0)]), // {din0_i, din0_q}
        .din1(abp_even[(ABP_WIDTH*(1+1)-1):(ABP_WIDTH*1)]), // {din1_i, din1_q}
        .din2(abp_even[(ABP_WIDTH*(2+1)-1):(ABP_WIDTH*2)]), // {din2_i, din2_q}
        .din3(abp_even[(ABP_WIDTH*(3+1)-1):(ABP_WIDTH*3)]), // {din3_i, din3_q}
        .din4(abp_even[(ABP_WIDTH*(4+1)-1):(ABP_WIDTH*4)]), // {din4_i, din4_q}
        .din5(abp_even[(ABP_WIDTH*(5+1)-1):(ABP_WIDTH*5)]), // {din5_i, din5_q}
        .din6(abp_even[(ABP_WIDTH*(6+1)-1):(ABP_WIDTH*6)]), // {din6_i, din6_q}
        .din7(abp_even[(ABP_WIDTH*(7+1)-1):(ABP_WIDTH*7)]), // {din7_i, din7_q}
        .dout(abp_sum_even)
    );

    // configuration port
    always @(posedge clk or negedge rst_n)
        if(~rst_n)
            lutIdc_r <= 0;
        else
            lutIdc_r <= lutIdc;

    assign doutc = doutc_r;
    always @(posedge clk or negedge rst_n)
        if(~rst_n)
            doutc_r <= 0;
        else
            if(lutIdc_r[`I_DELAY_MAX*1-1:`I_DELAY_MAX*0] !=0)
                doutc_r <= doutc_bus[DATA_WIDTH*1-1:DATA_WIDTH*0];
            else if(lutIdc_r[`I_DELAY_MAX*2-1:`I_DELAY_MAX*1] !=0)
                doutc_r <= doutc_bus[DATA_WIDTH*2-1:DATA_WIDTH*1];
            else if(lutIdc_r[`I_DELAY_MAX*3-1:`I_DELAY_MAX*2] !=0)
                doutc_r <= doutc_bus[DATA_WIDTH*3-1:DATA_WIDTH*2];
            else if(lutIdc_r[`I_DELAY_MAX*4-1:`I_DELAY_MAX*3] !=0)
                doutc_r <= doutc_bus[DATA_WIDTH*4-1:DATA_WIDTH*3];
            else if(lutIdc_r[`I_DELAY_MAX*5-1:`I_DELAY_MAX*4] !=0)
                doutc_r <= doutc_bus[DATA_WIDTH*5-1:DATA_WIDTH*4];
            else if(lutIdc_r[`I_DELAY_MAX*6-1:`I_DELAY_MAX*5] !=0)
                doutc_r <= doutc_bus[DATA_WIDTH*6-1:DATA_WIDTH*5];
            else if(lutIdc_r[`I_DELAY_MAX*7-1:`I_DELAY_MAX*6] !=0)
                doutc_r <= doutc_bus[DATA_WIDTH*7-1:DATA_WIDTH*6];
            else if(lutIdc_r[`I_DELAY_MAX*8-1:`I_DELAY_MAX*7] !=0)
                doutc_r <= doutc_bus[DATA_WIDTH*8-1:DATA_WIDTH*7];
            else
                doutc_r <= 0;


    // validc
    delay #(
        .TAPS(3), // ? delay from enc to validc
        .DWIDTH(1)
    )validc_delay
    (
        .clk(clk),
        .din(enc & (~wec)),
        .dout(validc)
    );

endmodule
