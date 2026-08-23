`timescale 1ns/1ps

//---------------------------------------------------------------------
//  ROM sincronica generica (salida registrada -> infiere BRAM)
//---------------------------------------------------------------------
module rom_sync #(
    parameter AW        = 12,
    parameter DW        = 16,
    parameter INIT_FILE = ""
)(
    input  wire            clk,
    input  wire [AW-1:0]   addr,
    output reg  [DW-1:0]   dout
);
    reg [DW-1:0] mem [0:(1<<AW)-1];

    initial begin
        if (INIT_FILE != "") $readmemh(INIT_FILE, mem);
    end

    always @(posedge clk) dout <= mem[addr];
endmodule


//---------------------------------------------------------------------
//  Modulo principal
//---------------------------------------------------------------------
module mult_reference #(
    parameter NB_INPUT       = 16,
    parameter NBF_INPUT      = 15,
    parameter NB_OUTPUT_MOD  = 16,
    parameter NBF_OUTPUT_MOD = 15,
    parameter NB_OUTPUT_PHA  = 16,
    parameter NBF_OUTPUT_PHA = 14,
    parameter SQRT_FILE      = "rom_sqrt.hex",
    parameter RECIP_FILE     = "rom_recip.hex",
    parameter ATAN_FILE      = "rom_atan.hex"
)(
    input  wire                             clk,
    input  wire                             i_rst,
    input  wire                             i_valid,
    input  wire signed [NB_INPUT      -1:0] i_x, i_y,
    output reg  signed [NB_OUTPUT_MOD -1:0] o_result,
    output reg  signed [NB_OUTPUT_PHA -1:0] o_phase,
    output wire                             o_valid
);

    // pi/2 en Q2.14  (notar: 25736 = 2 * 12868, el atan(1) de la LUT CORDIC)
    localparam signed [15:0] PI2_Q14 = 16'sd25736;

    //-----------------------------------------------------------------
    //  Contador de ceros a izquierda (16 bits)
    //-----------------------------------------------------------------
    function [3:0] lzc16;
        input [15:0] v;
        casez (v)
            16'b1???????????????: lzc16 = 4'd0;
            16'b01??????????????: lzc16 = 4'd1;
            16'b001?????????????: lzc16 = 4'd2;
            16'b0001????????????: lzc16 = 4'd3;
            16'b00001???????????: lzc16 = 4'd4;
            16'b000001??????????: lzc16 = 4'd5;
            16'b0000001?????????: lzc16 = 4'd6;
            16'b00000001????????: lzc16 = 4'd7;
            16'b000000001???????: lzc16 = 4'd8;
            16'b0000000001??????: lzc16 = 4'd9;
            16'b00000000001?????: lzc16 = 4'd10;
            16'b000000000001????: lzc16 = 4'd11;
            16'b0000000000001???: lzc16 = 4'd12;
            16'b00000000000001??: lzc16 = 4'd13;
            16'b000000000000001?: lzc16 = 4'd14;
            default:              lzc16 = 4'd15;
        endcase
    endfunction

    //=================================================================
    //  ETAPA 0 (combinacional sobre las entradas)
    //  |x|, |y|, signo del cociente, y ordenamiento min/max
    //=================================================================
    // |x| necesita 16 bits sin signo: |-1.0| = 32768 = 0x8000
    wire [15:0] ax_c   = i_x[15] ? (~i_x + 16'd1) : i_x;
    wire [15:0] ay_c   = i_y[15] ? (~i_y + 16'd1) : i_y;

    // reduccion de rango: t = min/max  =>  t en [0,1], atan(t) en [0,pi/4]
    wire        swp_c  = (ay_c > ax_c);
    wire [15:0] num_c  = swp_c ? ax_c : ay_c;
    wire [15:0] den_c  = swp_c ? ay_c : ax_c;

    // atan(y/x) tiene el signo de y/x (colapsa cuadrantes II->IV, III->I,
    // igual que el CORDIC con pre-rotacion de 180 grados)
    wire        sgn_c  = i_x[15] ^ i_y[15];
    wire        zer_c  = (den_c == 16'd0);   // x = y = 0

    //=================================================================
    //  Pipeline de control
    //=================================================================
    reg [4:0] sgn_p, swp_p, zer_p;   // bit k valido en el ciclo k+1
    reg [5:0] vld_p;                 // bit k valido en el ciclo k+1

    always @(posedge clk) begin
        if (i_rst) begin
            vld_p <= 6'd0;
        end else begin
            vld_p <= {vld_p[4:0], i_valid};
        end
        sgn_p <= {sgn_p[3:0], sgn_c};
        swp_p <= {swp_p[3:0], swp_c};
        zer_p <= {zer_p[3:0], zer_c};
    end

    assign o_valid = vld_p[5];

    //=================================================================
    //  ETAPA 1 : registro de operandos
    //=================================================================
    reg [15:0] ax1, ay1, num1, den1;

    always @(posedge clk) begin
        ax1  <= ax_c;
        ay1  <= ay_c;
        num1 <= num_c;
        den1 <= den_c;
    end

    //=================================================================
    //  ETAPA 2 : cuadrados (2 multiplicadores) + normalizacion
    //
    //  t = num/den es invariante al escalado, asi que corremos AMBOS
    //  por el mismo shift hasta que den quede en [0.5, 1). Eso acota
    //  el reciproco a (1, 2] y lo hace tabulable.
    //=================================================================
    wire [3:0]  sh    = lzc16(den1);
    wire [15:0] den_n = den1 << sh;      // MSB siempre en bit 15
    wire [15:0] num_n = num1 << sh;      // num <= den  =>  no desborda

    reg [31:0] xx2, yy2;
    reg [15:0] num_n2, den_n2;

    always @(posedge clk) begin
        xx2    <= ax1 * ax1;             // Q2.30, max 2^30
        yy2    <= ay1 * ay1;
        num_n2 <= num_n;
        den_n2 <= den_n;
    end

    //=================================================================
    //  ETAPA 3 : suma de cuadrados + lectura del reciproco
    //=================================================================
    reg [31:0] sum3;
    reg [15:0] num_n3;

    always @(posedge clk) begin
        sum3   <= xx2 + yy2;             // Q2.30, max 2^31 (= 2.0)
        num_n3 <= num_n2;
    end

    wire [15:0] recip_d;                 // 1/den_n en Q2.14, en (1, 2]
    rom_sync #(.AW(11), .DW(16), .INIT_FILE(RECIP_FILE)) u_rom_recip (
        .clk  (clk),
        .addr (den_n2[14:4]),            // bit 15 siempre en 1 -> no se direcciona
        .dout (recip_d)
    );

    //=================================================================
    //  ETAPA 4 : t = num/den (1 multiplicador) + lectura de sqrt
    //=================================================================
    wire [31:0] tprod = num_n3 * recip_d;   // Q0.16 * Q2.14 = valor * 2^30

    reg [15:0] t4;
    always @(posedge clk) t4 <= tprod[30:15];   // t en Q1.15, [0, 1.0]

    wire [15:0] sqrt_d;                  // R en Q2.14, [0, sqrt(2)]
    rom_sync #(.AW(12), .DW(16), .INIT_FILE(SQRT_FILE)) u_rom_sqrt (
        .clk  (clk),
        .addr (sum3[31:20]),             // suma truncada a 10 bits fraccionarios
        .dout (sqrt_d)
    );

    //=================================================================
    //  ETAPA 5 : lectura de atan
    //=================================================================
    reg [15:0] r14_5;
    always @(posedge clk) r14_5 <= sqrt_d;

    wire [15:0] atan_d;                  // atan(t) en Q2.14, [0, pi/4]
    rom_sync #(.AW(12), .DW(16), .INIT_FILE(ATAN_FILE)) u_rom_atan (
        .clk  (clk),
        .addr (t4[15:4]),
        .dout (atan_d)
    );

    //=================================================================
    //  ETAPA 6 : reconstruccion de cuadrante y saturacion
    //=================================================================
    // si hubo swap calculamos atan(min/max) = atan(x/y), y vale
    //     atan(y/x) = pi/2 - atan(x/y)
    wire signed [15:0] base = swp_p[4] ? (PI2_Q14 - $signed(atan_d))
                                       : $signed(atan_d);

    // R viene en Q2.14 y la salida es Q1.15: hay que correr 1 a la
    // izquierda, y todo R >= 1.0 no entra en S(16,15) -> satura
    wire mod_ovf = |r14_5[15:14];

    always @(posedge clk) begin
        if (i_rst) begin
            o_result <= {NB_OUTPUT_MOD{1'b0}};
            o_phase  <= {NB_OUTPUT_PHA{1'b0}};
        end else begin
            o_result <= mod_ovf ? 16'sh7FFF : $signed({r14_5[14:0], 1'b0});
            o_phase  <= zer_p[4] ? 16'sd0
                                 : (sgn_p[4] ? -base : base);
        end
    end

endmodule