//-----------------------------------------------------------------------------
// uart_baud_gen.v
// 16x oversampling baud-tick generator.
// tick16 is a single-cycle pulse every (divisor + 1) clock cycles.
//   baud_rate = f_clk / (16 * (divisor + 1))
//-----------------------------------------------------------------------------
module uart_baud_gen (
    input  wire        clk,
    input  wire        rst_n,
    input  wire [15:0] divisor,
    output reg         tick16
);

    reg [15:0] cnt;

    always @(posedge clk or negedge rst_n) begin
        if (!rst_n) begin
            cnt    <= 16'd0;
            tick16 <= 1'b0;
        end else if (cnt >= divisor) begin
            cnt    <= 16'd0;
            tick16 <= 1'b1;
        end else begin
            cnt    <= cnt + 16'd1;
            tick16 <= 1'b0;
        end
    end

endmodule
