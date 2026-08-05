// contador
`timescale 1ns/1ps

module actividad_3 (
  input  wire        clk,
  input  wire        rst,
  input  wire        en,
  output reg  [3:0]  count,
  output reg         tc
);

always @(posedge clk) begin

    tc <= 1'b0;   // por defecto no hay terminal count

    if (rst) begin
        count <= 4'd0;
    end
    else if (en) begin

        if (count < 4'd9) begin
            count <= count + 4'd1;
        end
        else begin
            count <= 4'd0;
            tc <= 1'b1;
        end

    end

end

endmodule
