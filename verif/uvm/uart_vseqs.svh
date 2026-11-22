//-----------------------------------------------------------------------------
// Virtual sequences (one per test scenario)
//-----------------------------------------------------------------------------
class uart_base_vseq extends uvm_sequence;
    `uvm_object_utils(uart_base_vseq)

    apb_sequencer   apb_sqr;
    uart_sequencer  uart_sqr;
    virtual uart_if uvif;
    uart_cfg        live;          // env mirror (read-only here)

    localparam int POLL_LIMIT = 100000;

    function new(string name = "uart_base_vseq");
        super.new(name);
    endfunction

    //------------------------------------------------------------ APB helpers
    task wr(bit [4:0] a, bit [31:0] d);
        apb_rw_seq s = apb_rw_seq::type_id::create("s");
        s.addr = a; s.write = 1'b1; s.wdata = d;
        s.start(apb_sqr, this);
    endtask

    task rd(bit [4:0] a, output bit [31:0] d);
        apb_rw_seq s = apb_rw_seq::type_id::create("s");
        s.addr = a; s.write = 1'b0;
        s.start(apb_sqr, this);
        d = s.rdata;
    endtask

    task rd_err(bit [4:0] a, bit w, output bit err);
        apb_rw_seq s = apb_rw_seq::type_id::create("s");
        s.addr = a; s.write = w; s.wdata = 32'hDEAD_BEEF;
        s.start(apb_sqr, this);
        err = s.slverr;
    endtask

    task expect_reg(bit [4:0] a, bit [31:0] exp, bit [31:0] msk = 32'hFFFF_FFFF);
        bit [31:0] d;
        rd(a, d);
        if ((d & msk) !== (exp & msk))
            `uvm_error("VSEQ", $sformatf("reg 0x%02h exp 0x%08h got 0x%08h (mask 0x%08h)", a, exp, d, msk))
    endtask

    task clks(int unsigned n);
        repeat (n) @(posedge uvif.clk);
    endtask

    //----------------------------------------------------------- UART helpers
    task program_cfg(uart_cfg c);
        wr(BAUD, {16'h0, c.divisor});
        wr(CTRL, {24'h0, c.ctrl_val()});
        `uvm_info("VSEQ", {"config: ", c.convert2string()}, UVM_MEDIUM)
    endtask

    function uart_cfg rand_cfg(bit lb = 0);
        uart_cfg c = uart_cfg::type_id::create("c");
        if (!c.randomize()) `uvm_fatal("RAND", "cfg randomization failed")
        c.loopback = lb;
        return c;
    endfunction

    // write n bytes into the TX FIFO, never overflowing it
    task send_tx(int unsigned n);
        bit [31:0] st;
        int        guard;
        for (int i = 0; i < n; i++) begin
            guard = 0;
            do begin
                rd(STATUS, st);
                if (++guard > POLL_LIMIT) `uvm_fatal("VSEQ", "TX FIFO stuck full")
            end while (st[0]);
            wr(TXDATA, $urandom_range(0, 255));
        end
    endtask

    task wait_tx_idle();
        bit [31:0] st;
        int        guard = 0;
        do begin
            rd(STATUS, st);
            if (++guard > POLL_LIMIT) `uvm_fatal("VSEQ", "TX never went idle")
        end while (!(st[1] && !st[4]));
        clks(4);
    endtask

    task drive_rx(int unsigned n, int unsigned perr = 0, int unsigned ferr = 0,
                  int unsigned glitch = 0, output int unsigned n_real);
        uart_frames_seq s = uart_frames_seq::type_id::create("s");
        s.n = n; s.perr_pct = perr; s.ferr_pct = ferr; s.glitch_pct = glitch;
        s.start(uart_sqr, this);
        n_real = n - s.n_glitch;
    endtask

    task read_rx(int unsigned n);
        bit [31:0] st, d;
        int        guard;
        for (int i = 0; i < n; i++) begin
            guard = 0;
            do begin
                rd(STATUS, st);
                if (++guard > POLL_LIMIT) `uvm_fatal("VSEQ", $sformatf("RX byte %0d never arrived", i))
            end while (st[3]);
            rd(RXDATA, d);
        end
    endtask

    task drain_rx();
        bit [31:0] st, d;
        rd(STATUS, st);
        while (!st[3]) begin
            rd(RXDATA, d);
            rd(STATUS, st);
        end
    endtask

    task clear_isr();
        wr(ISR, 32'h3C);
    endtask

    // full-duplex burst with the current configuration
    task duplex(int unsigned ntx, int unsigned nrx);
        int unsigned nr;
        fork
            begin send_tx(ntx); wait_tx_idle(); end
            begin
                fork
                    drive_rx(nrx, 0, 0, 0, nr);
                    read_rx(nrx);
                join
            end
        join
    endtask

    task body();
    endtask
endclass

//------------------------------------------------------------------- smoke
class uart_smoke_vseq extends uart_base_vseq;
    `uvm_object_utils(uart_smoke_vseq)
    function new(string name = "uart_smoke_vseq"); super.new(name); endfunction

    task body();
        uart_cfg c = uart_cfg::type_id::create("c");
        int unsigned nr;
        c.data_bits = 3; c.parity_en = 0; c.stop2 = 0; c.divisor = 1;
        program_cfg(c);
        send_tx(4);
        wait_tx_idle();
        drive_rx(4, 0, 0, 0, nr);
        read_rx(nr);
    endtask
endclass

//--------------------------------------------------------------- registers
class uart_reg_vseq extends uart_base_vseq;
    `uvm_object_utils(uart_reg_vseq)
    function new(string name = "uart_reg_vseq"); super.new(name); endfunction

    task body();
        bit err;
        bit [31:0] pat[] = '{32'h0000_0000, 32'hFFFF_FFFF, 32'hA5A5_A5A5, 32'h5A5A_5A5A};

        // reset values
        expect_reg(CTRL,   32'h0000_0060);
        expect_reg(BAUD,   32'h0000_001A);
        expect_reg(IER,    32'h0000_0000);
        expect_reg(STATUS, 32'h0000_000A);
        expect_reg(ISR,    32'h0000_0002);
        expect_reg(RXDATA, 32'h0000_0000);
        expect_reg(TXDATA, 32'h0000_0000);

        // read/write patterns (scoreboard mirrors the values)
        foreach (pat[i]) begin
            wr(BAUD, pat[i]); expect_reg(BAUD, pat[i] & 32'hFFFF);
            wr(IER,  pat[i]); expect_reg(IER,  pat[i] & 32'h3F);
            wr(CTRL, pat[i] & 32'h0000_007C);          // keep engines off
            expect_reg(CTRL, pat[i] & 32'h7C);
        end
        // walk every engine-enable / loopback mode
        for (int m = 0; m < 8; m++) begin
            wr(CTRL, {24'h0, m[2], 2'b11, 3'b000, m[1:0]});
            clks(4);
        end
        wr(CTRL, 32'h60);
        wr(IER, 32'h0);
        wr(BAUD, 32'd26);
        wr(BAUD, 32'd12);
        wr(BAUD, 32'd26);

        // unmapped address -> PSLVERR, mapped -> OK
        rd_err(UNMAP, 1'b0, err); if (!err) `uvm_error("VSEQ", "no PSLVERR on unmapped read")
        rd_err(UNMAP, 1'b1, err); if (!err) `uvm_error("VSEQ", "no PSLVERR on unmapped write")
        rd_err(CTRL,  1'b0, err); if (err)  `uvm_error("VSEQ", "unexpected PSLVERR on CTRL")

        // writes to read-only registers have no effect
        wr(STATUS, 32'hFFFF_FFFF);
        expect_reg(STATUS, 32'h0000_000A);
        wr(ISR, 32'h3F);
        expect_reg(ISR, 32'h0000_0002);
    endtask
endclass

//--------------------------------------------------------------- TX random
class uart_tx_vseq extends uart_base_vseq;
    `uvm_object_utils(uart_tx_vseq)
    int unsigned n_cfg = 16;
    function new(string name = "uart_tx_vseq"); super.new(name); endfunction

    task body();
        for (int k = 0; k < n_cfg; k++) begin
            program_cfg(rand_cfg());
            send_tx($urandom_range(4, 24));
            wait_tx_idle();
        end
    endtask
endclass

//--------------------------------------------------------------- RX random
class uart_rx_vseq extends uart_base_vseq;
    `uvm_object_utils(uart_rx_vseq)
    int unsigned n_cfg = 16;
    function new(string name = "uart_rx_vseq"); super.new(name); endfunction

    task body();
        int unsigned n, nr;
        for (int k = 0; k < n_cfg; k++) begin
            program_cfg(rand_cfg());
            n = $urandom_range(4, 12);
            drive_rx(n, 0, 0, 15, nr);       // includes start-bit glitches
            read_rx(nr);
        end
    endtask
endclass

//------------------------------------------------------------- full duplex
class uart_duplex_vseq extends uart_base_vseq;
    `uvm_object_utils(uart_duplex_vseq)
    int unsigned n_cfg = 12;
    function new(string name = "uart_duplex_vseq"); super.new(name); endfunction

    task body();
        for (int k = 0; k < n_cfg; k++) begin
            program_cfg(rand_cfg());
            duplex($urandom_range(4, 20), $urandom_range(4, 20));
        end
    endtask
endclass

//-------------------------------------------------------- parity / framing
class uart_err_vseq extends uart_base_vseq;
    `uvm_object_utils(uart_err_vseq)
    bit parity_mode = 1;   // 1: parity errors, 0: framing errors
    int unsigned n_cfg = 10;
    function new(string name = "uart_err_vseq"); super.new(name); endfunction

    task body();
        uart_cfg     c;
        int unsigned nr;
        bit [31:0]   isr;
        for (int k = 0; k < n_cfg; k++) begin
            c = rand_cfg();
            if (parity_mode) c.parity_en = 1;
            program_cfg(c);
            drive_rx(6, parity_mode ? 50 : 0, parity_mode ? 0 : 50, 0, nr);
            clks(c.bit_clks());
            rd(ISR, isr);                 // scoreboard checks sticky bits
            read_rx(nr);
            clear_isr();
            rd(ISR, isr);
            if (isr[5:2] != 0)
                `uvm_error("VSEQ", $sformatf("sticky bits not cleared: 0x%0h", isr))
        end
        // explicit worst case: every frame bad
        c = rand_cfg(); c.parity_en = 1; program_cfg(c);
        drive_rx(3, parity_mode ? 100 : 0, parity_mode ? 0 : 100, 0, nr);
        clks(c.bit_clks());
        rd(ISR, isr);
        if (!isr[parity_mode ? 2 : 3])
            `uvm_error("VSEQ", $sformatf("error flag not set, ISR=0x%0h", isr))
        read_rx(nr);
        clear_isr();
    endtask
endclass

//----------------------------------------------------------------- overrun
class uart_overrun_vseq extends uart_base_vseq;
    `uvm_object_utils(uart_overrun_vseq)
    function new(string name = "uart_overrun_vseq"); super.new(name); endfunction

    task body();
        uart_cfg     c = rand_cfg();
        int unsigned nr;
        bit [31:0]   isr, st;
        program_cfg(c);
        drive_rx(20, 0, 0, 0, nr);       // 4 frames more than the FIFO holds
        clks(c.bit_clks());
        rd(STATUS, st);
        if (!st[2]) `uvm_error("VSEQ", "RX FIFO not full after 20 frames")
        rd(ISR, isr);
        if (!isr[4]) `uvm_error("VSEQ", $sformatf("RX overrun not flagged, ISR=0x%0h", isr))
        read_rx(16);
        rd(STATUS, st);
        if (!st[3]) `uvm_error("VSEQ", "RX FIFO not empty after draining")
        clear_isr();
        expect_reg(ISR, 32'h2, 32'h3D);
    endtask
endclass

//---------------------------------------------------------------- overflow
class uart_overflow_vseq extends uart_base_vseq;
    `uvm_object_utils(uart_overflow_vseq)
    function new(string name = "uart_overflow_vseq"); super.new(name); endfunction

    task body();
        uart_cfg   c = rand_cfg();
        bit [31:0] isr, st;
        c.tx_en = 0;
        program_cfg(c);
        for (int i = 0; i < 20; i++) wr(TXDATA, $urandom_range(0, 255));
        rd(STATUS, st);
        if (!st[0] || st[12:8] != 16) `uvm_error("VSEQ", $sformatf("TX FIFO not full: STATUS=0x%0h", st))
        rd(ISR, isr);
        if (!isr[5]) `uvm_error("VSEQ", $sformatf("TX overflow not flagged, ISR=0x%0h", isr))
        clear_isr();
        c.tx_en = 1;
        program_cfg(c);
        wait_tx_idle();
    endtask
endclass

//---------------------------------------------------------------- loopback
class uart_loopback_vseq extends uart_base_vseq;
    `uvm_object_utils(uart_loopback_vseq)
    int unsigned n_cfg = 10;
    function new(string name = "uart_loopback_vseq"); super.new(name); endfunction

    task body();
        int unsigned n;
        for (int k = 0; k < n_cfg; k++) begin
            program_cfg(rand_cfg(1));
            n = $urandom_range(1, 16);
            send_tx(n);
            read_rx(n);
            wait_tx_idle();
        end
        program_cfg(rand_cfg(0));
    endtask
endclass

//--------------------------------------------------------------- interrupt
class uart_irq_vseq extends uart_base_vseq;
    `uvm_object_utils(uart_irq_vseq)
    function new(string name = "uart_irq_vseq"); super.new(name); endfunction

    task check_irq(bit exp, string what);
        bit [31:0] isr;
        clks(4);
        rd(ISR, isr);
        if (uvif.irq !== exp)
            `uvm_error("VSEQ", $sformatf("%s: irq=%0b expected %0b (ISR=0x%0h)", what, uvif.irq, exp, isr))
    endtask

    task body();
        uart_cfg     c = rand_cfg();
        int unsigned nr;
        bit [31:0]   d;
        c.parity_en = 1;
        program_cfg(c);

        // TX_EMPTY (level)
        wr(IER, 32'h02); check_irq(1, "tx_empty");
        wr(IER, 32'h00); check_irq(0, "masked");

        // RX_AVAIL (level)
        wr(IER, 32'h01); check_irq(0, "rx idle");
        drive_rx(1, 0, 0, 0, nr);
        check_irq(1, "rx_avail");
        read_rx(1);
        check_irq(0, "rx_avail cleared");

        // PARITY_ERR (sticky)
        wr(IER, 32'h04);
        drive_rx(1, 100, 0, 0, nr);
        check_irq(1, "parity_err");
        read_rx(1); clear_isr();
        check_irq(0, "parity_err cleared");

        // FRAME_ERR (sticky)
        wr(IER, 32'h08);
        drive_rx(1, 0, 100, 0, nr);
        check_irq(1, "frame_err");
        read_rx(1); clear_isr();
        check_irq(0, "frame_err cleared");

        // RX_OVERRUN (sticky)
        wr(IER, 32'h10);
        drive_rx(17, 0, 0, 0, nr);
        check_irq(1, "rx_overrun");
        read_rx(16); clear_isr();
        check_irq(0, "rx_overrun cleared");

        // TX_OVERFLOW (sticky)
        wr(IER, 32'h20);
        c.tx_en = 0; program_cfg(c);
        for (int i = 0; i < 17; i++) wr(TXDATA, i);
        check_irq(1, "tx_overflow");
        clear_isr();
        check_irq(0, "tx_overflow cleared");
        c.tx_en = 1; program_cfg(c);
        wait_tx_idle();

        // all sources enabled
        wr(IER, 32'h3F); check_irq(1, "all enabled");
        wr(IER, 32'h00); check_irq(0, "all masked");
    endtask
endclass

//------------------------------------------------------ constrained random
class uart_random_vseq extends uart_base_vseq;
    `uvm_object_utils(uart_random_vseq)
    int unsigned n_iter = 30;
    function new(string name = "uart_random_vseq"); super.new(name); endfunction

    task body();
        uart_cfg     c;
        int unsigned nr, n;
        bit [31:0]   isr;
        for (int k = 0; k < n_iter; k++) begin
            randcase
                4: begin program_cfg(rand_cfg()); duplex($urandom_range(1, 20), $urandom_range(1, 20)); end
                2: begin program_cfg(rand_cfg()); send_tx($urandom_range(1, 30)); wait_tx_idle(); end
                2: begin program_cfg(rand_cfg()); drive_rx($urandom_range(1, 12), 0, 0, 10, nr); read_rx(nr); end
                1: begin
                       c = rand_cfg(); c.parity_en = $urandom_range(0, 1); program_cfg(c);
                       drive_rx($urandom_range(1, 6), 30, 30, 0, nr);
                       clks(c.bit_clks());
                       rd(ISR, isr); read_rx(nr); clear_isr();
                   end
                1: begin
                       program_cfg(rand_cfg(1)); n = $urandom_range(1, 16);
                       send_tx(n); read_rx(n); wait_tx_idle();
                       program_cfg(rand_cfg(0));
                   end
            endcase
        end
    endtask
endclass
