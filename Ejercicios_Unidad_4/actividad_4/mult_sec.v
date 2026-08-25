module mult_sec #(
    parameter integer N = 8
)(
    input  wire                   clk,
    input  wire                   rst,
    input  wire                   start,

    input  wire unsigned [N-1:0] A,
    input  wire unsigned [N-1:0] B,

    output reg unsigned [2*N-1:0] producto,
    output reg                    done
);

    // Registros del multiplicador
    reg unsigned [2*N-1:0] acc;
    reg unsigned [2*N-1:0] A_shift;
    reg unsigned [N-1:0]   B_shift;

    // Contador de ciclos
    reg [3:0] count;

    // Estados de la FSM
    localparam IDLE    = 2'b00;
    localparam COMPUTE = 2'b01;
    localparam DONE    = 2'b10;

    reg [1:0] state;

    always @(posedge clk) begin

        if (rst) begin
            state    <= IDLE;
            acc      <= 0;
            A_shift  <= 0;
            B_shift  <= 0;
            count    <= 0;
            producto <= 0;
            done     <= 0;

        end else begin

            case (state)

                IDLE: begin
                    done <= 0;

                    if (start) begin
                        acc     <= 0;
                        A_shift <= A;
                        B_shift <= B;
                        count   <= 0;

                        state <= COMPUTE;
                    end
                end

                COMPUTE: begin

                    if (B_shift[0]) begin
                        acc <= acc + A_shift;
                    end

                    A_shift <= A_shift << 1;
                    B_shift <= B_shift >> 1;

                    count <= count + 1;

                    if (count == N-1) begin
                        state <= DONE;
                    end
                end

                DONE: begin
                    producto <= acc;
                    done     <= 1;

                    state <= IDLE;
                end

                default: begin
                    state <= IDLE;
                end

            endcase
        end
    end

endmodule