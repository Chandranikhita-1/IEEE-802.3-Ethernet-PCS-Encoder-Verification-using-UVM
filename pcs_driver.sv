`ifndef PCS_DRIVER_SV
`define PCS_DRIVER_SV

class pcs_driver extends uvm_driver #(pcs_input_seq_item);
  `uvm_component_utils(pcs_driver)

  virtual pcs_if vif;
  uvm_analysis_port #(pcs_input_seq_item) driven_port;

  function new(string name = "pcs_driver", uvm_component parent = null);
    super.new(name, parent);
  endfunction

  virtual function void build_phase(uvm_phase phase);
    super.build_phase(phase);
    driven_port = new("driven_port", this);
    if (!uvm_config_db #(virtual pcs_if)::get(this, "", "vif", vif)) begin
      `uvm_fatal("DRIVER", "Failed to get virtual interface")
    end
  endfunction

  virtual task run_phase(uvm_phase phase);
    vif.Din   <= 8'h00;
    vif.TX_EN <= 1'b0;

    @(posedge vif.Reset);
    @(negedge vif.Reset);

    forever begin
      pcs_input_seq_item item;
      seq_item_port.get_next_item(item);
      drive_item(item);
      seq_item_port.item_done();
    end
  endtask

  protected virtual task drive_item(pcs_input_seq_item item);
    @(negedge vif.Clk);
    vif.Din   <= item.din;
    vif.TX_EN <= item.tx_en;
    driven_port.write(item);
    `uvm_info("DRIVER", $sformatf("Driving Din=0x%02h TX_EN=%0b", item.din, item.tx_en), UVM_LOW)
  endtask
endclass

`endif
