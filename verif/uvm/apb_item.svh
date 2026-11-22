//-----------------------------------------------------------------------------
// apb_item - one APB3 transfer
//-----------------------------------------------------------------------------
class apb_item extends uvm_sequence_item;
    rand bit [4:0]  addr;
    rand bit        write;
    rand bit [31:0] wdata;
         bit [31:0] rdata;
         bit        slverr;

    `uvm_object_utils_begin(apb_item)
        `uvm_field_int(addr,   UVM_ALL_ON)
        `uvm_field_int(write,  UVM_ALL_ON)
        `uvm_field_int(wdata,  UVM_ALL_ON)
        `uvm_field_int(rdata,  UVM_ALL_ON)
        `uvm_field_int(slverr, UVM_ALL_ON)
    `uvm_object_utils_end

    constraint c_align { addr[1:0] == 2'b00; }

    function new(string name = "apb_item");
        super.new(name);
    endfunction

    function string convert2string();
        return $sformatf("%s addr=0x%02h data=0x%08h slverr=%0b",
                         write ? "WR" : "RD", addr, write ? wdata : rdata, slverr);
    endfunction
endclass
