// bloqueante vs no bloqueante
`timescale 1ns/1ps

module actividad_1 (
  input  wire        clk,
  input  wire        rst_n,
  output reg  [1:0]  a1,
  output reg  [1:0]  b1,
  output reg  [1:0]  c1,
  output reg  [1:0]  a2,
  output reg  [1:0]  b2,
  output reg  [1:0]  c2
);

  always @(posedge clk or negedge rst_n) begin
    if (!rst_n) begin
      a1 <= 2'd1;
      b1 <= 2'd2;
      c1 <= 2'd3;
      a2 <= 2'd1;
      b2 <= 2'd2;
      c2 <= 2'd3;
    end else begin
      // Blocking — orden importa
      a1 = b1;
      b1 = c1;
      c1 = a1;
      a2 <= b2;
      b2 <= c2;
      c2 <= a2;
    end
  end

endmodule
