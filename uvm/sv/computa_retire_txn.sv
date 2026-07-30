// Architectural-state snapshot of one retired instruction, meant to be
// compared directly against a Spike commit-log entry. 
// Contains what the ISA itself makes visible: PC, the
// instruction that retired there, the full register file, and any memory
// word touched by a load/store.
class computa_retire_txn extends uvm_sequence_item;

    bit [31:0] pc;
    bit [31:0] instruction;
    bit [31:0] regs [32];

    // Indices into regs[] that differ from the previously retired
    // instruction's snapshot. Populated by the monitor
    int unsigned changed_regs [$];

    bit        mem_valid;   // set only for lw/sw-class instructions
    bit [31:0] mem_addr;
    bit [31:0] mem_data;

    `uvm_object_utils_begin(computa_retire_txn)
        `uvm_field_int(pc,          UVM_ALL_ON)
        `uvm_field_int(instruction, UVM_ALL_ON)
        `uvm_field_sarray_int(regs, UVM_ALL_ON)
        `uvm_field_queue_int(changed_regs, UVM_ALL_ON)
        `uvm_field_int(mem_valid,   UVM_ALL_ON)
        `uvm_field_int(mem_addr,    UVM_ALL_ON)
        `uvm_field_int(mem_data,    UVM_ALL_ON)
    `uvm_object_utils_end

    function new(string name = "computa_retire_txn");
        super.new(name);
    endfunction : new

    function string convert2string();
        string s;
        s = $sformatf("pc=%0h instr=%0h", pc, instruction);
        foreach (changed_regs[i])
            s = {s, $sformatf(" x%0d=%0h", changed_regs[i], regs[changed_regs[i]])};
        if (mem_valid) s = {s, $sformatf(" mem[%0h]=%0h", mem_addr, mem_data)};
        return s;
    endfunction : convert2string

endclass : computa_retire_txn
