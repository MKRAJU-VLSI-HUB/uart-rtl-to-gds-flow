//-----------------------------------------------------------------------------
// uart_cfg - serial frame / baud configuration
// One "live" instance is shared by the env (mirrors CTRL/BAUD as written on
// APB); sequences randomize their own instances to program the DUT.
//-----------------------------------------------------------------------------
class uart_cfg extends uvm_object;
    `uvm_object_utils(uart_cfg)

    rand bit [1:0]  data_bits;   // 0:5 1:6 2:7 3:8
    rand bit        parity_en;
    rand bit        parity_odd;
    rand bit        stop2;
    rand bit [15:0] divisor;
         bit        tx_en     = 1'b1;
         bit        rx_en     = 1'b1;
         bit        loopback  = 1'b0;

    constraint c_div { divisor inside {[0:7]}; }

    function new(string name = "uart_cfg");
        super.new(name);
        data_bits = 2'd3;
        divisor   = 16'd26;
    endfunction

    function int unsigned nbits();    return data_bits + 5;          endfunction
    function int unsigned bit_clks(); return 16 * (divisor + 1);     endfunction
    function bit [7:0]    mask();     return 8'hFF >> (3 - data_bits); endfunction

    function bit [7:0] ctrl_val();
        return {loopback, data_bits, stop2, parity_odd, parity_en, rx_en, tx_en};
    endfunction

    function void from_ctrl(bit [7:0] c);
        tx_en      = c[0];
        rx_en      = c[1];
        parity_en  = c[2];
        parity_odd = c[3];
        stop2      = c[4];
        data_bits  = c[6:5];
        loopback   = c[7];
    endfunction

    function string convert2string();
        return $sformatf("%0d%s%0d div=%0d tx_en=%0b rx_en=%0b lb=%0b",
                         nbits(), parity_en ? (parity_odd ? "O" : "E") : "N",
                         stop2 ? 2 : 1, divisor, tx_en, rx_en, loopback);
    endfunction

    function void do_copy(uvm_object rhs);
        uart_cfg c;
        super.do_copy(rhs);
        $cast(c, rhs);
        data_bits  = c.data_bits;
        parity_en  = c.parity_en;
        parity_odd = c.parity_odd;
        stop2      = c.stop2;
        divisor    = c.divisor;
        tx_en      = c.tx_en;
        rx_en      = c.rx_en;
        loopback   = c.loopback;
    endfunction
endclass
