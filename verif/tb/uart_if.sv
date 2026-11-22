//-----------------------------------------------------------------------------
// uart_if.sv - serial line + interrupt interface
//-----------------------------------------------------------------------------
interface uart_if (input logic clk, input logic rst_n);
    logic rxd;      // driven by the testbench (DUT receive input)
    logic txd;      // driven by the DUT
    logic irq;      // DUT interrupt
endinterface
