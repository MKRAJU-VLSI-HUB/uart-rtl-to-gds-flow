//-----------------------------------------------------------------------------
// uart_fifo.v
// Synchronous first-word-fall-through FIFO.
//   - push is ignored when full, pop is ignored when empty
//   - dout always shows the oldest entry (valid when !empty)
//-----------------------------------------------------------------------------
module uart_fifo #(
    parameter WIDTH = 8,
    parameter DEPTH = 16,
    parameter AW    = 4          // log2(DEPTH)
) (
    input  wire             clk,
    input  wire             rst_n,
    input  wire             push,
    input  wire [WIDTH-1:0] din,
    input  wire             pop,
    output wire [WIDTH-1:0] dout,
    output wire             full,
    output wire             empty,
    output reg  [AW:0]      count
);

    reg [WIDTH-1:0] mem [0:DEPTH-1];
    reg [AW-1:0]    wr_ptr;
    reg [AW-1:0]    rd_ptr;

    wire do_push = push & ~full;
    wire do_pop  = pop  & ~empty;

    assign full  = (count == DEPTH);
    assign empty = (count == 0);
    assign dout  = mem[rd_ptr];

    integer i;

    always @(posedge clk or negedge rst_n) begin
        if (!rst_n) begin
            wr_ptr <= {AW{1'b0}};
            for (i = 0; i < DEPTH; i = i + 1)
                mem[i] <= {WIDTH{1'b0}};
        end else if (do_push) begin
            mem[wr_ptr] <= din;
            wr_ptr      <= wr_ptr + 1'b1;
        end
    end

    always @(posedge clk or negedge rst_n) begin
        if (!rst_n)
            rd_ptr <= {AW{1'b0}};
        else if (do_pop)
            rd_ptr <= rd_ptr + 1'b1;
    end

    always @(posedge clk or negedge rst_n) begin
        if (!rst_n)
            count <= {(AW+1){1'b0}};
        else if (do_push && !do_pop)
            count <= count + 1'b1;
        else if (do_pop && !do_push)
            count <= count - 1'b1;
    end

endmodule
