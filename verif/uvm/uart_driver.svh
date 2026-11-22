//-----------------------------------------------------------------------------
// uart_driver - drives serial frames on the DUT receive line (uart_rxd)
// Frame format is taken from the shared live configuration object.
//-----------------------------------------------------------------------------
class uart_driver extends uvm_driver #(uart_item);
    `uvm_component_utils(uart_driver)

    virtual uart_if vif;
    uart_cfg        cfg;

    function new(string name, uvm_component parent);
        super.new(name, parent);
    endfunction

    function void build_phase(uvm_phase phase);
        super.build_phase(phase);
        if (!uvm_config_db#(virtual uart_if)::get(this, "", "uart_vif", vif))
            `uvm_fatal("NOVIF", "uart_vif not found")
        if (!uvm_config_db#(uart_cfg)::get(this, "", "cfg", cfg))
            `uvm_fatal("NOCFG", "cfg not found")
    endfunction

    task run_phase(uvm_phase phase);
        vif.rxd <= 1'b1;
        wait (vif.rst_n === 1'b1);
        forever begin
            seq_item_port.get_next_item(req);
            drive_frame(req);
            seq_item_port.item_done();
        end
    endtask

    task drive_bit(bit b, int unsigned clks);
        vif.rxd <= b;
        repeat (clks) @(posedge vif.clk);
    endtask

    task drive_frame(uart_item t);
        int unsigned bc   = cfg.bit_clks();
        int unsigned nb   = cfg.nbits();
        bit [7:0]    d    = t.data & cfg.mask();
        bit          par  = (^d) ^ cfg.parity_odd ^ t.bad_parity;
        int unsigned idle = t.idle_bits;

        @(posedge vif.clk);
        if (t.glitch) begin
            drive_bit(1'b0, bc / 4);
            drive_bit(1'b1, bc);
            return;
        end
        drive_bit(1'b0, bc);                      // start
        for (int i = 0; i < nb; i++)
            drive_bit(d[i], bc);                  // data, LSB first
        if (cfg.parity_en)
            drive_bit(par, bc);                   // parity
        drive_bit(t.bad_stop ? 1'b0 : 1'b1, bc);  // stop
        if (cfg.stop2)
            drive_bit(1'b1, bc);
        if (t.bad_stop && idle == 0)
            idle = 1;                             // line must go idle again
        vif.rxd <= 1'b1;
        repeat (idle * bc) @(posedge vif.clk);
    endtask
endclass
