// Priv spec v1.13 3.7.1: the lowest-numbered PMP entry that matches decides;
module pmp_mpri_sva #(
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

  // lowest-numbered match, no lock filter (spec priority)
  logic hit_any, first_is_unlocked;
  always_comb begin
    hit_any = 1'b0;
    first_is_unlocked = 1'b0;
    for (int i = 0; i < N; i++)
    if (!hit_any && match[i]) begin
      hit_any = 1'b1;
      first_is_unlocked = !conf_i[i].locked;
    end
  end

  always_comb begin
    // spec: M + lowest match non-locked => access succeeds
    a_m_spec_priority :
    assert (!(priv_lvl_i == riscv::PRIV_LVL_M && hit_any && first_is_unlocked) || allow_i);
  end

  always_comb begin
    c_m_first_unlocked : cover (priv_lvl_i == riscv::PRIV_LVL_M && hit_any && first_is_unlocked);
    c_overrule_shape :
    cover (priv_lvl_i == riscv::PRIV_LVL_M && match[0] && !conf_i[0].locked && match[1]
           && conf_i[1].locked && ((access_type_i & conf_i[1].access_type) != access_type_i));
  end
endmodule
