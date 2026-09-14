// Sail-only harness for the TOR predecessor grain bit (evidence/sail/
// TIER1_PROTOCOL.md, Section 3.1). Drives the generated pmpCheckHw and, per
// slot, the generated leaf helpers through the sby's version shim; properties
// are in sail_leaf_sva. No CVA6 RTL.
module sail_leaf_fv (
    input logic [55:0]       addr_i,
    input logic [12:0]       width_i,
    input logic [ 1:0]       access_kind_i,
    input logic [ 1:0]       priv_kind_i,
    input logic [ 7:0][53:0] pmpaddr_i,
    input logic [ 7:0][ 7:0] cfg_i
);
  logic                                 [63:0] width;
  logic                                 [63:0] sail_addr   [64];
  t_Pmpcfg_ent                                 sail_cfg    [64];
  t_zMemoryAccessTypezIEmem_payloadz5zK        sail_access;
  t_Privilege                                  sail_priv;
  t_zoptionzIUExceptionTypezK                  sail_result;
  bit                                          top_exc;
  t_exception                                  top_cur;

  always_comb begin
    width = {51'b0, width_i};

    case (access_kind_i)
      0:       sail_access = zLoadzIEmem_payloadz5zK(Data);
      1:       sail_access = zStorezIEmem_payloadz5zK(Data);
      default: sail_access = zInstructionFetchzIEmem_payloadz5zK(SAIL_UNIT);
    endcase

    case (priv_kind_i)
      0:       sail_priv = User;
      1:       sail_priv = Supervisor;
      default: sail_priv = Machine;
    endcase

    // 8 implemented entries; slots 8..63 all-zero = OFF
    for (int i = 0; i < 64; i++) begin
      sail_addr[i]     = '0;
      sail_cfg[i].bits = '0;
    end
    for (int i = 0; i < 8; i++) begin
      sail_addr[i]     = {10'b0, pmpaddr_i[i]};
      sail_cfg[i].bits = cfg_i[i];
    end

    // domain: pmpCheck's width bound, no wrap past 2^56, legal CSR state
    // (reserved zero, no NA4 at G=1, no W without R)
    assume (width_i >= 13'd1 && width_i <= 13'd4096);
    assume ({8'b0, addr_i} + width <= 64'h0100_0000_0000_0000);
    for (int i = 0; i < 8; i++) begin
      assume (cfg_i[i][6:5] == 2'b00);
      assume (cfg_i[i][4:3] != 2'b10);
      assume (!(cfg_i[i][1] && !cfg_i[i][0]));
    end
  end

  pmpCheckHw sail_pmp (
      .addr_0                  (addr_i),
      .width_0                 (width),
      .access_0                (sail_access),
      .priv_0                  (sail_priv),
      .pmpaddr_n_0             (sail_addr),
      .pmpcfg_n_0              (sail_cfg),
      .zassert_reachablez3     (1'b1),
      .sail_return_2           (sail_result),
      .sail_have_exception_2   (top_exc),
      .sail_current_exception_2(top_cur)
  );

  // per slot: effective address, match with Sail's predecessor and with its
  // bit 0 cleared, RWX, lock
  logic [15:0][63:0] eff;
  t_pmpAddrMatch [15:0] m_sail, m_arch;
  logic [15:0] rwx, locked, exc_sail, exc_arch, exc_rwx;
  logic [15:0][1:0] mode;
  logic [15:0]      raw0;

  for (genvar i = 0; i < 16; i++) begin : gen_slot
    logic [63:0] prev;
    if (i == 0) begin : g_first
      assign prev = '0;
    end else begin : g_next
      assign prev = eff[i-1];
    end

    pmpReadAddrReg rd (
        .n_0          (64'(i)),
        .pmpaddr_n_0  (sail_addr),
        .pmpcfg_n_0   (sail_cfg),
        .sail_return_1(eff[i])
    );
    sail_leaf_match ms (
        .addr   (addr_i),
        .width  (width),
        .cfg    (sail_cfg[i]),
        .pmpaddr(eff[i]),
        .prev   (prev),
        .m      (m_sail[i]),
        .exc    (exc_sail[i])
    );
    sail_leaf_match ma (
        .addr   (addr_i),
        .width  (width),
        .cfg    (sail_cfg[i]),
        .pmpaddr(eff[i]),
        .prev   (prev & ~64'h1),
        .m      (m_arch[i]),
        .exc    (exc_arch[i])
    );
    sail_leaf_rwx rw (
        .cfg   (sail_cfg[i]),
        .access(sail_access),
        .ok    (rwx[i]),
        .exc   (exc_rwx[i])
    );
    pmpLocked lk (
        .cfg_0        (sail_cfg[i]),
        .sail_return_1(locked[i])
    );

    assign mode[i] = sail_cfg[i].bits[4:3];
    assign raw0[i] = sail_addr[i][0];
  end

  sail_leaf_sva chk (
      .m_mode    (sail_priv == Machine),
      .m_sail    (m_sail),
      .m_arch    (m_arch),
      .rwx       (rwx),
      .locked    (locked),
      .mode      (mode),
      .raw0      (raw0),
      .sail_allow(sail_result.tag == ZNONEZIUEXCEPTIONTYPEZK),
      .top_exc   (top_exc),
      .helper_exc(exc_sail | exc_arch | exc_rwx),
      .addr      (addr_i),
      .width     (width_i)
  );
endmodule
