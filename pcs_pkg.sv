`ifndef PCS_PKG_SV
`define PCS_PKG_SV

`include "uvm_macros.svh"
`include "pcs_if.sv"

package pcs_pkg;
  import uvm_pkg::*;

  `include "pcs_reference.sv"
  `include "pcs_input_seq_item.sv"
  `include "pcs_output_seq_item.sv"
  `include "pcs_sequencer.sv"
  `include "pcs_driver.sv"
  `include "pcs_monitor.sv"
  `include "pcs_scoreboard.sv"
  `include "pcs_coverage.sv"
  `include "pcs_agent.sv"
  `include "pcs_env.sv"
  `include "pcs_test_base.sv"
  `include "pcs_sequence.sv"
  `include "pcs_test_directed.sv"

endpackage

`endif
