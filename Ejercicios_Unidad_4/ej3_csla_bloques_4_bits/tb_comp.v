`timescale 1ns/1ps

module tb_comp;

    localparam int NRAND  = 1000;
    localparam int SETTLE = 400;    // ns, holgado para el peor caso del RCA

    // compuertas contadas del modelo (ver comentario al pie)
    localparam int G_RCA = 80, G_CSLA = 240, G_CLA = 138;

    logic [15:0] a, b;
    logic        cin;

    logic [15:0] s_rca,  s_csla,  s_cla;
    logic        co_rca, co_csla, co_cla;

    rca #(.N(16)) d_rca  (.a(a), .b(b), .c_in(cin), .s(s_rca),  .c_out(co_rca));
    csla16        d_csla (.a(a), .b(b), .c_in(cin), .o(s_csla), .c_out(co_csla));
    cla16         d_cla  (.a(a), .b(b), .c0 (cin),  .s(s_cla),  .c16 (co_cla));

    //------------------------------------------------------------------
    // Sondas: instante del ultimo cambio de cada salida
    //------------------------------------------------------------------
    time t0;
    time any_rca, any_csla, any_cla;    // cualquier salida
    time co_t_rca, co_t_csla, co_t_cla; // solo el carry

    always @(s_rca  or co_rca ) any_rca  = $time;
    always @(s_csla or co_csla) any_csla = $time;
    always @(s_cla  or co_cla ) any_cla  = $time;
    always @(co_rca ) co_t_rca  = $time;
    always @(co_csla) co_t_csla = $time;
    always @(co_cla ) co_t_cla  = $time;

    time dd_rca = 0, dd_csla = 0, dd_cla = 0;   // peor caso a,b -> salidas
    time dc_rca = 0, dc_csla = 0, dc_cla = 0;   // c_in -> c_out
    int  f_rca  = 0, f_csla  = 0, f_cla  = 0;
    int  nvec   = 0;

    //------------------------------------------------------------------
    // Aplica un vector, verifica los tres y actualiza el peor caso
    //------------------------------------------------------------------
    task automatic drive(input logic [15:0] ta, tb_, input logic tc);
        logic [16:0] esp;
        begin
            t0 = $time;
            a = ta; b = tb_; cin = tc;
            #SETTLE;
            nvec++;
            esp = ta + tb_ + tc;

            if ({co_rca,  s_rca } !== esp) f_rca++;
            if ({co_csla, s_csla} !== esp) f_csla++;
            if ({co_cla,  s_cla } !== esp) f_cla++;

            if (any_rca  > t0 && any_rca  - t0 > dd_rca ) dd_rca  = any_rca  - t0;
            if (any_csla > t0 && any_csla - t0 > dd_csla) dd_csla = any_csla - t0;
            if (any_cla  > t0 && any_cla  - t0 > dd_cla ) dd_cla  = any_cla  - t0;
        end
    endtask

    task automatic cero;
        begin a = 0; b = 0; cin = 0; #SETTLE; end
    endtask

    initial begin
        cero();

        // --- casos borde ---
        drive(16'hFFFF, 16'h0001, 1'b0);  cero();  // propagacion total
        drive(16'hFFFF, 16'h0000, 1'b1);  cero();  // propagacion via cin
        drive(16'h0000, 16'h0000, 1'b0);
        drive(16'hFFFF, 16'hFFFF, 1'b1);  cero();  // maximo + maximo + 1
        drive(16'h5555, 16'hAAAA, 1'b1);  cero();  // todos propagate
        drive(16'hAAAA, 16'h5555, 1'b1);  cero();
        drive(16'hFFFF, 16'hFFFF, 1'b0);  cero();  // generate puro
        drive(16'h8000, 16'h8000, 1'b0);           // overflow msb
        drive(16'h7FFF, 16'h0001, 1'b0);  cero();
        drive(16'h000F, 16'h0001, 1'b0);  cero();  // carry bloque 0->1
        drive(16'h00FF, 16'h0001, 1'b0);  cero();  // carry bloque 1->2
        drive(16'h0FFF, 16'h0001, 1'b0);  cero();  // carry bloque 2->3

        // --- aleatorios ---
        for (int i = 0; i < NRAND; i++)
            drive($urandom(), $urandom(), $urandom_range(0,1));

        // --- camino aislado c_in -> c_out (a=FFFF, b=0: todo propaga) ---
        a = 16'hFFFF; b = 16'h0000; cin = 1'b0;
        #SETTLE;
        t0 = $time; cin = 1'b1; #SETTLE;
        dc_rca  = co_t_rca  - t0;
        dc_csla = co_t_csla - t0;
        dc_cla  = co_t_cla  - t0;

        //--------------------------------------------------------------
        // Tabla
        //--------------------------------------------------------------
        $display("");
        $display("=================================================================");
        $display("  Sumadores de 16 bits  -  %0d vectores  (TXOR=3 TAND=2 TOR=2 TMUX=2)", nvec);
        $display("=================================================================");
        $display("  arq     gates  t_cin[ns]  t_data[ns]  Fmax[MHz]  area*delay  fail");
        $display("  ---------------------------------------------------------------");
        $display("  RCA   %7d %10d %11d %10.1f %11d %5d",
                 G_RCA,  dc_rca,  dd_rca,  1000.0/real'(dd_rca),  G_RCA *dd_rca,  f_rca);
        $display("  CSLA  %7d %10d %11d %10.1f %11d %5d",
                 G_CSLA, dc_csla, dd_csla, 1000.0/real'(dd_csla), G_CSLA*dd_csla, f_csla);
        $display("  CLA   %7d %10d %11d %10.1f %11d %5d",
                 G_CLA,  dc_cla,  dd_cla,  1000.0/real'(dd_cla),  G_CLA *dd_cla,  f_cla);
        $display("  ---------------------------------------------------------------");
        $display("  speedup vs RCA:  CSLA %0.2fx   CLA %0.2fx",
                 real'(dd_rca)/real'(dd_csla), real'(dd_rca)/real'(dd_cla));
        $display("=================================================================");
        $display("  t_cin  = camino aislado c_in -> c_out");
        $display("  t_data = peor caso a,b -> todas las salidas estables");
        if (f_rca + f_csla + f_cla == 0)
            $display("  los 3 sumadores pasaron todos los vectores.");
        else
            $display("  HAY FALLAS FUNCIONALES: los retardos no son confiables.");
        $display("");

        // --- lineas para el script de graficado ---
        $display("CSV,RCA,16,%0d,%0d,%0d,%0d,%0d",
                 G_RCA,  dc_rca,  dd_rca,  nvec-f_rca,  f_rca);
        $display("CSV,CSLA,16,%0d,%0d,%0d,%0d,%0d",
                 G_CSLA, dc_csla, dd_csla, nvec-f_csla, f_csla);
        $display("CSV,CLA,16,%0d,%0d,%0d,%0d,%0d",
                 G_CLA,  dc_cla,  dd_cla,  nvec-f_cla,  f_cla);

        $finish;
    end

    // Conteo de compuertas del modelo:
    //   RCA  = 16 FA x 5                        =  80
    //   CSLA = 8 RCA4 (32 FA x 5) + 20 mux x 4  = 240
    //   CLA  = 16 pg_gen x2 + 16 xor + 5 look x14 + 4 gpg x5 = 138
endmodule