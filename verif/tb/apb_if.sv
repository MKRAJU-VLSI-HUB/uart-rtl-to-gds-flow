//-----------------------------------------------------------------------------
// apb_if.sv - APB3 bus interface
//-----------------------------------------------------------------------------
interface apb_if (input logic pclk, input logic presetn);
    logic        psel;
    logic        penable;
    logic        pwrite;
    logic [4:0]  paddr;
    logic [31:0] pwdata;
    logic [31:0] prdata;
    logic        pready;
    logic        pslverr;
endinterface
