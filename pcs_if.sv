`ifndef PCS_IF_SV
`define PCS_IF_SV

interface pcs_if(input logic Clk);
  logic        Reset;   // active-high reset for DUTS26_0
  logic [7:0]  Din;
  logic        TX_EN;
  logic [3:0][2:0] Dout; // Dout[3]=A, Dout[2]=B, Dout[1]=C, Dout[0]=D

  // --- FSM state observation (driven by tb_top via hierarchical ref) ---
  logic [3:0]  fsm_state;   // mirrors DUT's cstate for FSM coverage
endinterface

`endif
