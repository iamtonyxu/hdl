`timescale 1ns / 1ps
//latency = 1+5+10=16
module cmag_fixed#(
    parameter LUT_DATA_WIDTH = 32,
    parameter LUT_ADDR_WIDTH = 10
)
(
    input                               clk,
    input                               rst_n,
    input   signed [LUT_DATA_WIDTH-1:0] tu,
    output  signed [LUT_ADDR_WIDTH-1:0] mag    
);

reg signed [LUT_DATA_WIDTH/2-1:0] signal_i;
reg signed [LUT_DATA_WIDTH/2-1:0] signal_q;
wire signed [LUT_DATA_WIDTH:0] signal_p;  

// Note: need to regenereate cordic IP to adjust data width
wire [27:0] s_axis_tdata;
wire [9:0] m_axis_tdata;

//signal_i, signal_q
always @(posedge clk or negedge rst_n)
    if(~rst_n) begin
        signal_i <= 0;
        signal_q <= 0;
    end
    else begin
        signal_i <= tu[LUT_DATA_WIDTH-1:LUT_DATA_WIDTH/2];
        signal_q <= tu[LUT_DATA_WIDTH/2-1:0];
    end

cpower_fixed #(
    .DATA_IN_WIDTH(LUT_DATA_WIDTH/2)
)
u1(
    .clk(clk),
    .rst_n(rst_n),
    .signal_i(signal_i),
    .signal_q(signal_q),
    .signal_p(signal_p)
);

localparam START = 0;
assign s_axis_tdata = signal_p[LUT_DATA_WIDTH-START-1:LUT_DATA_WIDTH-28-1];

//mag
assign mag = s_axis_tdata[9:0];

/*
//mag
assign mag = m_axis_tdata;

cordic_sqrt_root u2
(
    .aclk(clk),
    .s_axis_cartesian_tvalid(1'b1),
    .s_axis_cartesian_tdata(s_axis_tdata),
    .m_axis_dout_tvalid(),
    .m_axis_dout_tdata(m_axis_tdata)
);
*/

endmodule
