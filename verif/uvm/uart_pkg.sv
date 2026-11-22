//-----------------------------------------------------------------------------
// uart_pkg.sv - UVM verification package for the APB UART
//-----------------------------------------------------------------------------
package uart_pkg;
    import uvm_pkg::*;
    `include "uvm_macros.svh"

    // register map
    localparam bit [4:0] TXDATA = 5'h00;
    localparam bit [4:0] RXDATA = 5'h04;
    localparam bit [4:0] CTRL   = 5'h08;
    localparam bit [4:0] BAUD   = 5'h0C;
    localparam bit [4:0] STATUS = 5'h10;
    localparam bit [4:0] IER    = 5'h14;
    localparam bit [4:0] ISR    = 5'h18;
    localparam bit [4:0] UNMAP  = 5'h1C;

    `include "uart_cfg.svh"
    `include "apb_item.svh"
    `include "apb_driver.svh"
    `include "apb_monitor.svh"
    `include "apb_agent.svh"
    `include "uart_item.svh"
    `include "uart_driver.svh"
    `include "uart_monitor.svh"
    `include "uart_agent.svh"
    `include "uart_scoreboard.svh"
    `include "uart_coverage.svh"
    `include "uart_env.svh"
    `include "uart_seqs.svh"
    `include "uart_vseqs.svh"
    `include "uart_tests.svh"
endpackage
