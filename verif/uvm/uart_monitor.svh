//-----------------------------------------------------------------------------
// uart_monitor - decodes serial frames on one line (txd or rxd)
//   ap       : completed frame (data aligned to LSB, parity/stop status)
//   ap_start : start-bit detected (used to model TX FIFO occupancy)
// Data and parity are sampled at bit centre, the stop bit at 1/4 bit so the
// frame is published before the DUT itself completes the stop bit.
//-----------------------------------------------------------------------------
class uart_monitor extends uvm_monitor;
    `uvm_component_utils(uart_monitor)

    virtual uart_if vif;
    uart_cfg        cfg;
    bit             watch_tx = 1'b1;   // 1: monitor DUT txd, 0: monitor rxd

    uvm_analysis_port #(uart_item) ap;
    uvm_analysis_port #(uart_item) ap_start;

    int unsigned n_frames;

    function new(string name, uvm_component parent);
        super.new(name, parent);
        ap       = new("ap", this);
        ap_start = new("ap_start", this);
    endfunction

    function void build_phase(uvm_phase phase);
        super.build_phase(phase);
        if (!uvm_config_db#(virtual uart_if)::get(this, "", "uart_vif", vif))
            `uvm_fatal("NOVIF", "uart_vif not found")
        if (!uvm_config_db#(uart_cfg)::get(this, "", "cfg", cfg))
            `uvm_fatal("NOCFG", "cfg not found")
        void'(uvm_config_db#(bit)::get(this, "", "watch_tx", watch_tx));
    endfunction

    function logic line();
        return watch_tx ? vif.txd : vif.rxd;
    endfunction

    task run_phase(uvm_phase phase);
        uart_item    t;
        int unsigned bc, nb;
        bit [7:0]    d;
        bit          p;

        wait (vif.rst_n === 1'b1);
        forever begin
            // wait for idle, then a falling edge
            do @(posedge vif.clk); while (line() !== 1'b1);
            do @(posedge vif.clk); while (line() !== 1'b0);

            bc = cfg.bit_clks();
            nb = cfg.nbits();
            t  = uart_item::type_id::create("t");
            t.data_bits  = cfg.data_bits;
            t.parity_en  = cfg.parity_en;
            t.parity_odd = cfg.parity_odd;
            t.stop2      = cfg.stop2;
            ap_start.write(t);   // start edge = DUT has just popped its FIFO

            // centre of start bit
            repeat (bc / 2 - 1) @(posedge vif.clk);
            if (line() !== 1'b0) begin
                `uvm_info("UART_MON", "start-bit glitch ignored", UVM_HIGH)
                continue;
            end

            d = '0;
            for (int i = 0; i < nb; i++) begin
                repeat (bc) @(posedge vif.clk);
                d[i] = line();
            end
            t.data = d;
            if (t.parity_en) begin
                repeat (bc) @(posedge vif.clk);
                p      = line();
                t.perr = (^d) ^ p ^ t.parity_odd;
            end
            repeat ((3 * bc) / 4) @(posedge vif.clk);
            t.ferr = (line() !== 1'b1);
            if (t.stop2 && watch_tx) begin
                repeat (bc) @(posedge vif.clk);
                t.stop2_err = (line() !== 1'b1);
            end
            n_frames++;
            `uvm_info("UART_MON", {watch_tx ? "TX " : "RX ", t.convert2string()}, UVM_HIGH)
            ap.write(t);
        end
    endtask
endclass
