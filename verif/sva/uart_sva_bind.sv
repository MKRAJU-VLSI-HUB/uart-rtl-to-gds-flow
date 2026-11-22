//-----------------------------------------------------------------------------
// uart_sva_bind.sv - binds the assertion module into every uart_top instance
//-----------------------------------------------------------------------------
module uart_sva_bind;

bind uart_top uart_sva u_sva (
    .pclk     (pclk),
    .presetn  (presetn),
    .psel     (psel),
    .penable  (penable),
    .pwrite   (pwrite),
    .paddr    (paddr),
    .pwdata   (pwdata),
    .prdata   (prdata),
    .pready   (pready),
    .pslverr  (pslverr),
    .ctrl     (ctrl),
    .baud_div (baud_div),
    .tick16   (tick16),
    .tx_push  (tx_push),
    .tx_pop   (tx_pop),
    .tx_full  (tx_full),
    .tx_empty (tx_empty),
    .tx_count (tx_count),
    .rx_push  (rx_push),
    .rx_pop   (rx_pop),
    .rx_full  (rx_full),
    .rx_empty (rx_empty),
    .rx_count (rx_count),
    .tx_busy  (tx_busy),
    .rx_busy  (rx_busy),
    .txd_int  (txd_int),
    .rx_valid (rx_valid),
    .rx_perr  (rx_perr),
    .rx_ferr  (rx_ferr),
    .sticky   (u_regs.sticky),
    .ier      (u_regs.ier),
    .uart_txd (uart_txd),
    .irq      (irq)
);

endmodule
