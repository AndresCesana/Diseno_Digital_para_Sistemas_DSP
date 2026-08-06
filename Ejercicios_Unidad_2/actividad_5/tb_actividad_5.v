`timescale 1ns/1ps
module tb_actividad_5;
reg clk;
reg rst;
reg signed [7:0] x_in;
reg valid_in;
reg ready_in;
wire signed [15:0] y_out;
wire valid_out;
wire ready_out;
actividad_5 dut(
    .clk(clk),
    .rst(rst),
    .x_in(x_in),
    .valid_in(valid_in),
    .ready_out(ready_out),
    .y_out(y_out),
    .valid_out(valid_out),
    .ready_in(ready_in)
);
initial
    clk = 0;
always #5 clk = ~clk;
reg signed [15:0] gold_pipe [0:2];
reg gold_valid [0:2];
integer i;
integer ciclos;
integer muestras;
always @(posedge clk) begin
    if (rst) begin
        gold_pipe[0]  <= 0;
        gold_pipe[1]  <= 0;
        gold_pipe[2]  <= 0;

        gold_valid[0] <= 0;
        gold_valid[1] <= 0;
        gold_valid[2] <= 0;
    end
    else if (ready_in) begin
        gold_pipe[0] <= ((x_in + 8'sd5) * 8'sd3) >>> 4;
        gold_valid[0] <= valid_in;

        gold_pipe[1] <= gold_pipe[0];
        gold_valid[1] <= gold_valid[0];

        gold_pipe[2] <= gold_pipe[1];
        gold_valid[2] <= gold_valid[1];
    end
end
always @(posedge clk) begin
    #1;
    if (valid_out != gold_valid[2]) begin
        $display("ERROR VALID tiempo=%0t", $time);
        $finish;
    end
    if (valid_out && (y_out !== gold_pipe[2])) begin
        $display("ERROR DATA tiempo=%0t  y=%0d esperado=%0d",
                 $time,
                 y_out,
                 gold_pipe[2]);
        $finish;
    end
end

initial begin

    $display("");
    $display("---------------------------------------------------------------------------------------------");
    $display(" tiempo | x_in | vin | stage1 v1 | stage2 v2 | stage3 v3 | y_out vout | ready");
    $display("---------------------------------------------------------------------------------------------");
end
always @(posedge clk) begin
    #1;
    $display("%6t | %4d |  %b  | %5d  %b | %5d  %b | %5d  %b | %5d   %b  |   %b",
             $time,
             x_in,
             valid_in,
             dut.stage1,
             dut.valid1,
             dut.stage2,
             dut.valid2,
             dut.stage3,
             dut.valid3,
             y_out,
             valid_out,
             ready_in);
end
always @(posedge clk) begin
    ciclos = ciclos + 1;
    if(valid_in && ready_out)
        muestras = muestras + 1;
end
initial begin
    $dumpfile("tb_actividad_5.vcd");
    $dumpvars(0,tb_actividad_5);
    rst      = 1;
    valid_in = 0;
    ready_in = 1;
    x_in     = 0;
    ciclos = 0;
    muestras = 0;
    @(posedge clk);
    #1;
    rst = 0;
    for(i=0;i<10;i=i+1) begin
        @(posedge clk);
        x_in = i;
        valid_in = 1;
    end
    valid_in = 0;
    @(posedge clk);
    ready_in = 0;
    $display("");
    $display("------------ STALL ACTIVADO ------------");
    repeat(4)
        @(posedge clk);
    ready_in = 1;
    $display("");
    $display("------------ STALL LIBERADO ------------");
    repeat(10)
        @(posedge clk);
    $display("");
    $display("SIMULACION TERMINADA");
    $display("Ciclos = %0d", ciclos);
    $display("Muestras procesadas = %0d", muestras);
    $display("Throughput observado = %f muestras/ciclo", muestras*1.0/ciclos);  
    $finish;
end

endmodule