`timescale 1ns / 1ps
module video_frame_tb;
    localparam W = 640, H = 480;
    localparam W_N = 10, H_N = 10;

    reg i_clk = 0;
    reg i_rst = 1;
    always #20 i_clk = ~i_clk;              // 25 MHz pixel clock

    wire [W_N-1:0] h_cnt;
    wire [H_N-1:0] v_cnt;
    wire hs, vs;
    wire [7:0] r, g, b;
    wire active;

    video_timings timings_inst (
        .i_clk(i_clk), .i_rst(i_rst),
        .o_h_cnter(h_cnt), .o_v_cnter(v_cnt),
        .o_hs(hs), .o_vs(vs)
    );

    video_frame frame_inst (
        .i_clk(i_clk), .i_rst(i_rst),
        .i_h_cnter(h_cnt), .i_v_cnter(v_cnt),
        .i_hs(hs), .i_vs(vs),
        .o_red(r), .o_green(g), .o_blue(b),
        .o_active(active)
    );

    integer f, n_active, cyc;
    reg prev_active;

    initial begin
        repeat (3) @(posedge i_clk);
        @(negedge i_clk) i_rst = 0;

        // ---- 1) edges of o_active on the first visible line ----
        prev_active = 0;
        for (cyc = 0; cyc < 800; cyc = cyc + 1) begin
            @(negedge i_clk);              // sample mid-cycle, after the edge
            if (active !== prev_active)
                $display("line 0: o_active -> %0d while h_cnt = %0d (red = %0d)",
                         active, h_cnt, r);
            prev_active = active;
        end

        // ---- 2) one full frame to a PGM image ----
        // wait for the start of a frame
        while (!(h_cnt == 0 && v_cnt == 0)) @(negedge i_clk);
        f = $fopen("sim_frame.pgm", "w");
        $fwrite(f, "P2\n%0d %0d\n255\n", W, H);
        n_active = 0;
        for (cyc = 0; cyc < 800*525; cyc = cyc + 1) begin
            @(negedge i_clk);
            if (active) begin
                $fwrite(f, "%0d\n", r);
                n_active = n_active + 1;
            end
        end
        $fclose(f);
        $display("active pixels in one frame: %0d (expected %0d)", n_active, W*H);
        $finish;
    end
endmodule