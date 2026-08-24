`timescale 1ns/1ps

module tb_newton_raphson;

    parameter WIDTH  = 16;
    parameter N_ITER = 4;

    parameter A_MIN  = 16'h8000;   // 0.5
    parameter A_MAX  = 16'hFFFF;   // ~1.0

    //-------------------------------------------------------------------------
    // DUT
    //-------------------------------------------------------------------------
    reg                  clk   = 1'b0;
    reg                  rst_n = 1'b0;
    reg                  start = 1'b0;
    reg  [WIDTH-1:0]     a     = A_MIN;
    wire                 done;
    wire [WIDTH-1:0]     y;

    newton_raphson #(
        .N_ITER (N_ITER),
        .WIDTH  (WIDTH)
    ) dut (
        .clk    (clk),
        .rst_n  (rst_n),
        .start  (start),
        .a      (a),
        .done   (done),
        .y      (y)
    );

    always #5 clk = ~clk;          // 100 MHz

    //-------------------------------------------------------------------------
    // Estado del banco
    //-------------------------------------------------------------------------
    integer fd;
    integer errores      = 0;      // desviaciones fuera de tolerancia
    integer timeouts     = 0;
    integer n_casos      = 0;

    integer err_max_pos  = 0;      // mayor error positivo (LSB)
    integer err_max_neg  = 0;      // mayor error negativo (LSB)
    integer a_peor_pos   = 0;
    integer a_peor_neg   = 0;
    integer suma_err     = 0;      // para el sesgo medio

    integer ciclos_prev  = -1;     // latencia observada (debe ser constante)

    // Tolerancia: cuantos LSB de desviacion aceptamos antes de contar error.
    // Con truncamiento/redondeo esperamos 1-2 LSB; ponemos 4 como red de
    // seguridad para que solo salten los bugs reales, no el piso de ruido.
    parameter TOL_LSB = 4;

    //-------------------------------------------------------------------------
    // Referencia: y_ref = round(2^31 / a), saturado a 16 bits
    //-------------------------------------------------------------------------
    function integer y_referencia;
        input [WIDTH-1:0] av;
        real r;
        integer v;
        begin
            r = 2147483648.0 / $itor({16'd0, av});   // 2^31 / a_int
            v = $rtoi(r + 0.5);                      // redondeo al mas cercano
            if (v > 65535) v = 65535;                // saturacion Q1.15
            y_referencia = v;
        end
    endfunction

    //-------------------------------------------------------------------------
    // Ejecuta una conversion y deja el resultado en y_rtl / ciclos
    //-------------------------------------------------------------------------
    integer y_rtl;
    integer ciclos;

    task correr;
        input [WIDTH-1:0] av;
        integer guard;
        begin
            a = av;

            // --- pulso de arranque (1 ciclo) ---
            @(negedge clk);
            start = 1'b1;
            @(negedge clk);
            start = 1'b0;

            // --- esperar done, contando ciclos ---
            ciclos = 1;
            guard  = 0;
            while (done !== 1'b1 && guard < 200) begin
                @(negedge clk);
                ciclos = ciclos + 1;
                guard  = guard  + 1;
            end

            if (guard >= 200) begin
                $display("[TIMEOUT] a=%04h : done nunca se activo", av);
                timeouts = timeouts + 1;
                y_rtl    = 0;
                ciclos   = -1;
                // reset de emergencia para no arrastrar el cuelgue
                rst_n = 1'b0; @(negedge clk); rst_n = 1'b1; @(negedge clk);
            end else begin
                y_rtl = {16'd0, y};

                // --- segundo pulso: DONE -> IDLE (asi lo pide la FSM) ---
                @(negedge clk);
                start = 1'b1;
                @(negedge clk);
                start = 1'b0;
                @(negedge clk);

                if (done !== 1'b0)
                    $display("[AVISO] a=%04h : done no se limpio al volver a IDLE", av);
            end
        end
    endtask

    //-------------------------------------------------------------------------
    // Corre un caso, compara, acumula estadistica y lo escribe al CSV
    //-------------------------------------------------------------------------
    task chequear;
        input [WIDTH-1:0] av;
        input             verboso;
        integer ref_v, err;
        begin
            correr(av);
            ref_v = y_referencia(av);
            err   = y_rtl - ref_v;

            n_casos  = n_casos + 1;
            suma_err = suma_err + err;

            if (err > err_max_pos) begin
                err_max_pos = err;
                a_peor_pos  = av;
            end
            if (err < err_max_neg) begin
                err_max_neg = err;
                a_peor_neg  = av;
            end

            // latencia constante?
            if (ciclos > 0) begin
                if (ciclos_prev == -1)
                    ciclos_prev = ciclos;
                else if (ciclos != ciclos_prev) begin
                    $display("[ERROR] a=%04h : latencia %0d, se esperaba %0d",
                             av, ciclos, ciclos_prev);
                    errores = errores + 1;
                end
            end

            if (err > TOL_LSB || err < -TOL_LSB) begin
                $display("[ERROR] a=%04h  y_rtl=%04h (%0d)  y_ref=%04h (%0d)  err=%0d LSB",
                         av, y_rtl[15:0], y_rtl, ref_v[15:0], ref_v, err);
                errores = errores + 1;
            end else if (verboso) begin
                $display("  a=%04h (%.6f)  y_rtl=%04h  y_ref=%04h  err=%0d LSB  ciclos=%0d",
                         av, $itor({16'd0, av}) / 65536.0,
                         y_rtl[15:0], ref_v[15:0], err, ciclos);
            end

            $fwrite(fd, "%0d,%0d,%0d,%0d\n", av, y_rtl, ref_v, err);
        end
    endtask

    //-------------------------------------------------------------------------
    // Programa principal
    //-------------------------------------------------------------------------
    integer i;
    reg [255:0] nombre;

    initial begin
`ifdef DUMP
        $dumpfile("tb_newton_raphson.vcd");
        $dumpvars(0, tb_newton_raphson);
`endif

        $sformat(nombre, "nr_error_N%0d.csv", N_ITER);
        fd = $fopen(nombre, "w");
        if (fd == 0) begin
            $display("No se pudo abrir el CSV de salida");
            $finish;
        end
        $fwrite(fd, "a_int,y_rtl,y_ref,err_lsb\n");

        $display("=======================================================");
        $display(" TB newton_raphson   WIDTH=%0d  N_ITER=%0d", WIDTH, N_ITER);
        $display("=======================================================");

        // --- reset ---
        rst_n = 1'b0;
        repeat (4) @(negedge clk);
        rst_n = 1'b1;
        repeat (2) @(negedge clk);

        if (done !== 1'b0)
            $display("[ERROR] done alto despues del reset");

        //---------------------------------------------------------------
        // 1) Tests dirigidos (los casos que razonamos a mano)
        //---------------------------------------------------------------
        $display("\n--- Tests dirigidos ---");
        chequear(16'h8000, 1'b1);   // a=0.5      -> y=2.0, satura a FFFF
        chequear(16'h8001, 1'b1);   // apenas arriba del borde
        chequear(16'h9000, 1'b1);   // idx=1
        chequear(16'hA000, 1'b1);   // idx=2
        chequear(16'hC000, 1'b1);   // a=0.75     -> y=1.3333
        chequear(16'hE000, 1'b1);   // idx=6
        chequear(16'hF000, 1'b1);   // idx=7
        chequear(16'hFFFF, 1'b1);   // a~1.0      -> y~8001

        // un valor en el centro de cada subintervalo de la LUT
        $display("\n--- Centro de cada entrada de LUT ---");
        for (i = 0; i < 8; i = i + 1)
            chequear(16'h8000 + (i * 16'h1000) + 16'h0800, 1'b1);

        //---------------------------------------------------------------
        // 2) Barrido exhaustivo: los 32768 valores de a en [0.5, 1.0)
        //---------------------------------------------------------------
        $display("\n--- Barrido exhaustivo (32768 casos) ---");
        for (i = A_MIN; i <= A_MAX; i = i + 1) begin
            chequear(i[15:0], 1'b0);
            if ((i - A_MIN) % 4096 == 0 && i != A_MIN)
                $display("  ... %0d / 32768", i - A_MIN);
        end

        //---------------------------------------------------------------
        // 3) Resumen
        //---------------------------------------------------------------
        $display("\n=======================================================");
        $display(" RESUMEN   N_ITER=%0d", N_ITER);
        $display("-------------------------------------------------------");
        $display("  casos evaluados    : %0d", n_casos);
        $display("  latencia           : %0d ciclos (start -> done)", ciclos_prev);
        $display("  err maximo positivo: %0d LSB   (a=%04h)", err_max_pos, a_peor_pos[15:0]);
        $display("  err maximo negativo: %0d LSB   (a=%04h)", err_max_neg, a_peor_neg[15:0]);
        $display("  sesgo medio        : %.4f LSB", $itor(suma_err) / $itor(n_casos));
        $display("  fuera de tolerancia: %0d  (|err| > %0d LSB)", errores, TOL_LSB);
        $display("  timeouts           : %0d", timeouts);
        $display("-------------------------------------------------------");
        if (errores == 0 && timeouts == 0)
            $display("  RESULTADO: OK");
        else
            $display("  RESULTADO: FALLO");
        $display("=======================================================");
        $display("\nCSV escrito en %0s", nombre);

        $fclose(fd);
        $finish;
    end

endmodule