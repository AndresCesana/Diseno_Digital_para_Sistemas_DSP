`timescale 1ns/1ps

module tb_cordic;

    logic clk;
    logic rst;
    logic start;
    logic signed [15:0] theta;
    logic signed [15:0] cos_out;
    logic signed [15:0] sin_out;
    logic busy;
    logic done;

    cordic DUT (
        .clk(clk),
        .rst(rst),
        .start(start),
        .theta(theta),
        .cos_out(cos_out),
        .sin_out(sin_out),
        .busy(busy),
        .done(done)
    );

    initial begin
        clk = 1'b0;
        forever #5 clk = ~clk;
    end
    initial begin
        $dumpfile("tb_cordic.vcd");
        $dumpvars(0, tb_cordic);
    end
    initial begin
        rst = 1'b1;
        start = 1'b0;
        theta = 16'sd0;
        repeat(2) @(posedge clk);
        rst = 1'b0;
        $display("");
        $display("======================================");
        $display("TEST 1: THETA = PI/6");
        $display("======================================");
        theta = 16'sd8579;
        @(posedge clk);
        start = 1'b1;
        @(posedge clk);
        start = 1'b0;
        repeat(14) @(posedge clk);
        #1;
        $display("COS fixed = %d", cos_out);
        $display("SIN fixed = %d", sin_out);
        $display("COS = %f", $itor(cos_out) / 16384.0);
        $display("SIN = %f", $itor(sin_out) / 16384.0);
        $display("");
        $display("======================================");
        $display("TEST 2: THETA = PI/4");
        $display("======================================");
        theta = 16'sd12868;
        @(posedge clk);
        start = 1'b1;
        @(posedge clk);
        start = 1'b0;
        repeat(14) @(posedge clk);
        #1;
        $display("COS fixed = %d", cos_out);
        $display("SIN fixed = %d", sin_out);
        $display("COS = %f", $itor(cos_out) / 16384.0);
        $display("SIN = %f", $itor(sin_out) / 16384.0);
        $display("");
        $display("======================================");
        $display("TEST 3: THETA = PI/3");
        $display("======================================");
        theta = 16'sd17157;
        @(posedge clk);
        start = 1'b1;
        @(posedge clk);
        start = 1'b0;
        repeat(14) @(posedge clk);
        #1;
        $display("COS fixed = %d", cos_out);
        $display("SIN fixed = %d", sin_out);
        $display("COS = %f", $itor(cos_out) / 16384.0);
        $display("SIN = %f", $itor(sin_out) / 16384.0);
        $display("");
        $display("======================================");
        $display("SIMULACION TERMINADA");
        $display("======================================");
        #20;
        $finish;
    end
endmodule
