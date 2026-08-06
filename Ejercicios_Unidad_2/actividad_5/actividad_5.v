// contador
`timescale 1ns/1ps

module actividad_5 #(
    parameter WIDTHin = 8,
    parameter WIDTHout = 16,
    parameter A=8'sd5,
    parameter B=8'sd3
    )(
    input  wire        clk,
    input  wire        rst,
    input  wire signed [WIDTHin-1:0]  x_in,
    output wire signed  [WIDTHout-1:0]  y_out,
    input  wire        valid_in,
    output wire        ready_out,
    output wire         valid_out,
    input  wire        ready_in
);
reg signed [8:0]  stage1;
reg signed [16:0] stage2;
reg signed [16:0] stage3;

reg valid1;
reg valid2;
reg valid3;
assign ready_out = ready_in;

assign y_out     = stage3;
assign valid_out = valid3; 
always @(posedge clk) begin
    if (rst) begin
    stage1    <= 0;
    stage2    <= 0;
    stage3    <= 0;
    valid1    <= 0;
    valid2    <= 0;
    valid3    <= 0;
    end else if (ready_in) begin
        if (valid_in)
            stage1 <= x_in + A;
        valid1 <= valid_in;

        if (valid1)
            stage2 <= stage1 * B;
        valid2 <= valid1;

        if (valid2)
            stage3 <= stage2 >>> 4;
        valid3 <= valid2;
                
    end
end

endmodule
