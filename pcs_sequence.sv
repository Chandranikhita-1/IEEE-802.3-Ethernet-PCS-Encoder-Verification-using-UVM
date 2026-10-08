`ifndef PCS_SEQUENCE_SV
`define PCS_SEQUENCE_SV

class pcs_seq_base extends uvm_sequence #(pcs_input_seq_item);
  `uvm_object_utils(pcs_seq_base)
  `uvm_declare_p_sequencer(pcs_sequencer)

  function new(string name = "pcs_seq_base");
    super.new(name);
  endfunction

  task send_byte(logic [7:0] data, bit en);
    pcs_input_seq_item item;
    item = pcs_input_seq_item::type_id::create("item");
    start_item(item);
    item.din   = data;
    item.tx_en = en;
    finish_item(item);
  endtask

  task send_idle(int n = 4);
    repeat (n) send_byte(8'h00, 1'b0);
  endtask

  task send_packet(int nbytes, logic [7:0] start = 8'h55);
    for (int i = 0; i < nbytes; i++) begin
      send_byte(start + i[7:0], 1'b1);
    end
    send_idle(4);
  endtask
endclass

class pcs_seq_idle_check extends pcs_seq_base;
  `uvm_object_utils(pcs_seq_idle_check)
  function new(string name = "pcs_seq_idle_check"); super.new(name); endfunction
  virtual task body(); send_idle(20); endtask
endclass

class pcs_seq_minimal_packet extends pcs_seq_base;
  `uvm_object_utils(pcs_seq_minimal_packet)
  function new(string name = "pcs_seq_minimal_packet"); super.new(name); endfunction
  virtual task body(); send_idle(4); send_packet(1, 8'h55); endtask
endclass

class pcs_seq_full_frame extends pcs_seq_base;
  `uvm_object_utils(pcs_seq_full_frame)
  rand int unsigned pkt_len;
  constraint c_len { pkt_len inside {[8:64]}; }
  function new(string name = "pcs_seq_full_frame"); super.new(name); endfunction
  virtual task body(); send_idle(4); send_packet(pkt_len, 8'h20); endtask
endclass

class pcs_seq_back_to_back extends pcs_seq_base;
  `uvm_object_utils(pcs_seq_back_to_back)
  function new(string name = "pcs_seq_back_to_back"); super.new(name); endfunction
  virtual task body(); send_idle(4); send_packet(8, 8'h10); send_packet(8, 8'h80); endtask
endclass

class pcs_seq_long_packet extends pcs_seq_base;
  `uvm_object_utils(pcs_seq_long_packet)
  function new(string name = "pcs_seq_long_packet"); super.new(name); endfunction
  virtual task body(); send_idle(4); send_packet(128, 8'h00); endtask
endclass

class pcs_seq_all_zeros extends pcs_seq_base;
  `uvm_object_utils(pcs_seq_all_zeros)
  function new(string name = "pcs_seq_all_zeros"); super.new(name); endfunction
  virtual task body(); send_idle(4); repeat (16) send_byte(8'h00, 1'b1); send_idle(4); endtask
endclass

class pcs_seq_all_ones extends pcs_seq_base;
  `uvm_object_utils(pcs_seq_all_ones)
  function new(string name = "pcs_seq_all_ones"); super.new(name); endfunction
  virtual task body(); send_idle(4); repeat (16) send_byte(8'hFF, 1'b1); send_idle(4); endtask
endclass

class pcs_seq_alternating extends pcs_seq_base;
  `uvm_object_utils(pcs_seq_alternating)
  function new(string name = "pcs_seq_alternating"); super.new(name); endfunction
  virtual task body(); send_idle(4); repeat (16) begin send_byte(8'h55, 1'b1); send_byte(8'hAA, 1'b1); end send_idle(4); endtask
endclass

class pcs_seq_random extends pcs_seq_base;
  `uvm_object_utils(pcs_seq_random)
  rand int unsigned num_packets, min_bytes, max_bytes;
  constraint c { num_packets inside {[1:50]}; min_bytes inside {[1:128]}; max_bytes inside {[min_bytes:128]}; }
  function new(string name = "pcs_seq_random"); super.new(name); num_packets = 5; min_bytes = 1; max_bytes = 16; endfunction
  virtual task body();
    int len;
    send_idle(4);
    repeat (num_packets) begin
      len = $urandom_range(min_bytes, max_bytes);
      for (int i = 0; i < len; i++) send_byte($urandom, 1'b1);
      send_idle($urandom_range(2, 8));
    end
  endtask
endclass

class pcs_seq_walking_ones extends pcs_seq_base;
  `uvm_object_utils(pcs_seq_walking_ones)
  function new(string name = "pcs_seq_walking_ones"); super.new(name); endfunction
  virtual task body(); send_idle(4); for (int i = 0; i < 8; i++) send_byte(8'(1 << i), 1'b1); send_idle(4); endtask
endclass

class pcs_seq_idle_symbol_check extends pcs_seq_idle_check;
  `uvm_object_utils(pcs_seq_idle_symbol_check)
  function new(string name = "pcs_seq_idle_symbol_check"); super.new(name); endfunction
endclass

class pcs_seq_stress extends pcs_seq_base;
  `uvm_object_utils(pcs_seq_stress)
  function new(string name = "pcs_seq_stress"); super.new(name); endfunction
  virtual task body();
    pcs_seq_random r;
    r = pcs_seq_random::type_id::create("stress_random");
    void'(r.randomize() with { num_packets == 30; min_bytes == 1; max_bytes == 128; });
    r.start(m_sequencer);
  endtask
endclass

class pcs_seq_ssd_entry extends pcs_seq_base;
  `uvm_object_utils(pcs_seq_ssd_entry)

  function new(string name = "pcs_seq_ssd_entry");
    super.new(name);
  endfunction

  virtual task body();
    send_idle(8);

    send_byte(8'h55, 1'b1); // expected SSD1 cycle
    send_byte(8'h55, 1'b1); // expected SSD2 cycle
    send_byte(8'hD5, 1'b1); // data after SSD
    send_byte(8'h01, 1'b1);
    send_byte(8'h02, 1'b1);

    send_idle(8);
  endtask
endclass

class pcs_seq_very_long_packet extends pcs_seq_base;
  `uvm_object_utils(pcs_seq_very_long_packet)

  function new(string name = "pcs_seq_very_long_packet");
    super.new(name);
  endfunction

  virtual task body();
    send_idle(8);
    send_packet(300, 8'h00);
    send_idle(8);
  endtask
endclass


// Arc: arc_idle_stay  — sustained idle (already covered, but explicit)
class pcs_seq_fsm_idle_sustained extends pcs_seq_base;
  `uvm_object_utils(pcs_seq_fsm_idle_sustained)
  function new(string name = "pcs_seq_fsm_idle_sustained"); super.new(name); endfunction
  virtual task body();
    send_idle(32);  // long idle to accumulate arc_idle_stay hits
  endtask
endclass


// One complete packet exercises the full forward path
class pcs_seq_fsm_full_arc extends pcs_seq_base;
  `uvm_object_utils(pcs_seq_fsm_full_arc)
  function new(string name = "pcs_seq_fsm_full_arc"); super.new(name); endfunction
  virtual task body();
    send_idle(8);
    send_packet(16, 8'hA5);  // 16 bytes → arc_tx_stay fires many times
    send_idle(8);
  endtask
endclass

// Arc: arc_tx_stay — need many consecutive TX_EN=1 cycles
class pcs_seq_fsm_long_tx extends pcs_seq_base;
  `uvm_object_utils(pcs_seq_fsm_long_tx)
  function new(string name = "pcs_seq_fsm_long_tx"); super.new(name); endfunction
  virtual task body();
    send_idle(4);
    send_packet(200, 8'h00);  // very long data burst
    send_idle(4);
  endtask
endclass

// Multiple short packets: rapid idle→SDD2→tx→CSR2→ESD→idle cycling
// Maximises arc hit count per simulation time
class pcs_seq_fsm_rapid_packets extends pcs_seq_base;
  `uvm_object_utils(pcs_seq_fsm_rapid_packets)
  function new(string name = "pcs_seq_fsm_rapid_packets"); super.new(name); endfunction
  virtual task body();
    repeat (20) begin
      send_idle(2);           // minimal gap — arc_idle_stay (few)
      send_packet(4, 8'h11); // short data — arc_tx_stay (few), full path
    end
  endtask
endclass

class pcs_seq_txen_pulses extends pcs_seq_base;
  `uvm_object_utils(pcs_seq_txen_pulses)

  function new(string name = "pcs_seq_txen_pulses");
    super.new(name);
  endfunction

  virtual task body();
    send_idle(8);

    // 1-cycle pulse
    send_byte(8'h55, 1'b1);
    send_idle(4);

    // 2-cycle pulse
    send_byte(8'h55, 1'b1);
    send_byte(8'hD5, 1'b1);
    send_idle(4);

    // 3-cycle pulse
    send_byte(8'h55, 1'b1);
    send_byte(8'h55, 1'b1);
    send_byte(8'hD5, 1'b1);
    send_idle(4);

    // separated pulses
    send_byte(8'h10, 1'b1);
    send_idle(1);
    send_byte(8'h20, 1'b1);
    send_idle(6);
  endtask
endclass

class pcs_seq_long_idle extends pcs_seq_base;
  `uvm_object_utils(pcs_seq_long_idle)

  function new(string name = "pcs_seq_long_idle");
    super.new(name);
  endfunction

  virtual task body();
    send_idle(2000);
  endtask
endclass

// Try to disturb idle lookup phase using odd/even packet lengths
class pcs_seq_idle_lookup_phase_sweep extends pcs_seq_base;
  `uvm_object_utils(pcs_seq_idle_lookup_phase_sweep)

  function new(string name = "pcs_seq_idle_lookup_phase_sweep");
    super.new(name);
  endfunction

  virtual task body();
    send_idle(16);

    // Sweep packet lengths and idle gaps to change phase alignment
    for (int pkt_len = 1; pkt_len <= 32; pkt_len++) begin
      send_packet(pkt_len, 8'h20 + pkt_len[7:0]);

      // Vary idle gap after each packet
      send_idle((pkt_len % 9) + 1);
    end

    send_idle(64);
  endtask
endclass


// Many one-cycle and two-cycle TX_EN bursts.
// Useful for changing delayed tx_enable patterns and idle-entry timing.
class pcs_seq_idle_lookup_pulse_sweep extends pcs_seq_base;
  `uvm_object_utils(pcs_seq_idle_lookup_pulse_sweep)

  function new(string name = "pcs_seq_idle_lookup_pulse_sweep");
    super.new(name);
  endfunction

  virtual task body();
    send_idle(16);

    repeat (50) begin
      // 1-cycle burst
      send_byte($urandom_range(0, 255), 1'b1);
      send_idle($urandom_range(1, 7));

      // 2-cycle burst
      send_byte($urandom_range(0, 255), 1'b1);
      send_byte($urandom_range(0, 255), 1'b1);
      send_idle($urandom_range(1, 7));

      // 3-cycle burst
      send_byte($urandom_range(0, 255), 1'b1);
      send_byte($urandom_range(0, 255), 1'b1);
      send_byte($urandom_range(0, 255), 1'b1);
      send_idle($urandom_range(1, 7));
    end

    send_idle(64);
  endtask
endclass


// Long mixed test: many packet lengths, many idle gaps, many byte patterns.
// This is a last attempt to hit odd idle lookup cases naturally.
class pcs_seq_idle_lookup_random_stress extends pcs_seq_base;
  `uvm_object_utils(pcs_seq_idle_lookup_random_stress)

  function new(string name = "pcs_seq_idle_lookup_random_stress");
    super.new(name);
  endfunction

  virtual task body();
    int pkt_len;
    int gap_len;

    send_idle(32);

    repeat (200) begin
      pkt_len = $urandom_range(1, 80);
      gap_len = $urandom_range(1, 32);

      for (int i = 0; i < pkt_len; i++) begin
        send_byte($urandom_range(0, 255), 1'b1);
      end

      send_idle(gap_len);
    end

    send_idle(128);
  endtask
endclass

`endif
