//-----------------------------------------------------------------------------
// apb_monitor - publishes every completed APB transfer
//-----------------------------------------------------------------------------
class apb_monitor extends uvm_monitor;
    `uvm_component_utils(apb_monitor)

    virtual apb_if vif;
    uvm_analysis_port #(apb_item) ap;

    function new(string name, uvm_component parent);
        super.new(name, parent);
        ap = new("ap", this);
    endfunction

    function void build_phase(uvm_phase phase);
        super.build_phase(phase);
        if (!uvm_config_db#(virtual apb_if)::get(this, "", "apb_vif", vif))
            `uvm_fatal("NOVIF", "apb_vif not found")
    endfunction

    task run_phase(uvm_phase phase);
        apb_item t;
        forever begin
            @(posedge vif.pclk);
            if (vif.presetn === 1'b1 && vif.psel === 1'b1 &&
                vif.penable === 1'b1 && vif.pready === 1'b1) begin
                t        = apb_item::type_id::create("t");
                t.addr   = vif.paddr;
                t.write  = vif.pwrite;
                t.wdata  = vif.pwdata;
                t.rdata  = vif.prdata;
                t.slverr = vif.pslverr;
                `uvm_info("APB_MON", t.convert2string(), UVM_HIGH)
                ap.write(t);
            end
        end
    endtask
endclass
