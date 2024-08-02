`timescale 1ns / 1ps
`define EXTRA_BITS 3

module dpd_luts_row #(
    parameter ID_MASK = 64'hFFFF,
    parameter ROW = 0,   
    parameter I_DELAY_MAX = 8,
    parameter J_DELAY_MAX = 8,
    parameter DATA_WIDTH = 32,
    parameter ADDR_WIDTH = 10
)
(
    input clk,
    input rst_n,

    // input and output of dpd_luts_row for same j-delay
    input [ADDR_WIDTH-1:0] mag,
    output [DATA_WIDTH-1+`EXTRA_BITS*2:0] abz_out, //abz_out = sum(lut_out) of the column

    // configuration port
    input config_clk,
    input [ADDR_WIDTH-1:0] config_addr,
    input [DATA_WIDTH-1:0] config_din,
    output [DATA_WIDTH-1:0] config_dout,
    input [I_DELAY_MAX-1:0] config_lutId,
    input config_web
);

    reg [ADDR_WIDTH*I_DELAY_MAX-1:0] mag_delay;
    wire [DATA_WIDTH*I_DELAY_MAX-1:0]lut_out;
    wire [DATA_WIDTH*I_DELAY_MAX-1:0] config_dout_bus;
    reg [I_DELAY_MAX-1:0] config_lutId_d;

    genvar ii;
    generate
        for (ii=0; ii < I_DELAY_MAX; ii=ii+1)
        begin: MAG_I_DELAY
            always@(posedge clk or negedge rst_n)
            begin
                if(ii == 0) begin
                    if(~rst_n)
                        mag_delay[ADDR_WIDTH-1:0] <= 0;
                    else
                        mag_delay[ADDR_WIDTH-1:0] <= mag;
                end
                else begin
                    if(~rst_n)
                        mag_delay[ADDR_WIDTH*(ii+1)-1:ADDR_WIDTH*ii] <= 0;
                    else
                        mag_delay[ADDR_WIDTH*(ii+1)-1:ADDR_WIDTH*ii] <= mag_delay[ADDR_WIDTH*ii-1:ADDR_WIDTH*(ii-1)];
                end
            end
        end
    endgenerate

    cadder8#(
        .DWIDTH(DATA_WIDTH/2)
    )cadder
    (
        .clk(clk),
        .rst_n(rst_n),
        .din_enable(1'b1),
        .dout_valid(),
        .din0(lut_out[(DATA_WIDTH*(0+1)-1):(DATA_WIDTH*0)]), // {din0_i, din0_q}
        .din1(lut_out[(DATA_WIDTH*(1+1)-1):(DATA_WIDTH*1)]), // {din1_i, din1_q}
        .din2(lut_out[(DATA_WIDTH*(2+1)-1):(DATA_WIDTH*2)]), // {din2_i, din2_q}
        .din3(lut_out[(DATA_WIDTH*(3+1)-1):(DATA_WIDTH*3)]), // {din3_i, din3_q}
        .din4(lut_out[(DATA_WIDTH*(4+1)-1):(DATA_WIDTH*4)]), // {din4_i, din4_q}
        .din5(lut_out[(DATA_WIDTH*(5+1)-1):(DATA_WIDTH*5)]), // {din5_i, din5_q}
        .din6(lut_out[(DATA_WIDTH*(6+1)-1):(DATA_WIDTH*6)]), // {din6_i, din6_q}
        .din7(lut_out[(DATA_WIDTH*(7+1)-1):(DATA_WIDTH*7)]), // {din7_i, din7_q}
        .dout(abz_out) // {dout_i, dout_q}
    );

    always @(posedge config_clk or negedge rst_n)
        if(~rst_n)
            config_lutId_d <= 0;
        else
            config_lutId_d <= config_lutId;

    assign config_dout = config_lutId_d[0] ? config_dout_bus[DATA_WIDTH*1-1:DATA_WIDTH*0] :
                         config_lutId_d[1] ? config_dout_bus[DATA_WIDTH*2-1:DATA_WIDTH*1] :
                         config_lutId_d[2] ? config_dout_bus[DATA_WIDTH*3-1:DATA_WIDTH*2] :
                         config_lutId_d[3] ? config_dout_bus[DATA_WIDTH*4-1:DATA_WIDTH*3] :
                         config_lutId_d[4] ? config_dout_bus[DATA_WIDTH*5-1:DATA_WIDTH*4] :
                         config_lutId_d[5] ? config_dout_bus[DATA_WIDTH*6-1:DATA_WIDTH*5] :
                         config_lutId_d[6] ? config_dout_bus[DATA_WIDTH*7-1:DATA_WIDTH*6] :
                         config_lutId_d[7] ? config_dout_bus[DATA_WIDTH*8-1:DATA_WIDTH*7] :
                         0;

   genvar i_delay;
   generate
      for (i_delay=0; i_delay < I_DELAY_MAX; i_delay=i_delay+1)
      begin: LUT_I_DELAY
            dpd_lut #(
                .ID_MASK(ID_MASK),
                .ID(i_delay + ROW * J_DELAY_MAX),
                .DATA_WIDTH(DATA_WIDTH),
                .ADDR_WIDTH(ADDR_WIDTH)
            ) inst
            (
                .clk(clk),
                .rst_n(rst_n),

                // RAM port-A, only read
                .lut_addr(mag_delay[(ADDR_WIDTH*(i_delay+1)-1):(ADDR_WIDTH*i_delay)]),
                .lut_out(lut_out[(DATA_WIDTH*(i_delay+1)-1):(DATA_WIDTH*i_delay)]),

                // RAM port-B, read and write
                .config_clk(config_clk),
                .config_addr(config_addr),
                .config_din(config_din),
                .config_dout(config_dout_bus[(DATA_WIDTH*(i_delay+1)-1):(DATA_WIDTH*i_delay)]),
                .config_web(config_lutId[i_delay] & config_web)
            );

      end
   endgenerate

endmodule
