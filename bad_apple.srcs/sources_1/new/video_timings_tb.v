`timescale 1ns / 1ps
module video_timings_tb;

localparam W = 10, W_FP = 2, W_SYNC = 3,W_BP = 5; 
localparam H = 8, H_FP = 1, H_SYNC = 2, H_BP = 4; 

localparam W_TOT = W + W_FP + W_SYNC + W_BP;
localparam H_TOT = H + H_FP + H_SYNC + H_BP; 

localparam TRIES = 4 * W_TOT * H_TOT; 

reg i_clk = 0;
reg i_rst = 1; 
wire [$clog2(W_TOT) - 1 : 0] o_h_cnter; 
wire [$clog2(H_TOT) - 1 : 0] o_v_cnter; 
wire o_hs,o_vs; 

video_timings 
#(
    .W(W),.W_FP(W_FP),.W_SYNC(W_SYNC),.W_BP(W_BP),
    .H(H),.H_FP(H_FP),.H_SYNC(H_SYNC),.H_BP(H_BP)
)
video_timings_tb_inst(
    .i_clk(i_clk),.i_rst(i_rst),
    .o_h_cnter(o_h_cnter),.o_v_cnter(o_v_cnter),
    .o_hs(o_hs),.o_vs(o_vs)
);

always #20 i_clk = ~i_clk; 

initial begin 
    repeat(2) @ (posedge i_clk); 
    @(negedge i_clk) i_rst = 0; 
    repeat(TRIES) @ (posedge i_clk);
    $finish;
end


endmodule