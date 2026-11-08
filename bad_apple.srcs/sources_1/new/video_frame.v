`timescale 1ns / 1ps

module video_frame
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
    input i_clk,i_rst,
    input wire[W_N - 1 : 0] i_h_cnter,
    input wire[H_N - 1 : 0] i_v_cnter,
    input i_hs,i_vs, 
    input wire[31:0] i_bram_data, 

    output wire[7:0] o_red,o_green,o_blue, 
    output wire[9:0] o_bram_addr,
    output reg o_active 
);
// Image scaled down to 160x140 (4 times)
localparam SCALE = 2; 
localparam IMG_W = W >> SCALE;
localparam IMG_H = H >> SCALE;
localparam IMG_D = IMG_W * IMG_H;


wire active_d;
assign active_d = (i_h_cnter < W) && (i_v_cnter < H); 

//Loading data from .mem -> bram 
wire[W_N-1:0] x  = i_h_cnter >> 2; 
wire[H_N-1:0] y = i_v_cnter >> 2; 
wire[14:0] addr = x + y*IMG_W; 

/* 
Pixel addr -> (Word, Bit) for AXI to BRAM pipeline 
Each word is 4 bytes = 32 bits because of ARM stream 
=> Word = addr / 32 = addr >> 5 (divided into blocks)
=> Bit = addr % 32 = addr[4:0]

Because each word take 4 bytes, the address for each word will be 
byte_addr = word * 4 = word << 2 
*/
wire[9:0] word = addr >> 5; 
wire[4:0] pos = addr[4:0];
wire pixel;

reg[4:0] pos_d;

//Delay 
always @(posedge i_clk)
    begin
        if(i_rst)
            begin
                o_active <= 0; 
                pos_d <= 0;
            end
        else
            begin 
                o_active <= active_d; 
                pos_d <= pos;
            end
    end
assign o_bram_addr = word;
assign pixel = i_bram_data[pos_d];

//Assign color
assign o_red = o_active ? {8{pixel}} : 8'd0;
assign o_blue = o_active ? {8{pixel}} : 8'd0;
assign o_green = o_active ? {8{pixel}} : 8'd0;

endmodule
