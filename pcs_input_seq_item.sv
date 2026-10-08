`ifndef PCS_INPUT_SEQ_ITEM_SV
`define PCS_INPUT_SEQ_ITEM_SV

class pcs_input_seq_item extends uvm_sequence_item;
  `uvm_object_utils(pcs_input_seq_item)

  rand logic [7:0] din;
  rand logic       tx_en;

  function new(string name = "pcs_input_seq_item");
    super.new(name);
  endfunction

  virtual function string convert2string();
    return $sformatf("Din=0x%02h TX_EN=%0b", din, tx_en);
  endfunction
endclass

`endif
