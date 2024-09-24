`timescale 1ns / 100ps

module axi_dpd_actuator_v2_tb;

    localparam DCLK_PERIOD = 4; // dpd_actuator clock = 122.88/245.76 MHz
    localparam ACLK_PERIOD = 10; //s_axi_aclk = 100 MHz
    localparam ID_MASK = 64'hC0F070781C0E07;
    //localparam ID_MASK = 64'h01; // Note: To simplify test with 1 lut enabled

    localparam LUT_ADDR_WIDTH = 9;
    localparam LUT_ID_MAX = 64;
    localparam TU_LENGTH = 4047;

    // signal in/out
    reg                           data_clk;
    reg                           data_rstn;
    reg   [31:0]                  data_in_0;
    reg   [31:0]                  data_in_1;
    reg   [31:0]                  data_in_2;
    reg                           data_in_enable_0;
    wire  [31:0]                  data_out_0;
    wire                          data_out_valid_0;
    wire  [31:0]                  data_out_1;
    wire                          data_out_valid_1;

    // axi interface
    reg                           s_axi_aclk;
    reg                           s_axi_aresetn;
    //  axis write
    reg                           s_axi_awvalid;
    reg   [15:0]                  s_axi_awaddr;
    wire   [2:0]                  s_axi_awprot;
    wire                          s_axi_awready;
    reg                           s_axi_wvalid;
    reg   [31:0]                  s_axi_wdata;
    wire  [3:0]                   s_axi_wstrb;
    wire                          s_axi_wready;
    wire                          s_axi_bvalid;
    wire  [1:0]                   s_axi_bresp; // don't care
    reg                           s_axi_bready;
    // axis read
    reg                           s_axi_arvalid;
    reg   [15:0]                  s_axi_araddr;
    wire  [2:0]                   s_axi_arprot;
    wire                          s_axi_arready;
    wire                           s_axi_rvalid;
    wire  [1:0]                   s_axi_rresp; // don't care
    wire  [31:0]                  s_axi_rdata;
    reg                           s_axi_rready;

    // task signal
    reg  [31:0]                   axi_rdata;
    integer                       fileID, i;
    integer                       lut_id;
    reg   [63:0]                  id_mask;
    reg                           config_done;

    reg [31:0] mem_luts[0:(LUT_ID_MAX*(2**LUT_ADDR_WIDTH)-1)];
    reg [31:0] mem_luts_rd[0:(LUT_ID_MAX*(2**LUT_ADDR_WIDTH)-1)];
    reg [31:0] mem_tu[0:TU_LENGTH-1];
    reg [31:0] mem_mag[0:TU_LENGTH-1];
    reg [31:0] mem_tx[0:TU_LENGTH-1];

    // don't care
    assign s_axi_awprot = 0;
    assign s_axi_arprot = 0;
    assign s_axi_wstrb = 0; 

    // axi_write
    task axi_write;
        // user inteface
        input    [15:0]           axi_addr;
        input    [31:0]           axi_wdata;

        // write operation
        begin
            // driving external Global Reg            
            @(posedge s_axi_aclk); // wait rising edge of axi_clk
            s_axi_awaddr = axi_addr;
            s_axi_wdata = axi_wdata;
            s_axi_awvalid = 1;
            s_axi_wvalid = 1;
            s_axi_bready = 1;

            wait((s_axi_awready == 1) & 
                 (s_axi_wready  == 1));
            @(posedge s_axi_aclk); 
            s_axi_awvalid = 0;
            s_axi_wvalid = 0;
            s_axi_awaddr = 0;
            s_axi_wdata = 0;

            wait(s_axi_bvalid  == 1);
            @(posedge s_axi_aclk);
            s_axi_bready = 0;            
            
        end
    endtask

    // axi_read
    task axi_read;
        // user interface
        input   [15:0]          axi_addr;
        output  [31:0]          axi_rdata;

        // read operation
        begin
            s_axi_arvalid = 0;
            @(posedge s_axi_aclk); // wait rising edge of axi_clk
            s_axi_araddr = axi_addr;
            // read addr channel
            s_axi_arvalid = 1;
            wait(s_axi_arready == 1);
            @(posedge s_axi_aclk);
            s_axi_arvalid = 0;

            //read data channel
            s_axi_rready = 1;
            wait(s_axi_rvalid == 1);
            @(posedge s_axi_aclk);
            axi_rdata = s_axi_rdata;
            s_axi_rready = 0;
        end
    endtask

    task write_lut_entry;
        input [63:0] id_mask;
        input [9:0] lut_addr;
        input [31:0] lut_data;
        begin
            //write id_mask
            axi_write(16'h0014, id_mask[31:0]);
            #10;
            axi_write(16'h0018, id_mask[63:32]);
            #10;

            //write lut_entry
            axi_write(16'h8000 + lut_addr, lut_data);
            #10;

        end
    endtask

    task read_lut_entry;
        input [63:0] id_mask;
        input [9:0] lut_addr;
        output [31:0] lut_data;
        begin
            // write id_mask
            axi_write(16'h0014, id_mask[31:0]);
            axi_write(16'h0018, id_mask[63:32]);
            #10;

            // read lut_entry
            axi_read(16'h8000 + lut_addr, lut_data);
            #10;

        end
    endtask

    task write_lut;
        input [6:0] lut_id;
        begin
            id_mask = 2**lut_id;
            // write lut_id
            axi_write(16'h0014, id_mask[31:0]);
            axi_write(16'h0018, id_mask[63:32]);
            #10;

            // write lut entries
            for(i=0; i < 2**LUT_ADDR_WIDTH; i=i+1) begin
                axi_write(16'h8000 + i*4, mem_luts[i + lut_id*(2**LUT_ADDR_WIDTH)]);
            end

        end
    endtask

    task read_lut;
        input [6:0] lut_id;
        begin
            id_mask = 2**lut_id;
            // write lut_id
            axi_write(16'h0014, id_mask[31:0]);
            axi_write(16'h0018, id_mask[63:32]);
            #10;

            // read lut_entries
            for(i=0; i < 2**LUT_ADDR_WIDTH; i=i+1) begin
                axi_read(16'h8000 + i*4, mem_luts_rd[i + lut_id*(2**LUT_ADDR_WIDTH)]);
            end

        end
    endtask


    // data_clk
    initial begin
        data_clk = 1;
        forever #(DCLK_PERIOD/2) data_clk = ~data_clk;
    end

    // s_axi_aclk
    initial begin
        s_axi_aclk = 1;
        forever #(ACLK_PERIOD/2) s_axi_aclk = ~s_axi_aclk;
    end

    axi_dpd_actuator_v2 #(
        .ID_MASK(ID_MASK),
        .LUT_ADDR_WIDTH(LUT_ADDR_WIDTH)
    )
    axi_act(
        .data_clk(data_clk),
        .data_rstn(data_rstn),
        .data_in_0(data_in_0),
        .data_in_1(data_in_1),
        .data_in_2(data_in_2),
        .data_in_enable_0(data_in_enable_0),

        // signal to tx_adrv9009_tpl_core, two samples per channel
        .data_out_0(data_out_0),
        .data_out_valid_0(data_out_valid_0),
        .data_out_1(data_out_1),
        .data_out_valid_1(data_out_valid_1),

        // axis interface
        .s_axi_aclk(s_axi_aclk),
        .s_axi_aresetn(s_axi_aresetn),
        //  axis write
        .s_axi_awvalid(s_axi_awvalid),
        .s_axi_awaddr(s_axi_awaddr),
        .s_axi_awprot(s_axi_awprot),
        .s_axi_awready(s_axi_awready),
        .s_axi_wvalid(s_axi_wvalid),
        .s_axi_wdata(s_axi_wdata),
        .s_axi_wstrb(s_axi_wstrb),
        .s_axi_wready(s_axi_wready),
        .s_axi_bvalid(s_axi_bvalid),
        .s_axi_bresp(s_axi_bresp),
        .s_axi_bready(s_axi_bready),
        // axis read
        .s_axi_arvalid(s_axi_arvalid),
        .s_axi_araddr(s_axi_araddr),
        .s_axi_arprot(s_axi_arprot),
        .s_axi_arready(s_axi_arready),
        .s_axi_rvalid(s_axi_rvalid),
        .s_axi_rresp(s_axi_rresp),
        .s_axi_rdata(s_axi_rdata),
        .s_axi_rready(s_axi_rready)
    );

    // rst_n
    initial begin
        data_rstn = 0;
        s_axi_aresetn = 0;
        #100
        data_rstn = 1;
        s_axi_aresetn = 1;
    end

    // dpd actuator settings
    initial begin
        wait(s_axi_aresetn == 1);
        s_axi_arvalid = 0;
        s_axi_araddr = 0;
        s_axi_rready = 0;
        config_done = 0;
        #100;

        // write internal registers
        // scratch reg
        axi_write(16'h000C, 32'h1111_1111);
        #100;
        // dpd_out_sel
        axi_write(16'h0010, 32'hFFFF_FFFF);
        #100;
        // dpd_LutIdc_l
        axi_write(16'h0014, 32'h0000_0001);
        #100;
        // dpd_LutIdc_h
        axi_write(16'h0018, 32'h0000_0000);
        #100;

        // read internal registers
        // ip version
        axi_read(16'h0000, axi_rdata);
        //#10;
        // ip_mask_l
        axi_read(16'h0004, axi_rdata);
        //#10;
        // ip_mask_h
        axi_read(16'h0008, axi_rdata);
        //#10;
        // scratch reg
        axi_read(16'h000C, axi_rdata);
        //#10;
        // dpd_out_sel
        axi_read(16'h0010, axi_rdata);
        //#10;
        // dpd_lutIdc_l
        axi_read(16'h0014, axi_rdata);
        //#10;
        // dpd_LutIdc_h
        axi_read(16'h0018, axi_rdata);
        //#100;

        // read files about dpd actuator luts
        $readmemh("../src/dpd_luts.txt", mem_luts);

        for(lut_id = 0; lut_id < LUT_ID_MAX; lut_id = lut_id + 1) begin
            if (ID_MASK[lut_id] == 1'b1) begin
                write_lut(lut_id);
                read_lut(lut_id);
                #10;
            end
        end

/*
        for(lut_id = 0; lut_id < 6; lut_id = lut_id + 1) begin
            id_mask = 2**lut_id;
            // write luts
            for(i=0; i < 2**LUT_ADDR_WIDTH; i=i+1) begin
                write_lut_entry(id_mask, i*4, mem_luts[i + lut_id*(2**LUT_ADDR_WIDTH)]);
            end
            #100;

            // read luts
            for(i=0; i < 2**LUT_ADDR_WIDTH; i=i+1) begin
                read_lut_entry(id_mask, i*4, axi_rdata);
            end
        end
*/
        #100;
        config_done = 1;

    end

    // signal in/out
    initial begin
        data_in_0 = 0;
        data_in_1 = 0;
        data_in_2 = 0;
        data_in_enable_0 = 0;

        wait(config_done == 1);
        @(posedge data_clk);

        // read tu waveform and magnitude file
        $readmemh("../src/tu.txt", mem_tu);
        $readmemh("../src/tuMag.txt", mem_mag);

        for(i = 0; i < TU_LENGTH/2; i = i+1) begin
            data_in_0 = {mem_tu[2*i+1][31:16], mem_tu[2*i][31:16]}; // tu_i
            data_in_1 = {mem_tu[2*i+1][15:0], mem_tu[2*i][15:0]}; // tu_q
            data_in_2 = (mem_mag[2*i+1] * 2**16) + mem_mag[2*i]; // tu_mag

            data_in_enable_0 = 1;
            @(posedge data_clk);
        end

        data_in_0 = 0;
        data_in_1 = 0;
        data_in_2 = 0;
        data_in_enable_0 = 0;

        #100
        //save mem_tx into file
        fileID = $fopen("../src/tx_read_2phase.txt", "w");
        for (i = 0; i < TU_LENGTH-1; i = i+1) begin
            $fwrite(fileID,"%x\n", mem_tx[i]);
        end
        $fclose(fileID);
    end

    //mem_tx
    reg [15:0]tx_index;
    always@(posedge data_clk or negedge data_rstn)
        if(~data_rstn) begin
            tx_index <= 0;
        end
        else begin
            if(data_out_valid_0 == 1) begin
                mem_tx[2*tx_index] <= {data_out_1[15:0], data_out_0[15:0]};
                mem_tx[2*tx_index+1] <= {data_out_1[31:16], data_out_0[31:16]};
                tx_index <= tx_index + 1;
            end
            else begin
                tx_index <= 0;
            end
        end

endmodule