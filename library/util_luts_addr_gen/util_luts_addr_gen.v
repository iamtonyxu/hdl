`timescale 1ns / 100ps
/*
* this module is to calcuate magnitude of tu
* signal from tx_fir_interpolator, two samples per channel
* data_in_0 = {tu_i[2n+1],tu_i[2n]}
* data_in_1 = {tu_q[2n+1],tu_q[2n]}
* data_out_0 = data_in_0 aligned with data_out_2
* data_out_1 = data_in_1 aligned with data_out_2
* data_out_2 = {mag[2n+1], mag[2n]}
*/

module util_luts_addr_gen(
    input                           data_clk,
    input                           data_rstn,
    input   [31:0]                  data_in_0,
    input   [31:0]                  data_in_1,
    input                           data_in_enable,
    output  [31:0]                  data_out_0,
    output  [31:0]                  data_out_1,
    output  [31:0]                  data_out_2,
    output                          data_out_valid
);

localparam CPOWER_DELAY = 5;
localparam CORDIC_DELAY = 11;
localparam MAG_DELAY = 1 + CPOWER_DELAY + CORDIC_DELAY;
/*
set cordic_sqrt [create_ip -name cordic -vendor xilinx.com -library ip -version 6.0 -module_name cordic_sqrt]
set_property -dict [list \
  CONFIG.Coarse_Rotation {false} \
  CONFIG.Component_Name {cordic_sqrt} \
  CONFIG.Data_Format {UnsignedFraction} \
  CONFIG.Functional_Selection {Square_Root} \
  CONFIG.Input_Width {33} \
  CONFIG.Output_Width {11} \
] [get_ips cordic_sqrt]
*/

reg signed [15:0] signal_odd_i, signal_odd_q;
reg signed [15:0] signal_even_i, signal_even_q;
wire signed [32:0] signal_odd_p, signal_even_p;

// Note: need to regenereate cordic IP to adjust data width
wire [32:0] s_axis_tdata1, s_axis_tdata2;
wire [15:0] m_axis_tdata1, m_axis_tdata2;

//signal_i, signal_q
always@(posedge data_clk or negedge data_rstn)
    if(~data_rstn) begin
        signal_odd_i <= 0;
        signal_odd_q <= 0;
        signal_even_i <= 0;
        signal_even_q <= 0;
    end
    else begin
        if(data_in_enable) begin
            signal_odd_i <= data_in_0[31:16];
            signal_odd_q <= data_in_1[31:16];
            signal_even_i <= data_in_0[15:0];
            signal_even_q <= data_in_1[15:0];
        end
        else begin
            signal_odd_i <= 0;
            signal_odd_q <= 0;
            signal_even_i <= 0;
            signal_even_q <= 0;
        end
    end

// delay of cpower_fixed = 5
cpower_fixed #(
    .DATA_IN_WIDTH(16)
)
power1(
    .clk(data_clk),
    .rst_n(data_rstn),
    .signal_i(signal_odd_i),
    .signal_q(signal_odd_q),
    .signal_p(signal_odd_p)
);

cpower_fixed #(
    .DATA_IN_WIDTH(16)
)
power2(
    .clk(data_clk),
    .rst_n(data_rstn),
    .signal_i(signal_even_i),
    .signal_q(signal_even_q),
    .signal_p(signal_even_p)
);

//localparam START = 0;
assign s_axis_tdata1 = signal_odd_p;
assign s_axis_tdata2 = signal_even_p;

assign data_out_2 = {m_axis_tdata1, m_axis_tdata2};

// delay of cordic_sqrt = 11? depends on input/output width
cordic_sqrt sqrt1
(
    .aclk(data_clk),
    .s_axis_cartesian_tvalid(1'b1),
    .s_axis_cartesian_tdata(s_axis_tdata1),
    .m_axis_dout_tvalid(),
    .m_axis_dout_tdata(m_axis_tdata1)
);

cordic_sqrt sqrt2
(
    .aclk(data_clk),
    .s_axis_cartesian_tvalid(1'b1),
    .s_axis_cartesian_tdata(s_axis_tdata2),
    .m_axis_dout_tvalid(),
    .m_axis_dout_tdata(m_axis_tdata2)
);

delay #(
    .TAPS(MAG_DELAY),
    .DWIDTH(32)
)data_0_delay
(
    .clk(data_clk),
    .din(data_in_0),
    .dout(data_out_0)
);

delay #(
    .TAPS(MAG_DELAY),
    .DWIDTH(32)
)data_1_delay
(
    .clk(data_clk),
    .din(data_in_1),
    .dout(data_out_1)
);

delay #(
    .TAPS(MAG_DELAY),
    .DWIDTH(1)
)data_valid_delay
(
    .clk(data_clk),
    .din(data_in_enable),
    .dout(data_out_valid)
);

endmodule