// Fix certification (evidence/sail/fix_cert/PROTOCOL.md): Section 3.3 properties
// on a Sail 0.14 model carrying #1959. Same module and ports as the frozen
// sail_oracle_sva.sv; adds the acceptance cover.
module sail_oracle_sva (
    input logic           [55:0] addr,
    input logic           [63:0] width,
    input riscv::pmpcfg_t [ 1:0] cfg,         // [0] predecessor, [1] entry
    input logic                  raw0_prev,   // predecessor's raw pmpaddr[0]
    input logic                  cva6_match,
    input t_pmpAddrMatch         m_sail,
    input t_pmpAddrMatch         m_arch,
    input t_pmpAddrMatch         m_prev,
    input logic                  helper_exc
);
  // c2 domain: naturally aligned, no wrap past 2^56, legal G=1 pmpcfg
  // (reserved zero, no NA4, no W without R)
  logic dom;
  always_comb begin
    dom = ({8'b0, addr} & (width - 64'd1)) == 64'd0
       && {8'b0, addr} <= 64'h00ff_ffff_ffff_ffff - (width - 64'd1);
    for (int i = 0; i < 2; i++)
    dom &= cfg[i].reserved == 2'b00 && cfg[i].addr_mode != riscv::NA4
          && !(cfg[i].access_type.w && !cfg[i].access_type.r);
  end

  // extracted oracle agrees: Match for a CVA6 match, NoMatch otherwise
  logic agree;
  assign agree = cva6_match ? m_sail == PMP_Match : m_sail == PMP_NoMatch;

  always_comb begin
`ifdef SAIL_ORACLE_REJECT
    a_extracted_sail_leaf_equiv : assert (!dom || agree);
`else
    a_cva6_matches_arch_leaf : assert (!dom || cva6_match == (m_arch == PMP_Match));
    a_arch_leaf_not_partial : assert (!dom || m_arch != PMP_PartialMatch);
    a_leaf_disagreement_shape :
    assert (!dom || agree || (cfg[1].addr_mode == riscv::TOR
                              && cfg[0].addr_mode == riscv::NAPOT && raw0_prev));
    a_leaf_disagreement_preempted : assert (!dom || agree || m_prev != PMP_NoMatch);
    // constant by construction: generated pmpMatchAddr never raises one
    a_sail_helper_no_internal_exception : assert (!dom || !helper_exc);
`endif
    c_aligned4_extracted_rejects :
    cover (dom && width == 64'd4 && cva6_match && m_sail == PMP_NoMatch);
    c_aligned4_extracted_accepts :
    cover (dom && width == 64'd4 && cfg[1].addr_mode == riscv::TOR
           && cfg[0].addr_mode == riscv::NAPOT && raw0_prev
           && cva6_match && m_sail == PMP_Match);
  end
endmodule
