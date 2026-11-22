//-----------------------------------------------------------------------------
// tb_top.sv - UVM testbench top
//-----------------------------------------------------------------------------
`timescale 1ns/1ps

module tb_top;
    import uvm_pkg::*;
    import uart_pkg::*;
    `include "uvm_macros.svh"

    logic pclk;
    logic presetn;

    // 100 MHz clock
    initial pclk = 1'b0;
    always #5 pclk = ~pclk;

    initial begin
        presetn = 1'b0;
        repeat (10) @(posedge pclk);
        presetn <= 1'b1;
    end

    apb_if  apb (.pclk(pclk), .presetn(presetn));
    uart_if uif (.clk(pclk),  .rst_n(presetn));

    uart_top dut (
        .pclk     (pclk),
        .presetn  (presetn),
        .psel     (apb.psel),
        .penable  (apb.penable),
        .pwrite   (apb.pwrite),
        .paddr    (apb.paddr),
        .pwdata   (apb.pwdata),
        .prdata   (apb.prdata),
        .pready   (apb.pready),
        .pslverr  (apb.pslverr),
        .uart_rxd (uif.rxd),
        .uart_txd (uif.txd),
        .irq      (uif.irq)
    );

    initial begin
        uvm_config_db#(virtual apb_if )::set(null, "*", "apb_vif",  apb);
        uvm_config_db#(virtual uart_if)::set(null, "*", "uart_vif", uif);
        run_test();
    end

    // global watchdog
    initial begin
        #200ms;
        `uvm_fatal("TB_TOP", "Global simulation timeout")
    end

endmodule
