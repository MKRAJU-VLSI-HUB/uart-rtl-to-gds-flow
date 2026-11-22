//-----------------------------------------------------------------------------
// uart_tx.v
// UART transmitter.
//   - 5/6/7/8 data bits (LSB first), optional even/odd parity, 1 or 2 stop bits
//   - frame configuration is latched at the start of every frame
//   - every bit lasts exactly 16 tick16 periods
//   - back-to-back frames are sent without idle gap when the FIFO has data
//-----------------------------------------------------------------------------
module uart_tx (
    input  wire       clk,
    input  wire       rst_n,
    input  wire       tick16,
    input  wire       tx_en,
    input  wire [1:0] data_bits,     // 00:5 01:6 10:7 11:8
    input  wire       parity_en,
    input  wire       parity_odd,
    input  wire       stop2,
    // TX FIFO read side
    input  wire       fifo_empty,
    input  wire [7:0] fifo_data,
    output reg        fifo_pop,
    // serial line
    output reg        txd,
    output wire       busy
);

    localparam [2:0] S_IDLE  = 3'd0,
                     S_START = 3'd1,
                     S_DATA  = 3'd2,
                     S_PAR   = 3'd3,
                     S_STOP  = 3'd4;

    reg [2:0] state;
    reg [3:0] tcnt;          // tick counter inside one bit
    reg [2:0] bcnt;          // data bit index
    reg [7:0] shreg;
    reg       par_bit;
    reg       stop_cnt;
    reg [1:0] db_q;
    reg       pen_q;
    reg       stop2_q;

    wire [7:0] mask      = (data_bits == 2'b00) ? 8'h1F :
                           (data_bits == 2'b01) ? 8'h3F :
                           (data_bits == 2'b10) ? 8'h7F : 8'hFF;
    wire       new_par   = (^(fifo_data & mask)) ^ parity_odd;
    wire [2:0] last_bit  = 3'd4 + {1'b0, db_q};
    wire       bit_end   = tick16 && (tcnt == 4'd15);
    wire       can_start = tx_en && !fifo_empty;

    assign busy = (state != S_IDLE);

    always @(posedge clk or negedge rst_n) begin
        if (!rst_n) begin
            state    <= S_IDLE;
            tcnt     <= 4'd0;
            bcnt     <= 3'd0;
            shreg    <= 8'd0;
            par_bit  <= 1'b0;
            stop_cnt <= 1'b0;
            db_q     <= 2'b11;
            pen_q    <= 1'b0;
            stop2_q  <= 1'b0;
            fifo_pop <= 1'b0;
        end else begin
            fifo_pop <= 1'b0;
            case (state)
                S_IDLE: begin
                    if (tick16 && can_start) begin
                        fifo_pop <= 1'b1;
                        shreg    <= fifo_data;
                        par_bit  <= new_par;
                        db_q     <= data_bits;
                        pen_q    <= parity_en;
                        stop2_q  <= stop2;
                        tcnt     <= 4'd0;
                        state    <= S_START;
                    end
                end

                S_START: begin
                    if (tick16) begin
                        tcnt <= tcnt + 4'd1;
                        if (tcnt == 4'd15) begin
                            bcnt  <= 3'd0;
                            state <= S_DATA;
                        end
                    end
                end

                S_DATA: begin
                    if (tick16) begin
                        tcnt <= tcnt + 4'd1;
                        if (tcnt == 4'd15) begin
                            shreg <= {1'b0, shreg[7:1]};
                            if (bcnt == last_bit) begin
                                stop_cnt <= 1'b0;
                                state    <= pen_q ? S_PAR : S_STOP;
                            end else begin
                                bcnt <= bcnt + 3'd1;
                            end
                        end
                    end
                end

                S_PAR: begin
                    if (tick16) begin
                        tcnt <= tcnt + 4'd1;
                        if (tcnt == 4'd15)
                            state <= S_STOP;
                    end
                end

                S_STOP: begin
                    if (tick16) begin
                        tcnt <= tcnt + 4'd1;
                        if (bit_end) begin
                            if (stop2_q && !stop_cnt) begin
                                stop_cnt <= 1'b1;
                            end else if (can_start) begin
                                // back-to-back frame, no idle gap
                                fifo_pop <= 1'b1;
                                shreg    <= fifo_data;
                                par_bit  <= new_par;
                                db_q     <= data_bits;
                                pen_q    <= parity_en;
                                stop2_q  <= stop2;
                                state    <= S_START;
                            end else begin
                                state    <= S_IDLE;
                            end
                        end
                    end
                end

                default: state <= S_IDLE;
            endcase
        end
    end

    // registered, glitch-free serial output
    always @(posedge clk or negedge rst_n) begin
        if (!rst_n)
            txd <= 1'b1;
        else begin
            case (state)
                S_START: txd <= 1'b0;
                S_DATA:  txd <= shreg[0];
                S_PAR:   txd <= par_bit;
                default: txd <= 1'b1;
            endcase
        end
    end

endmodule
