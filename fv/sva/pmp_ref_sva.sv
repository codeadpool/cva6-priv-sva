// PMP arbitration reference model - checker for pmp.sv (PMP-3/4/8, GAP-1).
module pmp_ref_sva #(
    parameter config_pkg::cva6_cfg_t CVA6Cfg = config_pkg::cva6_cfg_empty
) (
    input logic [CVA6Cfg.PLEN-1:0] addr_i,
    input riscv::pmp_access_t access_type_i,
    input riscv::priv_lvl_t priv_lvl_i,
    input logic [(CVA6Cfg.NrPMPEntries > 0 ? CVA6Cfg.NrPMPEntries-1 : 0):0][CVA6Cfg.PLEN-3:0] conf_addr_i,
    input riscv::pmpcfg_t [(CVA6Cfg.NrPMPEntries > 0 ? CVA6Cfg.NrPMPEntries-1 : 0):0] conf_i,
    input logic allow_i
);
  localparam int unsigned N = CVA6Cfg.NrPMPEntries;

  // own matchers (same trusted pmp_entry as the DUT)
  logic [N-1:0] match;
  for (genvar i = 0; i < N; i++) begin : gen_ref_match
    logic [CVA6Cfg.PLEN-3:0] prev;
    assign prev = (i == 0) ? '0 : conf_addr_i[i-1];
    pmp_entry #(
        .CVA6Cfg(CVA6Cfg)
    ) i_ref_entry (
        .addr_i          (addr_i),
        .conf_addr_i     (conf_addr_i[i]),
        .conf_addr_prev_i(prev),
        .conf_addr_mode_i(conf_i[i].addr_mode),
        .match_o         (match[i])
    );
  end

  // applicable: participates in arbitration for the current mode
  logic [N-1:0] applicable;
  always_comb
    for (int i = 0; i < N; i++)
      applicable[i] = match[i] && (priv_lvl_i != riscv::PRIV_LVL_M || conf_i[i].locked);

  logic hit;
  logic ref_allow;
  always_comb begin
    hit = 1'b0;
    ref_allow = (priv_lvl_i == riscv::PRIV_LVL_M);
    for (int i = 0; i < N; i++)
    if (!hit && applicable[i]) begin
      hit = 1'b1;
      ref_allow = ((access_type_i & conf_i[i].access_type) == access_type_i);
    end
  end

  always_comb begin
    // full output equivalence: PMP-3 + PMP8 in S/U, PMP-4 + PMP-8 in M
    a_ref_equiv : assert (allow_i == ref_allow);
    a_gap1_m_bypass : assert (!(priv_lvl_i == riscv::PRIV_LVL_M && !hit) || allow_i);
  end

  always_comb begin
    c_su_allow : cover (priv_lvl_i != riscv::PRIV_LVL_M && hit && allow_i);
    c_su_perm_deny : cover (priv_lvl_i != riscv::PRIV_LVL_M && hit && !allow_i);
    c_m_locked_deny : cover (priv_lvl_i == riscv::PRIV_LVL_M && hit && !allow_i);
    c_m_no_lock_allow : cover (priv_lvl_i == riscv::PRIV_LVL_M && !hit && allow_i);
    // first-match priority visible: entry1 would deny, entry0 wins
    c_shadowed_entry :
    cover (applicable[0] && applicable[1]
           && ((access_type_i & conf_i[0].access_type) == access_type_i)
           && ((access_type_i & conf_i[1].access_type) != access_type_i) && allow_i);
  end
endmodule
