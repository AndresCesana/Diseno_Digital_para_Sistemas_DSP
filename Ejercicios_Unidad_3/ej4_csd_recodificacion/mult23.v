//==============================================================
//  Multiplicacion por constante K = 23
//
//    K_bin = 1 0 1 1 1        = 16 + 4 + 2 + 1   -> 3 sumadores
//    K_csd = 1 0 -1 0 0 -1    = 32 - 8 - 1       -> 2 sumadores
//
//  X es signado de N bits  ->  Y necesita N+5 bits
//  (el peso mas alto del CSD es 2^5, porque 23 < 32)
//==============================================================
`timescale 1ns/1ps

//--------------------------------------------------------------
// Version CSD:  Y = (X<<5) - (X<<3) - X     -> 2 restadores
//--------------------------------------------------------------
module mult23_csd #(parameter N = 8) (
    input  wire signed [N-1:0] x,
    output wire signed [N+4:0] y
);
    // extension de signo a N+5 bits ANTES de operar
    wire signed [N+4:0] xe = x;

    assign y = (xe <<< 5) - (xe <<< 3) - xe;
endmodule


//--------------------------------------------------------------
// Version binaria:  Y = (X<<4) + (X<<2) + (X<<1) + X  -> 3 sumadores
//--------------------------------------------------------------
module mult23_bin #(parameter N = 8) (
    input  wire signed [N-1:0] x,
    output wire signed [N+4:0] y
);
    wire signed [N+4:0] xe = x;

    assign y = (xe <<< 4) + (xe <<< 2) + (xe <<< 1) + xe;
endmodule