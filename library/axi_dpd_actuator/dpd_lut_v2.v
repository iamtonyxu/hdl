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

    // RAM port-A
    wire                     wea_w;
    wire    [ADDR_WIDTH-1:0] addra_w;
    wire    [DATA_WIDTH-1:0] dina_w;
    reg     [DATA_WIDTH-1:0] douta_r;

    // RAM port-B
    reg [DATA_WIDTH-1:0] doutb_r;

    // RAM output: port-A and port-C
    assign douta = enc ? 0 : douta_r;
    assign doutc = douta_r;

    // RAM output: port-B
    assign doutb = enc ? 0 : doutb_r;

    generate
        if (ID_MASK[ID]) begin:LUT_ENABLE
            (* rom_style="{distributed | block}" *)
            reg [DATA_WIDTH-1:0] ram[2**ADDR_WIDTH-1:0];

            ///////////////////////
            // only for simulation
            integer i;
            initial begin
                for(i=0; i<2**ADDR_WIDTH; i=i+1) begin
                    ram[i] = 0;
                end
            end
            ///////////////////////

            // RAM input: port-A
            assign wea_w = enc ? wec : 0;
            assign addra_w = enc ? addrc : addra;
            assign dina_w = dinc;
            
            // RAM input on port-A
            always@(posedge clk)
                if(wea_w)
                    ram[addra_w] <= dina_w;

            // RAM output: port-A and port-C
            always@(posedge clk)
                if(~rst_n)
                    douta_r <= 0;
                else
                    douta_r <= ram[addra_w];

            // RAM output: port-B
            always@(posedge clk)
                if(~rst_n)
                    doutb_r <= 0;
                else
                    doutb_r <= ram[addrb];

        end 
        else begin:LUT_DISABLE
            always@(posedge clk) begin
                douta_r <= 0;
                doutb_r <= 0;
            end

        end
    endgenerate
       
endmodule
