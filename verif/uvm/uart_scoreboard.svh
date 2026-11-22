//-----------------------------------------------------------------------------
// uart_scoreboard - reference model + checker
//   * TX path : APB writes to TXDATA  -> expected frames on txd
//   * RX path : frames driven on rxd  -> expected APB reads of RXDATA
//   * loopback: APB writes to TXDATA  -> expected APB reads of RXDATA
//   * FIFO occupancy model for TX overflow / RX overrun
//   * sticky ISR model (parity, framing, overrun, overflow) with W1C
//   * register mirror check of CTRL, BAUD, IER and PSLVERR decode
//-----------------------------------------------------------------------------
`uvm_analysis_imp_decl(_apb)
`uvm_analysis_imp_decl(_txf)
`uvm_analysis_imp_decl(_txs)
`uvm_analysis_imp_decl(_rxf)

class uart_scoreboard extends uvm_component;
    `uvm_component_utils(uart_scoreboard)

    uvm_analysis_imp_apb #(apb_item,  uart_scoreboard) apb_imp;
    uvm_analysis_imp_txf #(uart_item, uart_scoreboard) txf_imp;
    uvm_analysis_imp_txs #(uart_item, uart_scoreboard) txs_imp;
    uvm_analysis_imp_rxf #(uart_item, uart_scoreboard) rxf_imp;

    uart_cfg   cfg;                 // live mirror of CTRL / BAUD

    bit [7:0]  exp_tx_q[$];         // bytes accepted by TX FIFO, in order
    int        tx_occ;              // modelled TX FIFO occupancy
    uart_item  exp_rx_q[$];         // frames accepted by RX FIFO, in order
    bit [3:0]  sticky;              // {tx_ovf, rx_ovr, frame_err, parity_err}
    bit [5:0]  ier;

    int unsigned n_tx_ok, n_rx_ok, n_reg_ok, n_err;
    int unsigned n_perr, n_ferr, n_ovr, n_ovf;

    function new(string name, uvm_component parent);
        super.new(name, parent);
        apb_imp = new("apb_imp", this);
        txf_imp = new("txf_imp", this);
        txs_imp = new("txs_imp", this);
        rxf_imp = new("rxf_imp", this);
    endfunction

    function void build_phase(uvm_phase phase);
        super.build_phase(phase);
        if (!uvm_config_db#(uart_cfg)::get(this, "", "cfg", cfg))
            `uvm_fatal("NOCFG", "cfg not found")
        cfg.from_ctrl(8'h60);       // reset value
        cfg.divisor = 16'd26;
    endfunction

    function void fail(string id, string msg);
        n_err++;
        `uvm_error(id, msg)
    endfunction

    //--------------------------------------------------------------- APB side
    function void write_apb(apb_item t);
        bit [2:0] a = t.addr[4:2];

        if (t.slverr !== (a == 3'd7))
            fail("SB_SLVERR", $sformatf("PSLVERR=%0b for %s", t.slverr, t.convert2string()));

        if (t.write) begin
            case (t.addr)
                TXDATA: begin
                    if (cfg.loopback) begin
                        uart_item e = uart_item::type_id::create("e");
                        e.data = t.wdata[7:0] & cfg.mask();
                        if (exp_rx_q.size() < 16) exp_rx_q.push_back(e);
                    end else if (tx_occ >= 16) begin
                        sticky[3] = 1'b1;
                        n_ovf++;
                    end else begin
                        exp_tx_q.push_back(t.wdata[7:0]);
                        tx_occ++;
                    end
                end
                CTRL: cfg.from_ctrl(t.wdata[7:0]);
                BAUD: cfg.divisor = t.wdata[15:0];
                IER:  ier = t.wdata[5:0];
                ISR:  sticky &= ~t.wdata[5:2];
                default: ;
            endcase
        end else begin
            case (t.addr)
                RXDATA: begin
                    if (exp_rx_q.size() == 0) begin
                        if (t.rdata !== 32'h0)
                            fail("SB_RX", $sformatf("RXDATA read 0x%0h while model FIFO empty", t.rdata));
                    end else begin
                        uart_item e = exp_rx_q.pop_front();
                        if (t.rdata !== {24'h0, e.data})
                            fail("SB_RX", $sformatf("RXDATA exp 0x%02h got 0x%0h", e.data, t.rdata));
                        else
                            n_rx_ok++;
                    end
                end
                CTRL:   check_reg("CTRL", t.rdata, {24'h0, cfg.ctrl_val()});
                BAUD:   check_reg("BAUD", t.rdata, {16'h0, cfg.divisor});
                IER:    check_reg("IER",  t.rdata, {26'h0, ier});
                ISR: begin
                    if (t.rdata[5:2] !== sticky)
                        fail("SB_ISR", $sformatf("ISR sticky exp 0x%0h got 0x%0h", sticky, t.rdata[5:2]));
                    else
                        n_reg_ok++;
                end
                STATUS: begin
                    if (t.rdata[0] && t.rdata[1])
                        fail("SB_STATUS", "TX_FULL and TX_EMPTY both set");
                    if (t.rdata[2] && t.rdata[3])
                        fail("SB_STATUS", "RX_FULL and RX_EMPTY both set");
                end
                default: ;
            endcase
        end
    endfunction

    function void check_reg(string name, bit [31:0] got, bit [31:0] exp);
        if (got !== exp)
            fail("SB_REG", $sformatf("%s exp 0x%08h got 0x%08h", name, exp, got));
        else
            n_reg_ok++;
    endfunction

    //---------------------------------------------------------- serial side
    function void write_txs(uart_item t);
        if (tx_occ > 0) tx_occ--;
    endfunction

    function void write_txf(uart_item t);
        bit [7:0] m = 8'hFF >> (3 - t.data_bits);
        bit [7:0] e;
        if (exp_tx_q.size() == 0) begin
            fail("SB_TX", $sformatf("unexpected frame on txd: %s", t.convert2string()));
            return;
        end
        e = exp_tx_q.pop_front() & m;
        if (t.data !== e)
            fail("SB_TX", $sformatf("txd data exp 0x%02h got 0x%02h", e, t.data));
        else if (t.perr || t.ferr || t.stop2_err)
            fail("SB_TX", $sformatf("txd frame format error: %s", t.convert2string()));
        else
            n_tx_ok++;
    endfunction

    function void write_rxf(uart_item t);
        if (!cfg.rx_en || cfg.loopback) return;
        if (t.perr) begin sticky[0] = 1'b1; n_perr++; end
        if (t.ferr) begin sticky[1] = 1'b1; n_ferr++; end
        if (exp_rx_q.size() >= 16) begin
            sticky[2] = 1'b1;
            n_ovr++;
        end else begin
            exp_rx_q.push_back(t);
        end
    endfunction

    //------------------------------------------------------------ end of test
    function void check_phase(uvm_phase phase);
        if (exp_tx_q.size() != 0)
            fail("SB_EOT", $sformatf("%0d TX bytes never seen on txd", exp_tx_q.size()));
        if (exp_rx_q.size() != 0)
            fail("SB_EOT", $sformatf("%0d RX frames never read back", exp_rx_q.size()));
    endfunction

    function void report_phase(uvm_phase phase);
        `uvm_info("SB_SUMMARY", $sformatf(
            "TX frames OK=%0d | RX frames OK=%0d | reg checks OK=%0d | parity_err=%0d frame_err=%0d overrun=%0d overflow=%0d | mismatches=%0d",
            n_tx_ok, n_rx_ok, n_reg_ok, n_perr, n_ferr, n_ovr, n_ovf, n_err), UVM_NONE)
    endfunction
endclass
