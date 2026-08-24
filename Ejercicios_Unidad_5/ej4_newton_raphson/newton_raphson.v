module lut #(
    parameter WIDTH = 16
)(
    input wire [2:0] idx,
    output reg [WIDTH - 1 : 0] out
);
    always @(*) begin
        case (idx)
            3'b000: out = 61681;
            3'b001: out = 55188;
            3'b010: out = 49932;
            3'b011: out = 45590;
            3'b100: out = 41943;
            3'b101: out = 38836;
            3'b110: out = 36158;
            3'b111: out = 33825;
            default: out = {WIDTH{1'b0}};
        endcase
    end    
endmodule

module newton_raphson #(
    parameter N_ITER = 4,
    parameter WIDTH = 16
)(
    input wire clk, rst_n, start,
    input wire [WIDTH - 1 : 0] a,
    output reg done,
    output reg [WIDTH - 1 : 0] y
);
    localparam IDLE = 2'b00; 
    localparam INIT = 2'b01;
    localparam ITER = 2'b10;
    localparam DONE = 2'b11;
    reg [1:0] status;

    wire sel = (status == INIT);                        
    wire en  = (status == INIT) || (status == ITER);    

    reg [WIDTH - 1 : 0] a_reg;
    reg [WIDTH - 1 : 0] y_reg;
    wire [WIDTH - 1 : 0] y_lut;
    lut #(.WIDTH(WIDTH)) u_lut (.idx(a_reg[14:12]), .out(y_lut));
    wire [2*WIDTH-1:0] p1   = a_reg * y_reg;           
    wire [2*WIDTH-1:0] d    = -p1;                      
    wire [WIDTH:0] d_r = (d + (1 << (WIDTH-1))) >> WIDTH;
    wire [WIDTH-1:0] d16 = d_r[WIDTH] ? {WIDTH{1'b1}} : d_r[WIDTH-1:0];
    wire [2*WIDTH-1:0] p2   = y_reg * d16;              
    wire [WIDTH:0] y_full = (p2 + (1 << (WIDTH-2))) >> (WIDTH-1);
    wire [WIDTH-1:0] y_next = y_full[WIDTH] ? {WIDTH{1'b1}} : y_full[WIDTH-1:0];
    wire [WIDTH - 1 : 0] y_in = sel ? y_lut : y_next;

    reg [$clog2(N_ITER+1)-1:0] iter;

    always @(posedge clk) begin
        if(!rst_n) begin
            status <= IDLE; iter <= 0; done <= 1'b0; y_reg <= 0;
        end else begin
            if (en) y_reg <= y_in;
            case (status)
                IDLE: if(start) begin 
                    a_reg <= a; status <= INIT;
                    iter <= 0; end
                INIT: begin  
                        status <= ITER; end 
                ITER: begin
                        iter <= iter + 1;
                        status <= (iter == N_ITER - 1) ? DONE : ITER; end
                DONE: begin 
                        y <= y_reg; done <= 1'b1;
                        if(start) begin
                            status <= IDLE; done <= 1'b0; end end
                default: status <= IDLE;
            endcase
        end
    end
endmodule

