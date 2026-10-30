`timescale 1ns/1ps
module tb_frame_rom
#(
    parameter D = 8, 
    parameter AW = $clog2(D),
    parameter FRAME = "test.mem"
);
    reg        clk  = 0;
    reg  [AW - 1:0] addr = 0;
    wire data;

    always #5 clk = ~clk;          // 100 MHz, 10 ns period

    frame_rom #(.D(D), .AW(AW), .FRAME(FRAME)) frame_rom_tb_inst (
        .clk(clk), .addr(addr), .data(data)
    );

    initial 
    begin 
        repeat(8)
            begin @(posedge clk)
                addr <= addr + 1;
            end 
        #50;
        $finish;
    end
endmodule