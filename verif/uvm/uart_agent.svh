//-----------------------------------------------------------------------------
// uart_agent - serial agent: driver on rxd + monitors on rxd and txd
//-----------------------------------------------------------------------------
typedef uvm_sequencer #(uart_item) uart_sequencer;

class uart_agent extends uvm_agent;
    `uvm_component_utils(uart_agent)

    uart_sequencer sqr;
    uart_driver    drv;
    uart_monitor   tx_mon;   // observes DUT transmit line
    uart_monitor   rx_mon;   // observes DUT receive line (stimulus)

    function new(string name, uvm_component parent);
        super.new(name, parent);
    endfunction

    function void build_phase(uvm_phase phase);
        super.build_phase(phase);
        uvm_config_db#(bit)::set(this, "tx_mon", "watch_tx", 1'b1);
        uvm_config_db#(bit)::set(this, "rx_mon", "watch_tx", 1'b0);
        tx_mon = uart_monitor::type_id::create("tx_mon", this);
        rx_mon = uart_monitor::type_id::create("rx_mon", this);
        sqr    = uart_sequencer::type_id::create("sqr", this);
        drv    = uart_driver::type_id::create("drv", this);
    endfunction

    function void connect_phase(uvm_phase phase);
        drv.seq_item_port.connect(sqr.seq_item_export);
    endfunction
endclass
