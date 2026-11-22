//-----------------------------------------------------------------------------
// uart_env - APB agent + UART agent + scoreboard + coverage
//-----------------------------------------------------------------------------
class uart_env extends uvm_env;
    `uvm_component_utils(uart_env)

    apb_agent       apb_agt;
    uart_agent      uart_agt;
    uart_scoreboard sb;
    uart_coverage   cov;
    uart_cfg        cfg;    // live configuration mirror

    function new(string name, uvm_component parent);
        super.new(name, parent);
    endfunction

    function void build_phase(uvm_phase phase);
        super.build_phase(phase);
        cfg = uart_cfg::type_id::create("cfg");
        uvm_config_db#(uart_cfg)::set(this, "*", "cfg", cfg);
        apb_agt  = apb_agent::type_id::create("apb_agt", this);
        uart_agt = uart_agent::type_id::create("uart_agt", this);
        sb       = uart_scoreboard::type_id::create("sb", this);
        cov      = uart_coverage::type_id::create("cov", this);
    endfunction

    function void connect_phase(uvm_phase phase);
        apb_agt.mon.ap.connect(sb.apb_imp);
        apb_agt.mon.ap.connect(cov.apb_imp);
        uart_agt.tx_mon.ap.connect(sb.txf_imp);
        uart_agt.tx_mon.ap_start.connect(sb.txs_imp);
        uart_agt.rx_mon.ap.connect(sb.rxf_imp);
        uart_agt.tx_mon.ap.connect(cov.tx_imp);
        uart_agt.rx_mon.ap.connect(cov.rx_imp);
    endfunction
endclass
