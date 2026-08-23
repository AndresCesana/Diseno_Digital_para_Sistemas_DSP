`timescale 1ns/1ps
//=====================================================================
//  tb_compare.v  --  Entregables (c) y (d)
//
//  Corre cordic_vectorial y mult_reference con el MISMO estimulo y
//  vuelca todo a resultados.csv para analizar con analyze.py
//
//  Columnas:  set,ix,iy,cor_r,cor_phi,ref_r,ref_phi
//  set: 0=deterministico  1=barrido polar  2=barrido radial  3=aleatorio
//
//  Requiere las ROMs generadas:  python3 gen_roms.py
//=====================================================================
module tb_compare;

    localparam CLK_T   = 10;
    localparam N_ANG   = 2048;    // puntos del barrido polar
    localparam N_RAD   = 256;     // puntos del barrido radial
    localparam N_RND   = 20000;   // puntos aleatorios
    localparam real PI = 3.14159265358979;

    reg clk = 1'b0;
    reg rst = 1'b1;
    reg valid = 1'b0;
    reg signed [15:0] ix = 0, iy = 0;

    wire signed [15:0] cor_r, cor_p;
    wire signed [15:0] ref_r, ref_p;
    wire cor_v, ref_v;

    integer fd;
    integer k, tag;

    always #(CLK_T/2) clk = ~clk;

    //-----------------------------------------------------------------
    //  DUTs
    //-----------------------------------------------------------------
    cordic_vectorial u_cordic (
        .clk      (clk),
        .i_rst    (rst),
        .i_valid  (valid),
        .i_x      (ix),
        .i_y      (iy),
        .o_result (cor_r),
        .o_phase  (cor_p),
        .o_valid  (cor_v)
    );

    mult_reference u_ref (
        .clk      (clk),
        .i_rst    (rst),
        .i_valid  (valid),
        .i_x      (ix),
        .i_y      (iy),
        .o_result (ref_r),
        .o_phase  (ref_p),
        .o_valid  (ref_v)
    );

    //-----------------------------------------------------------------
    //  Captura: cada DUT tiene latencia distinta (17 vs 6 ciclos),
    //  se engancha cada resultado en su propio o_valid
    //-----------------------------------------------------------------
    reg signed [15:0] cor_r_q, cor_p_q, ref_r_q, ref_p_q;

    always @(posedge clk) begin
        if (cor_v) begin cor_r_q <= cor_r; cor_p_q <= cor_p; end
        if (ref_v) begin ref_r_q <= ref_r; ref_p_q <= ref_p; end
    end

    //-----------------------------------------------------------------
    //  Aplicar un vector y registrar la fila
    //-----------------------------------------------------------------
    task apply;
        input integer set_id;
        input signed [15:0] vx, vy;
        integer w;
        begin
            @(posedge clk);
            ix    <= vx;
            iy    <= vy;
            valid <= 1'b1;
            @(posedge clk);
            valid <= 1'b0;
            // holgado: el CORDIC tarda 17, la referencia 6
            for (w = 0; w < 30; w = w + 1) @(posedge clk);
            $fwrite(fd, "%0d,%0d,%0d,%0d,%0d,%0d,%0d\n",
                    set_id, vx, vy, cor_r_q, cor_p_q, ref_r_q, ref_p_q);
        end
    endtask

    //  real -> Q1.15 con recorte al rango representable
    function signed [15:0] to_q15;
        input real v;
        integer t;
        begin
            t = $rtoi(v * 32768.0);
            if (t >  32767) t =  32767;
            if (t < -32768) t = -32768;
            to_q15 = t[15:0];
        end
    endfunction

    //-----------------------------------------------------------------
    //  Estimulo
    //-----------------------------------------------------------------
    real ang, rad, seed_r;
    integer rnd_x, rnd_y;

    initial begin
        fd = $fopen("resultados.csv", "w");
        $fwrite(fd, "set,ix,iy,cor_r,cor_phi,ref_r,ref_phi\n");

        repeat (10) @(posedge clk);
        rst = 1'b0;
        repeat (5) @(posedge clk);

        //--- set 0: casos determinsticos ---------------------------
        $display("[tb] set 0: deterministicos");
        apply(0,  16384,  16384);   // I    45 grados
        apply(0, -16384,  16384);   // II   colapsa a -45
        apply(0, -16384, -16384);   // III  colapsa a +45
        apply(0,  16384, -16384);   // IV   -45
        apply(0,  32767,      0);   // eje +x
        apply(0,      0,  32767);   // eje +y  -> +pi/2
        apply(0, -32768,      0);   // x = -1.0 exacto
        apply(0, -32768,   1000);   // borde de la pre-rotacion
        apply(0,  29491,  29491);   // R = 1.27 -> satura
        apply(0,      0,      0);   // degenerado

        //--- set 1: barrido polar (R fijo) -> error vs angulo -------
        $display("[tb] set 1: barrido polar, %0d puntos", N_ANG);
        for (k = 0; k < N_ANG; k = k + 1) begin
            ang = -PI + 2.0*PI*k/N_ANG;
            apply(1, to_q15(0.70*$cos(ang)), to_q15(0.70*$sin(ang)));
        end

        //--- set 2: barrido radial (45 grados) -> error vs modulo ---
        $display("[tb] set 2: barrido radial, %0d puntos", N_RAD);
        for (k = 1; k <= N_RAD; k = k + 1) begin
            rad = 0.99 * k / N_RAD;
            apply(2, to_q15(rad*0.70710678), to_q15(rad*0.70710678));
        end

        //--- set 3: aleatorio uniforme ------------------------------
        $display("[tb] set 3: aleatorio, %0d puntos", N_RND);
        for (k = 0; k < N_RND; k = k + 1) begin
            rnd_x = $random % 32768;
            rnd_y = $random % 32768;
            apply(3, rnd_x[15:0], rnd_y[15:0]);
        end

        $fclose(fd);
        $display("[tb] listo -> resultados.csv");
        $finish;
    end

endmodule