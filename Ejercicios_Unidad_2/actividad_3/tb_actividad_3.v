`timescale 1ns/1ps

module tb_actividad_3;

    reg clk;
    reg rst;
    reg en;

    wire [3:0] count;
    wire tc;


    // Golden model
    reg [3:0] gold_count;
    reg gold_tc;


    integer i;
    integer rollover_count;


    // Instancia del DUT
    actividad_3 dut (
        .clk(clk),
        .rst(rst),
        .en(en),
        .count(count),
        .tc(tc)
    );


    always #5 clk = ~clk;


    initial begin
        $dumpfile("tb_actividad_3.vcd");
        $dumpvars(0, tb_actividad_3);
    end



    // Golden model muy parecido a la actividad porque se deben comparar

    always @(posedge clk) begin

        if (rst) begin

            gold_count <= 4'd0;
            gold_tc <= 1'b0;

        end

        else if (en) begin

            if (gold_count == 4'd9) begin

                gold_count <= 4'd0;
                gold_tc <= 1'b1;

            end

            else begin

                gold_count <= gold_count + 4'd1;
                gold_tc <= 1'b0;

            end

        end

        else begin

            gold_tc <= 1'b0;

        end

    end

        // Auto-check
    always @(posedge clk) begin
        #1;

        if (count !== gold_count) begin
            $display("ERROR: count=%d esperado=%d", count, gold_count);
            $finish;
        end

        if (tc !== gold_tc) begin
            $display("ERROR: tc=%d esperado=%d", tc, gold_tc);
            $finish;
        end
    end

    // --------------------------------
    // Test principal
    // --------------------------------

    initial begin

        clk = 0;
        rst = 1;
        en  = 0;

        gold_count = 4'd0;
        gold_tc = 1'b0;

        rollover_count = 0;



        @(posedge clk);
        #1;

        rst = 0;
        en = 1;



        // Prueba de reset después de 5 ciclos
        $display("Prueba de RESET sincrono");


        repeat(5) begin
            @(posedge clk);
            #1;
        end


        $display("Valor antes del reset: count=%d", count);



        // Activar reset síncrono
        rst = 1;


        @(posedge clk);
        #1;

        $display("Valor despues del reset: count=%d", count);



        // Quitar reset

        rst = 0;


        // Prueba de 100 ciclos

        $display("Prueba de 100 ciclos");


        rollover_count = 0;


        for (i = 0; i < 100; i = i + 1) begin

            @(posedge clk);
            #1;


            if (tc)
                rollover_count = rollover_count + 1;

        end



        $display("Rollovers detectados: %d",
                 rollover_count);

        $finish;


    end


endmodule