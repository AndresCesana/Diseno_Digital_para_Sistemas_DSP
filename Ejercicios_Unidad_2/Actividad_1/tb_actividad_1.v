`timescale 1ns/1ps

module tb_actividad_1;

reg clk;
reg rst_n;

wire [1:0] a1, b1, c1;
wire [1:0] a2, b2, c2;

initial clk = 0;
always #5 clk = ~clk;
actividad_1 uA (.clk(clk), .rst_n(rst_n), .a1(a1), .b1(b1), .c1(c1), .a2(a2), .b2(b2), .c2(c2));

initial begin
    $dumpfile("tb_actividad_1.vcd");
    $dumpvars(0, tb_actividad_1);

    rst_n = 0;
    #5 rst_n = 1;   // Suelto reset entre flancos

    $display("");
    $display("Tiempo |  Caso A (blocking)   |  Caso B (non-blocking)");
    $display("-------+----------------------+------------------------");
    $display("  reset|  a1=%0d b1=%0d c1=%0d         |  a2=%0d b2=%0d c2=%0d", a1, b1, c1, a2, b2, c2);

    @(posedge clk); #1;
    $display("  10ns |  a1=%0d b1=%0d c1=%0d         |  a2=%0d b2=%0d c2=%0d", a1, b1, c1, a2, b2, c2);

    @(posedge clk); #1;
    $display("  20ns |  a1=%0d b1=%0d c1=%0d         |  a2=%0d b2=%0d c2=%0d", a1, b1, c1, a2, b2, c2);;

    @(posedge clk); #1;
    $display("  30ns |  a1=%0d b1=%0d c1=%0d         |  a2=%0d b2=%0d c2=%0d", a1, b1, c1, a2, b2, c2);

    $display("");
    $display("Observar: Caso B rota circularmente (1,2,3)->(2,3,1)->(3,1,2)->(1,2,3)");
    $display("          Caso A NO rota -- el orden de = importa y rompe la abstraccion.");
    $display("");
    $finish;
  end

endmodule