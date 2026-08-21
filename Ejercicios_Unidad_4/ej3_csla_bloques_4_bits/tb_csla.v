module tb_csla16;
    logic [15:0] a, b, o;
    logic        c_in, c_out;
    int          errores = 0;
 
    csla16 dut (.c_in(c_in), .a(a), .b(b), .o(o), .c_out(c_out));
 
    task automatic check(input logic [15:0] ta, tb_, input logic tci);
        logic [16:0] esperado;
        begin
            a = ta; b = tb_; c_in = tci;
            #200;                          // holgura para la peor cadena de retardos
            esperado = ta + tb_ + tci;
            if ({c_out, o} !== esperado) begin
                errores++;
                $display("ERROR: %0d + %0d + %0d -> obtenido %0d, esperado %0d",
                         ta, tb_, tci, {c_out, o}, esperado);
            end
        end
    endtask
 
    initial begin
        // casos borde
        check(16'h0000, 16'h0000, 1'b0);
        check(16'hFFFF, 16'h0001, 1'b0);   // acarreo por toda la cadena
        check(16'hFFFF, 16'h0000, 1'b1);
        check(16'hFFFF, 16'hFFFF, 1'b1);
        check(16'h8000, 16'h8000, 1'b0);
        check(16'h0FFF, 16'h0001, 1'b0);   // acarreo entre bloques
 
        // aleatorios
        for (int i = 0; i < 500; i++)
            check($urandom(), $urandom(), $urandom_range(0,1));
 
        if (errores == 0) $display("OK: todos los casos pasaron.");
        else              $display("FALLARON %0d casos.", errores);
        $finish;
    end
endmodule
 