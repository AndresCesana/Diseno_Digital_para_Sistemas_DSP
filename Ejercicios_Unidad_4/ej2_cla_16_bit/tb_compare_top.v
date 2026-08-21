`timescale 1ns/1ps

// Corre RCA de 16 bits y CLA de 16 bits, cada uno con 1000 vectores random,
// y emite una linea CSV,RCA,... y una CSV,CLA,... comparables por N.
module tb_compare_top;

    localparam SLOT = 5_000_000;   // ventana por instancia (holgada)

    tb_rca #(.N(16), .N_RANDOM(1000), .START_TIME(0*SLOT)) tb_rca16 ();
    tb_cla #(          .N_RANDOM(1000), .START_TIME(1*SLOT)) tb_cla16 ();

    initial begin
        $dumpfile("cla_vs_rca.vcd");
        $dumpvars(0, tb_compare_top);
        #(2*SLOT);
        $display("");
        $display("=== Comparacion RCA vs CLA (N=16, 1000 vectores) finalizada ===");
        $finish;
    end

endmodule