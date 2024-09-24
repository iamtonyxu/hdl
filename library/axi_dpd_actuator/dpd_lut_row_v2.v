`timescale 1ns / 1ps
`define EXTRA_BITS 3
/*
*   write_Lut:
*   enc = 1, wec = 1, addrc = lut_addr, dinc = lut_din
*   latency = 1 clk period
*
*   read_lut:
*   enc = 1, wec = 0, addrc = lut_addr
*   latency = 2 clk periods
*
*/

module dpd_luts_row_v2 #(
    parameter ID_MASK = 64'hFFFF_FFFF_FFFF_FFFF,
    parameter J_DELAY = 0,   
    parameter I_DELAY_MAX = 8,
    parameter J_DELAY_MAX = 8,
    parameter DATA_WIDTH = 32,
    parameter ADDR_WIDTH = 10
)
(
    // input and output of dpd_luts_row for same j-delay
    input                       clk,
    input                       rst_n,
    input   [ADDR_WIDTH-1:0]    mag_odd, // 0, 2, 4 ...
    input   [ADDR_WIDTH-1:0]    mag_even,// 1, 3, 5 ...
    output  [DATA_WIDTH-1+`EXTRA_BITS*2:0] hout_odd,
    output  [DATA_WIDTH-1+`EXTRA_BITS*2:0] hout_even,

    //configration port
    input                       enc,
    input   [I_DELAY_MAX-1:0]   lutIdc,
    input                       wec,
    input   [ADDR_WIDTH-1:0]    addrc,
    input   [DATA_WIDTH-1:0]    dinc,
    output  [DATA_WIDTH-1:0]    doutc

);

    wire [DATA_WIDTH*I_DELAY_MAX-1:0] doutc_bus;
    reg [I_DELAY_MAX-1:0] lutIdc_r;
    reg [DATA_WIDTH-1:0] doutc_r;

    reg [ADDR_WIDTH*I_DELAY_MAX/2-1:0] mag_odd_dd;
    reg [ADDR_WIDTH*I_DELAY_MAX/2-1:0] mag_even_dd;
    wire [ADDR_WIDTH*I_DELAY_MAX-1:0] mag_bus_odd;
    wire [ADDR_WIDTH*I_DELAY_MAX-1:0] mag_bus_even;
    
    wire [DATA_WIDTH*I_DELAY_MAX-1:0]dout_bus_odd;
    wire [DATA_WIDTH*I_DELAY_MAX-1:0]dout_bus_even;

    assign mag_bus_odd = {  mag_even_dd[ADDR_WIDTH*3-1:ADDR_WIDTH*2],
                            mag_odd_dd[ADDR_WIDTH*3-1:ADDR_WIDTH*2],
                            mag_even_dd[ADDR_WIDTH*2-1:ADDR_WIDTH*1],
                            mag_odd_dd[ADDR_WIDTH*2-1:ADDR_WIDTH*1],
                            mag_even_dd[ADDR_WIDTH*1-1:ADDR_WIDTH*0],
                            mag_odd_dd[ADDR_WIDTH*1-1:ADDR_WIDTH*0],
                            mag_even,
                            mag_odd
                            };

    assign mag_bus_even = { mag_odd_dd[ADDR_WIDTH*4-1:ADDR_WIDTH*3],
                            mag_even_dd[ADDR_WIDTH*3-1:ADDR_WIDTH*2],
                            mag_odd_dd[ADDR_WIDTH*3-1:ADDR_WIDTH*2],
                            mag_even_dd[ADDR_WIDTH*2-1:ADDR_WIDTH*1],
                            mag_odd_dd[ADDR_WIDTH*2-1:ADDR_WIDTH*1],
                            mag_even_dd[ADDR_WIDTH*1-1:ADDR_WIDTH*0],
                            mag_odd_dd[ADDR_WIDTH*1-1:ADDR_WIDTH*0],
                            mag_even
                            };

    genvar ii;
    generate
        for (ii=0; ii < I_DELAY_MAX/2; ii=ii+1)
        begin: MAG_I_EVEN
            always@(posedge clk or negedge rst_n)
            begin
                if(ii == 0) begin
                    if(~rst_n) begin
                        mag_even_dd[ADDR_WIDTH-1:0] <= 0;
                    end
                    else
                        mag_even_dd[ADDR_WIDTH-1:0] <= mag_even;
                end
                else begin
                    if(~rst_n) begin
                        mag_even_dd[ADDR_WIDTH*(ii+1)-1:ADDR_WIDTH*ii] <= 0;
                    end
                    else begin
                        mag_even_dd[ADDR_WIDTH*(ii+1)-1:ADDR_WIDTH*ii] <= mag_even_dd[ADDR_WIDTH*ii-1:ADDR_WIDTH*(ii-1)];
                    end
                end
            end
        end
    endgenerate

    genvar jj;
    generate
        for (jj=0; jj < I_DELAY_MAX/2; jj=jj+1)
        begin: MAG_I_ODD
            always@(posedge clk or negedge rst_n)
            begin
                if(jj == 0) begin
                    if(~rst_n) begin
                        mag_odd_dd[ADDR_WIDTH-1:0] <= 0;
                    end
                    else
                        mag_odd_dd[ADDR_WIDTH-1:0] <= mag_odd;
                end
                else begin
                    if(~rst_n) begin
                        mag_odd_dd[ADDR_WIDTH*(jj+1)-1:ADDR_WIDTH*jj] <= 0;
                    end
                    else begin
                        mag_odd_dd[ADDR_WIDTH*(jj+1)-1:ADDR_WIDTH*jj] <= mag_odd_dd[ADDR_WIDTH*jj-1:ADDR_WIDTH*(jj-1)];
                    end
                end
            end
        end
    endgenerate

    cadder8#(
        .DWIDTH(DATA_WIDTH/2)
    )cadder_even
    (
        .clk(clk),
        .rst_n(rst_n),
        .din_enable(1'b1),
        .dout_valid(),
        .din0(dout_bus_even[(DATA_WIDTH*1-1):(DATA_WIDTH*0)]), // {din0_i, din0_q}
        .din1(dout_bus_even[(DATA_WIDTH*2-1):(DATA_WIDTH*1)]), // {din1_i, din1_q}
        .din2(dout_bus_even[(DATA_WIDTH*3-1):(DATA_WIDTH*2)]), // {din2_i, din2_q}
        .din3(dout_bus_even[(DATA_WIDTH*4-1):(DATA_WIDTH*3)]), // {din3_i, din3_q}
        .din4(dout_bus_even[(DATA_WIDTH*5-1):(DATA_WIDTH*4)]), // {din4_i, din4_q}
        .din5(dout_bus_even[(DATA_WIDTH*6-1):(DATA_WIDTH*5)]), // {din5_i, din5_q}
        .din6(dout_bus_even[(DATA_WIDTH*7-1):(DATA_WIDTH*6)]), // {din6_i, din6_q}
        .din7(dout_bus_even[(DATA_WIDTH*8-1):(DATA_WIDTH*7)]), // {din7_i, din7_q}
        .dout(hout_even) // {dout_i, dout_q}
    );

    cadder8#(
        .DWIDTH(DATA_WIDTH/2)
    )cadder_odd
    (
        .clk(clk),
        .rst_n(rst_n),
        .din_enable(1'b1),
        .dout_valid(),
        .din0(dout_bus_odd[(DATA_WIDTH*1-1):(DATA_WIDTH*0)]), // {din0_i, din0_q}
        .din1(dout_bus_odd[(DATA_WIDTH*2-1):(DATA_WIDTH*1)]), // {din1_i, din1_q}
        .din2(dout_bus_odd[(DATA_WIDTH*3-1):(DATA_WIDTH*2)]), // {din2_i, din2_q}
        .din3(dout_bus_odd[(DATA_WIDTH*4-1):(DATA_WIDTH*3)]), // {din3_i, din3_q}
        .din4(dout_bus_odd[(DATA_WIDTH*5-1):(DATA_WIDTH*4)]), // {din4_i, din4_q}
        .din5(dout_bus_odd[(DATA_WIDTH*6-1):(DATA_WIDTH*5)]), // {din5_i, din5_q}
        .din6(dout_bus_odd[(DATA_WIDTH*7-1):(DATA_WIDTH*6)]), // {din6_i, din6_q}
        .din7(dout_bus_odd[(DATA_WIDTH*8-1):(DATA_WIDTH*7)]), // {din7_i, din7_q}
        .dout(hout_odd) // {dout_i, dout_q}
    );

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
            if(lutIdc_r[0])
                doutc_r <= doutc_bus[DATA_WIDTH*1-1:DATA_WIDTH*0];
            else if(lutIdc_r[1])
                doutc_r <= doutc_bus[DATA_WIDTH*2-1:DATA_WIDTH*1];
            else if(lutIdc_r[2])
                doutc_r <= doutc_bus[DATA_WIDTH*3-1:DATA_WIDTH*2];
            else if(lutIdc_r[3])
                doutc_r <= doutc_bus[DATA_WIDTH*4-1:DATA_WIDTH*3];
            else if(lutIdc_r[4])
                doutc_r <= doutc_bus[DATA_WIDTH*5-1:DATA_WIDTH*4];
            else if(lutIdc_r[5])
                doutc_r <= doutc_bus[DATA_WIDTH*6-1:DATA_WIDTH*5];
            else if(lutIdc_r[6])
                doutc_r <= doutc_bus[DATA_WIDTH*7-1:DATA_WIDTH*6];
            else if(lutIdc_r[7])
                doutc_r <= doutc_bus[DATA_WIDTH*8-1:DATA_WIDTH*7];
            else
                doutc_r <= 0;

   genvar i_delay;
   generate
      for (i_delay=0; i_delay < I_DELAY_MAX; i_delay=i_delay+1)
      begin: LUT_I_DELAY
            dpd_lut_v2 #(
                .ID_MASK(ID_MASK),
                .ID(i_delay + J_DELAY * J_DELAY_MAX),
                .DATA_WIDTH(DATA_WIDTH),
                .ADDR_WIDTH(ADDR_WIDTH)
            ) inst
            (
                //configration port, read and write
                .clk(clk),
                .rst_n(rst_n),
                .enc(enc & lutIdc[i_delay]),
                .wec(wec),
                .addrc(addrc),
                .dinc(dinc),
                .doutc(doutc_bus[DATA_WIDTH*(i_delay+1)-1:DATA_WIDTH*i_delay]),

                // RAM port-A, only read
                .addra(mag_bus_odd[ADDR_WIDTH*(i_delay+1)-1:ADDR_WIDTH*i_delay]),
                .douta(dout_bus_odd[DATA_WIDTH*(i_delay+1)-1:DATA_WIDTH*i_delay]),

                // RAM port-B, only read
                .addrb(mag_bus_even[ADDR_WIDTH*(i_delay+1)-1:ADDR_WIDTH*i_delay]),
                .doutb(dout_bus_even[DATA_WIDTH*(i_delay+1)-1:DATA_WIDTH*i_delay])
            );
      end
   endgenerate

endmodule
