

`ifndef PCS_COVERAGE_SV
`define PCS_COVERAGE_SV

`uvm_analysis_imp_decl(_in)
`uvm_analysis_imp_decl(_out)


typedef enum logic [3:0] {
  COV_s_reset        = 4'd0,
  COV_s_send_idle    = 4'd1,
  COV_s_SDD1         = 4'd2,
  COV_s_SDD2         = 4'd3,
  COV_s_Transmit_data= 4'd4,
  COV_s_CSR1         = 4'd5,
  COV_s_CSR2         = 4'd6,
  COV_s_ESD1         = 4'd7,
  COV_s_ESD2         = 4'd8
} cov_state_t;

class pcs_coverage extends uvm_component;
  `uvm_component_utils(pcs_coverage)

  uvm_analysis_imp_in  #(pcs_input_seq_item,  pcs_coverage) input_export;
  uvm_analysis_imp_out #(pcs_output_seq_item, pcs_coverage) output_export;

  // Virtual interface handle to observe FSM state
  virtual pcs_if vif;

  // -----------------------------
  // Input-side sampled variables
  // -----------------------------
  logic [7:0] cov_din;
  bit         cov_tx_en;
  bit         cov_prev_tx_en;

  bit         cov_packet_start;
  bit         cov_packet_end;

  int unsigned packet_len;
  int unsigned idle_gap_len;

  int unsigned cov_packet_len_sample;
  int unsigned cov_idle_gap_sample;

  // -----------------------------
  // Output-side sampled variables
  // -----------------------------
  logic signed [2:0] cov_A;
  logic signed [2:0] cov_B;
  logic signed [2:0] cov_C;
  logic signed [2:0] cov_D;
  logic [11:0]       cov_raw;

 
covergroup cg_input;
  option.per_instance = 1;

  cp_tx_en: coverpoint cov_tx_en {
    bins idle = {0};
    bins data = {1};
  }

  cp_tx_en_transition: coverpoint cov_tx_en {
    bins idle_to_data = (0 => 1);
    bins data_to_idle = (1 => 0);
  }

  cp_din: coverpoint cov_din {
    bins zero       = {8'h00};
    bins preamble55 = {8'h55};
    bins sfd_d5     = {8'hD5};
    bins low_range  = {[8'h01:8'h1F]};
    bins mid_range  = {[8'h20:8'hDF]};
    bins high_range = {[8'hE0:8'hFF]};
  }

  cp_packet_start: coverpoint cov_packet_start {
    bins seen = {1};
  }

  cp_packet_end: coverpoint cov_packet_end {
    bins seen = {1};
  }

  cp_packet_len: coverpoint cov_packet_len_sample iff (cov_packet_end) {
    bins one_byte      = {1};
    bins short_pkt     = {[2:8]};
    bins medium_pkt    = {[9:64]};
    bins long_pkt      = {[65:256]};
    bins very_long_pkt = {[257:1024]};
  }

  cp_idle_gap: coverpoint cov_idle_gap_sample iff (cov_packet_start) {
    bins no_gap     = {0};
    bins small_gap  = {[1:4]};
    bins medium_gap = {[5:16]};
    bins long_gap   = {[17:128]};
  }

  cg_input_cc: cross cp_tx_en, cp_din {
    ignore_bins idle_with_nonzero_data =
      binsof(cp_tx_en.idle) &&
      (binsof(cp_din.preamble55) ||
       binsof(cp_din.sfd_d5)     ||
       binsof(cp_din.low_range)  ||
       binsof(cp_din.mid_range)  ||
       binsof(cp_din.high_range));
  }

endgroup

 
  covergroup cg_output;
    option.per_instance = 1;

    cp_A: coverpoint cov_A {
      bins neg2 = {-2};
      bins neg1 = {-1};
      bins zero = {0};
      bins pos1 = {1};
      bins pos2 = {2};
      illegal_bins illegal = default;
    }

    cp_B: coverpoint cov_B {
      bins neg2 = {-2};
      bins neg1 = {-1};
      bins zero = {0};
      bins pos1 = {1};
      bins pos2 = {2};
      illegal_bins illegal = default;
    }

    cp_C: coverpoint cov_C {
      bins neg2 = {-2};
      bins neg1 = {-1};
      bins zero = {0};
      bins pos1 = {1};
      bins pos2 = {2};
      illegal_bins illegal = default;
    }

    cp_D: coverpoint cov_D {
      bins neg2 = {-2};
      bins neg1 = {-1};
      bins zero = {0};
      bins pos1 = {1};
      bins pos2 = {2};
      illegal_bins illegal = default;
    }

    cross cp_A, cp_B;
    cross cp_C, cp_D;

  endgroup

  
  logic [3:0] cov_fsm_state;
  logic [3:0] cov_fsm_prev;

  covergroup cg_fsm;
    option.per_instance = 1;

    // ------ State coverage ------
    cp_state: coverpoint cov_fsm_state {
      bins st_reset   = {4'd0};  // s_reset
      bins st_idle    = {4'd1};  // s_send_idle
      bins st_SDD2    = {4'd3};  // s_SDD2
      bins st_tx_data = {4'd4};  // s_Transmit_data
      bins st_CSR2    = {4'd6};  // s_CSR2
      bins st_ESD1    = {4'd7};  // s_ESD1
      bins st_ESD2    = {4'd8};  // s_ESD2
      // Dead states in this DUT — should never be reached
      illegal_bins st_SDD1_dead = {4'd2};  // s_SDD1
      illegal_bins st_CSR1_dead = {4'd5};  // s_CSR1
    }

    // ------ Transition (arc) coverage ------
    // Sampled via cov_fsm_prev → cov_fsm_state
    cp_arc: coverpoint cov_fsm_state {
      bins arc_reset_to_idle = (4'd0 => 4'd1);  // power-on → idle
      bins arc_idle_to_SDD2  = (4'd1 => 4'd3);  // TX_EN rises → SSD phase
      bins arc_SDD2_to_tx    = (4'd3 => 4'd4);  // SSD done → data
      bins arc_tx_to_CSR2    = (4'd4 => 4'd6);  // TX_EN falls → CSReset
      bins arc_CSR2_to_ESD1  = (4'd6 => 4'd7);  // CSReset done → ESD
      bins arc_ESD1_to_ESD2  = (4'd7 => 4'd8);  // ESD first cycle
      bins arc_ESD2_to_idle  = (4'd8 => 4'd1);  // ESD done → idle
      // Self-loops
      bins arc_idle_stay     = (4'd1 => 4'd1);  // sustained idle
      bins arc_tx_stay       = (4'd4 => 4'd4);  // sustained TX
    }

  endgroup

  function new(string name = "pcs_coverage", uvm_component parent = null);
    super.new(name, parent);

    input_export  = new("input_export", this);
    output_export = new("output_export", this);

    cg_input  = new();
    cg_output = new();
    cg_fsm    = new();

    reset_cov_state();
  endfunction

  function void reset_cov_state();
    cov_din              = '0;
    cov_tx_en            = 0;
    cov_prev_tx_en       = 0;
    cov_packet_start     = 0;
    cov_packet_end       = 0;
    packet_len           = 0;
    idle_gap_len         = 0;
    cov_packet_len_sample = 0;
    cov_idle_gap_sample   = 0;

    cov_A   = 0;
    cov_B   = 0;
    cov_C   = 0;
    cov_D   = 0;
    cov_raw = 0;

    // FSM state initialise to reset state
    cov_fsm_state = 4'd0;
    cov_fsm_prev  = 4'd0;
  endfunction

  // Grab VIF from config_db in build_phase
  virtual function void build_phase(uvm_phase phase);
    super.build_phase(phase);
    if (!uvm_config_db #(virtual pcs_if)::get(this, "", "vif", vif))
      `uvm_fatal("COV", "Cannot get vif from config_db")
  endfunction

  // Called whenever driver broadcasts an input item
  virtual function void write_in(pcs_input_seq_item t);
    cov_din        = t.din;
    cov_tx_en      = t.tx_en;

    cov_packet_start = (cov_tx_en == 1'b1 && cov_prev_tx_en == 1'b0);
    cov_packet_end   = (cov_tx_en == 1'b0 && cov_prev_tx_en == 1'b1);

    if (cov_packet_start) begin
      cov_idle_gap_sample = idle_gap_len;
      idle_gap_len = 0;
      packet_len   = 1;
    end
    else if (cov_tx_en) begin
      packet_len++;
    end
    else begin
      idle_gap_len++;
    end

    if (cov_packet_end) begin
      cov_packet_len_sample = packet_len;
    end

    cg_input.sample();

    cov_prev_tx_en = cov_tx_en;
  endfunction

  // Called whenever monitor broadcasts an output item
  // Also sample FSM state here (aligned to output clock boundary)
  virtual function void write_out(pcs_output_seq_item t);
    cov_A   = t.A;
    cov_B   = t.B;
    cov_C   = t.C;
    cov_D   = t.D;
    cov_raw = t.raw;

    // Sample FSM state from vif (updated combinatorially by tb_top assign)
    cov_fsm_prev  = cov_fsm_state;
    cov_fsm_state = vif.fsm_state;
    cg_fsm.sample();

    cg_output.sample();
  endfunction

  function void report_phase(uvm_phase phase);
    super.report_phase(phase);

    `uvm_info("COV",
      $sformatf("Input coverage  = %0.2f%%", cg_input.get_coverage()),
      UVM_LOW)

    `uvm_info("COV",
      $sformatf("Output coverage = %0.2f%%", cg_output.get_coverage()),
      UVM_LOW)

    `uvm_info("COV",
      $sformatf("FSM    coverage = %0.2f%%", cg_fsm.get_coverage()),
      UVM_LOW)

    
    `uvm_info("COV", "--- FSM coverpoint summary ---", UVM_LOW)
    `uvm_info("COV",
      $sformatf("  cp_state coverage = %0.2f%%", cg_fsm.cp_state.get_coverage()),
      UVM_LOW)
    `uvm_info("COV",
      $sformatf("  cp_arc   coverage = %0.2f%%", cg_fsm.cp_arc.get_coverage()),
      UVM_LOW)
  endfunction

endclass

`endif
