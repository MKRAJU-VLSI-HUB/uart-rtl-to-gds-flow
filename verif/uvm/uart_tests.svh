//-----------------------------------------------------------------------------
// Tests
//-----------------------------------------------------------------------------
class uart_base_test extends uvm_test;
    `uvm_component_utils(uart_base_test)

    uart_env env;

    function new(string name, uvm_component parent);
        super.new(name, parent);
    endfunction

    function void build_phase(uvm_phase phase);
        super.build_phase(phase);
        env = uart_env::type_id::create("env", this);
    endfunction

    function void end_of_elaboration_phase(uvm_phase phase);
        if (uvm_report_enabled(UVM_HIGH))
            uvm_top.print_topology();
    endfunction

    // overridden by each test
    virtual function uart_base_vseq make_vseq();
        return uart_base_vseq::type_id::create("vseq");
    endfunction

    task run_phase(uvm_phase phase);
        uart_base_vseq vs;
        virtual uart_if uvif;
        phase.raise_objection(this);
        if (!uvm_config_db#(virtual uart_if)::get(this, "", "uart_vif", uvif))
            `uvm_fatal("NOVIF", "uart_vif not found")
        vs          = make_vseq();
        vs.apb_sqr  = env.apb_agt.sqr;
        vs.uart_sqr = env.uart_agt.sqr;
        vs.uvif     = uvif;
        vs.live     = env.cfg;
        wait (uvif.rst_n === 1'b1);
        repeat (5) @(posedge uvif.clk);
        vs.start(null);
        repeat (200) @(posedge uvif.clk);
        phase.drop_objection(this);
    endtask

    function void report_phase(uvm_phase phase);
        uvm_report_server rs = uvm_report_server::get_server();
        int errs = rs.get_severity_count(UVM_ERROR) + rs.get_severity_count(UVM_FATAL);
        `uvm_info("RESULT", $sformatf("%s : %s", get_type_name(), errs == 0 ? "PASSED" : "FAILED"), UVM_NONE)
    endfunction
endclass

`define UART_TEST(TNAME, VSEQ)                                         \
class TNAME extends uart_base_test;                                    \
    `uvm_component_utils(TNAME)                                        \
    function new(string name, uvm_component parent);                   \
        super.new(name, parent);                                       \
    endfunction                                                        \
    virtual function uart_base_vseq make_vseq();                       \
        VSEQ v = VSEQ::type_id::create("vseq");                        \
        return v;                                                      \
    endfunction                                                        \
endclass

`UART_TEST(uart_smoke_test,    uart_smoke_vseq)
`UART_TEST(uart_reg_test,      uart_reg_vseq)
`UART_TEST(uart_tx_test,       uart_tx_vseq)
`UART_TEST(uart_rx_test,       uart_rx_vseq)
`UART_TEST(uart_duplex_test,   uart_duplex_vseq)
`UART_TEST(uart_overrun_test,  uart_overrun_vseq)
`UART_TEST(uart_overflow_test, uart_overflow_vseq)
`UART_TEST(uart_loopback_test, uart_loopback_vseq)
`UART_TEST(uart_irq_test,      uart_irq_vseq)
`UART_TEST(uart_random_test,   uart_random_vseq)

class uart_parity_err_test extends uart_base_test;
    `uvm_component_utils(uart_parity_err_test)
    function new(string name, uvm_component parent); super.new(name, parent); endfunction
    virtual function uart_base_vseq make_vseq();
        uart_err_vseq v = uart_err_vseq::type_id::create("vseq");
        v.parity_mode = 1;
        return v;
    endfunction
endclass

class uart_frame_err_test extends uart_base_test;
    `uvm_component_utils(uart_frame_err_test)
    function new(string name, uvm_component parent); super.new(name, parent); endfunction
    virtual function uart_base_vseq make_vseq();
        uart_err_vseq v = uart_err_vseq::type_id::create("vseq");
        v.parity_mode = 0;
        return v;
    endfunction
endclass
