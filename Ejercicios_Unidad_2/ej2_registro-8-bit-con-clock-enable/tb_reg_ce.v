`timescale 1ns/1ps

module tb_reg_ce;

    localparam WIDTH = 8;

    reg clk;
    reg rst_n;
    reg ce;
    reg [WIDTH-1:0] d;
    wire [WIDTH-1:0] q;

    integer vector;
    integer errors;

    initial clk = 0;
    always #5 clk = ~clk;

    reg_ce #(.WIDTH(WIDTH)) dut (.clk(clk), .rst_n(rst_n), .ce(ce), .d(d), .q(q));

    task check;
      input [8*24-1:0] nombre;
      input [WIDTH-1:0] esperado;
      begin
        vector = vector + 1;
        if (q === esperado)
          $display("%3d |%s| ce=%b d=0x%02h   | q=0x%02h esp=0x%02h | PASS  ",
           vector, nombre, ce, d, q, esperado);
        
        else begin
          $display("%3d |%s| ce=%b d=0x%02h   | q=0x%02h esp=0x%02h | FAIL  ",
           vector, nombre, ce, d, q, esperado);
          errors = errors + 1;
        end
      end
    endtask

    task paso;
      input [8*24-1:0]  nombre;
      input             ce_in;
      input [WIDTH-1:0] d_in;
      input [WIDTH-1:0] esperado;
      begin
        @(negedge clk);

        ce = ce_in;
        d = d_in;

        @(posedge clk); #1;

        check(nombre, esperado);
      end
    endtask

    initial begin
      $dumpfile("tb_reg_ce.vcd");
      $dumpvars(0, tb_reg_ce);

      vector = 0;
      errors = 0;
      ce = 0;
      d = {WIDTH{1'b0}};
      rst_n = 0;

      $display("");
      $display(" #  | Nombre                 | Entradas      | Resultado       | Estado");
      $display("----+------------------------       +---------------+-----------------+-------");
      #12;
      check("V1 reset inicial", 8'h00);
      rst_n = 1;                       
      paso("V2 escritura ce=1",   1, 8'hA5, 8'hA5);
      paso("V3 escritura ce=1",   1, 8'h3C, 8'h3C);
      paso("V4 hold ce=0",        0, 8'hFF, 8'h3C);
      paso("V5 hold ce=0",        0, 8'h00, 8'h3C);
      paso("V6 hold ce=0",        0, 8'h7E, 8'h3C);
      paso("V7 escritura ce=1",   1, 8'h7E, 8'h7E);

      @(negedge clk);
      ce=1; d=8'hFF; #2;
      rst_n = 0; #1;
      check("V8 reset asincrono", 8'h00);
      @(negedge clk);
      rst_n = 1;

      paso("V9 escritura ce=1",   1, 8'h55, 8'h55);
      paso("V10 hold ce=0",       0, 8'hAA, 8'h55);
      $display("");
      if (errors == 0)
        $display("RESULTADO: los %0d vectores pasaron.", vector);
      else
        $display("RESULTADO: %0d de %0d vectores fallaron.", errors, vector);
      $finish;
    end  

endmodule