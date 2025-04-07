`timescale 1ns / 1ps
/*
*   write_Lut:
*   enc = 1, wec = 1, addrc = lut_addr, dinc = lut_din
*   latency = 1 clk period
*
*   read_lut:
*   enc = 1, wec = 0, addrc = lut_addr
*   latency = 1 clk period
*
*/

module dpd_lut_v2 #(
    parameter ID_MASK = 64'hFFFF_FFFF_FFFF_FFFF,
    parameter ID = 0,
    parameter DATA_WIDTH = 32,
    parameter ADDR_WIDTH = 10
)
(
    // Configration port
    // with the same clk as port-A and port-B
    input                       clk,
    input                       rst_n,
    input   [1:0]               lut_sel,

    input                       enc,
    input                       wec,
    input   [ADDR_WIDTH-1:0]    addrc,
    input   [DATA_WIDTH-1:0]    dinc,
    output  [DATA_WIDTH-1:0]    doutc,

    // RAM port-A, only read
    input   [ADDR_WIDTH-1:0]    addra,
    output  [DATA_WIDTH-1:0]    douta,

    // RAM port-B, only read
    input   [ADDR_WIDTH-1:0]    addrb,
    output  [DATA_WIDTH-1:0]    doutb
);

    // lut select: lut to program and or active lut in use
    reg [1:0]               lut_sel_r;
    wire                    lutp;
    wire                    luta;

    always@(posedge clk)
        if(~rst_n)
            lut_sel_r <= 2'b00;
        else
            lut_sel_r <= lut_sel;

    assign  lutp = lut_sel_r[1];
    assign  luta = lut_sel_r[0];

    // RAM port-A
    wire                     wea_w;
    wire    [ADDR_WIDTH-1:0] addra_w;
    wire    [DATA_WIDTH-1:0] dina_w;
    reg     [DATA_WIDTH-1:0] douta_r0, douta_r1;

    // RAM port-B
    reg [DATA_WIDTH-1:0] doutb_r0, doutb_r1;

    // RAM output: port-A and port-C
    assign douta = luta ? douta_r1 : douta_r0;
    assign doutc = luta ? douta_r1 : douta_r0;

    // RAM output: port-B
    assign doutb = luta ? doutb_r1 : doutb_r0;

    // RAM input: port-A
    assign wea_w = enc ? wec : 0;
    assign addra_w = enc ? addrc : addra;
    assign dina_w = dinc;

    generate
        if (ID_MASK[ID]) begin:LUT_ENABLE0
            (* ram_style="block" *)
            reg [DATA_WIDTH-1:0] ram0[2**ADDR_WIDTH-1:0];

            ///////////////////////
            // only for simulation
            integer i;
            initial begin
                for(i=0; i<2**ADDR_WIDTH; i=i+1) begin
                    ram0[i] = 0;
                end
            end
            ///////////////////////
            
            // RAM input on port-A
            always@(posedge clk)
                if(~lutp & wea_w)
                        ram0[addra_w] <= dina_w;

            // RAM output: port-A and port-C
            always@(posedge clk)
                if(~rst_n)
                    douta_r0 <= 0;
                else
                    douta_r0 <= ram0[addra_w];

            // RAM output: port-B
            always@(posedge clk)
                if(~rst_n)
                    doutb_r0 <= 0;
                else
                    doutb_r0 <= ram0[addrb];

        end
        else begin:LUT_DISABLE0
            always@(posedge clk) begin
                douta_r0 <= 0;
                doutb_r0 <= 0;
            end

        end
    endgenerate


    generate
        if (ID_MASK[ID]) begin:LUT_ENABLE1
            (* ram_style="block" *)
            reg [DATA_WIDTH-1:0] ram1[2**ADDR_WIDTH-1:0];

            ///////////////////////
            // only for simulation
            integer i;
            initial begin
                for(i=0; i<2**ADDR_WIDTH; i=i+1) begin
                    ram1[i] = 0;
                end
            end
            ///////////////////////
            
            // RAM input on port-A
            always@(posedge clk)
                if(lutp & wea_w)
                        ram1[addra_w] <= dina_w;

            // RAM output: port-A and port-C
            always@(posedge clk)
                if(~rst_n)
                    douta_r1 <= 0;
                else
                    douta_r1 <= ram1[addra_w];

            // RAM output: port-B
            always@(posedge clk)
                if(~rst_n)
                    doutb_r1 <= 0;
                else
                    doutb_r1 <= ram1[addrb];

        end
        else begin:LUT_DISABLE1
            always@(posedge clk) begin
                douta_r1 <= 0;
                doutb_r1 <= 0;
            end

        end
    endgenerate

endmodule
