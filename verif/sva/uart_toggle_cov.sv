//-----------------------------------------------------------------------------
// uart_toggle_cov.sv - toggle coverage monitor (bound into uart_top)
// Records 0->1 and 1->0 transitions of every DUT port bit and key internal
// register bit, and prints a toggle-coverage summary at the end of the run.
// Bits that are constant by design (PRDATA[31:21], PREADY) are excluded.
//-----------------------------------------------------------------------------
module uart_toggle_cov #(parameter int W = 1) (
    input logic         clk,
    input logic         rst_n,
    input logic [W-1:0] sig
);
    bit [W-1:0] rose_seen, fell_seen;
    logic [W-1:0] prev;
    bit           valid;

    // cumulative across regression runs: previous results are loaded from and
    // saved back to toggle_db.txt in the simulation directory
    initial begin
        int fd;
        fd = $fopen("toggle_db.txt", "r");
        if (fd != 0) begin
            void'($fscanf(fd, "%h %h", rose_seen, fell_seen));
            $fclose(fd);
        end
    end

    always @(posedge clk) begin
        if (rst_n === 1'b1) begin
            if (valid) begin
                rose_seen |= ~prev &  sig;
                fell_seen |=  prev & ~sig;
            end
            prev  <= sig;
            valid <= 1'b1;
        end
    end

    final begin
        int fd = $fopen("toggle_db.txt", "w");
        int both = 0;
        string missing = "";
        for (int i = 0; i < W; i++) begin
            if (rose_seen[i] && fell_seen[i]) both++;
            else missing = {missing, $sformatf(" %0d", i)};
        end
        $fwrite(fd, "%h %h\n", rose_seen, fell_seen);
        $fclose(fd);
        $display("TOGGLE_COV: %0d / %0d bits toggled 0->1 and 1->0 (%0.2f%%, cumulative)%s",
                 both, W, 100.0 * both / W,
                 missing == "" ? "" : {" | not toggled bit index:", missing});
    end
endmodule
