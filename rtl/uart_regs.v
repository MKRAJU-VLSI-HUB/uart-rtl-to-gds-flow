//-----------------------------------------------------------------------------
// uart_regs.v
// APB3 slave register block (zero wait state).
//
//  Offset  Name     Access  Description
//  0x00    TXDATA   W       push byte into TX FIFO
//  0x04    RXDATA   R       pop byte from RX FIFO (reads 0 when empty)
//  0x08    CTRL     RW      [0] TX_EN [1] RX_EN [2] PARITY_EN [3] PARITY_ODD
//                           [4] STOP2 [6:5] DATA_BITS (0:5..3:8) [7] LOOPBACK
//  0x0C    BAUD     RW      [15:0] divisor, baud = fclk / (16*(div+1))
//  0x10    STATUS   R       [0] TX_FULL [1] TX_EMPTY [2] RX_FULL [3] RX_EMPTY
//                           [4] TX_BUSY [5] RX_BUSY [12:8] TX_LVL [20:16] RX_LVL
//  0x14    IER      RW      interrupt enables, same bit order as ISR
//  0x18    ISR      R/W1C   [0] RX_AVAIL [1] TX_EMPTY (level, read only)
//                           [2] PARITY_ERR [3] FRAME_ERR [4] RX_OVERRUN
//                           [5] TX_OVERFLOW (sticky, write 1 to clear)
//  0x1C    -        -       unmapped, returns PSLVERR
//-----------------------------------------------------------------------------
module uart_regs (
    input  wire        pclk,
    input  wire        presetn,
    input  wire        psel,
    input  wire        penable,
    input  wire        pwrite,
    input  wire [4:0]  paddr,
    input  wire [31:0] pwdata,
    output reg  [31:0] prdata,
    output wire        pready,
    output wire        pslverr,
    // configuration
    output reg  [7:0]  ctrl,
    output reg  [15:0] baud_div,
    // TX FIFO write side
    output wire        tx_push,
    output wire [7:0]  tx_wdata,
    input  wire        tx_full,
    input  wire        tx_empty,
    input  wire [4:0]  tx_count,
    // RX FIFO read side
    output wire        rx_pop,
    input  wire [7:0]  rx_rdata,
    input  wire        rx_full,
    input  wire        rx_empty,
    input  wire [4:0]  rx_count,
    // engine status / events
    input  wire        tx_busy,
    input  wire        rx_busy,
    input  wire        rx_valid,
    input  wire        rx_parity_err,
    input  wire        rx_frame_err,
    output wire        irq
);

    localparam [2:0] A_TXDATA = 3'd0,
                     A_RXDATA = 3'd1,
                     A_CTRL   = 3'd2,
                     A_BAUD   = 3'd3,
                     A_STATUS = 3'd4,
                     A_IER    = 3'd5,
                     A_ISR    = 3'd6;

    wire [2:0] addr   = paddr[4:2];
    wire       access = psel & penable;
    wire       wr     = access &  pwrite;
    wire       rd     = access & ~pwrite;

    reg  [5:0] ier;
    reg  [3:0] sticky;   // {tx_ovf, rx_ovr, frame_err, parity_err}

    assign pready   = 1'b1;
    assign pslverr  = access & (addr == 3'd7);

    assign tx_push  = wr & (addr == A_TXDATA);
    assign tx_wdata = pwdata[7:0];
    assign rx_pop   = rd & (addr == A_RXDATA) & ~rx_empty;

    wire [5:0] isr = {sticky, tx_empty, ~rx_empty};
    assign irq = |(isr & ier);

    wire [31:0] status = {11'd0, rx_count, 3'd0, tx_count,
                          2'd0, rx_busy, tx_busy, rx_empty, rx_full,
                          tx_empty, tx_full};

    // control registers
    always @(posedge pclk or negedge presetn) begin
        if (!presetn) begin
            ctrl     <= 8'h60;       // 8N1, TX/RX disabled
            baud_div <= 16'd26;      // ~115200 baud @ 50 MHz
            ier      <= 6'd0;
        end else if (wr) begin
            case (addr)
                A_CTRL: ctrl     <= pwdata[7:0];
                A_BAUD: baud_div <= pwdata[15:0];
                A_IER:  ier      <= pwdata[5:0];
                default: ;
            endcase
        end
    end

    // sticky error flags: set has priority over write-1-to-clear
    wire [3:0] set_evt = { tx_push & tx_full,
                           rx_valid & rx_full,
                           rx_valid & rx_frame_err,
                           rx_valid & rx_parity_err };
    wire [3:0] clr_evt = (wr && addr == A_ISR) ? pwdata[5:2] : 4'd0;

    always @(posedge pclk or negedge presetn) begin
        if (!presetn)
            sticky <= 4'd0;
        else
            sticky <= set_evt | (sticky & ~clr_evt);
    end

    // read mux
    always @(*) begin
        case (addr)
            A_RXDATA: prdata = rx_empty ? 32'd0 : {24'd0, rx_rdata};
            A_CTRL:   prdata = {24'd0, ctrl};
            A_BAUD:   prdata = {16'd0, baud_div};
            A_STATUS: prdata = status;
            A_IER:    prdata = {26'd0, ier};
            A_ISR:    prdata = {26'd0, isr};
            default:  prdata = 32'd0;
        endcase
    end

endmodule
