`timescale 1ns/1ps
`include "DUTS26_0.sv"
`include "uvm_macros.svh"
`include "pcs_pkg.sv"

module tb_top;
  import uvm_pkg::*;
  import pcs_pkg::*;

  localparam time CLK_PERIOD = 8ns;
  logic Clk;

  pcs_if pcs_vif(Clk);

  initial begin
    Clk = 1'b0;
    forever #(CLK_PERIOD/2) Clk = ~Clk;
  end

  DUTS26_0 dut (
    .Clk   (Clk),
    .Reset (pcs_vif.Reset),
    .Din   (pcs_vif.Din),
    .TX_EN (pcs_vif.TX_EN),
    .Dout  (pcs_vif.Dout)
  );

  initial begin
    pcs_vif.Reset = 1'b0;
    pcs_vif.Din   = 8'h00;
    pcs_vif.TX_EN = 1'b0;

    #1ns;
    pcs_vif.Reset = 1'b1;
    repeat (5) @(posedge Clk);
    pcs_vif.Reset = 1'b0;
  end

  initial begin
    uvm_config_db #(virtual pcs_if)::set(null, "*", "vif", pcs_vif);
    run_test("pcs_test_directed");
  end

  // --- Expose DUT internal FSM state to interface for FSM coverage ---
  // hierarchical reference: tb_top.dut.cstate
  assign pcs_vif.fsm_state = dut.cstate;

  initial begin
      $dumpfile("pcs_tb.vcd");
      $dumpvars(0, tb_top);
    end

endmodule
