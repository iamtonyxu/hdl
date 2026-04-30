`timescale 1ns / 1ps



module rx_data_capture
       (
           input clk,
           input rstn,
           input wire [31:0] rx_cap_config,

           input wire [127: 0] rx_tdata_0,
           input wire [3:0] rx_start_of_multiframe_0,

           output reg [31: 0] bram_addr_0,
           output wire bram_clk,
           output reg [127: 0] bram_din_0,
           output reg bram_en_0,
           output reg [15: 0] bram_we_0
       );

wire trigger;
reg [1: 0] trigger_dly;
// reg [16: 0] write_depth;

assign trigger = rx_cap_config[0];
// assign write_depth = rx_cap_config[31:16];

assign bram_clk = clk;

wire  trigger_posedge = (trigger_dly == 2'b01) ? (1'b1) : (1'b0);

always @(posedge clk or negedge rstn) begin
    if (!rstn) begin
        trigger_dly <= 2'b0;
    end
    else begin
        trigger_dly[0] <= trigger;
        trigger_dly[1] <= trigger_dly[0];
    end
end

reg r_tri;
reg r_tri_cap_rx0;


always @(posedge clk or negedge rstn) begin
    if (!rstn) begin
        r_tri <= 1'b0;
    end
    else begin
        if (trigger_posedge) begin
            r_tri <= 1'b1;
        end
        else begin
            if (r_tri_cap_rx0 == 1'b1) begin
                r_tri <= 1'b0;
            end
        end
    end

end

always @(posedge clk or negedge rstn) begin
    if (!rstn) begin
        r_tri_cap_rx0 = 1'b0;
    end
    else begin
        if (r_tri&&(rx_start_of_multiframe_0 != 0)) begin
            r_tri_cap_rx0 <= 1'b1;
        end
        else begin
            if (bram_addr_0 == 32'h40000) begin
                r_tri_cap_rx0 <= 1'b0;
            end
        end
    end
end


always @(posedge clk or negedge rstn) begin
    if (!rstn) begin
        bram_en_0 <= 1'b0;
        bram_we_0 <= 16'b0;
        bram_addr_0 <= 32'hfffffff0;
    end
    else begin
        if (r_tri_cap_rx0) begin
            bram_addr_0 <= bram_addr_0 + 32'd16;
            bram_en_0 <= 1'b1;
            bram_we_0 <= 16'hffff;
        end
        else begin
            bram_en_0 <= 1'b0;
            bram_we_0 <= 16'b0;
            bram_addr_0 <= 32'hfffffff0;
        end
    end
end


always @(posedge clk or negedge rstn) begin
    if(!rstn) begin
        bram_din_0 <= 127'b0;
    end
    else begin
        bram_din_0 <= rx_tdata_0;
    end
end

endmodule
