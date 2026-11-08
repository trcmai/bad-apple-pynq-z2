`timescale 1ns / 1ps

module frame_fetcher_tb;

localparam N_BURSTS  = 338;                // 480x360 frame (5,408 words)
localparam BRAM_AW   = 13;
localparam BURST_LEN = 16;
localparam N_WORDS   = N_BURSTS * BURST_LEN;

reg clk = 0, rstn = 0, start = 0;
always #5 clk = ~clk;                      // 100 MHz

wire        done, err;
wire [31:0] araddr, rdata;
wire [3:0]  arlen;
wire [2:0]  arsize;
wire [1:0]  arburst, rresp;
wire        arvalid, arready, rvalid, rready, rlast;
wire        bram_we;
wire [BRAM_AW-1:0] bram_addr;
wire [31:0] bram_din;

// DUT 
frame_fetcher #(.N_BURSTS(N_BURSTS), .BURST_LEN(BURST_LEN), .BRAM_AW(BRAM_AW)) dut(
    .m_axi_aclk(clk), .m_axi_aresetn(rstn), .i_start(start), .i_base_addr(32'd0),
    .o_done(done), .o_err(err),
    .m_axi_araddr(araddr), .m_axi_arlen(arlen), .m_axi_arsize(arsize),
    .m_axi_arburst(arburst), .m_axi_arvalid(arvalid), .m_axi_arready(arready),
    .m_axi_rdata(rdata), .m_axi_rresp(rresp), .m_axi_rlast(rlast),
    .m_axi_rvalid(rvalid), .m_axi_rready(rready),
    .o_bram_wenb(bram_we), .o_bram_addr(bram_addr), .o_bram_din(bram_din)
);

// fake DDR (subordinate) 
axi_rd_slave_model slave(
    .i_clk(clk), .i_rst_n(rstn),
    .i_araddr(araddr), .i_arlen(arlen), .i_arvalid(arvalid), .o_arready(arready),
    .o_rdata(rdata), .o_rresp(rresp), .o_rlast(rlast),
    .o_rvalid(rvalid), .i_rready(rready)
);

// fake BRAM
reg [31:0] bram [0:(1<<BRAM_AW)-1];
always @(posedge clk)
    if(bram_we) bram[bram_addr] <= bram_din;

// AXI rule checks on the AR channel 
reg        was_stalled = 0;
reg [31:0] prev_addr;
integer    n_ar = 0;
always @(posedge clk)
    begin
        // rule 3: ARVALID must stay HIGH and ARADDR stable until ARREADY
        if(was_stalled && (!arvalid || araddr != prev_addr))
            $display("%t ERROR: ARVALID dropped or ARADDR changed while stalled", $time);

        // 4 KB rule: first and last byte of the burst in the same 4 KB page
        if(arvalid && arready)
            begin
                n_ar = n_ar + 1;
                if(araddr[31:12] != ((araddr + 32'd63) >> 12))
                    $display("%t ERROR: burst at %h crosses 4 KB", $time, araddr);
            end

        was_stalled <= arvalid && !arready;
        prev_addr   <= araddr;
    end

// stimulus + result check 
integer i, errors;
initial
    begin
        #20 rstn = 1;
        #20 @(posedge clk) start <= 1;
            @(posedge clk) start <= 0;      // 1-cycle pulse

        wait(done);
        #20;

        errors = 0;
        for(i = 0; i < N_WORDS; i = i + 1)
            if(bram[i] !== 32'hA000_0000 + i)
                begin
                    $display("ERROR: bram[%0d] = %h (expected %h)", i, bram[i], 32'hA000_0000 + i);
                    errors = errors + 1;
                end

        if(n_ar != N_BURSTS) $display("ERROR: %0d AR handshakes, expected %0d", n_ar, N_BURSTS);
        if(err)              $display("ERROR: o_err set");
        if(errors == 0)      $display("PASS: %0d words correct", N_WORDS);
        $finish;
    end

// ---------------- timeout: stops the sim if done never comes ----------------
initial
    begin
        #5000000;
        $display("TIMEOUT: o_done never went HIGH");
        $finish;
    end

endmodule