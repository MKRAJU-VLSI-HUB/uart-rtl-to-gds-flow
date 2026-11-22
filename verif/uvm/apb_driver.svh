//-----------------------------------------------------------------------------
// apb_driver - APB3 master BFM (setup + access phase, honours PREADY)
//-----------------------------------------------------------------------------
class apb_driver extends uvm_driver #(apb_item);
    `uvm_component_utils(apb_driver)

    virtual apb_if vif;

    function new(string name, uvm_component parent);
        super.new(name, parent);
    endfunction

    function void build_phase(uvm_phase phase);
        super.build_phase(phase);
        if (!uvm_config_db#(virtual apb_if)::get(this, "", "apb_vif", vif))
            `uvm_fatal("NOVIF", "apb_vif not found")
    endfunction

    task run_phase(uvm_phase phase);
        vif.psel    <= 1'b0;
        vif.penable <= 1'b0;
        vif.pwrite  <= 1'b0;
        vif.paddr   <= '0;
        vif.pwdata  <= '0;
        wait (vif.presetn === 1'b1);
        forever begin
            seq_item_port.get_next_item(req);
            drive(req);
            seq_item_port.item_done();
        end
    endtask

    task drive(apb_item t);
        // setup phase
        @(posedge vif.pclk);
        vif.psel    <= 1'b1;
        vif.penable <= 1'b0;
        vif.pwrite  <= t.write;
        vif.paddr   <= t.addr;
        vif.pwdata  <= t.write ? t.wdata : 32'h0;
        // access phase
        @(posedge vif.pclk);
        vif.penable <= 1'b1;
        do @(posedge vif.pclk); while (vif.pready !== 1'b1);
        t.rdata  = vif.prdata;
        t.slverr = vif.pslverr;
        vif.psel    <= 1'b0;
        vif.penable <= 1'b0;
    endtask
endclass
