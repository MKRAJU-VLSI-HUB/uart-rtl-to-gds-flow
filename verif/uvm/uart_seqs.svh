//-----------------------------------------------------------------------------
// Agent-level sequences
//-----------------------------------------------------------------------------

// single APB transfer
class apb_rw_seq extends uvm_sequence #(apb_item);
    `uvm_object_utils(apb_rw_seq)

    bit [4:0]  addr;
    bit        write;
    bit [31:0] wdata;
    bit [31:0] rdata;
    bit        slverr;

    function new(string name = "apb_rw_seq");
        super.new(name);
    endfunction

    task body();
        apb_item t = apb_item::type_id::create("t");
        start_item(t);
        t.addr  = addr;
        t.write = write;
        t.wdata = wdata;
        finish_item(t);
        rdata  = t.rdata;
        slverr = t.slverr;
    endtask
endclass

// burst of serial frames on the DUT receive line
class uart_frames_seq extends uvm_sequence #(uart_item);
    `uvm_object_utils(uart_frames_seq)

    int unsigned n          = 1;
    int unsigned perr_pct   = 0;    // % of frames with a parity error
    int unsigned ferr_pct   = 0;    // % of frames with a framing error
    int unsigned glitch_pct = 0;    // % of start-bit glitches
    bit          fixed_data = 0;
    bit [7:0]    data_val;
    int unsigned n_glitch;

    function new(string name = "uart_frames_seq");
        super.new(name);
    endfunction

    task body();
        uart_item t;
        n_glitch = 0;
        for (int i = 0; i < n; i++) begin
            t = uart_item::type_id::create("t");
            start_item(t);
            if (!t.randomize() with {
                    bad_parity dist {1 := perr_pct,   0 := 100 - perr_pct};
                    bad_stop   dist {1 := ferr_pct,   0 := 100 - ferr_pct};
                    glitch     dist {1 := glitch_pct, 0 := 100 - glitch_pct};
                })
                `uvm_fatal("RAND", "uart_item randomization failed")
            if (fixed_data) t.data = data_val;
            if (t.glitch) n_glitch++;
            finish_item(t);
        end
    endtask
endclass
