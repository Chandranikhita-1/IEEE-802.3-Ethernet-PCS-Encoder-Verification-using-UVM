`ifndef PCS_MONITOR_SV
`define PCS_MONITOR_SV

class pcs_monitor extends uvm_monitor;
  `uvm_component_utils(pcs_monitor)

  virtual pcs_if vif;
  uvm_analysis_port #(pcs_output_seq_item) output_port;

  function new(string name = "pcs_monitor", uvm_component parent = null);
    super.new(name, parent);
  endfunction

  virtual function void build_phase(uvm_phase phase);
    super.build_phase(phase);
    output_port = new("output_port", this);
    if (!uvm_config_db #(virtual pcs_if)::get(this, "", "vif", vif)) begin
      `uvm_fatal("MONITOR", "Failed to get virtual interface")
    end
  endfunction

  virtual task run_phase(uvm_phase phase);
    pcs_output_seq_item item;

    @(posedge vif.Reset);
    @(negedge vif.Reset);

    forever begin
      @(posedge vif.Clk);
      #1ps;
      item = pcs_output_seq_item::type_id::create("item");
      item.decode_from_dout(vif.Dout);
      output_port.write(item);
      `uvm_info("MONITOR", {"Sampled ", item.convert2string()}, UVM_LOW)
    end
  endtask
endclass

`endif
