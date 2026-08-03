`timescale 1ns/1ps

module tb_detector_101;

    localparam logic [10:0] SEQ     = 11'b11010110101;
    localparam logic [10:0] Y_ESP   = 11'b00010100101;
    localparam integer      DET_ESP = 4;   // cantidad de unos en Y_ESP

    logic clk;
    logic rst_n;
    logic x;
    wire  y;

    integer errors;
    integer vector;
    integer detecciones;

    initial clk = 0;
    always #5 clk = ~clk;

    detector_101 dut (.clk(clk), .rst_n(rst_n), .x(x), .y(y));

    // Traduce el valor binario del estado a su nombre, para la traza
    function string nombre_estado(input logic [1:0] s);
        case (s)
            2'b00:   nombre_estado = "S0";
            2'b01:   nombre_estado = "S1";
            2'b10:   nombre_estado = "S10";
            2'b11:   nombre_estado = "S101";
            default: nombre_estado = "??";
        endcase
    endfunction

    task check(input string nombre, input logic y_esperado);
        begin
            #1;
            vector = vector + 1;
            if (y === 1'b1)
                detecciones = detecciones + 1;

            if (y !== y_esperado)
                errors = errors + 1;

            $display("%3d | %-8s | %b | %-6s | %b | %3b | %-4s",
                     vector, nombre, x, nombre_estado(dut.estado),
                     y, y_esperado, (y === y_esperado) ? "ok" : "FAIL");
        end
    endtask

    task paso(input string nombre, input logic bit_in, input logic y_esperado);
        begin
            @(negedge clk);
            x = bit_in;
            @(posedge clk);
            check(nombre, y_esperado);
        end
    endtask

    initial begin
        $dumpfile("tb_detector_101.vcd");
        $dumpvars(0, tb_detector_101);

        vector      = 0;
        errors      = 0;
        detecciones = 0;
        rst_n       = 0;
        x           = 0;

        $display("");
        $display("  # | Nombre   | x | Estado | y | esp | Res");
        $display("----+----------+---+--------+---+-----+-----");

        #12; rst_n = 1;

        for (int i = 10; i >= 0; i = i - 1) begin
            paso($sformatf("ciclo %0d", 10-i), SEQ[i], Y_ESP[i]);
        end

        $display("");
        $display("Vectores    : %0d de %0d pasaron.", vector - errors, vector);
        $display("Detecciones : esperadas=%0d, obtenidas=%0d", DET_ESP, detecciones);
        if (errors == 0 && detecciones == DET_ESP)
            $display("RESULTADO   : PASS");
        else
            $display("RESULTADO   : FAIL (%0d vectores con error)", errors);
        $display("");
        $finish;
    end
endmodule