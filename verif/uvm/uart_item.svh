//-----------------------------------------------------------------------------
// uart_item - one serial frame
// Stimulus fields are used by the driver, observed fields are filled by the
// monitor.
//-----------------------------------------------------------------------------
class uart_item extends uvm_sequence_item;
    // stimulus
    rand bit [7:0]    data;
    rand bit          bad_parity;   // flip the parity bit
    rand bit          bad_stop;     // drive stop bit low (framing error)
    rand bit          glitch;       // short low pulse instead of a frame
    rand int unsigned idle_bits;    // idle time after the frame

    // observed
    bit       perr;
    bit       ferr;
    bit       stop2_err;
    bit [1:0] data_bits;
    bit       parity_en;
    bit       parity_odd;
    bit       stop2;

    constraint c_default {
        idle_bits inside {[0:2]};
    }

    `uvm_object_utils_begin(uart_item)
        `uvm_field_int(data,       UVM_ALL_ON)
        `uvm_field_int(bad_parity, UVM_ALL_ON)
        `uvm_field_int(bad_stop,   UVM_ALL_ON)
        `uvm_field_int(perr,       UVM_ALL_ON)
        `uvm_field_int(ferr,       UVM_ALL_ON)
    `uvm_object_utils_end

    function new(string name = "uart_item");
        super.new(name);
    endfunction

    function string convert2string();
        return $sformatf("data=0x%02h (%0d bits) perr=%0b ferr=%0b",
                         data, data_bits + 5, perr, ferr);
    endfunction
endclass
