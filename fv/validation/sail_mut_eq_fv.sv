// direct equivalence for adapter mutation (evidence/sail/TIER1_PROTOCOL.md §1):
// baseline and mutant wrapper on shared inputs. sail_mutation.sh builds base_fv
// and mut_fv from copies of pmp_sail_ref_fv.sv.
module sail_mut_eq_fv #(
    parameter config_pkg::cva6_cfg_t Cfg = build_config_pkg::build_config(
        cva6_config_pkg::cva6_cfg
    ),
    parameter int unsigned N = (Cfg.NrPMPEntries > 0 ? Cfg.NrPMPEntries : 1)
) (
    input logic           [Cfg.PLEN-1:0]               addr_i,
    input logic           [         1:0]               size_lg2_i,
    input logic           [         1:0]               access_kind_i,
    input logic           [         1:0]               priv_kind_i,
    input logic           [       N-1:0][Cfg.PLEN-3:0] pmpaddr_i,
    input riscv::pmpcfg_t [       N-1:0]               cfg_i
);
  logic base_sail, base_cva6, mut_sail, mut_cva6;

  base_fv base (
      .addr_i       (addr_i),
      .size_lg2_i   (size_lg2_i),
      .access_kind_i(access_kind_i),
      .priv_kind_i  (priv_kind_i),
      .pmpaddr_i    (pmpaddr_i),
      .cfg_i        (cfg_i),
      .sail_allow_o (base_sail),
      .cva6_allow_o (base_cva6)
  );

  mut_fv mut (
      .addr_i       (addr_i),
      .size_lg2_i   (size_lg2_i),
      .access_kind_i(access_kind_i),
      .priv_kind_i  (priv_kind_i),
      .pmpaddr_i    (pmpaddr_i),
      .cfg_i        (cfg_i),
      .sail_allow_o (mut_sail),
      .cva6_allow_o (mut_cva6)
  );

  always_comb begin
    a_same_decision : assert (base_sail == mut_sail && base_cva6 == mut_cva6);
    // domain is not empty
    c_domain : cover (1'b1);
  end
endmodule
