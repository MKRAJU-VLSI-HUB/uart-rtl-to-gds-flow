//-----------------------------------------------------------------------------
// uart_sva.sv - SystemVerilog assertions for uart_top (bound, white-box)
//-----------------------------------------------------------------------------
module uart_sva (
    input logic        pclk,
    input logic        presetn,
    // APB
    input logic        psel,
    input logic        penable,
    input logic        pwrite,
    input logic [4:0]  paddr,
    input logic [31:0] pwdata,
    input logic [31:0] prdata,
    input logic        pready,
    input logic        pslverr,
    // internals
    input logic [7:0]  ctrl,
    input logic [15:0] baud_div,
    input logic        tick16,
    input logic        tx_push,
    input logic        tx_pop,
    input logic        tx_full,
    input logic        tx_empty,
    input logic [4:0]  tx_count,
    input logic        rx_push,
    input logic        rx_pop,
    input logic        rx_full,
    input logic        rx_empty,
    input logic [4:0]  rx_count,
    input logic        tx_busy,
    input logic        rx_busy,
    input logic        txd_int,
    input logic        rx_valid,
    input logic        rx_perr,
    input logic        rx_ferr,
    input logic [3:0]  sticky,
    input logic [5:0]  ier,
    // pins
    input logic        uart_txd,
    input logic        irq
);

    wire apb_access = psel && penable;
    wire isr_w1c    = apb_access && pwrite && (paddr[4:2] == 3'd6);

    default clocking cb @(posedge pclk); endclocking

    //------------------------------------------------------------------ APB
    a_apb_pready     : assert property (disable iff (!presetn) pready === 1'b1)
                       else $error("PREADY must always be high");
    a_apb_slverr_acc : assert property (disable iff (!presetn) pslverr |-> apb_access)
                       else $error("PSLVERR outside access phase");
    a_apb_unmapped   : assert property (disable iff (!presetn) apb_access && paddr[4:2] == 3'd7 |-> pslverr)
                       else $error("no PSLVERR for unmapped address");
    a_apb_mapped_ok  : assert property (disable iff (!presetn) apb_access && paddr[4:2] != 3'd7 |-> !pslverr)
                       else $error("PSLVERR for mapped address");
    a_apb_rdata_known: assert property (disable iff (!presetn) apb_access && !pwrite |-> !$isunknown(prdata))
                       else $error("PRDATA unknown during read");
    a_apb_penable    : assert property (disable iff (!presetn) penable |-> psel)
                       else $error("PENABLE without PSEL");
    a_apb_setup      : assert property (disable iff (!presetn) $rose(penable) |-> $past(psel && !penable))
                       else $error("access phase not preceded by setup phase");

    //---------------------------------------------------------------- FIFOs
    a_tx_cnt_max     : assert property (disable iff (!presetn) tx_count <= 5'd16);
    a_rx_cnt_max     : assert property (disable iff (!presetn) rx_count <= 5'd16);
    a_tx_flags       : assert property (disable iff (!presetn) !(tx_full && tx_empty));
    a_rx_flags       : assert property (disable iff (!presetn) !(rx_full && rx_empty));
    a_tx_empty_cnt   : assert property (disable iff (!presetn) tx_empty == (tx_count == 0));
    a_rx_full_cnt    : assert property (disable iff (!presetn) rx_full  == (rx_count == 16));
    a_tx_cnt_inc     : assert property (disable iff (!presetn) tx_push && !tx_full && !tx_pop |=> tx_count == $past(tx_count) + 1)
                       else $error("TX FIFO count did not increment on push");
    a_tx_cnt_hold_f  : assert property (disable iff (!presetn) tx_push && tx_full && !tx_pop |=> tx_count == 5'd16)
                       else $error("TX FIFO accepted data while full");
    a_rx_cnt_dec     : assert property (disable iff (!presetn) rx_pop && !rx_push |=> rx_count == $past(rx_count) - 1)
                       else $error("RX FIFO count did not decrement on pop");
    a_rx_cnt_hold_f  : assert property (disable iff (!presetn) rx_push && rx_full && !rx_pop |=> rx_count == 5'd16)
                       else $error("RX FIFO accepted data while full");
    a_tx_pop_safe    : assert property (disable iff (!presetn) tx_pop |-> !tx_empty)
                       else $error("transmitter popped an empty FIFO");
    a_rx_pop_safe    : assert property (disable iff (!presetn) rx_pop |-> !rx_empty);

    //----------------------------------------------------------------- baud
    a_tick_pulse     : assert property (disable iff (!presetn) baud_div != 0 && tick16 |=> !tick16)
                       else $error("tick16 wider than one cycle");
    a_tick_div0      : assert property (disable iff (!presetn) baud_div == 0 && $past(baud_div == 0) && $past(presetn) |-> tick16);

    //---------------------------------------------------------- transmitter
    a_txd_idle_high  : assert property (disable iff (!presetn) !tx_busy && !$past(tx_busy) |-> txd_int)
                       else $error("txd not idle-high while transmitter idle");
    a_txd_on_tick    : assert property (disable iff (!presetn) $changed(txd_int) |-> $past(tick16, 2))
                       else $error("txd changed off the bit-tick grid");
    a_tx_start_bit   : assert property (disable iff (!presetn) tx_pop |=> !txd_int)
                       else $error("no start bit after FIFO pop");
    a_tx_needs_en    : assert property (disable iff (!presetn) $rose(tx_busy) |-> $past(ctrl[0]))
                       else $error("frame started with TX disabled");

    //------------------------------------------------------------- receiver
    a_rx_valid_pulse : assert property (disable iff (!presetn) rx_valid |=> !rx_valid);
    a_rx_err_qual    : assert property (disable iff (!presetn) rx_perr || rx_ferr |-> rx_valid)
                       else $error("error flag without rx_valid");
    a_rx_perr_cfg    : assert property (disable iff (!presetn) rx_perr |-> ctrl[2])
                       else $error("parity error reported with parity disabled");
    a_rx_needs_en    : assert property (disable iff (!presetn) $rose(rx_busy) |-> $past(ctrl[1]))
                       else $error("reception started with RX disabled");

    //------------------------------------------------------- status / irq
    a_overrun_flag   : assert property (disable iff (!presetn) rx_valid && rx_full |=> sticky[2])
                       else $error("RX overrun not flagged");
    a_overflow_flag  : assert property (disable iff (!presetn) tx_push && tx_full |=> sticky[3])
                       else $error("TX overflow not flagged");
    a_perr_flag      : assert property (disable iff (!presetn) rx_valid && rx_perr |=> sticky[0]);
    a_ferr_flag      : assert property (disable iff (!presetn) rx_valid && rx_ferr |=> sticky[1]);
    a_irq_func       : assert property (disable iff (!presetn) irq == |({sticky, tx_empty, ~rx_empty} & ier))
                       else $error("irq does not match ISR & IER");

    genvar g;
    generate
        for (g = 0; g < 4; g++) begin : g_sticky
            a_sticky_hold : assert property (disable iff (!presetn) $fell(sticky[g]) |-> $past(isr_w1c && pwdata[g+2]))
                            else $error("sticky ISR bit %0d cleared without W1C", g + 2);
        end
    endgenerate

    a_loopback_txd   : assert property (disable iff (!presetn) ctrl[7] |-> uart_txd)
                       else $error("txd pin not held idle in loopback");

    //---------------------------------------------------------------- reset
    a_reset_txd      : assert property (@(posedge pclk) !presetn |-> uart_txd && !irq);

    //-------------------------------------------------------------- covers
    c_tx_back2back   : cover property (disable iff (!presetn) $past(tx_busy) && tx_pop);
    c_tx_full        : cover property (disable iff (!presetn) tx_push && tx_full);
    c_rx_full        : cover property (disable iff (!presetn) rx_valid && rx_full);
    c_parity_err     : cover property (disable iff (!presetn) rx_valid && rx_perr);
    c_frame_err      : cover property (disable iff (!presetn) rx_valid && rx_ferr);
    c_both_err       : cover property (disable iff (!presetn) rx_valid && rx_perr && rx_ferr);
    c_loopback_rx    : cover property (disable iff (!presetn) ctrl[7] && rx_valid);
    c_rx_glitch      : cover property (disable iff (!presetn) $rose(rx_busy) ##[1:200] $fell(rx_busy) && !rx_valid);
    c_duplex         : cover property (disable iff (!presetn) tx_busy && rx_busy);
    c_irq            : cover property (disable iff (!presetn) $rose(irq));

endmodule
