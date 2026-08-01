`timescale 1ns/1ps

module reg_ce #(
    parameter WIDTH = 8
) (
    input  wire                clk,
    input  wire                rst_n,
    input  wire                ce,
    input  wire  [WIDTH-1:0]   d,
    output reg   [WIDTH-1:0]   q
);

  always_ff @(posedge clk or negedge rst_n) begin
    if (!rst_n)
      q <= {WIDTH{1'b0}};
    else if (ce)
      q <= d;
    end

endmodule
