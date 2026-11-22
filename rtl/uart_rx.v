//-----------------------------------------------------------------------------
// uart_rx.v
// UART receiver with 16x oversampling.
//   - 2-flop synchronizer on the serial input
//   - start bit validated at its centre (glitch rejection)
//   - data/parity/stop sampled at bit centre
//   - a new start bit is only accepted after the line was seen idle (high),
//     so a held-low line (break / framing error) does not cause false frames
//   - rx_valid pulses for one cycle with data and error flags
//-----------------------------------------------------------------------------
module uart_rx (
    input  wire       clk,
    input  wire       rst_n,
    input  wire       tick16,
    input  wire       rx_en,
    input  wire [1:0] data_bits,     // 00:5 01:6 10:7 11:8
    input  wire       parity_en,
    input  wire       parity_odd,
    input  wire       rxd,
    output reg  [7:0] rx_data,
    output reg        rx_valid,
    output reg        parity_err,
    output reg        frame_err,
    output wire       busy
);

    localparam [2:0] S_IDLE  = 3'd0,
                     S_START = 3'd1,
                     S_DATA  = 3'd2,
                     S_PAR   = 3'd3,
                     S_STOP  = 3'd4;

    // input synchronizer (reset to idle level)
    reg rxd_m, rxd_s;
    always @(posedge clk or negedge rst_n) begin
        if (!rst_n) begin
            rxd_m <= 1'b1;
            rxd_s <= 1'b1;
        end else begin
            rxd_m <= rxd;
            rxd_s <= rxd_m;
        end
    end

    reg [2:0] state;
    reg [3:0] tcnt;
    reg [2:0] bcnt;
    reg [7:0] shreg;
    reg       par_acc;
    reg       perr_q;
    reg       armed;
    reg [1:0] db_q;
    reg       pen_q;
    reg       podd_q;

    wire [2:0] last_bit = 3'd4 + {1'b0, db_q};

    assign busy = (state != S_IDLE);

    // align received bits to LSB according to the frame length
    reg [7:0] aligned;
    always @(*) begin
        case (db_q)
            2'b00:   aligned = {3'b000, shreg[7:3]};
            2'b01:   aligned = {2'b00,  shreg[7:2]};
            2'b10:   aligned = {1'b0,   shreg[7:1]};
            default: aligned = shreg;
        endcase
    end

    always @(posedge clk or negedge rst_n) begin
        if (!rst_n) begin
            state      <= S_IDLE;
            tcnt       <= 4'd0;
            bcnt       <= 3'd0;
            shreg      <= 8'd0;
            par_acc    <= 1'b0;
            perr_q     <= 1'b0;
            armed      <= 1'b0;
            db_q       <= 2'b11;
            pen_q      <= 1'b0;
            podd_q     <= 1'b0;
            rx_data    <= 8'd0;
            rx_valid   <= 1'b0;
            parity_err <= 1'b0;
            frame_err  <= 1'b0;
        end else begin
            rx_valid   <= 1'b0;
            parity_err <= 1'b0;
            frame_err  <= 1'b0;

            case (state)
                S_IDLE: begin
                    if (tick16) begin
                        if (rxd_s)
                            armed <= 1'b1;
                        else if (armed && rx_en) begin
                            armed  <= 1'b0;
                            tcnt   <= 4'd0;
                            db_q   <= data_bits;
                            pen_q  <= parity_en;
                            podd_q <= parity_odd;
                            state  <= S_START;
                        end
                    end
                end

                S_START: begin
                    if (tick16) begin
                        if (tcnt == 4'd7) begin
                            tcnt <= 4'd0;
                            if (!rxd_s) begin
                                bcnt    <= 3'd0;
                                par_acc <= 1'b0;
                                state   <= S_DATA;
                            end else begin
                                state   <= S_IDLE;   // glitch, not a start bit
                            end
                        end else begin
                            tcnt <= tcnt + 4'd1;
                        end
                    end
                end

                S_DATA: begin
                    if (tick16) begin
                        tcnt <= tcnt + 4'd1;
                        if (tcnt == 4'd15) begin
                            shreg   <= {rxd_s, shreg[7:1]};
                            par_acc <= par_acc ^ rxd_s;
                            if (bcnt == last_bit)
                                state <= pen_q ? S_PAR : S_STOP;
                            else
                                bcnt  <= bcnt + 3'd1;
                        end
                    end
                end

                S_PAR: begin
                    if (tick16) begin
                        tcnt <= tcnt + 4'd1;
                        if (tcnt == 4'd15) begin
                            perr_q <= par_acc ^ rxd_s ^ podd_q;
                            state  <= S_STOP;
                        end
                    end
                end

                S_STOP: begin
                    if (tick16) begin
                        tcnt <= tcnt + 4'd1;
                        if (tcnt == 4'd15) begin
                            rx_data    <= aligned;
                            rx_valid   <= 1'b1;
                            parity_err <= pen_q & perr_q;
                            frame_err  <= ~rxd_s;
                            perr_q     <= 1'b0;
                            state      <= S_IDLE;
                        end
                    end
                end

                default: state <= S_IDLE;
            endcase
        end
    end

endmodule
