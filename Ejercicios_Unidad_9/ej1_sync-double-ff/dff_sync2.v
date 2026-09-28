module dff_sync2 #(
    parameter TAU_DEMO = 0,
    parameter STAGES = 2
)(
    input wire dst_clk,
    input wire rst,
    input wire src_bit,
    output wire synced
);

    reg [STAGES-1:0] pipe;

    always @(posedge dst_clk) begin
        if(!rst) pipe <= {STAGES{1'b0}};
        else begin
            for (integer i = 0; i < STAGES - 1; i = i + 1) pipe[i+1] <= pipe[i];
            pipe[0] <= src_bit;
        end
    end

    assign synced = pipe[STAGES-1];

endmodule