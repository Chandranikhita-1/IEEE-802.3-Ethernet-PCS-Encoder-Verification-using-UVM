`ifndef PCS_SEQUENCER_SV
`define PCS_SEQUENCER_SV

class pcs_sequencer extends uvm_sequencer #(pcs_input_seq_item);
  `uvm_component_utils(pcs_sequencer)

  function new(string name = "pcs_sequencer", uvm_component parent = null);
    super.new(name, parent);
  endfunction
endclass

`endif
