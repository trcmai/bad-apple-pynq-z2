`timescale 1ns / 1ps
module frame_rom #(
    parameter D    = 19200, 
    parameter AW   = $clog2(D),
    parameter FRAME = "frame.mem"
)(
    input               clk,
    input  [AW-1:0]     addr,
    output reg pixel
);
    (* rom_style = "block" *) reg [0:0] mem[0 : D-1];

    initial $readmemb(FRAME, mem);

    always @(posedge clk)
        pixel <= mem[addr];
endmodule