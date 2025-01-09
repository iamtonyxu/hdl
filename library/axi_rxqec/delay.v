`timescale 1ns / 1ps

module delay #(
    parameter TAPS = 2,
    parameter DWIDTH = 16
)
(
    input clk,
    input [DWIDTH-1:0] din,
    output [DWIDTH-1:0] dout
);

    reg [DWIDTH*TAPS-1:0] din_d;

    // dout
    generate
        if(TAPS == 0) begin:TAPS0
            assign dout = din;
        end
        else begin: TAPSN
            assign dout = din_d[(DWIDTH*TAPS-1):(DWIDTH*(TAPS-1))];
        end
    endgenerate

    
    genvar i;
    generate
        for(i = 0; i < TAPS; i=i+1) begin:dd
            if(i==0) begin
                always@(posedge clk)
                    din_d[DWIDTH-1:0] <= din;
            end
            else begin
                always@(posedge clk) begin
                    din_d[DWIDTH*(i+1)-1:DWIDTH*i] <=  din_d[DWIDTH*i-1:DWIDTH*(i-1)];
                end
            end
        end
    endgenerate


endmodule