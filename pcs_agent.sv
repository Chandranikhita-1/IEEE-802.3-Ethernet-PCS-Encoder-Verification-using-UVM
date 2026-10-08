`ifndef PCS_AGENT_SV
`define PCS_AGENT_SV

class pcs_agent extends uvm_agent;
  `uvm_component_utils(pcs_agent)

  pcs_driver    driver;
  pcs_monitor   monitor;
  pcs_sequencer sequencer;

  function new(string name = "pcs_agent", uvm_component parent = null);
    super.new(name, parent);
  endfunction

  virtual function void build_phase(uvm_phase phase);
    super.build_phase(phase);
    driver    = pcs_driver::type_id::create("driver", this);
    monitor   = pcs_monitor::type_id::create("monitor", this);
    sequencer = pcs_sequencer::type_id::create("sequencer", this);
  endfunction

  virtual function void connect_phase(uvm_phase phase);
    driver.seq_item_port.connect(sequencer.seq_item_export);
  endfunction
endclass

`endif
