`timescale 1ns/1ps

module detector_101(

    input wire clk,
    input wire rst_n, // asincrono, activo bajo
    input wire x,
    output logic y
);

    localparam S0 = 2'b00, S1 = 2'b01, S10 = 2'b10, S101 = 2'b11;
    logic [1:0] estado, prox_estado;

    always_ff @(posedge clk or negedge rst_n) begin
        if (!rst_n)
            estado <= S0;
        else
            estado <= prox_estado;
    end

    always_comb begin
        case (estado)
            S0: begin
                    if(x)
                        prox_estado = S1;
                    else
                        prox_estado = S0;
            end        
            S1: begin
                    if(x)
                        prox_estado = S1;
                    else
                        prox_estado = S10;
            end
            S10: begin 
                    if(x)
                        prox_estado = S101;
                    else
                        prox_estado = S0;
            end
            S101: begin
                    if(x)
                        prox_estado = S1;
                    else
                        prox_estado = S10;
            end
            default: prox_estado = S0;         
        endcase 
    end

    always_comb begin
        y = estado == S101 ? 1'b1 : 1'b0;
    end
endmodule