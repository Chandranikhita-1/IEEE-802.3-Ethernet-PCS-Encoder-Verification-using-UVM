
`ifndef PCS_TEST_DIRECTED_SV
`define PCS_TEST_DIRECTED_SV

class pcs_test_directed extends pcs_test_base;
  `uvm_component_utils(pcs_test_directed)

  virtual pcs_if vif;

  function new(string name = "pcs_test_directed", uvm_component parent = null);
    super.new(name, parent);
  endfunction

  virtual function void build_phase(uvm_phase phase);
    super.build_phase(phase);

    if (!uvm_config_db #(virtual pcs_if)::get(this, "", "vif", vif)) begin
      `uvm_fatal("NOVIF", "Could not get virtual interface in pcs_test_directed")
    end
  endfunction

  virtual task run_phase(uvm_phase phase);
    phase.raise_objection(this);

    run_tc("TC1 idle",             pcs_seq_idle_check::type_id::create("tc1"));
    run_tc("TC2 minimal packet",   pcs_seq_minimal_packet::type_id::create("tc2"));
    run_tc("TC3 full frame",       pcs_seq_full_frame::type_id::create("tc3"));
    run_tc("TC4 back-to-back",     pcs_seq_back_to_back::type_id::create("tc4"));
    run_tc("TC5 long packet",      pcs_seq_long_packet::type_id::create("tc5"));
    run_tc("TC6 all zeros",        pcs_seq_all_zeros::type_id::create("tc6"));
    run_tc("TC7 all ones",         pcs_seq_all_ones::type_id::create("tc7"));
    run_tc("TC8 alternating",      pcs_seq_alternating::type_id::create("tc8"));

    begin
      pcs_seq_random s;
      s = pcs_seq_random::type_id::create("tc9");
      void'(s.randomize() with {
        num_packets == 20;
        min_bytes   == 4;
        max_bytes   == 64;
      });
      run_tc("TC9 random", s);
    end

    run_tc("TC10 walking ones",        pcs_seq_walking_ones::type_id::create("tc10"));
    run_tc("TC11 idle symbols",        pcs_seq_idle_symbol_check::type_id::create("tc11"));
    run_tc("TC12 stress",              pcs_seq_stress::type_id::create("tc12"));

    run_tc("TC13 SSD entry",           pcs_seq_ssd_entry::type_id::create("tc13_ssd"));
    run_tc("TC14 very long packet",    pcs_seq_very_long_packet::type_id::create("tc14_vlong"));
    run_tc("TC15 long idle",           pcs_seq_long_idle::type_id::create("tc15_long_idle"));
    run_tc("TC16 TX_EN pulse patterns", pcs_seq_txen_pulses::type_id::create("tc16_pulses"));

    run_tc("TC17 FSM idle sustained",  pcs_seq_fsm_idle_sustained::type_id::create("tc17_fsm_idle"));
    run_tc("TC18 FSM full arc",        pcs_seq_fsm_full_arc::type_id::create("tc18_fsm_full"));
    run_tc("TC19 FSM long TX",         pcs_seq_fsm_long_tx::type_id::create("tc19_fsm_long_tx"));
    run_tc("TC20 FSM rapid packets",   pcs_seq_fsm_rapid_packets::type_id::create("tc20_fsm_rapid"));
    run_tc("TC21 idle lookup phase sweep",
       pcs_seq_idle_lookup_phase_sweep::type_id::create("tc21_idle_lookup_phase"));

run_tc("TC22 idle lookup pulse sweep",
       pcs_seq_idle_lookup_pulse_sweep::type_id::create("tc22_idle_lookup_pulse"));

run_tc("TC23 idle lookup random stress",
       pcs_seq_idle_lookup_random_stress::type_id::create("tc23_idle_lookup_random"));

    // Reset-directed tests for FSM reset transition coverage
    run_reset_directed_tests();

    phase.drop_objection(this);
  endtask

  protected task run_tc(string name, pcs_seq_base seq);
    `uvm_info("TEST", $sformatf("===== Running %s =====", name), UVM_NONE)
    seq.start(env.agent.sequencer);
  endtask

 
  protected task drive_cycle(logic [7:0] din, bit tx_en);
    @(negedge vif.Clk);
    vif.Din   <= din;
    vif.TX_EN <= tx_en;
  endtask

  protected task drive_idle_cycles(int n);
    repeat (n) begin
      drive_cycle(8'h00, 1'b0);
    end
  endtask

  protected task drive_data_cycles(int n, logic [7:0] start = 8'h55);
    for (int i = 0; i < n; i++) begin
      drive_cycle(start + i[7:0], 1'b1);
    end
  endtask

  protected task pulse_reset(string tag, int unsigned cycles = 2);
    `uvm_info("RESET_TC", $sformatf("Pulsing reset during %s", tag), UVM_NONE)

    @(negedge vif.Clk);
    vif.Reset <= 1'b1;
    vif.Din   <= 8'h00;
    vif.TX_EN <= 1'b0;

    repeat (cycles) @(negedge vif.Clk);

    vif.Reset <= 1'b0;
    vif.Din   <= 8'h00;
    vif.TX_EN <= 1'b0;

    // Let DUT settle after reset
    repeat (4) @(posedge vif.Clk);
  endtask

  
  protected task run_reset_directed_tests();

    `uvm_info("TEST", "===== Running TC_RESET_IDLE =====", UVM_NONE)
    drive_idle_cycles(8);
    pulse_reset("s_send_idle");

    `uvm_info("TEST", "===== Running TC_RESET_SDD2 =====", UVM_NONE)
    drive_idle_cycles(8);
    drive_cycle(8'h55, 1'b1);     // packet start, DUT likely enters SDD2
    pulse_reset("s_SDD2");

    `uvm_info("TEST", "===== Running TC_RESET_TRANSMIT_DATA =====", UVM_NONE)
    drive_idle_cycles(8);
    drive_data_cycles(8, 8'h10);  // hold TX_EN high long enough for transmit state
    pulse_reset("s_Transmit_data");

    `uvm_info("TEST", "===== Running TC_RESET_CSR2 =====", UVM_NONE)
    drive_idle_cycles(8);
    drive_data_cycles(8, 8'h20);
    drive_cycle(8'h00, 1'b0);     // first cycle after TX_EN drops, likely CSR2
    pulse_reset("s_CSR2");

    `uvm_info("TEST", "===== Running TC_RESET_ESD1 =====", UVM_NONE)
    drive_idle_cycles(8);
    drive_data_cycles(8, 8'h30);
    drive_cycle(8'h00, 1'b0);     // CSR2
    drive_cycle(8'h00, 1'b0);     // likely ESD1
    pulse_reset("s_ESD1");

    `uvm_info("TEST", "===== Running TC_RESET_ESD2 =====", UVM_NONE)
    drive_idle_cycles(8);
    drive_data_cycles(8, 8'h40);
    drive_cycle(8'h00, 1'b0);     // CSR2
    drive_cycle(8'h00, 1'b0);     // ESD1
    drive_cycle(8'h00, 1'b0);     // likely ESD2
    pulse_reset("s_ESD2");

    // Attempt reset near SSD1 timing.
    // This may still not hit s_SDD1 if the DUT bypasses that state.
    `uvm_info("TEST", "===== Running TC_RESET_SDD1_ATTEMPT =====", UVM_NONE)
    drive_idle_cycles(8);
    drive_cycle(8'h55, 1'b1);
    pulse_reset("s_SDD1 attempt");

    drive_idle_cycles(8);

  endtask

endclass

`endif
