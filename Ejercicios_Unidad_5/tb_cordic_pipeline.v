`timescale 1ns/1ps

module tb_cordic_pipeline;
    logic clk;
    logic rst;
    logic valid_in;
    logic signed [15:0] theta;
    logic valid_out;
    logic signed [15:0] cos_out;
    logic signed [15:0] sin_out;
    cordic_pipeline DUT (
        .clk(clk),
        .rst(rst),
        .valid_in(valid_in),
        .theta(theta),
        .valid_out(valid_out),
        .cos_out(cos_out),
        .sin_out(sin_out)
    );

    initial begin
        clk = 1'b0;
        forever #5 clk = ~clk;
    end
    initial begin
        $dumpfile("tb_cordic_pipeline.vcd");
        $dumpvars(0, tb_cordic_pipeline);
    end
    always @(posedge clk) begin
        if (valid_out) begin
            $display(
                "t=%0t  COS=%d (%f)  SIN=%d (%f)",
                $time,
                cos_out,
                $itor(cos_out)/16384.0,
                sin_out,
                $itor(sin_out)/16384.0
            );
        end
    end

    initial begin
        rst = 1'b1;
        valid_in = 1'b0;
        theta = 16'sd0;
        repeat(2) @(posedge clk);
        rst = 1'b0;
        @(negedge clk);
        theta = 16'sd8579;
        valid_in = 1'b1;
        @(negedge clk);
        theta = 16'sd12868;
        @(negedge clk);
        theta = 16'sd17157;
        @(negedge clk);
        valid_in = 1'b0;
        theta = 16'sd0;
        repeat(20) @(posedge clk);
        $display("");
        $display("======================================");
        $display("SIMULACION TERMINADA");
        $display("======================================");
        $finish;
    end
endmodule