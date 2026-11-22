//-----------------------------------------------------------------------------
// uart_top.v
// APB3 UART controller - top level
//   APB3 register interface, 16-deep TX and RX FIFOs, programmable baud rate,
//   5-8 data bits, none/even/odd parity, 1/2 stop bits, internal loopback,
//   maskable interrupt.
//-----------------------------------------------------------------------------
module uart_top (
    input  wire        pclk,
    input  wire        presetn,
    // APB3 slave
    input  wire        psel,
    input  wire        penable,
    input  wire        pwrite,
    input  wire [4:0]  paddr,
    input  wire [31:0] pwdata,
    output wire [31:0] prdata,
    output wire        pready,
    output wire        pslverr,
    // serial interface
    input  wire        uart_rxd,
    output wire        uart_txd,
    // interrupt
    output wire        irq
);

    wire [7:0]  ctrl;
    wire [15:0] baud_div;

    wire tx_en      = ctrl[0];
    wire rx_en      = ctrl[1];
    wire parity_en  = ctrl[2];
    wire parity_odd = ctrl[3];
    wire stop2      = ctrl[4];
    wire [1:0] data_bits = ctrl[6:5];
    wire loopback   = ctrl[7];

    wire       tick16;

    wire       tx_push, tx_pop, tx_full, tx_empty;
    wire [7:0] tx_wdata, tx_rdata;
    wire [4:0] tx_count;

    wire       rx_push, rx_pop, rx_full, rx_empty;
    wire [7:0] rx_rdata, rx_byte;
    wire [4:0] rx_count;

    wire       rx_valid, rx_perr, rx_ferr;
    wire       tx_busy, rx_busy;
    wire       txd_int;

    assign rx_push  = rx_valid;
    assign uart_txd = loopback ? 1'b1 : txd_int;
    wire   rxd_int  = loopback ? txd_int : uart_rxd;

    uart_regs u_regs (
        .pclk          (pclk),
        .presetn       (presetn),
        .psel          (psel),
        .penable       (penable),
        .pwrite        (pwrite),
        .paddr         (paddr),
        .pwdata        (pwdata),
        .prdata        (prdata),
        .pready        (pready),
        .pslverr       (pslverr),
        .ctrl          (ctrl),
        .baud_div      (baud_div),
        .tx_push       (tx_push),
        .tx_wdata      (tx_wdata),
        .tx_full       (tx_full),
        .tx_empty      (tx_empty),
        .tx_count      (tx_count),
        .rx_pop        (rx_pop),
        .rx_rdata      (rx_rdata),
        .rx_full       (rx_full),
        .rx_empty      (rx_empty),
        .rx_count      (rx_count),
        .tx_busy       (tx_busy),
        .rx_busy       (rx_busy),
        .rx_valid      (rx_valid),
        .rx_parity_err (rx_perr),
        .rx_frame_err  (rx_ferr),
        .irq           (irq)
    );

    uart_baud_gen u_baud (
        .clk     (pclk),
        .rst_n   (presetn),
        .divisor (baud_div),
        .tick16  (tick16)
    );

    uart_fifo #(.WIDTH(8), .DEPTH(16), .AW(4)) u_tx_fifo (
        .clk   (pclk),
        .rst_n (presetn),
        .push  (tx_push),
        .din   (tx_wdata),
        .pop   (tx_pop),
        .dout  (tx_rdata),
        .full  (tx_full),
        .empty (tx_empty),
        .count (tx_count)
    );

    uart_fifo #(.WIDTH(8), .DEPTH(16), .AW(4)) u_rx_fifo (
        .clk   (pclk),
        .rst_n (presetn),
        .push  (rx_push),
        .din   (rx_byte),
        .pop   (rx_pop),
        .dout  (rx_rdata),
        .full  (rx_full),
        .empty (rx_empty),
        .count (rx_count)
    );

    uart_tx u_tx (
        .clk        (pclk),
        .rst_n      (presetn),
        .tick16     (tick16),
        .tx_en      (tx_en),
        .data_bits  (data_bits),
        .parity_en  (parity_en),
        .parity_odd (parity_odd),
        .stop2      (stop2),
        .fifo_empty (tx_empty),
        .fifo_data  (tx_rdata),
        .fifo_pop   (tx_pop),
        .txd        (txd_int),
        .busy       (tx_busy)
    );

    uart_rx u_rx (
        .clk        (pclk),
        .rst_n      (presetn),
        .tick16     (tick16),
        .rx_en      (rx_en),
        .data_bits  (data_bits),
        .parity_en  (parity_en),
        .parity_odd (parity_odd),
        .rxd        (rxd_int),
        .rx_data    (rx_byte),
        .rx_valid   (rx_valid),
        .parity_err (rx_perr),
        .frame_err  (rx_ferr),
        .busy       (rx_busy)
    );

endmodule
