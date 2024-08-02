`timescale 1ns / 1ps

module dpd_lut #(
    parameter ID_MASK = 64'hff,
    parameter ID = 0,
    parameter DATA_WIDTH = 32,
    parameter ADDR_WIDTH = 10
)
(
    input clk,
    input rst_n,

    // RAM port-A, only read 
    input [ADDR_WIDTH-1:0] lut_addr,
    output [DATA_WIDTH-1:0] lut_out,

    // RAM port-B, read and write
    input config_clk,
    input [ADDR_WIDTH-1:0] config_addr,
    input [DATA_WIDTH-1:0] config_din,
    output [DATA_WIDTH-1:0] config_dout,
    input config_web
);

    // RAM port-A
    reg [DATA_WIDTH-1:0] dout_a;

    // RAM port-B
    reg [DATA_WIDTH-1:0] dout_b;
    wire write_enb; 

    // lut output on port-A and port-B
    assign lut_out = dout_a;
    assign config_dout = dout_b;

    generate
        if (ID_MASK[ID]) begin:LUT_ENABLE
            (* rom_style="{distributed | block}" *)
            reg [DATA_WIDTH-1:0] ram[2**ADDR_WIDTH-1:0];
    
            // LUT output: port-A
            always@(posedge clk or negedge rst_n)
            if(~rst_n) begin
                dout_a <= 0;
            end
            else begin
                dout_a <= ram[lut_addr];
            end

            // LUT output: port-B
            always@(posedge config_clk or negedge rst_n)
            if(~rst_n) begin
                dout_b <= 0;
            end
            else begin
                dout_b <= ram[config_addr];
            end

            // configuration on port-B
            always@(posedge config_clk)
                if(config_web) begin
                    ram[config_addr] <= config_din;
                end
        end 
        else begin:LUT_DISABLE
            always@(posedge clk)
            begin
                dout_a <= 0;
            end

            always@(posedge config_clk)
            begin
                //dout_b <= ((lut_addr == 0) & (config_addr == 0) & (config_web)) ? config_din : 0;
                dout_b <= 0;
            end
        end
    endgenerate
       
endmodule
