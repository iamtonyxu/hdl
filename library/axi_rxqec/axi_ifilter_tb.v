`timescale 1ns/100ps

module axi_ifilter_tb;
    localparam CLK_PERIOD = 10;
    localparam DATA_LENGTH = 512;
    localparam IFIR_TAPS = 7;

    reg clk;
    reg rst_n;
    integer fileID, ii;
    reg done;

    reg signed [15:0]h0;
    reg signed [15:0]h1;
    reg signed [15:0]h2;
    reg signed [15:0]h3;
    reg signed [15:0]x0;
    reg signed [15:0]x1;
    wire [31:0]din;
    wire [31:0]dout;

    reg [31:0] mem_din[0:DATA_LENGTH-1];
    reg [31:0] mem_dout[0:DATA_LENGTH-1];
    reg [15:0] mem_hi[0:IFIR_TAPS-1];

    assign din = {x1, x0};

    // clk
    initial begin
        clk = 1;
        forever #(CLK_PERIOD/2) clk = ~clk;
    end

    //rst_n
    initial begin
        rst_n = 0;
        $readmemh("x.txt", mem_din);
        $readmemh("hi.txt", mem_hi);

        #100;
        rst_n = 1;
    end

    // h0,h1,h2,h3
    initial begin
        h0 = 0;
        h1 = 0;
        h2 = 0;
        h3 = 0;
        wait (rst_n == 1);
        
        h0 = mem_hi[3];
        h1 = mem_hi[2];
        h2 = mem_hi[1];
        h3 = mem_hi[0];

    end

    //x0, x1
    initial begin
        x0 = 0;
        x1 = 0;
        done = 0;
        wait (rst_n == 1);
        for(ii = 0; ii < DATA_LENGTH; ii = ii + 1) begin
            x0 = mem_din[ii][15:0];
            x1 = mem_din[ii][31:16];
            //x0 = ii*2+1;
            //x1 = ii*2+2;
            @(posedge clk);
        end
        done = 1;
    end

    // save mem_dout into file
    initial begin
        wait (done == 1);
        fileID = $fopen("sim_dout_i.txt", "w");
        for(ii = 0; ii < DATA_LENGTH; ii = ii+1) begin
            $fwrite(fileID, "%x\n", mem_dout[ii]);
        end
        $fclose(fileID);
    end

    axi_ifilter u1
    (
        .clk(clk),
        .rst_n(rst_n),
        .h0(h0),
        .h1(h1),
        .h2(h2),
        .h3(h3),
        .din(din),
        .dout(dout)
    );

    reg [9:0]dout_index;
    wire dout_valid;
    reg [9:0]latency_cnt;

    always@(posedge clk or negedge rst_n)
        if(~rst_n)
            latency_cnt <= 0;
        else if(latency_cnt < 14)
            latency_cnt <= latency_cnt + 1;

    assign dout_valid = (latency_cnt == 14) ? 1 : 0;

    always@(posedge clk or negedge rst_n)
        if(~rst_n) begin
            dout_index <= 0;
        end
        else begin
            if(dout_valid & ~done) begin
                mem_dout[dout_index] <= dout;
                if(dout_index < DATA_LENGTH) begin
                    dout_index <= dout_index + 1;
                end
                else begin
                    dout_index <= 0;
                end
            end
            else begin
                dout_index <= 0;
            end
        end

endmodule
