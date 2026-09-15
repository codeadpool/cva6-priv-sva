// Section 3.3 harness (evidence/sail/TIER1_PROTOCOL.md): CVA6 pmp_entry with
// #3490 against Sail 0.14's private pmpMatchAddr, one predecessor/entry pair.
// No assumptions: every property in sail_oracle_sva is guarded by the c2
// domain. Requires Cfg.PLEN == 56, as the Sail SV is generated at PLEN=56.
module sail_oracle_fv #(
    parameter config_pkg::cva6_cfg_t Cfg = build_config_pkg::build_config(cva6_config_pkg::cva6_cfg)
) (
    input logic           [Cfg.PLEN-1:0]               addr_i,
    input logic           [         1:0]               size_lg2_i,
    input logic           [         1:0][Cfg.PLEN-3:0] pmpaddr_i,   // [0] predecessor, [1] entry
    input riscv::pmpcfg_t [         1:0]               cfg_i
);
  localparam int PMPADDR_W = Cfg.PLEN - 2;

  logic        [63:0] width;
  logic        [63:0] sail_addr[64];
  t_Pmpcfg_ent        sail_cfg [64];

  always_comb begin
    width = 64'b1 << size_lg2_i;

    // slot 0 predecessor, slot 1 entry, slots 2..63 all-zero = OFF
    for (int i = 0; i < 64; i++) begin
      sail_addr[i]     = '0;
      sail_cfg[i].bits = '0;
    end
    for (int i = 0; i < 2; i++) begin
      sail_addr[i]     = {{(64 - PMPADDR_W) {1'b0}}, pmpaddr_i[i]};
      sail_cfg[i].bits = cfg_i[i];
    end
  end

  // CVA6: the entry's point match, predecessor passed raw as pmp.sv does
  logic cva6_match;
  pmp_entry #(
      .CVA6Cfg(Cfg)
  ) i_entry (
      .addr_i          (addr_i),
      .conf_addr_i     (pmpaddr_i[1]),
      .conf_addr_prev_i(pmpaddr_i[0]),
      .conf_addr_mode_i(cfg_i[1].addr_mode),
      .match_o         (cva6_match)
  );

  // Sail: effective addresses, then the entry's match with Sail's predecessor
  // (the extracted leaf oracle), with that predecessor's bit 0 cleared, and the
  // predecessor's own match
  logic [63:0] eff_prev, eff;
  t_pmpAddrMatch m_sail, m_arch, m_prev;
  bit exc_sail, exc_arch, exc_prev;

  pmpReadAddrReg rd0 (
      .n_0          (64'd0),
      .pmpaddr_n_0  (sail_addr),
      .pmpcfg_n_0   (sail_cfg),
      .sail_return_1(eff_prev)
  );
  pmpReadAddrReg rd1 (
      .n_0          (64'd1),
      .pmpaddr_n_0  (sail_addr),
      .pmpcfg_n_0   (sail_cfg),
      .sail_return_1(eff)
  );
  sail_leaf_match ms (
      .addr   (addr_i),
      .width  (width),
      .cfg    (sail_cfg[1]),
      .pmpaddr(eff),
      .prev   (eff_prev),
      .m      (m_sail),
      .exc    (exc_sail)
  );
  sail_leaf_match ma (
      .addr   (addr_i),
      .width  (width),
      .cfg    (sail_cfg[1]),
      .pmpaddr(eff),
      .prev   (eff_prev & ~64'h1),
      .m      (m_arch),
      .exc    (exc_arch)
  );
  sail_leaf_match mp (
      .addr   (addr_i),
      .width  (width),
      .cfg    (sail_cfg[0]),
      .pmpaddr(eff_prev),
      .prev   ('0),
      .m      (m_prev),
      .exc    (exc_prev)
  );

  sail_oracle_sva chk (
      .addr      (addr_i),
      .width     (width),
      .cfg       (cfg_i),
      .raw0_prev (pmpaddr_i[0][0]),
      .cva6_match(cva6_match),
      .m_sail    (m_sail),
      .m_arch    (m_arch),
      .m_prev    (m_prev),
      .helper_exc(exc_sail | exc_arch | exc_prev)
  );
endmodule
