module atan_rom (
    input  logic [3:0] addr,
    output logic signed [15:0] atan_value
);

    always_comb begin
        case (addr)
            4'd0:  atan_value = 16'sd12868;
            4'd1:  atan_value = 16'sd7596;
            4'd2:  atan_value = 16'sd4014;
            4'd3:  atan_value = 16'sd2037;
            4'd4:  atan_value = 16'sd1023;
            4'd5:  atan_value = 16'sd512;
            4'd6:  atan_value = 16'sd256;
            4'd7:  atan_value = 16'sd128;
            4'd8:  atan_value = 16'sd64;
            4'd9:  atan_value = 16'sd32;
            4'd10: atan_value = 16'sd16;
            4'd11: atan_value = 16'sd8;
            4'd12: atan_value = 16'sd4;
            4'd13: atan_value = 16'sd2;
            default: atan_value = 16'sd0;
        endcase
    end

endmodule