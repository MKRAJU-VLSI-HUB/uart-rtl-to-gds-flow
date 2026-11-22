//-----------------------------------------------------------------------------
// uart_coverage - functional coverage collector
//-----------------------------------------------------------------------------
`uvm_analysis_imp_decl(_cov_apb)
`uvm_analysis_imp_decl(_cov_tx)
`uvm_analysis_imp_decl(_cov_rx)

class uart_coverage extends uvm_component;
    `uvm_component_utils(uart_coverage)

    uvm_analysis_imp_cov_apb #(apb_item,  uart_coverage) apb_imp;
    uvm_analysis_imp_cov_tx  #(uart_item, uart_coverage) tx_imp;
    uvm_analysis_imp_cov_rx  #(uart_item, uart_coverage) rx_imp;

    uart_cfg  cfg;
    bit [5:0] ier;

    // frame format, per direction
    covergroup cg_frame with function sample(bit [1:0] db, bit pen, bit podd,
                                             bit s2, bit dir);
        option.per_instance = 1;
        cp_data_bits : coverpoint db  { bins b5 = {0}; bins b6 = {1}; bins b7 = {2}; bins b8 = {3}; }
        cp_parity    : coverpoint {pen, podd} { bins none = {2'b00, 2'b01}; bins even = {2'b10}; bins odd = {2'b11}; }
        cp_stop      : coverpoint s2  { bins one = {0}; bins two = {1}; }
        cp_dir       : coverpoint dir { bins tx = {0}; bins rx = {1}; }
        x_format     : cross cp_data_bits, cp_parity, cp_stop, cp_dir;
    endgroup

    // data values
    covergroup cg_data with function sample(bit [7:0] d, bit [7:0] m, bit [1:0] db, bit dir);
        option.per_instance = 1;
        cp_value  : coverpoint d {
            bins zero    = {8'h00};
            bins low     = {[8'h01:8'h1F]};
            bins mid     = {[8'h20:8'h7F]};
            bins high    = {[8'h80:8'hFE]};
            bins all_one = {8'hFF};
        }
        cp_all_ones : coverpoint (d == m)        { bins hit = {1}; }
        cp_walk     : coverpoint (d == (8'h55 & m) || d == (8'hAA & m)) { bins hit = {1}; }
        cp_db       : coverpoint db;
        cp_dir      : coverpoint dir { bins tx = {0}; bins rx = {1}; }
        x_ones_db   : cross cp_all_ones, cp_db, cp_dir;
        x_zero_db   : cross cp_value, cp_db {
            ignore_bins unreachable = binsof(cp_value) intersect {[8'h20:8'hFF]} && binsof(cp_db) intersect {0};
            ignore_bins unreach6    = binsof(cp_value) intersect {[8'h40:8'hFF]} && binsof(cp_db) intersect {1};
            ignore_bins unreach7    = binsof(cp_value) intersect {[8'h80:8'hFF]} && binsof(cp_db) intersect {2};
        }
    endgroup

    // receive error conditions
    covergroup cg_rx_err with function sample(bit pen, bit perr, bit ferr);
        option.per_instance = 1;
        cp_perr : coverpoint perr iff (pen) { bins ok = {0}; bins err = {1}; }
        cp_ferr : coverpoint ferr { bins ok = {0}; bins err = {1}; }
        x_err   : cross cp_perr, cp_ferr;
    endgroup

    // register accesses
    covergroup cg_apb with function sample(bit [2:0] a, bit wr, bit err);
        option.per_instance = 1;
        cp_addr : coverpoint a {
            bins txdata = {0}; bins rxdata = {1}; bins ctrl = {2}; bins baud = {3};
            bins status = {4}; bins ier    = {5}; bins isr  = {6}; bins unmap = {7};
        }
        cp_rw   : coverpoint wr { bins rd = {0}; bins wr = {1}; }
        cp_err  : coverpoint err { bins ok = {0}; bins slverr = {1}; }
        x_access: cross cp_addr, cp_rw;
    endgroup

    // baud divisor programming
    covergroup cg_baud with function sample(bit [15:0] div);
        option.per_instance = 1;
        cp_div : coverpoint div {
            bins d0    = {0};
            bins d1    = {1};
            bins d2_3  = {[2:3]};
            bins d4_7  = {[4:7]};
            bins big   = {[8:16'hFFFE]};
            bins max   = {16'hFFFF};
        }
    endgroup

    // interrupt status / enables
    covergroup cg_isr with function sample(bit [5:0] isr, bit [5:0] en);
        option.per_instance = 1;
        cp_rx_avail  : coverpoint isr[0] { bins clr = {0}; bins set = {1}; }
        cp_tx_empty  : coverpoint isr[1] { bins clr = {0}; bins set = {1}; }
        cp_par_err   : coverpoint isr[2] { bins clr = {0}; bins set = {1}; }
        cp_frm_err   : coverpoint isr[3] { bins clr = {0}; bins set = {1}; }
        cp_overrun   : coverpoint isr[4] { bins clr = {0}; bins set = {1}; }
        cp_overflow  : coverpoint isr[5] { bins clr = {0}; bins set = {1}; }
        cp_ier       : coverpoint en {
            bins none = {6'h00}; bins rx = {6'h01}; bins tx = {6'h02}; bins perr = {6'h04};
            bins ferr = {6'h08}; bins ovr = {6'h10}; bins ovf = {6'h20}; bins all = {6'h3F};
        }
    endgroup

    // FIFO levels / flags seen through STATUS
    covergroup cg_status with function sample(bit [31:0] st);
        option.per_instance = 1;
        cp_tx_lvl : coverpoint st[12:8]  { bins empty = {0}; bins partial = {[1:15]}; bins full = {16}; }
        cp_rx_lvl : coverpoint st[20:16] { bins empty = {0}; bins partial = {[1:15]}; bins full = {16}; }
        cp_tx_bsy : coverpoint st[4];
        cp_rx_bsy : coverpoint st[5];
    endgroup

    // operating modes
    covergroup cg_mode with function sample(bit [7:0] c);
        option.per_instance = 1;
        cp_loopback : coverpoint c[7];
        cp_tx_en    : coverpoint c[0];
        cp_rx_en    : coverpoint c[1];
        x_mode      : cross cp_loopback, cp_tx_en, cp_rx_en;
    endgroup

    function new(string name, uvm_component parent);
        super.new(name, parent);
        apb_imp   = new("apb_imp", this);
        tx_imp    = new("tx_imp",  this);
        rx_imp    = new("rx_imp",  this);
        cg_frame  = new();
        cg_data   = new();
        cg_rx_err = new();
        cg_apb    = new();
        cg_baud   = new();
        cg_isr    = new();
        cg_status = new();
        cg_mode   = new();
    endfunction

    function void write_cov_apb(apb_item t);
        cg_apb.sample(t.addr[4:2], t.write, t.slverr);
        if (t.write) begin
            case (t.addr)
                BAUD: cg_baud.sample(t.wdata[15:0]);
                CTRL: cg_mode.sample(t.wdata[7:0]);
                IER:  ier = t.wdata[5:0];
                default: ;
            endcase
        end else begin
            case (t.addr)
                ISR:    cg_isr.sample(t.rdata[5:0], ier);
                STATUS: cg_status.sample(t.rdata);
                default: ;
            endcase
        end
    endfunction

    function void write_cov_tx(uart_item t);
        cg_frame.sample(t.data_bits, t.parity_en, t.parity_odd, t.stop2, 1'b0);
        cg_data.sample(t.data, 8'hFF >> (3 - t.data_bits), t.data_bits, 1'b0);
    endfunction

    function void write_cov_rx(uart_item t);
        cg_frame.sample(t.data_bits, t.parity_en, t.parity_odd, t.stop2, 1'b1);
        cg_data.sample(t.data, 8'hFF >> (3 - t.data_bits), t.data_bits, 1'b1);
        cg_rx_err.sample(t.parity_en, t.perr, t.ferr);
    endfunction

    function void report_phase(uvm_phase phase);
        `uvm_info("COVERAGE", $sformatf({"\n  cg_frame  = %6.2f%%\n  cg_data   = %6.2f%%\n  cg_rx_err = %6.2f%%",
                  "\n  cg_apb    = %6.2f%%\n  cg_baud   = %6.2f%%\n  cg_isr    = %6.2f%%",
                  "\n  cg_status = %6.2f%%\n  cg_mode   = %6.2f%%"},
                  cg_frame.get_inst_coverage(), cg_data.get_inst_coverage(),
                  cg_rx_err.get_inst_coverage(), cg_apb.get_inst_coverage(),
                  cg_baud.get_inst_coverage(), cg_isr.get_inst_coverage(),
                  cg_status.get_inst_coverage(), cg_mode.get_inst_coverage()), UVM_NONE)
    endfunction
endclass
