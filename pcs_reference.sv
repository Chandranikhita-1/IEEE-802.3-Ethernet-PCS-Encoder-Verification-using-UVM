`ifndef PCS_REFERENCE_SV
`define PCS_REFERENCE_SV

`ifndef PCS_DEFAULT_SCR_SEED
`define PCS_DEFAULT_SCR_SEED 33'h1
`endif


typedef logic signed [2:0] pcs_symbol_t;

typedef enum logic [1:0] {
  PCS_SEND_N = 2'd0,
  PCS_SEND_Z = 2'd1,
  PCS_SEND_I = 2'd2
} pcs_tx_mode_t;

typedef enum logic [3:0] {
  COND_NORMAL        = 4'd0,
  COND_XMT_ERR       = 4'd1,
  COND_CS_EXTEND_ERR = 4'd2,
  COND_CS_EXTEND     = 4'd3,
  COND_CS_RESET      = 4'd4,
  COND_SSD1          = 4'd5,
  COND_SSD2          = 4'd6,
  COND_ESD1          = 4'd7,
  COND_ESD2_EXT_0    = 4'd8,
  COND_ESD2_EXT_1    = 4'd9,
  COND_ESD2_EXT_2    = 4'd10,
  COND_ESD_EXT_ERR   = 4'd11
} pcs_condition_t;

class scrambler_model;
  bit          IS_MASTER;
  logic [32:0] scr;
  logic [3:0]  Sx, Sy, Sg;

  function new(bit master_mode = 1'b1, logic [32:0] seed = `PCS_DEFAULT_SCR_SEED);
    IS_MASTER = master_mode;
    reset(seed);
  endfunction

  function void reset(logic [32:0] seed = `PCS_DEFAULT_SCR_SEED);
    logic [32:0] use_seed;
    use_seed = (seed == 33'd0) ? `PCS_DEFAULT_SCR_SEED : seed;
    scr = use_seed;
    compute_sg();
  endfunction

  function void tick();
    logic new_bit;
    new_bit = IS_MASTER ? (scr[32] ^ scr[12]) : (scr[32] ^ scr[19]);
    scr = {scr[31:0], new_bit};
    compute_sg();
  endfunction

  function void compute_sg();
    Sy[0] = scr[0];
    Sy[1] = scr[3] ^ scr[8];
    Sy[2] = scr[6] ^ scr[16];
    Sy[3] = scr[9] ^ scr[14] ^ scr[19] ^ scr[24];

    Sx[0] = scr[4] ^ scr[6];
    Sx[1] = scr[7] ^ scr[9] ^ scr[12] ^ scr[14];
    Sx[2] = scr[10] ^ scr[12] ^ scr[20] ^ scr[22];
    Sx[3] = scr[13] ^ scr[15] ^ scr[18] ^ scr[20] ^
            scr[23] ^ scr[25] ^ scr[28] ^ scr[30];

    Sg[0] = scr[1] ^ scr[5];
    Sg[1] = scr[4] ^ scr[8] ^ scr[9] ^ scr[13];
    Sg[2] = scr[7] ^ scr[11] ^ scr[17] ^ scr[21];
    Sg[3] = scr[10] ^ scr[14] ^ scr[15] ^ scr[19] ^
            scr[20] ^ scr[24] ^ scr[25] ^ scr[29];
  endfunction
endclass

class sign_model;
  bit tx_en_d1, tx_en_d2, tx_en_d3, tx_en_d4;
  bit Srev;
  pcs_symbol_t A, B, C, D;

  function new();
    reset();
  endfunction

  function void reset();
    tx_en_d1 = 1'b0;
    tx_en_d2 = 1'b0;
    tx_en_d3 = 1'b0;
    tx_en_d4 = 1'b0;
    Srev     = 1'b0;
    A = 3'sd0;
    B = 3'sd0;
    C = 3'sd0;
    D = 3'sd0;
  endfunction

  function void tick(
    input bit          tx_en,
    input logic [3:0]  Sg,
    input pcs_symbol_t TA,
    input pcs_symbol_t TB,
    input pcs_symbol_t TC,
    input pcs_symbol_t TD
  );
    pcs_symbol_t snA, snB, snC, snD;

    // Use the old history values here.  After this calculation, shift in tx_en[n].
    Srev = tx_en_d2 | tx_en_d4;

    snA = ((Sg[0] ^ Srev) == 1'b0) ? 3'sd1 : -3'sd1;
    snB = ((Sg[1] ^ Srev) == 1'b0) ? 3'sd1 : -3'sd1;
    snC = ((Sg[2] ^ Srev) == 1'b0) ? 3'sd1 : -3'sd1;
    snD = ((Sg[3] ^ Srev) == 1'b0) ? 3'sd1 : -3'sd1;

    A = TA * snA;
    B = TB * snB;
    C = TC * snC;
    D = TD * snD;

    tx_en_d4 = tx_en_d3;
    tx_en_d3 = tx_en_d2;
    tx_en_d2 = tx_en_d1;
    tx_en_d1 = tx_en;
  endfunction
endclass

class sc_model;
  bit         phase;
  logic [3:1] Sy_prev;
  logic [7:0] Sc;

  function new();
    reset();
  endfunction

  function void reset();
    phase   = 1'b0;       // First symbol after scrambler reset uses current Sy[3:1].
    Sy_prev = 3'b000;
    Sc      = 8'h00;
  endfunction

  function void tick(
    input bit          tx_en_d2,
    input logic [3:0]  Sx,
    input logic [3:0]  Sy,
    input pcs_tx_mode_t tx_mode
  );
    Sc[7:4] = tx_en_d2 ? Sx[3:0] : 4'b0000;

    if (tx_mode == PCS_SEND_Z) begin
      Sc[3:1] = 3'b000;
    end
    else if (phase == 1'b0) begin
      Sc[3:1] = Sy[3:1];
    end
    else begin
      Sc[3:1] = Sy_prev ^ 3'b111;
    end

    Sc[0] = (tx_mode == PCS_SEND_Z) ? 1'b0 : Sy[0];

    Sy_prev = Sy[3:1];
    phase   = ~phase;
  endfunction
endclass

class conv_encoder_model;
  logic [2:0] cs;
  logic [8:0] Sd;

  function new();
    reset();
  endfunction

  function void reset();
    cs = 3'b000;
    Sd = 9'b000_000000;
  endfunction

  function void tick(
    input logic [7:0]  TXD,
    input bit          tx_en_d2,
    input bit          tx_en,
    input bit          tx_error,
    input pcs_tx_mode_t tx_mode,
    input logic [7:0]  Sc,
    input bit          loc_lpi_req       = 1'b0,
    input bit          loc_rcvr_status_ok = 1'b0,
    input bit          loc_update_done   = 1'b0
  );
    logic       csreset;
    logic [2:0] cs_prev;
    logic [2:0] cs_next;
    logic       cext;
    logic       cext_err;

    cs_prev = cs;
    cs_next = 3'b000;
    csreset = tx_en_d2 & ~tx_en;

    cext     = ((!tx_en) && (TXD == 8'h0F)) ? tx_error : 1'b0;
    cext_err = ((!tx_en) && (TXD != 8'h0F) && !loc_lpi_req) ? tx_error : 1'b0;

    // Spec: csn[0] = csn-1[2], and Sdn[8] = csn[0].
    cs_next[0] = cs_prev[2];
    Sd[8]      = cs_next[0];

    if (!csreset && tx_en_d2) begin
      Sd[7] = Sc[7] ^ TXD[7];
      Sd[6] = Sc[6] ^ TXD[6];
    end
    else if (csreset) begin
      Sd[7] = cs_prev[1];
      Sd[6] = cs_prev[0];
    end
    else begin
      Sd[7] = Sc[7];
      Sd[6] = Sc[6];
    end

    Sd[5:4] = tx_en_d2 ? (Sc[5:4] ^ TXD[5:4]) : Sc[5:4];

    if (tx_en_d2) begin
      Sd[3] = Sc[3] ^ TXD[3];
      Sd[2] = Sc[2] ^ TXD[2];
      Sd[1] = Sc[1] ^ TXD[1];
      Sd[0] = Sc[0] ^ TXD[0];
    end
    else begin
      Sd[3] = (loc_lpi_req && (tx_mode != PCS_SEND_Z)) ? (Sc[3] ^ 1'b1) : Sc[3];
      Sd[2] = (loc_rcvr_status_ok && (tx_mode != PCS_SEND_Z)) ? (Sc[2] ^ 1'b1) : Sc[2];
      Sd[1] = (loc_update_done && (tx_mode != PCS_SEND_Z)) ? (Sc[1] ^ 1'b1) : (Sc[1] ^ cext_err);
      Sd[0] = Sc[0] ^ cext;
    end

    cs_next[1] = tx_en_d2 ? (Sd[6] ^ cs_prev[0]) : 1'b0;
    cs_next[2] = tx_en_d2 ? (Sd[7] ^ cs_prev[1]) : 1'b0;

    cs = cs_next;
  endfunction
endclass

class lut_model;
  pcs_symbol_t TA, TB, TC, TD;

  function new();
    reset();
  endfunction

  function void reset();
    TA = 3'sd0;
    TB = 3'sd0;
    TC = 3'sd0;
    TD = 3'sd0;
  endfunction

  function automatic void unpack_symbols(input logic [11:0] packed_symbols);
    TA = packed_symbols[11:9];
    TB = packed_symbols[8:6];
    TC = packed_symbols[5:3];
    TD = packed_symbols[2:0];
  endfunction

  function automatic logic [11:0] normal_packed(input logic [2:0] subset, input logic [5:0] row);
    case ({subset, row})
      9'b000_000000: normal_packed = 12'h000; // +0,+0,+0,+0
      9'b000_000001: normal_packed = 12'hC00; // -2,+0,+0,+0
      9'b000_000010: normal_packed = 12'h180; // +0,-2,+0,+0
      9'b000_000011: normal_packed = 12'hD80; // -2,-2,+0,+0
      9'b000_000100: normal_packed = 12'h030; // +0,+0,-2,+0
      9'b000_000101: normal_packed = 12'hC30; // -2,+0,-2,+0
      9'b000_000110: normal_packed = 12'h1B0; // +0,-2,-2,+0
      9'b000_000111: normal_packed = 12'hDB0; // -2,-2,-2,+0
      9'b000_001000: normal_packed = 12'h006; // +0,+0,+0,-2
      9'b000_001001: normal_packed = 12'hC06; // -2,+0,+0,-2
      9'b000_001010: normal_packed = 12'h186; // +0,-2,+0,-2
      9'b000_001011: normal_packed = 12'hD86; // -2,-2,+0,-2
      9'b000_001100: normal_packed = 12'h036; // +0,+0,-2,-2
      9'b000_001101: normal_packed = 12'hC36; // -2,+0,-2,-2
      9'b000_001110: normal_packed = 12'h1B6; // +0,-2,-2,-2
      9'b000_001111: normal_packed = 12'hDB6; // -2,-2,-2,-2
      9'b000_010000: normal_packed = 12'h249; // +1,+1,+1,+1
      9'b000_010001: normal_packed = 12'hE49; // -1,+1,+1,+1
      9'b000_010010: normal_packed = 12'h3C9; // +1,-1,+1,+1
      9'b000_010011: normal_packed = 12'hFC9; // -1,-1,+1,+1
      9'b000_010100: normal_packed = 12'h279; // +1,+1,-1,+1
      9'b000_010101: normal_packed = 12'hE79; // -1,+1,-1,+1
      9'b000_010110: normal_packed = 12'h3F9; // +1,-1,-1,+1
      9'b000_010111: normal_packed = 12'hFF9; // -1,-1,-1,+1
      9'b000_011000: normal_packed = 12'h24F; // +1,+1,+1,-1
      9'b000_011001: normal_packed = 12'hE4F; // -1,+1,+1,-1
      9'b000_011010: normal_packed = 12'h3CF; // +1,-1,+1,-1
      9'b000_011011: normal_packed = 12'hFCF; // -1,-1,+1,-1
      9'b000_011100: normal_packed = 12'h27F; // +1,+1,-1,-1
      9'b000_011101: normal_packed = 12'hE7F; // -1,+1,-1,-1
      9'b000_011110: normal_packed = 12'h3FF; // +1,-1,-1,-1
      9'b000_011111: normal_packed = 12'hFFF; // -1,-1,-1,-1
      9'b000_100000: normal_packed = 12'h400; // +2,+0,+0,+0
      9'b000_100001: normal_packed = 12'h580; // +2,-2,+0,+0
      9'b000_100010: normal_packed = 12'h430; // +2,+0,-2,+0
      9'b000_100011: normal_packed = 12'h5B0; // +2,-2,-2,+0
      9'b000_100100: normal_packed = 12'h406; // +2,+0,+0,-2
      9'b000_100101: normal_packed = 12'h586; // +2,-2,+0,-2
      9'b000_100110: normal_packed = 12'h436; // +2,+0,-2,-2
      9'b000_100111: normal_packed = 12'h5B6; // +2,-2,-2,-2
      9'b000_101000: normal_packed = 12'h010; // +0,+0,+2,+0
      9'b000_101001: normal_packed = 12'hC10; // -2,+0,+2,+0
      9'b000_101010: normal_packed = 12'h190; // +0,-2,+2,+0
      9'b000_101011: normal_packed = 12'hD90; // -2,-2,+2,+0
      9'b000_101100: normal_packed = 12'h016; // +0,+0,+2,-2
      9'b000_101101: normal_packed = 12'hC16; // -2,+0,+2,-2
      9'b000_101110: normal_packed = 12'h196; // +0,-2,+2,-2
      9'b000_101111: normal_packed = 12'hD96; // -2,-2,+2,-2
      9'b000_110000: normal_packed = 12'h080; // +0,+2,+0,+0
      9'b000_110001: normal_packed = 12'hC80; // -2,+2,+0,+0
      9'b000_110010: normal_packed = 12'h0B0; // +0,+2,-2,+0
      9'b000_110011: normal_packed = 12'hCB0; // -2,+2,-2,+0
      9'b000_110100: normal_packed = 12'h086; // +0,+2,+0,-2
      9'b000_110101: normal_packed = 12'hC86; // -2,+2,+0,-2
      9'b000_110110: normal_packed = 12'h0B6; // +0,+2,-2,-2
      9'b000_110111: normal_packed = 12'hCB6; // -2,+2,-2,-2
      9'b000_111000: normal_packed = 12'h002; // +0,+0,+0,+2
      9'b000_111001: normal_packed = 12'hC02; // -2,+0,+0,+2
      9'b000_111010: normal_packed = 12'h182; // +0,-2,+0,+2
      9'b000_111011: normal_packed = 12'hD82; // -2,-2,+0,+2
      9'b000_111100: normal_packed = 12'h032; // +0,+0,-2,+2
      9'b000_111101: normal_packed = 12'hC32; // -2,+0,-2,+2
      9'b000_111110: normal_packed = 12'h1B2; // +0,-2,-2,+2
      9'b000_111111: normal_packed = 12'hDB2; // -2,-2,-2,+2
      9'b001_000000: normal_packed = 12'h001; // +0,+0,+0,+1
      9'b001_000001: normal_packed = 12'hC01; // -2,+0,+0,+1
      9'b001_000010: normal_packed = 12'h181; // +0,-2,+0,+1
      9'b001_000011: normal_packed = 12'hD81; // -2,-2,+0,+1
      9'b001_000100: normal_packed = 12'h031; // +0,+0,-2,+1
      9'b001_000101: normal_packed = 12'hC31; // -2,+0,-2,+1
      9'b001_000110: normal_packed = 12'h1B1; // +0,-2,-2,+1
      9'b001_000111: normal_packed = 12'hDB1; // -2,-2,-2,+1
      9'b001_001000: normal_packed = 12'h007; // +0,+0,+0,-1
      9'b001_001001: normal_packed = 12'hC07; // -2,+0,+0,-1
      9'b001_001010: normal_packed = 12'h187; // +0,-2,+0,-1
      9'b001_001011: normal_packed = 12'hD87; // -2,-2,+0,-1
      9'b001_001100: normal_packed = 12'h037; // +0,+0,-2,-1
      9'b001_001101: normal_packed = 12'hC37; // -2,+0,-2,-1
      9'b001_001110: normal_packed = 12'h1B7; // +0,-2,-2,-1
      9'b001_001111: normal_packed = 12'hDB7; // -2,-2,-2,-1
      9'b001_010000: normal_packed = 12'h248; // +1,+1,+1,+0
      9'b001_010001: normal_packed = 12'hE48; // -1,+1,+1,+0
      9'b001_010010: normal_packed = 12'h3C8; // +1,-1,+1,+0
      9'b001_010011: normal_packed = 12'hFC8; // -1,-1,+1,+0
      9'b001_010100: normal_packed = 12'h278; // +1,+1,-1,+0
      9'b001_010101: normal_packed = 12'hE78; // -1,+1,-1,+0
      9'b001_010110: normal_packed = 12'h3F8; // +1,-1,-1,+0
      9'b001_010111: normal_packed = 12'hFF8; // -1,-1,-1,+0
      9'b001_011000: normal_packed = 12'h24E; // +1,+1,+1,-2
      9'b001_011001: normal_packed = 12'hE4E; // -1,+1,+1,-2
      9'b001_011010: normal_packed = 12'h3CE; // +1,-1,+1,-2
      9'b001_011011: normal_packed = 12'hFCE; // -1,-1,+1,-2
      9'b001_011100: normal_packed = 12'h27E; // +1,+1,-1,-2
      9'b001_011101: normal_packed = 12'hE7E; // -1,+1,-1,-2
      9'b001_011110: normal_packed = 12'h3FE; // +1,-1,-1,-2
      9'b001_011111: normal_packed = 12'hFFE; // -1,-1,-1,-2
      9'b001_100000: normal_packed = 12'h401; // +2,+0,+0,+1
      9'b001_100001: normal_packed = 12'h581; // +2,-2,+0,+1
      9'b001_100010: normal_packed = 12'h431; // +2,+0,-2,+1
      9'b001_100011: normal_packed = 12'h5B1; // +2,-2,-2,+1
      9'b001_100100: normal_packed = 12'h407; // +2,+0,+0,-1
      9'b001_100101: normal_packed = 12'h587; // +2,-2,+0,-1
      9'b001_100110: normal_packed = 12'h437; // +2,+0,-2,-1
      9'b001_100111: normal_packed = 12'h5B7; // +2,-2,-2,-1
      9'b001_101000: normal_packed = 12'h011; // +0,+0,+2,+1
      9'b001_101001: normal_packed = 12'hC11; // -2,+0,+2,+1
      9'b001_101010: normal_packed = 12'h191; // +0,-2,+2,+1
      9'b001_101011: normal_packed = 12'hD91; // -2,-2,+2,+1
      9'b001_101100: normal_packed = 12'h017; // +0,+0,+2,-1
      9'b001_101101: normal_packed = 12'hC17; // -2,+0,+2,-1
      9'b001_101110: normal_packed = 12'h197; // +0,-2,+2,-1
      9'b001_101111: normal_packed = 12'hD97; // -2,-2,+2,-1
      9'b001_110000: normal_packed = 12'h081; // +0,+2,+0,+1
      9'b001_110001: normal_packed = 12'hC81; // -2,+2,+0,+1
      9'b001_110010: normal_packed = 12'h0B1; // +0,+2,-2,+1
      9'b001_110011: normal_packed = 12'hCB1; // -2,+2,-2,+1
      9'b001_110100: normal_packed = 12'h087; // +0,+2,+0,-1
      9'b001_110101: normal_packed = 12'hC87; // -2,+2,+0,-1
      9'b001_110110: normal_packed = 12'h0B7; // +0,+2,-2,-1
      9'b001_110111: normal_packed = 12'hCB7; // -2,+2,-2,-1
      9'b001_111000: normal_packed = 12'h24A; // +1,+1,+1,+2
      9'b001_111001: normal_packed = 12'hE4A; // -1,+1,+1,+2
      9'b001_111010: normal_packed = 12'h3CA; // +1,-1,+1,+2
      9'b001_111011: normal_packed = 12'hFCA; // -1,-1,+1,+2
      9'b001_111100: normal_packed = 12'h27A; // +1,+1,-1,+2
      9'b001_111101: normal_packed = 12'hE7A; // -1,+1,-1,+2
      9'b001_111110: normal_packed = 12'h3FA; // +1,-1,-1,+2
      9'b001_111111: normal_packed = 12'hFFA; // -1,-1,-1,+2
      9'b010_000000: normal_packed = 12'h009; // +0,+0,+1,+1
      9'b010_000001: normal_packed = 12'hC09; // -2,+0,+1,+1
      9'b010_000010: normal_packed = 12'h189; // +0,-2,+1,+1
      9'b010_000011: normal_packed = 12'hD89; // -2,-2,+1,+1
      9'b010_000100: normal_packed = 12'h039; // +0,+0,-1,+1
      9'b010_000101: normal_packed = 12'hC39; // -2,+0,-1,+1
      9'b010_000110: normal_packed = 12'h1B9; // +0,-2,-1,+1
      9'b010_000111: normal_packed = 12'hDB9; // -2,-2,-1,+1
      9'b010_001000: normal_packed = 12'h00F; // +0,+0,+1,-1
      9'b010_001001: normal_packed = 12'hC0F; // -2,+0,+1,-1
      9'b010_001010: normal_packed = 12'h18F; // +0,-2,+1,-1
      9'b010_001011: normal_packed = 12'hD8F; // -2,-2,+1,-1
      9'b010_001100: normal_packed = 12'h03F; // +0,+0,-1,-1
      9'b010_001101: normal_packed = 12'hC3F; // -2,+0,-1,-1
      9'b010_001110: normal_packed = 12'h1BF; // +0,-2,-1,-1
      9'b010_001111: normal_packed = 12'hDBF; // -2,-2,-1,-1
      9'b010_010000: normal_packed = 12'h240; // +1,+1,+0,+0
      9'b010_010001: normal_packed = 12'hE40; // -1,+1,+0,+0
      9'b010_010010: normal_packed = 12'h3C0; // +1,-1,+0,+0
      9'b010_010011: normal_packed = 12'hFC0; // -1,-1,+0,+0
      9'b010_010100: normal_packed = 12'h270; // +1,+1,-2,+0
      9'b010_010101: normal_packed = 12'hE70; // -1,+1,-2,+0
      9'b010_010110: normal_packed = 12'h3F0; // +1,-1,-2,+0
      9'b010_010111: normal_packed = 12'hFF0; // -1,-1,-2,+0
      9'b010_011000: normal_packed = 12'h246; // +1,+1,+0,-2
      9'b010_011001: normal_packed = 12'hE46; // -1,+1,+0,-2
      9'b010_011010: normal_packed = 12'h3C6; // +1,-1,+0,-2
      9'b010_011011: normal_packed = 12'hFC6; // -1,-1,+0,-2
      9'b010_011100: normal_packed = 12'h276; // +1,+1,-2,-2
      9'b010_011101: normal_packed = 12'hE76; // -1,+1,-2,-2
      9'b010_011110: normal_packed = 12'h3F6; // +1,-1,-2,-2
      9'b010_011111: normal_packed = 12'hFF6; // -1,-1,-2,-2
      9'b010_100000: normal_packed = 12'h409; // +2,+0,+1,+1
      9'b010_100001: normal_packed = 12'h589; // +2,-2,+1,+1
      9'b010_100010: normal_packed = 12'h439; // +2,+0,-1,+1
      9'b010_100011: normal_packed = 12'h5B9; // +2,-2,-1,+1
      9'b010_100100: normal_packed = 12'h40F; // +2,+0,+1,-1
      9'b010_100101: normal_packed = 12'h58F; // +2,-2,+1,-1
      9'b010_100110: normal_packed = 12'h43F; // +2,+0,-1,-1
      9'b010_100111: normal_packed = 12'h5BF; // +2,-2,-1,-1
      9'b010_101000: normal_packed = 12'h250; // +1,+1,+2,+0
      9'b010_101001: normal_packed = 12'hE50; // -1,+1,+2,+0
      9'b010_101010: normal_packed = 12'h3D0; // +1,-1,+2,+0
      9'b010_101011: normal_packed = 12'hFD0; // -1,-1,+2,+0
      9'b010_101100: normal_packed = 12'h256; // +1,+1,+2,-2
      9'b010_101101: normal_packed = 12'hE56; // -1,+1,+2,-2
      9'b010_101110: normal_packed = 12'h3D6; // +1,-1,+2,-2
      9'b010_101111: normal_packed = 12'hFD6; // -1,-1,+2,-2
      9'b010_110000: normal_packed = 12'h089; // +0,+2,+1,+1
      9'b010_110001: normal_packed = 12'hC89; // -2,+2,+1,+1
      9'b010_110010: normal_packed = 12'h0B9; // +0,+2,-1,+1
      9'b010_110011: normal_packed = 12'hCB9; // -2,+2,-1,+1
      9'b010_110100: normal_packed = 12'h08F; // +0,+2,+1,-1
      9'b010_110101: normal_packed = 12'hC8F; // -2,+2,+1,-1
      9'b010_110110: normal_packed = 12'h0BF; // +0,+2,-1,-1
      9'b010_110111: normal_packed = 12'hCBF; // -2,+2,-1,-1
      9'b010_111000: normal_packed = 12'h242; // +1,+1,+0,+2
      9'b010_111001: normal_packed = 12'hE42; // -1,+1,+0,+2
      9'b010_111010: normal_packed = 12'h3C2; // +1,-1,+0,+2
      9'b010_111011: normal_packed = 12'hFC2; // -1,-1,+0,+2
      9'b010_111100: normal_packed = 12'h272; // +1,+1,-2,+2
      9'b010_111101: normal_packed = 12'hE72; // -1,+1,-2,+2
      9'b010_111110: normal_packed = 12'h3F2; // +1,-1,-2,+2
      9'b010_111111: normal_packed = 12'hFF2; // -1,-1,-2,+2
      9'b011_000000: normal_packed = 12'h008; // +0,+0,+1,+0
      9'b011_000001: normal_packed = 12'hC08; // -2,+0,+1,+0
      9'b011_000010: normal_packed = 12'h188; // +0,-2,+1,+0
      9'b011_000011: normal_packed = 12'hD88; // -2,-2,+1,+0
      9'b011_000100: normal_packed = 12'h038; // +0,+0,-1,+0
      9'b011_000101: normal_packed = 12'hC38; // -2,+0,-1,+0
      9'b011_000110: normal_packed = 12'h1B8; // +0,-2,-1,+0
      9'b011_000111: normal_packed = 12'hDB8; // -2,-2,-1,+0
      9'b011_001000: normal_packed = 12'h00E; // +0,+0,+1,-2
      9'b011_001001: normal_packed = 12'hC0E; // -2,+0,+1,-2
      9'b011_001010: normal_packed = 12'h18E; // +0,-2,+1,-2
      9'b011_001011: normal_packed = 12'hD8E; // -2,-2,+1,-2
      9'b011_001100: normal_packed = 12'h03E; // +0,+0,-1,-2
      9'b011_001101: normal_packed = 12'hC3E; // -2,+0,-1,-2
      9'b011_001110: normal_packed = 12'h1BE; // +0,-2,-1,-2
      9'b011_001111: normal_packed = 12'hDBE; // -2,-2,-1,-2
      9'b011_010000: normal_packed = 12'h241; // +1,+1,+0,+1
      9'b011_010001: normal_packed = 12'hE41; // -1,+1,+0,+1
      9'b011_010010: normal_packed = 12'h3C1; // +1,-1,+0,+1
      9'b011_010011: normal_packed = 12'hFC1; // -1,-1,+0,+1
      9'b011_010100: normal_packed = 12'h271; // +1,+1,-2,+1
      9'b011_010101: normal_packed = 12'hE71; // -1,+1,-2,+1
      9'b011_010110: normal_packed = 12'h3F1; // +1,-1,-2,+1
      9'b011_010111: normal_packed = 12'hFF1; // -1,-1,-2,+1
      9'b011_011000: normal_packed = 12'h247; // +1,+1,+0,-1
      9'b011_011001: normal_packed = 12'hE47; // -1,+1,+0,-1
      9'b011_011010: normal_packed = 12'h3C7; // +1,-1,+0,-1
      9'b011_011011: normal_packed = 12'hFC7; // -1,-1,+0,-1
      9'b011_011100: normal_packed = 12'h277; // +1,+1,-2,-1
      9'b011_011101: normal_packed = 12'hE77; // -1,+1,-2,-1
      9'b011_011110: normal_packed = 12'h3F7; // +1,-1,-2,-1
      9'b011_011111: normal_packed = 12'hFF7; // -1,-1,-2,-1
      9'b011_100000: normal_packed = 12'h408; // +2,+0,+1,+0
      9'b011_100001: normal_packed = 12'h588; // +2,-2,+1,+0
      9'b011_100010: normal_packed = 12'h438; // +2,+0,-1,+0
      9'b011_100011: normal_packed = 12'h5B8; // +2,-2,-1,+0
      9'b011_100100: normal_packed = 12'h40E; // +2,+0,+1,-2
      9'b011_100101: normal_packed = 12'h58E; // +2,-2,+1,-2
      9'b011_100110: normal_packed = 12'h43E; // +2,+0,-1,-2
      9'b011_100111: normal_packed = 12'h5BE; // +2,-2,-1,-2
      9'b011_101000: normal_packed = 12'h251; // +1,+1,+2,+1
      9'b011_101001: normal_packed = 12'hE51; // -1,+1,+2,+1
      9'b011_101010: normal_packed = 12'h3D1; // +1,-1,+2,+1
      9'b011_101011: normal_packed = 12'hFD1; // -1,-1,+2,+1
      9'b011_101100: normal_packed = 12'h257; // +1,+1,+2,-1
      9'b011_101101: normal_packed = 12'hE57; // -1,+1,+2,-1
      9'b011_101110: normal_packed = 12'h3D7; // +1,-1,+2,-1
      9'b011_101111: normal_packed = 12'hFD7; // -1,-1,+2,-1
      9'b011_110000: normal_packed = 12'h088; // +0,+2,+1,+0
      9'b011_110001: normal_packed = 12'hC88; // -2,+2,+1,+0
      9'b011_110010: normal_packed = 12'h0B8; // +0,+2,-1,+0
      9'b011_110011: normal_packed = 12'hCB8; // -2,+2,-1,+0
      9'b011_110100: normal_packed = 12'h08E; // +0,+2,+1,-2
      9'b011_110101: normal_packed = 12'hC8E; // -2,+2,+1,-2
      9'b011_110110: normal_packed = 12'h0BE; // +0,+2,-1,-2
      9'b011_110111: normal_packed = 12'hCBE; // -2,+2,-1,-2
      9'b011_111000: normal_packed = 12'h00A; // +0,+0,+1,+2
      9'b011_111001: normal_packed = 12'hC0A; // -2,+0,+1,+2
      9'b011_111010: normal_packed = 12'h18A; // +0,-2,+1,+2
      9'b011_111011: normal_packed = 12'hD8A; // -2,-2,+1,+2
      9'b011_111100: normal_packed = 12'h03A; // +0,+0,-1,+2
      9'b011_111101: normal_packed = 12'hC3A; // -2,+0,-1,+2
      9'b011_111110: normal_packed = 12'h1BA; // +0,-2,-1,+2
      9'b011_111111: normal_packed = 12'hDBA; // -2,-2,-1,+2
      9'b100_000000: normal_packed = 12'h048; // +0,+1,+1,+0
      9'b100_000001: normal_packed = 12'hC48; // -2,+1,+1,+0
      9'b100_000010: normal_packed = 12'h1C8; // +0,-1,+1,+0
      9'b100_000011: normal_packed = 12'hDC8; // -2,-1,+1,+0
      9'b100_000100: normal_packed = 12'h078; // +0,+1,-1,+0
      9'b100_000101: normal_packed = 12'hC78; // -2,+1,-1,+0
      9'b100_000110: normal_packed = 12'h1F8; // +0,-1,-1,+0
      9'b100_000111: normal_packed = 12'hDF8; // -2,-1,-1,+0
      9'b100_001000: normal_packed = 12'h04E; // +0,+1,+1,-2
      9'b100_001001: normal_packed = 12'hC4E; // -2,+1,+1,-2
      9'b100_001010: normal_packed = 12'h1CE; // +0,-1,+1,-2
      9'b100_001011: normal_packed = 12'hDCE; // -2,-1,+1,-2
      9'b100_001100: normal_packed = 12'h07E; // +0,+1,-1,-2
      9'b100_001101: normal_packed = 12'hC7E; // -2,+1,-1,-2
      9'b100_001110: normal_packed = 12'h1FE; // +0,-1,-1,-2
      9'b100_001111: normal_packed = 12'hDFE; // -2,-1,-1,-2
      9'b100_010000: normal_packed = 12'h201; // +1,+0,+0,+1
      9'b100_010001: normal_packed = 12'hE01; // -1,+0,+0,+1
      9'b100_010010: normal_packed = 12'h381; // +1,-2,+0,+1
      9'b100_010011: normal_packed = 12'hF81; // -1,-2,+0,+1
      9'b100_010100: normal_packed = 12'h231; // +1,+0,-2,+1
      9'b100_010101: normal_packed = 12'hE31; // -1,+0,-2,+1
      9'b100_010110: normal_packed = 12'h3B1; // +1,-2,-2,+1
      9'b100_010111: normal_packed = 12'hFB1; // -1,-2,-2,+1
      9'b100_011000: normal_packed = 12'h207; // +1,+0,+0,-1
      9'b100_011001: normal_packed = 12'hE07; // -1,+0,+0,-1
      9'b100_011010: normal_packed = 12'h387; // +1,-2,+0,-1
      9'b100_011011: normal_packed = 12'hF87; // -1,-2,+0,-1
      9'b100_011100: normal_packed = 12'h237; // +1,+0,-2,-1
      9'b100_011101: normal_packed = 12'hE37; // -1,+0,-2,-1
      9'b100_011110: normal_packed = 12'h3B7; // +1,-2,-2,-1
      9'b100_011111: normal_packed = 12'hFB7; // -1,-2,-2,-1
      9'b100_100000: normal_packed = 12'h448; // +2,+1,+1,+0
      9'b100_100001: normal_packed = 12'h5C8; // +2,-1,+1,+0
      9'b100_100010: normal_packed = 12'h478; // +2,+1,-1,+0
      9'b100_100011: normal_packed = 12'h5F8; // +2,-1,-1,+0
      9'b100_100100: normal_packed = 12'h44E; // +2,+1,+1,-2
      9'b100_100101: normal_packed = 12'h5CE; // +2,-1,+1,-2
      9'b100_100110: normal_packed = 12'h47E; // +2,+1,-1,-2
      9'b100_100111: normal_packed = 12'h5FE; // +2,-1,-1,-2
      9'b100_101000: normal_packed = 12'h211; // +1,+0,+2,+1
      9'b100_101001: normal_packed = 12'hE11; // -1,+0,+2,+1
      9'b100_101010: normal_packed = 12'h391; // +1,-2,+2,+1
      9'b100_101011: normal_packed = 12'hF91; // -1,-2,+2,+1
      9'b100_101100: normal_packed = 12'h217; // +1,+0,+2,-1
      9'b100_101101: normal_packed = 12'hE17; // -1,+0,+2,-1
      9'b100_101110: normal_packed = 12'h397; // +1,-2,+2,-1
      9'b100_101111: normal_packed = 12'hF97; // -1,-2,+2,-1
      9'b100_110000: normal_packed = 12'h281; // +1,+2,+0,+1
      9'b100_110001: normal_packed = 12'hE81; // -1,+2,+0,+1
      9'b100_110010: normal_packed = 12'h2B1; // +1,+2,-2,+1
      9'b100_110011: normal_packed = 12'hEB1; // -1,+2,-2,+1
      9'b100_110100: normal_packed = 12'h287; // +1,+2,+0,-1
      9'b100_110101: normal_packed = 12'hE87; // -1,+2,+0,-1
      9'b100_110110: normal_packed = 12'h2B7; // +1,+2,-2,-1
      9'b100_110111: normal_packed = 12'hEB7; // -1,+2,-2,-1
      9'b100_111000: normal_packed = 12'h04A; // +0,+1,+1,+2
      9'b100_111001: normal_packed = 12'hC4A; // -2,+1,+1,+2
      9'b100_111010: normal_packed = 12'h1CA; // +0,-1,+1,+2
      9'b100_111011: normal_packed = 12'hDCA; // -2,-1,+1,+2
      9'b100_111100: normal_packed = 12'h07A; // +0,+1,-1,+2
      9'b100_111101: normal_packed = 12'hC7A; // -2,+1,-1,+2
      9'b100_111110: normal_packed = 12'h1FA; // +0,-1,-1,+2
      9'b100_111111: normal_packed = 12'hDFA; // -2,-1,-1,+2
      9'b101_000000: normal_packed = 12'h049; // +0,+1,+1,+1
      9'b101_000001: normal_packed = 12'hC49; // -2,+1,+1,+1
      9'b101_000010: normal_packed = 12'h1C9; // +0,-1,+1,+1
      9'b101_000011: normal_packed = 12'hDC9; // -2,-1,+1,+1
      9'b101_000100: normal_packed = 12'h079; // +0,+1,-1,+1
      9'b101_000101: normal_packed = 12'hC79; // -2,+1,-1,+1
      9'b101_000110: normal_packed = 12'h1F9; // +0,-1,-1,+1
      9'b101_000111: normal_packed = 12'hDF9; // -2,-1,-1,+1
      9'b101_001000: normal_packed = 12'h04F; // +0,+1,+1,-1
      9'b101_001001: normal_packed = 12'hC4F; // -2,+1,+1,-1
      9'b101_001010: normal_packed = 12'h1CF; // +0,-1,+1,-1
      9'b101_001011: normal_packed = 12'hDCF; // -2,-1,+1,-1
      9'b101_001100: normal_packed = 12'h07F; // +0,+1,-1,-1
      9'b101_001101: normal_packed = 12'hC7F; // -2,+1,-1,-1
      9'b101_001110: normal_packed = 12'h1FF; // +0,-1,-1,-1
      9'b101_001111: normal_packed = 12'hDFF; // -2,-1,-1,-1
      9'b101_010000: normal_packed = 12'h200; // +1,+0,+0,+0
      9'b101_010001: normal_packed = 12'hE00; // -1,+0,+0,+0
      9'b101_010010: normal_packed = 12'h380; // +1,-2,+0,+0
      9'b101_010011: normal_packed = 12'hF80; // -1,-2,+0,+0
      9'b101_010100: normal_packed = 12'h230; // +1,+0,-2,+0
      9'b101_010101: normal_packed = 12'hE30; // -1,+0,-2,+0
      9'b101_010110: normal_packed = 12'h3B0; // +1,-2,-2,+0
      9'b101_010111: normal_packed = 12'hFB0; // -1,-2,-2,+0
      9'b101_011000: normal_packed = 12'h206; // +1,+0,+0,-2
      9'b101_011001: normal_packed = 12'hE06; // -1,+0,+0,-2
      9'b101_011010: normal_packed = 12'h386; // +1,-2,+0,-2
      9'b101_011011: normal_packed = 12'hF86; // -1,-2,+0,-2
      9'b101_011100: normal_packed = 12'h236; // +1,+0,-2,-2
      9'b101_011101: normal_packed = 12'hE36; // -1,+0,-2,-2
      9'b101_011110: normal_packed = 12'h3B6; // +1,-2,-2,-2
      9'b101_011111: normal_packed = 12'hFB6; // -1,-2,-2,-2
      9'b101_100000: normal_packed = 12'h449; // +2,+1,+1,+1
      9'b101_100001: normal_packed = 12'h5C9; // +2,-1,+1,+1
      9'b101_100010: normal_packed = 12'h479; // +2,+1,-1,+1
      9'b101_100011: normal_packed = 12'h5F9; // +2,-1,-1,+1
      9'b101_100100: normal_packed = 12'h44F; // +2,+1,+1,-1
      9'b101_100101: normal_packed = 12'h5CF; // +2,-1,+1,-1
      9'b101_100110: normal_packed = 12'h47F; // +2,+1,-1,-1
      9'b101_100111: normal_packed = 12'h5FF; // +2,-1,-1,-1
      9'b101_101000: normal_packed = 12'h210; // +1,+0,+2,+0
      9'b101_101001: normal_packed = 12'hE10; // -1,+0,+2,+0
      9'b101_101010: normal_packed = 12'h390; // +1,-2,+2,+0
      9'b101_101011: normal_packed = 12'hF90; // -1,-2,+2,+0
      9'b101_101100: normal_packed = 12'h216; // +1,+0,+2,-2
      9'b101_101101: normal_packed = 12'hE16; // -1,+0,+2,-2
      9'b101_101110: normal_packed = 12'h396; // +1,-2,+2,-2
      9'b101_101111: normal_packed = 12'hF96; // -1,-2,+2,-2
      9'b101_110000: normal_packed = 12'h280; // +1,+2,+0,+0
      9'b101_110001: normal_packed = 12'hE80; // -1,+2,+0,+0
      9'b101_110010: normal_packed = 12'h2B0; // +1,+2,-2,+0
      9'b101_110011: normal_packed = 12'hEB0; // -1,+2,-2,+0
      9'b101_110100: normal_packed = 12'h286; // +1,+2,+0,-2
      9'b101_110101: normal_packed = 12'hE86; // -1,+2,+0,-2
      9'b101_110110: normal_packed = 12'h2B6; // +1,+2,-2,-2
      9'b101_110111: normal_packed = 12'hEB6; // -1,+2,-2,-2
      9'b101_111000: normal_packed = 12'h202; // +1,+0,+0,+2
      9'b101_111001: normal_packed = 12'hE02; // -1,+0,+0,+2
      9'b101_111010: normal_packed = 12'h382; // +1,-2,+0,+2
      9'b101_111011: normal_packed = 12'hF82; // -1,-2,+0,+2
      9'b101_111100: normal_packed = 12'h232; // +1,+0,-2,+2
      9'b101_111101: normal_packed = 12'hE32; // -1,+0,-2,+2
      9'b101_111110: normal_packed = 12'h3B2; // +1,-2,-2,+2
      9'b101_111111: normal_packed = 12'hFB2; // -1,-2,-2,+2
      9'b110_000000: normal_packed = 12'h041; // +0,+1,+0,+1
      9'b110_000001: normal_packed = 12'hC41; // -2,+1,+0,+1
      9'b110_000010: normal_packed = 12'h1C1; // +0,-1,+0,+1
      9'b110_000011: normal_packed = 12'hDC1; // -2,-1,+0,+1
      9'b110_000100: normal_packed = 12'h071; // +0,+1,-2,+1
      9'b110_000101: normal_packed = 12'hC71; // -2,+1,-2,+1
      9'b110_000110: normal_packed = 12'h1F1; // +0,-1,-2,+1
      9'b110_000111: normal_packed = 12'hDF1; // -2,-1,-2,+1
      9'b110_001000: normal_packed = 12'h047; // +0,+1,+0,-1
      9'b110_001001: normal_packed = 12'hC47; // -2,+1,+0,-1
      9'b110_001010: normal_packed = 12'h1C7; // +0,-1,+0,-1
      9'b110_001011: normal_packed = 12'hDC7; // -2,-1,+0,-1
      9'b110_001100: normal_packed = 12'h077; // +0,+1,-2,-1
      9'b110_001101: normal_packed = 12'hC77; // -2,+1,-2,-1
      9'b110_001110: normal_packed = 12'h1F7; // +0,-1,-2,-1
      9'b110_001111: normal_packed = 12'hDF7; // -2,-1,-2,-1
      9'b110_010000: normal_packed = 12'h208; // +1,+0,+1,+0
      9'b110_010001: normal_packed = 12'hE08; // -1,+0,+1,+0
      9'b110_010010: normal_packed = 12'h388; // +1,-2,+1,+0
      9'b110_010011: normal_packed = 12'hF88; // -1,-2,+1,+0
      9'b110_010100: normal_packed = 12'h238; // +1,+0,-1,+0
      9'b110_010101: normal_packed = 12'hE38; // -1,+0,-1,+0
      9'b110_010110: normal_packed = 12'h3B8; // +1,-2,-1,+0
      9'b110_010111: normal_packed = 12'hFB8; // -1,-2,-1,+0
      9'b110_011000: normal_packed = 12'h20E; // +1,+0,+1,-2
      9'b110_011001: normal_packed = 12'hE0E; // -1,+0,+1,-2
      9'b110_011010: normal_packed = 12'h38E; // +1,-2,+1,-2
      9'b110_011011: normal_packed = 12'hF8E; // -1,-2,+1,-2
      9'b110_011100: normal_packed = 12'h23E; // +1,+0,-1,-2
      9'b110_011101: normal_packed = 12'hE3E; // -1,+0,-1,-2
      9'b110_011110: normal_packed = 12'h3BE; // +1,-2,-1,-2
      9'b110_011111: normal_packed = 12'hFBE; // -1,-2,-1,-2
      9'b110_100000: normal_packed = 12'h441; // +2,+1,+0,+1
      9'b110_100001: normal_packed = 12'h5C1; // +2,-1,+0,+1
      9'b110_100010: normal_packed = 12'h471; // +2,+1,-2,+1
      9'b110_100011: normal_packed = 12'h5F1; // +2,-1,-2,+1
      9'b110_100100: normal_packed = 12'h447; // +2,+1,+0,-1
      9'b110_100101: normal_packed = 12'h5C7; // +2,-1,+0,-1
      9'b110_100110: normal_packed = 12'h477; // +2,+1,-2,-1
      9'b110_100111: normal_packed = 12'h5F7; // +2,-1,-2,-1
      9'b110_101000: normal_packed = 12'h051; // +0,+1,+2,+1
      9'b110_101001: normal_packed = 12'hC51; // -2,+1,+2,+1
      9'b110_101010: normal_packed = 12'h1D1; // +0,-1,+2,+1
      9'b110_101011: normal_packed = 12'hDD1; // -2,-1,+2,+1
      9'b110_101100: normal_packed = 12'h057; // +0,+1,+2,-1
      9'b110_101101: normal_packed = 12'hC57; // -2,+1,+2,-1
      9'b110_101110: normal_packed = 12'h1D7; // +0,-1,+2,-1
      9'b110_101111: normal_packed = 12'hDD7; // -2,-1,+2,-1
      9'b110_110000: normal_packed = 12'h288; // +1,+2,+1,+0
      9'b110_110001: normal_packed = 12'hE88; // -1,+2,+1,+0
      9'b110_110010: normal_packed = 12'h2B8; // +1,+2,-1,+0
      9'b110_110011: normal_packed = 12'hEB8; // -1,+2,-1,+0
      9'b110_110100: normal_packed = 12'h28E; // +1,+2,+1,-2
      9'b110_110101: normal_packed = 12'hE8E; // -1,+2,+1,-2
      9'b110_110110: normal_packed = 12'h2BE; // +1,+2,-1,-2
      9'b110_110111: normal_packed = 12'hEBE; // -1,+2,-1,-2
      9'b110_111000: normal_packed = 12'h20A; // +1,+0,+1,+2
      9'b110_111001: normal_packed = 12'hE0A; // -1,+0,+1,+2
      9'b110_111010: normal_packed = 12'h38A; // +1,-2,+1,+2
      9'b110_111011: normal_packed = 12'hF8A; // -1,-2,+1,+2
      9'b110_111100: normal_packed = 12'h23A; // +1,+0,-1,+2
      9'b110_111101: normal_packed = 12'hE3A; // -1,+0,-1,+2
      9'b110_111110: normal_packed = 12'h3BA; // +1,-2,-1,+2
      9'b110_111111: normal_packed = 12'hFBA; // -1,-2,-1,+2
      9'b111_000000: normal_packed = 12'h040; // +0,+1,+0,+0
      9'b111_000001: normal_packed = 12'hC40; // -2,+1,+0,+0
      9'b111_000010: normal_packed = 12'h1C0; // +0,-1,+0,+0
      9'b111_000011: normal_packed = 12'hDC0; // -2,-1,+0,+0
      9'b111_000100: normal_packed = 12'h070; // +0,+1,-2,+0
      9'b111_000101: normal_packed = 12'hC70; // -2,+1,-2,+0
      9'b111_000110: normal_packed = 12'h1F0; // +0,-1,-2,+0
      9'b111_000111: normal_packed = 12'hDF0; // -2,-1,-2,+0
      9'b111_001000: normal_packed = 12'h046; // +0,+1,+0,-2
      9'b111_001001: normal_packed = 12'hC46; // -2,+1,+0,-2
      9'b111_001010: normal_packed = 12'h1C6; // +0,-1,+0,-2
      9'b111_001011: normal_packed = 12'hDC6; // -2,-1,+0,-2
      9'b111_001100: normal_packed = 12'h076; // +0,+1,-2,-2
      9'b111_001101: normal_packed = 12'hC76; // -2,+1,-2,-2
      9'b111_001110: normal_packed = 12'h1F6; // +0,-1,-2,-2
      9'b111_001111: normal_packed = 12'hDF6; // -2,-1,-2,-2
      9'b111_010000: normal_packed = 12'h209; // +1,+0,+1,+1
      9'b111_010001: normal_packed = 12'hE09; // -1,+0,+1,+1
      9'b111_010010: normal_packed = 12'h389; // +1,-2,+1,+1
      9'b111_010011: normal_packed = 12'hF89; // -1,-2,+1,+1
      9'b111_010100: normal_packed = 12'h239; // +1,+0,-1,+1
      9'b111_010101: normal_packed = 12'hE39; // -1,+0,-1,+1
      9'b111_010110: normal_packed = 12'h3B9; // +1,-2,-1,+1
      9'b111_010111: normal_packed = 12'hFB9; // -1,-2,-1,+1
      9'b111_011000: normal_packed = 12'h20F; // +1,+0,+1,-1
      9'b111_011001: normal_packed = 12'hE0F; // -1,+0,+1,-1
      9'b111_011010: normal_packed = 12'h38F; // +1,-2,+1,-1
      9'b111_011011: normal_packed = 12'hF8F; // -1,-2,+1,-1
      9'b111_011100: normal_packed = 12'h23F; // +1,+0,-1,-1
      9'b111_011101: normal_packed = 12'hE3F; // -1,+0,-1,-1
      9'b111_011110: normal_packed = 12'h3BF; // +1,-2,-1,-1
      9'b111_011111: normal_packed = 12'hFBF; // -1,-2,-1,-1
      9'b111_100000: normal_packed = 12'h440; // +2,+1,+0,+0
      9'b111_100001: normal_packed = 12'h5C0; // +2,-1,+0,+0
      9'b111_100010: normal_packed = 12'h470; // +2,+1,-2,+0
      9'b111_100011: normal_packed = 12'h5F0; // +2,-1,-2,+0
      9'b111_100100: normal_packed = 12'h446; // +2,+1,+0,-2
      9'b111_100101: normal_packed = 12'h5C6; // +2,-1,+0,-2
      9'b111_100110: normal_packed = 12'h476; // +2,+1,-2,-2
      9'b111_100111: normal_packed = 12'h5F6; // +2,-1,-2,-2
      9'b111_101000: normal_packed = 12'h050; // +0,+1,+2,+0
      9'b111_101001: normal_packed = 12'hC50; // -2,+1,+2,+0
      9'b111_101010: normal_packed = 12'h1D0; // +0,-1,+2,+0
      9'b111_101011: normal_packed = 12'hDD0; // -2,-1,+2,+0
      9'b111_101100: normal_packed = 12'h056; // +0,+1,+2,-2
      9'b111_101101: normal_packed = 12'hC56; // -2,+1,+2,-2
      9'b111_101110: normal_packed = 12'h1D6; // +0,-1,+2,-2
      9'b111_101111: normal_packed = 12'hDD6; // -2,-1,+2,-2
      9'b111_110000: normal_packed = 12'h289; // +1,+2,+1,+1
      9'b111_110001: normal_packed = 12'hE89; // -1,+2,+1,+1
      9'b111_110010: normal_packed = 12'h2B9; // +1,+2,-1,+1
      9'b111_110011: normal_packed = 12'hEB9; // -1,+2,-1,+1
      9'b111_110100: normal_packed = 12'h28F; // +1,+2,+1,-1
      9'b111_110101: normal_packed = 12'hE8F; // -1,+2,+1,-1
      9'b111_110110: normal_packed = 12'h2BF; // +1,+2,-1,-1
      9'b111_110111: normal_packed = 12'hEBF; // -1,+2,-1,-1
      9'b111_111000: normal_packed = 12'h042; // +0,+1,+0,+2
      9'b111_111001: normal_packed = 12'hC42; // -2,+1,+0,+2
      9'b111_111010: normal_packed = 12'h1C2; // +0,-1,+0,+2
      9'b111_111011: normal_packed = 12'hDC2; // -2,-1,+0,+2
      9'b111_111100: normal_packed = 12'h072; // +0,+1,-2,+2
      9'b111_111101: normal_packed = 12'hC72; // -2,+1,-2,+2
      9'b111_111110: normal_packed = 12'h1F2; // +0,-1,-2,+2
      9'b111_111111: normal_packed = 12'hDF2; // -2,-1,-2,+2
      default: normal_packed = 12'h000;
    endcase
  endfunction

  function automatic logic [11:0] special_packed(input logic [2:0] subset, input pcs_condition_t condition);
    case (condition)
      COND_SSD1:        special_packed = 12'h492; // +2,+2,+2,+2
      COND_SSD2:        special_packed = 12'h496; // +2,+2,+2,-2
      COND_ESD1:        special_packed = 12'h492; // +2,+2,+2,+2
      COND_ESD2_EXT_0:        special_packed = 12'h496; // +2,+2,+2,-2
      COND_ESD2_EXT_1:        special_packed = 12'h4B2; // +2,+2,-2,+2
      COND_ESD2_EXT_2:        special_packed = 12'h592; // +2,-2,+2,+2
      COND_ESD_EXT_ERR:        special_packed = 12'hC92; // -2,+2,+2,+2

      COND_XMT_ERR: begin
        case (subset)
          3'b000: special_packed = 12'h090; // +0,+2,+2,+0
          3'b001: special_packed = 12'h481; // +2,+2,+0,+1
          3'b010: special_packed = 12'h252; // +1,+1,+2,+2
          3'b011: special_packed = 12'h08A; // +0,+2,+1,+2
          3'b100: special_packed = 12'h44A; // +2,+1,+1,+2
          3'b101: special_packed = 12'h290; // +1,+2,+2,+0
          3'b110: special_packed = 12'h451; // +2,+1,+2,+1
          3'b111: special_packed = 12'h450; // +2,+1,+2,+0
          default: special_packed = 12'h000;
        endcase
      end

      COND_CS_EXTEND_ERR: begin
        case (subset)
          3'b000: special_packed = 12'hC96; // -2,+2,+2,-2
          3'b001: special_packed = 12'h4B7; // +2,+2,-2,-1
          3'b010: special_packed = 12'hFD2; // -1,-1,+2,+2
          3'b011: special_packed = 12'hCBA; // -2,+2,-1,+2
          3'b100: special_packed = 12'h5FA; // +2,-1,-1,+2
          3'b101: special_packed = 12'hE96; // -1,+2,+2,-2
          3'b110: special_packed = 12'h5D7; // +2,-1,+2,-1
          3'b111: special_packed = 12'h5D6; // +2,-1,+2,-2
          default: special_packed = 12'h000;
        endcase
      end

      COND_CS_EXTEND: begin
        case (subset)
          3'b000: special_packed = 12'h402; // +2,+0,+0,+2
          3'b001: special_packed = 12'h411; // +2,+0,+2,+1
          3'b010: special_packed = 12'h489; // +2,+2,+1,+1
          3'b011: special_packed = 12'h40A; // +2,+0,+1,+2
          3'b100: special_packed = 12'h291; // +1,+2,+2,+1
          3'b101: special_packed = 12'h212; // +1,+0,+2,+2
          3'b110: special_packed = 12'h28A; // +1,+2,+1,+2
          3'b111: special_packed = 12'h442; // +2,+1,+0,+2
          default: special_packed = 12'h000;
        endcase
      end

      COND_CS_RESET: begin
        case (subset)
          3'b000: special_packed = 12'h5B2; // +2,-2,-2,+2
          3'b001: special_packed = 12'h597; // +2,-2,+2,-1
          3'b010: special_packed = 12'h4BF; // +2,+2,-1,-1
          3'b011: special_packed = 12'h5BA; // +2,-2,-1,+2
          3'b100: special_packed = 12'hE97; // -1,+2,+2,-1
          3'b101: special_packed = 12'hF92; // -1,-2,+2,+2
          3'b110: special_packed = 12'hEBA; // -1,+2,-1,+2
          3'b111: special_packed = 12'h5F2; // +2,-1,-2,+2
          default: special_packed = 12'h000;
        endcase
      end

      default: special_packed = 12'h000;
    endcase
  endfunction

  function void tick(input logic [8:0] Sd, input pcs_condition_t condition);
    logic [2:0]  subset;
    logic [11:0] packed_symbols;

    subset = {Sd[6], Sd[7], Sd[8]};

    if (condition == COND_NORMAL) begin
      packed_symbols = normal_packed(subset, Sd[5:0]);
    end
    else begin
      packed_symbols = special_packed(subset, condition);
    end

    unpack_symbols(packed_symbols);
  endfunction
endclass

class pcs_ref_model;
  // Project command code defaults.  Change these to match your class/DUT command map.
  logic [7:0] CMD_IDLE;
  logic [7:0] CMD_XMT_ERR;
  logic [7:0] CMD_CARRIER_EXT;
  logic [7:0] CMD_CARRIER_EXT_ERR;
  logic [7:0] CMD_SEND_Z;

  scrambler_model     scr;
  sc_model            sc;
  conv_encoder_model  conv;
  lut_model           lut;
  sign_model          sign;

  bit          is_master;
  logic [32:0] scr_seed;

  bit tx_error_d1, tx_error_d2, tx_error_d3;
  bit cext_err_active;

  pcs_symbol_t A, B, C, D;
  logic [11:0] symb_vector;
  pcs_condition_t last_condition;

  function new(
    bit          master_mode             = 1'b1,
    logic [32:0] seed                    = `PCS_DEFAULT_SCR_SEED,
    logic [7:0]  cmd_idle                = 8'h00,
    logic [7:0]  cmd_xmt_err             = 8'h01,
    logic [7:0]  cmd_carrier_ext         = 8'h0F,
    logic [7:0]  cmd_carrier_ext_err     = 8'hFE,
    logic [7:0]  cmd_send_z              = 8'hFF
  );
    is_master           = master_mode;
    scr_seed            = (seed == 33'd0) ? `PCS_DEFAULT_SCR_SEED : seed;
    CMD_IDLE            = cmd_idle;
    CMD_XMT_ERR         = cmd_xmt_err;
    CMD_CARRIER_EXT     = cmd_carrier_ext;
    CMD_CARRIER_EXT_ERR = cmd_carrier_ext_err;
    CMD_SEND_Z          = cmd_send_z;

    scr  = new(is_master, scr_seed);
    sc   = new();
    conv = new();
    lut  = new();
    sign = new();
    reset();
  endfunction

  function void reset();
    scr.reset(scr_seed);
    sc.reset();
    conv.reset();
    lut.reset();
    sign.reset();
    tx_error_d1     = 1'b0;
    tx_error_d2     = 1'b0;
    tx_error_d3     = 1'b0;
    cext_err_active = 1'b0;
    A = 3'sd0;
    B = 3'sd0;
    C = 3'sd0;
    D = 3'sd0;
    symb_vector    = 12'h000;
    last_condition = COND_NORMAL;
  endfunction

  function automatic logic [11:0] pack_symbols_12b(
    input pcs_symbol_t A_i,
    input pcs_symbol_t B_i,
    input pcs_symbol_t C_i,
    input pcs_symbol_t D_i
  );
    // Default output encoding is signed 3-bit two's complement per symbol.
    pack_symbols_12b = {A_i[2:0], B_i[2:0], C_i[2:0], D_i[2:0]};
  endfunction

  function automatic pcs_condition_t derive_condition(
    input bit         tx_en,
    input bit         tx_error,
    input logic [7:0] TXD,
    input bit         cext_err_for_this_symbol
  );
    bit csreset_now;
    bit esd1_now;
    bit esd2_now;
    bit esd_ext_err_now;

    csreset_now     = sign.tx_en_d2 & ~tx_en;
    esd1_now        = (~sign.tx_en_d2) & sign.tx_en_d3;
    esd2_now        = (~sign.tx_en_d3) & sign.tx_en_d4;
    esd_ext_err_now = cext_err_for_this_symbol |
                      (tx_error & tx_error_d1 & tx_error_d2 & (TXD != 8'h0F)) |
                      (tx_error & tx_error_d1 & tx_error_d2 & tx_error_d3 & (TXD != 8'h0F));

    // SSD has priority; TX_ER during SSD is delayed until SSD completes.
    if (tx_en && !sign.tx_en_d1) begin
      return COND_SSD1;
    end
    else if (sign.tx_en_d1 && !sign.tx_en_d2) begin
      return COND_SSD2;
    end
    else if (tx_error && tx_en && sign.tx_en_d2) begin
      return COND_XMT_ERR;
    end
    else if (csreset_now) begin
      if (cext_err_for_this_symbol || (tx_error && (TXD != 8'h0F))) begin
        return COND_CS_EXTEND_ERR;
      end
      else if (tx_error && (TXD == 8'h0F)) begin
        return COND_CS_EXTEND;
      end
      else begin
        return COND_CS_RESET;
      end
    end
    else if (esd1_now) begin
      if (esd_ext_err_now) begin
        return COND_ESD_EXT_ERR;
      end
      else begin
        return COND_ESD1;
      end
    end
    else if (esd2_now) begin
      if (esd_ext_err_now) begin
        return COND_ESD_EXT_ERR;
      end
      else if ((!tx_error) && (!tx_error_d1)) begin
        return COND_ESD2_EXT_0;
      end
      else if ((!tx_error) && tx_error_d1 && tx_error_d2 && tx_error_d3) begin
        return COND_ESD2_EXT_1;
      end
      else if (tx_error && tx_error_d1 && tx_error_d2 && tx_error_d3 && (TXD == 8'h0F)) begin
        return COND_ESD2_EXT_2;
      end
      else begin
        return COND_ESD2_EXT_0;
      end
    end

    return COND_NORMAL;
  endfunction

  function void update_error_history(input bit tx_error);
    tx_error_d3 = tx_error_d2;
    tx_error_d2 = tx_error_d1;
    tx_error_d1 = tx_error;
  endfunction

  function void publish_outputs();
    A = sign.A;
    B = sign.B;
    C = sign.C;
    D = sign.D;
    symb_vector = pack_symbols_12b(A, B, C, D);
  endfunction

  function void tick_gmii(
    input logic [7:0]  TXD,
    input bit          tx_en,
    input bit          tx_error = 1'b0,
    input pcs_tx_mode_t tx_mode = PCS_SEND_N,
    input bit          loc_lpi_req = 1'b0,
    input bit          loc_rcvr_status_ok = 1'b0,
    input bit          loc_update_done = 1'b0
  );
    pcs_condition_t condition;
    bit csreset_now;
    bit esd2_now;
    bit cext_err_for_this_symbol;

    csreset_now = sign.tx_en_d2 & ~tx_en;
    esd2_now    = (~sign.tx_en_d3) & sign.tx_en_d4;

    cext_err_for_this_symbol = cext_err_active |
                                (csreset_now && tx_error && (TXD != 8'h0F));

    // Scrambler advances once per symbol period.
    scr.tick();
    sc.tick(sign.tx_en_d2, scr.Sx, scr.Sy, tx_mode);

    if (tx_mode == PCS_SEND_Z) begin
      // SEND_Z forces the final PMA vector to zero.
      sign.tick(tx_en, scr.Sg, 3'sd0, 3'sd0, 3'sd0, 3'sd0);
      last_condition = COND_NORMAL;
    end
    else begin
      condition = derive_condition(tx_en, tx_error, TXD, cext_err_for_this_symbol);
      conv.tick(TXD, sign.tx_en_d2, tx_en, tx_error, tx_mode, sc.Sc,
                loc_lpi_req, loc_rcvr_status_ok, loc_update_done);
      lut.tick(conv.Sd, condition);
      sign.tick(tx_en, scr.Sg, lut.TA, lut.TB, lut.TC, lut.TD);
      last_condition = condition;
    end

    publish_outputs();
    update_error_history(tx_error);

    if (esd2_now) begin
      cext_err_active = 1'b0;
    end
    else if (csreset_now && tx_error && (TXD != 8'h0F)) begin
      cext_err_active = 1'b1;
    end
  endfunction

  function void decode_project_word(
    input  logic [8:0] in_word,
    output logic [7:0] TXD,
    output bit         tx_en,
    output bit         tx_error,
    output pcs_tx_mode_t tx_mode
  );
    tx_mode  = PCS_SEND_N;
    tx_error = 1'b0;
    tx_en    = 1'b0;
    TXD      = 8'h00;

    if (in_word[8] == 1'b0) begin
      // Data byte.
      tx_en    = 1'b1;
      tx_error = 1'b0;
      TXD      = in_word[7:0];
    end
    else begin
      // Command byte.  Adjust CMD_* values in new() to match your project handout/DUT.
      if (in_word[7:0] == CMD_IDLE) begin
        tx_en    = 1'b0;
        tx_error = 1'b0;
        TXD      = CMD_IDLE;
      end
      else if (in_word[7:0] == CMD_XMT_ERR) begin
        tx_en    = 1'b1;
        tx_error = 1'b1;
        TXD      = 8'h00;
      end
      else if (in_word[7:0] == CMD_CARRIER_EXT) begin
        tx_en    = 1'b0;
        tx_error = 1'b1;
        TXD      = 8'h0F;
      end
      else if (in_word[7:0] == CMD_CARRIER_EXT_ERR) begin
        tx_en    = 1'b0;
        tx_error = 1'b1;
        TXD      = 8'h00;
      end
      else if (in_word[7:0] == CMD_SEND_Z) begin
        tx_en    = 1'b0;
        tx_error = 1'b0;
        TXD      = 8'h00;
        tx_mode  = PCS_SEND_Z;
      end
      else begin
        // Safe fallback for undefined commands.  Change this if your command map uses
        // other command values for errors/training/carrier extension.
        tx_en    = 1'b0;
        tx_error = 1'b0;
        TXD      = in_word[7:0];
      end
    end
  endfunction

  function void tick_project(input logic [8:0] in_word);
    logic [7:0]  TXD;
    bit          tx_en;
    bit          tx_error;
    pcs_tx_mode_t tx_mode;

    decode_project_word(in_word, TXD, tx_en, tx_error, tx_mode);
    tick_gmii(TXD, tx_en, tx_error, tx_mode);
  endfunction

  // Compatibility helper for your earlier version.  It still allows a forced condition,
  // but the preferred method is tick_gmii() or tick_project().
  function void tick_forced_condition(
    input logic [7:0]  TXD,
    input bit          tx_en,
    input bit          tx_error,
    input pcs_tx_mode_t tx_mode,
    input pcs_condition_t forced_condition
  );
    scr.tick();
    sc.tick(sign.tx_en_d2, scr.Sx, scr.Sy, tx_mode);

    if (tx_mode == PCS_SEND_Z) begin
      sign.tick(tx_en, scr.Sg, 3'sd0, 3'sd0, 3'sd0, 3'sd0);
      last_condition = COND_NORMAL;
    end
    else begin
      conv.tick(TXD, sign.tx_en_d2, tx_en, tx_error, tx_mode, sc.Sc);
      lut.tick(conv.Sd, forced_condition);
      sign.tick(tx_en, scr.Sg, lut.TA, lut.TB, lut.TC, lut.TD);
      last_condition = forced_condition;
    end

    publish_outputs();
    update_error_history(tx_error);
  endfunction
endclass

`endif
