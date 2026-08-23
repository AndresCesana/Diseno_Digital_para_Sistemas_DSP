module artan #(
    parameter NB_OUTPUT_PHA = 16
)(
    input wire [3 : 0] index,
    output reg signed [NB_OUTPUT_PHA - 1 : 0] phase
);

    always @(*) begin
        case (index)
            4'd0 : phase = 12868;
            4'd1 : phase = 7596;
            4'd2 : phase = 4014;
            4'd3 : phase = 2037;
            4'd4 : phase = 1023;
            4'd5 : phase = 512;
            4'd6 : phase = 256;
            4'd7 : phase = 128;
            4'd8 : phase = 64;
            4'd9 : phase = 32;
            4'd10 : phase = 16;
            4'd11 : phase = 8;
            4'd12 : phase = 4;
            4'd13 : phase = 2;
            4'd14 : phase = 1;
            4'd15 : phase = 0;
            default: phase = {NB_OUTPUT_PHA{1'b0}};
        endcase
    end

endmodule

module cordic_vectorial #(
    parameter NB_INPUT = 16,
    parameter NBF_INPUT = 15,
    parameter NB_OUTPUT_MOD = 16,
    parameter NBF_OUTPUT_MOD = 15,
    parameter NB_OUTPUT_PHA = 16,
    parameter NBF_OUTPUT_PHA = 14,
    parameter N_ITER = 16
)(
    input wire clk,
    input wire i_rst,
    input wire i_valid,
    input wire signed [NB_INPUT - 1 : 0] i_x, i_y,
    output wire signed [NB_OUTPUT_MOD - 1 : 0] o_result,
    output wire signed [NB_OUTPUT_PHA - 1 : 0] o_phase,
    output wire o_valid 
);

    localparam NB_INT = NB_INPUT + 2; 

    reg signed [NB_INT - 1 : 0] x, y;
    reg signed [NB_OUTPUT_PHA - 1 : 0] z;
    reg [3:0]  iter;
    reg busy;
    reg done;
    reg zero_in;

    wire signed [NB_INT-1:0] x_ext = i_x;   // extension automatica
    wire signed [NB_INT-1:0] y_ext = i_y;
    wire neg = i_x[NB_INPUT-1];


    wire signed [NB_INT - 1 : 0] x_comp;
    wire [NB_INT - NB_OUTPUT_MOD : 0] chk = x_comp[NB_INT-1 : NB_OUTPUT_MOD-1];
    wire signed [NB_OUTPUT_PHA - 1: 0] angle;
    wire d;
    wire ovf;

    artan #(.NB_OUTPUT_PHA(NB_OUTPUT_PHA)) u_atan (
        .index (iter),
        .phase (angle)
    );

    assign d = ~y[NB_INT - 1];
    assign x_comp = (x>>>1) + (x>>>3) - (x>>>6) - (x>>>9) - (x>>>13);
    assign ovf = (|chk) & ~(&chk);

    always @(posedge clk) begin
        if (i_rst) begin
            busy <= 1'b0;
            iter <= 4'd0;
            x <= {NB_INT{1'b0}};
            y <= {NB_INT{1'b0}};
            z <= {NB_OUTPUT_PHA{1'b0}};
        end
        else if (!busy && i_valid) begin
            x <= neg ? -x_ext : x_ext;
            y <= neg ? -y_ext : y_ext;
            z <= {NB_OUTPUT_PHA{1'b0}};
            iter <= 4'd0;
            busy <= 1'b1;
            zero_in <= (i_x == 0) && (i_y == 0);
        end
        else if (busy) begin
            x <= d ? x + (y >>> iter): x - (y >>> iter);
            y <= d ? y - (x >>> iter): y + (x >>> iter);
            z <= d ? z + angle: z - angle;

            iter <= iter + 1;
            if (iter == N_ITER - 1) busy <= 1'b0;
        end
    end

    always @(posedge clk) begin
        if(i_rst) done <= 1'b0;
        else done <= busy && (iter == N_ITER - 1);
    end

    assign o_result = ovf ? (x_comp[NB_INT-1] ? {1'b1, {(NB_OUTPUT_MOD-1){1'b0}}}   // min
                                          : {1'b0, {(NB_OUTPUT_MOD-1){1'b1}}})  // max
                      : x_comp[NB_OUTPUT_MOD-1:0];
    assign o_phase = zero_in ? {NB_OUTPUT_PHA{1'b0}} : z;
    assign o_valid = done;

endmodule