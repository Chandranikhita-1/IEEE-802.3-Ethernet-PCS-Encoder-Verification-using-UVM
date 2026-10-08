`ifndef PCS_OUTPUT_SEQ_ITEM_SV
`define PCS_OUTPUT_SEQ_ITEM_SV

typedef enum int {
  OFFSET_BINARY  = 0,
  TWOS_COMP      = 1,
  SIGN_MAG_0     = 2,
  SIGN_MAG_1     = 3,
  GRAY           = 4,
  INV_OFFSET     = 5,
  INV_TWOS_COMP  = 6
} encoding_t;

class pcs_output_seq_item extends uvm_sequence_item;
  `uvm_object_utils(pcs_output_seq_item)

  logic [11:0] raw;
  logic [2:0] A_raw, B_raw, C_raw, D_raw;
  logic signed [2:0] A, B, C, D;
  encoding_t encoding = TWOS_COMP;

  function new(string name = "pcs_output_seq_item");
    super.new(name);
  endfunction

  function automatic logic signed [2:0] decode_sym(logic [2:0] raw_sym);
    case (encoding)
      OFFSET_BINARY: begin
        case (raw_sym)
          3'b000: return -2;
          3'b001: return -1;
          3'b010: return  0;
          3'b011: return  1;
          3'b100: return  2;
          default: return  0;
        endcase
      end
      TWOS_COMP: return $signed(raw_sym);
      SIGN_MAG_0: return raw_sym[2] ? -$signed({1'b0, raw_sym[1:0]}) : $signed({1'b0, raw_sym[1:0]});
      SIGN_MAG_1: return raw_sym[2] ?  $signed({1'b0, raw_sym[1:0]}) : -$signed({1'b0, raw_sym[1:0]});
      GRAY: begin
        case (raw_sym)
          3'b010: return -2;
          3'b110: return -1;
          3'b000: return  0;
          3'b001: return  1;
          3'b011: return  2;
          default: return  0;
        endcase
      end
      INV_OFFSET: begin
        case (raw_sym)
          3'b100: return -2;
          3'b011: return -1;
          3'b010: return  0;
          3'b001: return  1;
          3'b000: return  2;
          default: return  0;
        endcase
      end
      INV_TWOS_COMP: return -$signed(raw_sym);
      default: return 0;
    endcase
  endfunction

  function void decode_from_dout(logic [3:0][2:0] dout);
    A_raw = dout[3];
    B_raw = dout[2];
    C_raw = dout[1];
    D_raw = dout[0];
    raw   = {A_raw, B_raw, C_raw, D_raw};
    A = decode_sym(A_raw);
    B = decode_sym(B_raw);
    C = decode_sym(C_raw);
    D = decode_sym(D_raw);
  endfunction

  virtual function string convert2string();
    return $sformatf("A=%0d B=%0d C=%0d D=%0d raw=0x%03h", A, B, C, D, raw);
  endfunction
endclass

`endif
