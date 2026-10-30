`timescale 1ns / 1ps
module video_timings
#(
    parameter W = 640, 
    parameter W_FP = 16, 
    parameter W_SYNC = 96, 
    parameter W_BP = 48,
    parameter W_TOT = W + W_FP + W_SYNC + W_BP, //=800
    parameter W_N = $clog2(W_TOT),

    parameter H = 480,
    parameter H_FP = 10, 
    parameter H_SYNC = 2, 
    parameter H_BP = 33, 
    parameter H_TOT = H + H_FP + H_SYNC + H_BP, //=525
    parameter H_N = $clog2(H_TOT)
)
(
    input wire i_clk,i_rst,
    output wire [W_N-1:0] o_h_cnter, 
    output wire [H_N-1:0] o_v_cnter,
    output wire o_hs,o_vs 
);

reg [W_N-1:0] w_cnter; 
reg [H_N-1:0] h_cnter; 
wire [W_N-1:0] nxt_w_cnter; 
wire [H_N-1:0] nxt_h_cnter; 

wire h_enable;

//Horizontal 
always @(posedge i_clk)
    begin
        if(i_rst)
            w_cnter <= 0; 
        else if (w_cnter == W_TOT - 1) 
            w_cnter <= 0; 
        else 
            w_cnter <= nxt_w_cnter;
    end
assign nxt_w_cnter = w_cnter + 1;
assign h_enable = (w_cnter == W_TOT - 1);

//Vertical 
always @(posedge i_clk)
    begin
        if(i_rst)
            h_cnter <= 0; 
        else if(h_enable)
            begin
                if(h_cnter == H_TOT - 1)
                    h_cnter <= 0;
                else
                    h_cnter <= nxt_h_cnter;
            end
    end
assign nxt_h_cnter = h_cnter + 1; 

//Output
assign o_h_cnter = w_cnter; 
assign o_v_cnter = h_cnter; 
assign o_hs = !(W + W_FP <= w_cnter && w_cnter < W + W_FP + W_SYNC); 
assign o_vs = !(H + H_FP <= h_cnter && h_cnter < H + H_FP + H_SYNC); 

endmodule