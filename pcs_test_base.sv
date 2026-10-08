`ifndef PCS_TEST_BASE_SV
`define PCS_TEST_BASE_SV

class pcs_test_base extends uvm_test;
  `uvm_component_utils(pcs_test_base)

  pcs_env env;

  function new(string name = "pcs_test_base", uvm_component parent = null);
    super.new(name, parent);
  endfunction

  virtual function void build_phase(uvm_phase phase);
    super.build_phase(phase);
    env = pcs_env::type_id::create("env", this);
  endfunction
endclass

`endif
