`timescale 1ns/1ps

module actividad_3_tb;
    reg signed [10:0] x1;
    reg signed [10:0] x2;

    wire signed [6:0] o1_trunc;
    wire signed [6:0] o2_round;

    wire signed [4:0] o3_wrap;
    wire signed [4:0] o4_sat;

    reg signed [6:0] gold_trunc;
    reg signed [6:0] gold_round;

    reg signed [4:0] gold_wrap;
    reg signed [4:0] gold_sat;


    integer errores;

    actividad_3 uut (
        .x1(x1),
        .x2(x2),

        .o1_trunc(o1_trunc),
        .o2_round(o2_round),

        .o3_wrap(o3_wrap),
        .o4_sat(o4_sat)
    );

    initial begin

        errores = 0;

        $dumpfile("actividad_3_tb.vcd");
        $dumpvars(0, actividad_3_tb);

        x1 = 11'b00101100100;

        gold_trunc = 7'b0101100;
        gold_round = 7'b0101101;


        #10;


        $display("==========================================");
        $display("PARTE A");
        $display("==========================================");

        $display("x          = %b", x1);

        $display("trunc DUT  = %b", o1_trunc);
        $display("trunc GOLD = %b", gold_trunc);

        $display("round DUT  = %b", o2_round);
        $display("round GOLD = %b", gold_round);


        if (o1_trunc !== gold_trunc) begin

            $display("ERROR: truncado");

            errores = errores + 1;

        end


        if (o2_round !== gold_round) begin

            $display("ERROR: redondeo");

            errores = errores + 1;

        end

        x2 = 11'b01000110000;

        gold_wrap = 5'b00110;
        gold_sat  = 5'b01111;


        #10;


        $display("==========================================");
        $display("PARTE B");
        $display("==========================================");

        $display("y          = %b", x2);

        $display("wrap DUT   = %b", o3_wrap);
        $display("wrap GOLD  = %b", gold_wrap);

        $display("sat DUT    = %b", o4_sat);
        $display("sat GOLD   = %b", gold_sat);

        if (o3_wrap !== gold_wrap) begin

            $display("ERROR: wrap-around");

            errores = errores + 1;

        end

        if (o4_sat !== gold_sat) begin

            $display("ERROR: saturacion");


        end

        $display("==========================================");

        if (errores == 0) begin

            $display("[PASS] Todos los casos correctos.");

        end
        else begin

            $display("[FAIL] Se encontraron %0d errores.", errores);

        end

        $display("==========================================");

        $finish;

    end

endmodule