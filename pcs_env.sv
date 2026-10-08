/*`ifndef PCS_ENV_SV
`define PCS_ENV_SV

class pcs_env extends uvm_env;
  `uvm_component_utils(pcs_env)

  pcs_agent      agent;
  pcs_scoreboard scoreboard;
  pcs_coverage   coverage;

  function new(string name = "pcs_env", uvm_component parent = null);
    super.new(name, parent);
  endfunction

  virtual function void build_phase(uvm_phase phase);
    super.build_phase(phase);
    agent      = pcs_agent::type_id::create("agent", this);
    scoreboard = pcs_scoreboard::type_id::create("scoreboard", this);
    coverage   = pcs_coverage::type_id::create("coverage", this);
  endfunction

  virtual function void connect_phase(uvm_phase phase);
    agent.monitor.output_port.connect(scoreboard.monitor_port);
    agent.monitor.output_port.connect(coverage.analysis_export);
    agent.driver.driven_port.connect(scoreboard.driver_fifo.analysis_export);
  endfunction
endclass

`endif*/

`ifndef PCS_ENV_SV
`define PCS_ENV_SV

class pcs_env extends uvm_env;
  `uvm_component_utils(pcs_env)

  pcs_agent      agent;
  pcs_scoreboard scoreboard;
  pcs_coverage   coverage;

  function new(string name = "pcs_env", uvm_component parent = null);
    super.new(name, parent);
  endfunction

  virtual function void build_phase(uvm_phase phase);
    super.build_phase(phase);

    agent      = pcs_agent::type_id::create("agent", this);
    scoreboard = pcs_scoreboard::type_id::create("scoreboard", this);
    coverage   = pcs_coverage::type_id::create("coverage", this);
  endfunction

  virtual function void connect_phase(uvm_phase phase);
    super.connect_phase(phase);

    agent.monitor.output_port.connect(scoreboard.monitor_port);
    agent.driver.driven_port.connect(scoreboard.driver_fifo.analysis_export);

    agent.driver.driven_port.connect(coverage.input_export);
    agent.monitor.output_port.connect(coverage.output_export);
  endfunction

endclass

`endif
