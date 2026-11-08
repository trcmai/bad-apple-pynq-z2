`timescale 1ns / 1ps
/*
Simple AXI read subordinate model (SIMULATION ONLY, not synthesizable)
- accepts an address at random moments (random ARREADY)
- returns ARLEN+1 transfers with random gaps in RVALID
- holds RVALID/RDATA/RLAST stable while RREADY is low (rule 3)
- memory content: word i = 32'hA000_0000 + i (easy to recognise)
------------------------------------------------------------------
*/
module axi_rd_slave_model
(
    input wire i_clk,i_rst_n,

    // AR channel
    input  wire [31:0] i_araddr,
    input  wire [3:0]  i_arlen,
    input  wire        i_arvalid,
    output reg         o_arready,

    // R channel
    output wire [31:0] o_rdata,
    output wire [1:0]  o_rresp,
    output wire        o_rlast,
    output wire        o_rvalid,
    input  wire        i_rready
);

reg [31:0] mem [0:8191];          // fake DDR: 32 KB
integer i;
initial
    for(i = 0; i < 8192; i = i + 1)
        mem[i] = 32'hA000_0000 + i;

reg        busy, stall;
reg [31:0] base;
reg [3:0]  len, beat;

wire ar_hs = i_arvalid && o_arready;
wire r_hs  = o_rvalid  && i_rready;

// payload only changes when 'beat' changes -> stable while stalled
assign o_rvalid = busy && !stall;
assign o_rdata  = mem[(base >> 2) + beat];
assign o_rlast  = (beat == len);
assign o_rresp  = 2'b00;          // always OKAY

always @(posedge i_clk)
    begin
        if(!i_rst_n)
            begin
                busy      <= 1'b0;
                stall     <= 1'b0;
                o_arready <= 1'b0;
            end
        else
            begin
                // random gaps, but never drop RVALID while it waits for RREADY
                if(o_rvalid && !i_rready) stall <= 1'b0;
                else                      stall <= (($random & 3) == 0);   // ~25% gaps

                if(!busy)
                    begin
                        if(ar_hs)
                            begin
                                busy      <= 1'b1;
                                base      <= i_araddr;
                                len       <= i_arlen;
                                beat      <= 4'd0;
                                o_arready <= 1'b0;
                            end
                        else
                            o_arready <= $random;   // random acceptance
                    end
                else if(r_hs)
                    begin
                        if(o_rlast) busy <= 1'b0;
                        else        beat <= beat + 1;
                    end
            end
    end

endmodule