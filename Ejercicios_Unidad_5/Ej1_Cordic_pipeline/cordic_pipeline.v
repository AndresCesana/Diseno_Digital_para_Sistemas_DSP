`timescale 1ns/1ps
module cordic_pipeline #(
    parameter NB = 16,
    parameter NBF = 14,
    parameter NITER = 14
)(
    input  logic                  clk,
    input  logic                  rst,
    input  logic                  valid_in,
    input  logic signed [NB-1:0]  theta,
    output logic                  valid_out,
    output logic signed [NB-1:0]  cos_out,
    output logic signed [NB-1:0]  sin_out
);
    localparam logic signed [NB-1:0] K = 16'sd9943;
    logic signed [NB-1:0] x_pipe [0:NITER];
    logic signed [NB-1:0] y_pipe [0:NITER];
    logic signed [NB-1:0] z_pipe [0:NITER];
    logic valid_pipe [0:NITER];
    logic signed [NB-1:0] atan_table [0:NITER-1];
    initial begin
        atan_table[0]  = 16'sd12868;
        atan_table[1]  = 16'sd7596;
        atan_table[2]  = 16'sd4014;
        atan_table[3]  = 16'sd2037;
        atan_table[4]  = 16'sd1023;
        atan_table[5]  = 16'sd512;
        atan_table[6]  = 16'sd256;
        atan_table[7]  = 16'sd128;
        atan_table[8]  = 16'sd64;
        atan_table[9]  = 16'sd32;
        atan_table[10] = 16'sd16;
        atan_table[11] = 16'sd8;
        atan_table[12] = 16'sd4;
        atan_table[13] = 16'sd2;
    end
    always_ff @(posedge clk) begin
        if (rst) begin
            x_pipe[0] <= '0;
            y_pipe[0] <= '0;
            z_pipe[0] <= '0;
            valid_pipe[0] <= 1'b0;
        end
        else begin
            x_pipe[0] <= K;
            y_pipe[0] <= 16'sd0;
            z_pipe[0] <= theta;
            valid_pipe[0] <= valid_in;
        end
    end
    genvar i;
    generate
        for (i = 0; i < NITER; i = i + 1) begin : CORDIC_STAGE
            always_ff @(posedge clk) begin
                if (rst) begin
                    x_pipe[i+1] <= '0;
                    y_pipe[i+1] <= '0;
                    z_pipe[i+1] <= '0;
                    valid_pipe[i+1] <= 1'b0;
                end
                else begin
                    if (z_pipe[i] >= 0) begin
                        x_pipe[i+1] <= x_pipe[i] -
                                       (y_pipe[i] >>> i);
                        y_pipe[i+1] <= y_pipe[i] +
                                       (x_pipe[i] >>> i);
                        z_pipe[i+1] <= z_pipe[i] -
                                       atan_table[i];
                    end
                    else begin
                        x_pipe[i+1] <= x_pipe[i] +
                                       (y_pipe[i] >>> i);
                        y_pipe[i+1] <= y_pipe[i] -
                                       (x_pipe[i] >>> i);
                        z_pipe[i+1] <= z_pipe[i] +
                                       atan_table[i];
                    end
                    valid_pipe[i+1] <= valid_pipe[i];
                end
            end
        end
    endgenerate
    assign cos_out   = x_pipe[NITER];
    assign sin_out   = y_pipe[NITER];
    assign valid_out = valid_pipe[NITER];
endmodule
