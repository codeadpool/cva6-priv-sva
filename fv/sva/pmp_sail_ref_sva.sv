// Sail-derived PMP equivalence properties, checker for the pmp_sail_ref_fv
// miter (CVA6 pmp.sv vs Sail-RISC-V 0.12 pmpCheckHw), bound in the wrapper.
module pmp_sail_ref_sva #(
    parameter config_pkg::cva6_cfg_t CVA6Cfg = config_pkg::cva6_cfg_empty
) (
    input logic [CVA6Cfg.PLEN-1:0] addr_i,
    input riscv::pmp_access_t access_type_i,
    input riscv::priv_lvl_t priv_lvl_i,
    input logic [(CVA6Cfg.NrPMPEntries > 0 ? CVA6Cfg.NrPMPEntries-1 : 0):0][CVA6Cfg.PLEN-3:0] conf_addr_i,
    input riscv::pmpcfg_t [(CVA6Cfg.NrPMPEntries > 0 ? CVA6Cfg.NrPMPEntries-1 : 0):0] conf_i,
    input logic cva6_allow_i,
    input logic sail_allow_i
);
  localparam int unsigned N = CVA6Cfg.NrPMPEntries;

  // address-match per entry, using the DUT's own pmp_entry. `prev` is
  // pmpReadAddrReg at G=1, the architectural bound; golden pmp.sv feeds the raw
  // stored pmpaddr. #3490's pmp_entry masks bit 0 of both TOR bounds, so amatch
  // equals the DUT's match on c2/c3 but not on golden. Never used as an oracle.
  logic [N-1:0] amatch;
  for (genvar i = 0; i < N; i++) begin : gen_amatch
    logic [CVA6Cfg.PLEN-3:0] prev;
    assign prev = (i == 0) ? '0 : conf_i[i-1].addr_mode[1] ? conf_addr_i[i-1] : {conf_addr_i[i-1][CVA6Cfg.PLEN-3:1], 1'b0};
    pmp_entry #(
        .CVA6Cfg(CVA6Cfg)
    ) i_amatch (
        .addr_i          (addr_i),
        .conf_addr_i     (conf_addr_i[i]),
        .conf_addr_prev_i(prev),
        .conf_addr_mode_i(conf_i[i].addr_mode),
        .match_o         (amatch[i])
    );
  end

  // F7 shape: (1) the lowest-numbered address-matching entry is unlocked, and
  // (2) the first locked matching entry denies the requested permission. Sail
  // returns at the lowest match (M-mode + unlocked => allow); CVA6 filters
  // unlocked entries before priority (pmp.sv:55) and applies that later locked
  // entry => deny. that is the entire F7 / #3177 divergence
  logic any_match, lowest_unlocked;
  logic any_locked_match, first_locked_denies;
  always_comb begin
    any_match       = 1'b0;
    lowest_unlocked = 1'b0;
    for (int i = 0; i < N; i++)
    if (!any_match && amatch[i]) begin
      any_match       = 1'b1;
      lowest_unlocked = !conf_i[i].locked;
    end
    any_locked_match    = 1'b0;
    first_locked_denies = 1'b0;
    for (int i = 0; i < N; i++)
    if (!any_locked_match && amatch[i] && conf_i[i].locked) begin
      any_locked_match    = 1'b1;
      first_locked_denies = ((access_type_i & conf_i[i].access_type) != access_type_i);
    end
  end
  logic f7_shape;
  assign f7_shape = any_match && lowest_unlocked && any_locked_match && first_locked_denies;

  always_comb begin
    // Theorem A: U/S conformance.
    a_us_equiv : assert (priv_lvl_i == riscv::PRIV_LVL_M || (sail_allow_i == cva6_allow_i));
    // Theorem B: every M-mode divergence has the F7 shape.
    a_m_div_is_f7 :
    assert (!(priv_lvl_i == riscv::PRIV_LVL_M && (sail_allow_i != cva6_allow_i)) || f7_shape);
    // Theorem C: the F7 shape always diverges in M-mode. B and C are an iff.
    a_f7_implies_div :
    assert (!(priv_lvl_i == riscv::PRIV_LVL_M && f7_shape) || (sail_allow_i != cva6_allow_i));
    // Column 3 only, swapping A/B/C out: with #3177 corrected nothing diverges.
    // a_full_equiv : assert (sail_allow_i == cva6_allow_i);
  end

  // STATUs 2026-09-08. Three same-base columns on CVA6 v5.3.0 (2ef1c1b1), each
  // adding only the named archived patch. Only the live theorem set moves.
  // Logs: evidence/sail/.
  //
  //   c1  no patch                          A,B,C  -> prove FAILS
  //   c2  + pmp_tor_grain_both_pr3490       A,B,C  -> all PROVEN, 5/5 covers
  //   c3  + pmp_3177_priority as well       A,full -> a_full_equiv PROVEN,
  //                                                   cover FAILS (only
  //                                                   c_m_divergence unreached)

  always_comb begin
    // non-vacuity + F7 witness
    c_read_deny : cover (access_type_i == riscv::ACCESS_READ && !cva6_allow_i);
    c_write_allow : cover (access_type_i == riscv::ACCESS_WRITE && cva6_allow_i);
    c_exec_deny : cover (access_type_i == riscv::ACCESS_EXEC && !sail_allow_i);
    c_f7_shape : cover (priv_lvl_i == riscv::PRIV_LVL_M && f7_shape);
    c_m_divergence : cover (priv_lvl_i == riscv::PRIV_LVL_M && (sail_allow_i != cva6_allow_i));
  end
endmodule
