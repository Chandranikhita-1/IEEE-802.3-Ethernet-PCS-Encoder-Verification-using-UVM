`ifndef PCS_SCOREBOARD_SV
`define PCS_SCOREBOARD_SV

class pcs_scoreboard extends uvm_scoreboard;
  `uvm_component_utils(pcs_scoreboard)

  uvm_analysis_imp      #(pcs_output_seq_item, pcs_scoreboard) monitor_port;
  uvm_tlm_analysis_fifo #(pcs_input_seq_item)                  driver_fifo;

  pcs_ref_model ref_model;
  int unsigned pass_count, fail_count, total_count;

  function new(string name = "pcs_scoreboard", uvm_component parent = null);
    super.new(name, parent);
  endfunction

  virtual function void build_phase(uvm_phase phase);
    super.build_phase(phase);
    monitor_port = new("monitor_port", this);
    driver_fifo  = new("driver_fifo", this);
    ref_model    = new(.master_mode(1'b1), .seed(33'h1));
  endfunction

  virtual function void write(pcs_output_seq_item mon_item);
    pcs_input_seq_item drv_item;

    if (!driver_fifo.try_get(drv_item)) begin
      `uvm_error("SB", "No driven item available for this monitored output. Check latency/reset alignment.")
      return;
    end

    total_count++;
    ref_model.tick_gmii(drv_item.din, drv_item.tx_en);

    if (mon_item.A !== ref_model.A || mon_item.B !== ref_model.B ||
        mon_item.C !== ref_model.C || mon_item.D !== ref_model.D) begin
      fail_count++;
      `uvm_error("SB", $sformatf(
        "MISMATCH[%0d] DUT A=%0d B=%0d C=%0d D=%0d | REF A=%0d B=%0d C=%0d D=%0d | Din=0x%02h TX_EN=%0b",
        total_count, mon_item.A, mon_item.B, mon_item.C, mon_item.D,
        ref_model.A, ref_model.B, ref_model.C, ref_model.D,
        drv_item.din, drv_item.tx_en))
    end
    else begin
      pass_count++;
      `uvm_info("SB", $sformatf("MATCH[%0d] A=%0d B=%0d C=%0d D=%0d", total_count, mon_item.A, mon_item.B, mon_item.C, mon_item.D), UVM_LOW)
    end
  endfunction

  virtual function void report_phase(uvm_phase phase);
    `uvm_info("SB", $sformatf("\n===== RESULTS =====\nTOTAL=%0d PASS=%0d FAIL=%0d\n===================", total_count, pass_count, fail_count), UVM_NONE)
  endfunction
endclass

`endif
