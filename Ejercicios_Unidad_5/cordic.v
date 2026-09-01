module cordic (
    input  logic               clk,
    input  logic               rst,
    input  logic               start,
    input  logic signed [15:0] theta,
    output logic signed [15:0] cos_out,
    output logic signed [15:0] sin_out,
    output logic               busy,
    output logic               done
);
    localparam int NB  = 16;
    localparam int NBF = 14;
    localparam int NITER = 14;
    localparam logic signed [15:0] K = 16'sd9943;

    typedef enum logic [1:0] {
        IDLE,
        ITER,
        DONE
    } state_t;
    state_t state;

    logic signed [15:0] x_reg;
    logic signed [15:0] y_reg;
    logic signed [15:0] z_reg;
    logic signed [15:0] x_next;
    logic signed [15:0] y_next;
    logic signed [15:0] z_next;
    logic [3:0] iter;
    logic signed [15:0] atan_value;
    atan_rom ROM (
        .addr(iter),
        .atan_value(atan_value)
    );
    always_comb begin
        if (z_reg >= 0) begin
            x_next = x_reg - (y_reg >>> iter);
            y_next = y_reg + (x_reg >>> iter);
            z_next = z_reg - atan_value;
        end
        else begin
            x_next = x_reg + (y_reg >>> iter);
            y_next = y_reg - (x_reg >>> iter);
            z_next = z_reg + atan_value;
        end
    end
    always_ff @(posedge clk) begin
        if (rst) begin
            state   <= IDLE;
            x_reg   <= 16'sd0;
            y_reg   <= 16'sd0;
            z_reg   <= 16'sd0;
            iter    <= 4'd0;
            cos_out <= 16'sd0;
            sin_out <= 16'sd0;
            busy <= 1'b0;
            done <= 1'b0;
        end
        else begin
            case (state)
                IDLE: begin
                    done <= 1'b0;
                    busy <= 1'b0;
                    if (start) begin
                        x_reg <= K;
                        y_reg <= 16'sd0;
                        z_reg <= theta;
                        iter <= 4'd0;
                        busy <= 1'b1;
                        state <= ITER;
                    end
                end
                ITER: begin
                    x_reg <= x_next;
                    y_reg <= y_next;
                    z_reg <= z_next;
                    if (iter == NITER-1) begin
                        cos_out <= x_next;
                        sin_out <= y_next;
                        busy <= 1'b0;
                        state <= DONE;
                    end
                    else begin
                        iter <= iter + 1'b1;
                    end
                end
                DONE: begin
                    done <= 1'b1;
                    state <= IDLE;
                end
            endcase
        end
    end
endmodule