// F9 mstatus.MPP WARL legality. mstatus.mpp may only hold an implemented mode
// (M/S/U); the reserved encoding 2'b10 (PRIV_LVL_HS) is not a mode in any config,
// CVA6's guard (csr_regfile.sv:1382) rejects it only when RVH=0, so at RVH=1 it
// survives. Incomplete fix of #1988/#2274. Differential: run on the #3387 FORK,
// proves at RVH=0, CEXes at RVH=1. Detail: docs/FINDINGS.md (F9)
module mpp_legal_sva #(
    parameter config_pkg::cva6_cfg_t CVA6Cfg = config_pkg::cva6_cfg_empty
) (
    input logic                   clk_i,
    input logic                   rst_ni,
    input logic             [1:0] mst_mpp,     // mstatus_q.mpp
    input riscv::priv_lvl_t       priv_lvl,    // priv_lvl_q
    input riscv::priv_lvl_t       ld_st_priv,  // ld_st_priv_lvl_o
    input logic                   mret_i,      // mret
    input logic                   mprv_i       // mprv (debuggated eff., :2531)
);
  logic past_valid;
  always_ff @(posedge clk_i)
    if (!rst_ni) past_valid <= 1'b0;
    else past_valid <= 1'b1;

  // legal set is config independent: 2'b10 is not {M,S,U}
  logic mpp_legal, priv_legal, ldst_legal;
  assign mpp_legal = (mst_mpp == riscv::PRIV_LVL_M)
      || (CVA6Cfg.RVS && mst_mpp == riscv::PRIV_LVL_S)
      || (CVA6Cfg.RVU && mst_mpp == riscv::PRIV_LVL_U);
  assign priv_legal = (priv_lvl == riscv::PRIV_LVL_M)
      || (CVA6Cfg.RVS && priv_lvl == riscv::PRIV_LVL_S)
      || (CVA6Cfg.RVU && priv_lvl == riscv::PRIV_LVL_U);
  assign ldst_legal = (ld_st_priv == riscv::PRIV_LVL_M)
      || (CVA6Cfg.RVS && ld_st_priv == riscv::PRIV_LVL_S)
      || (CVA6Cfg.RVU && ld_st_priv == riscv::PRIV_LVL_U);

  // root-cause invariant; asserted on mpp not priv_lvl (priv_lvl is dret-corruptible, F8)
  always_ff @(posedge clk_i) if (rst_ni && past_valid) a_mpp_legal : assert (mpp_legal);

  always_ff @(posedge clk_i)
    if (rst_ni && past_valid) begin
      c_mret_seen : cover (mret_i);
      c_mprv_seen : cover (mprv_i);
      c_mpp_reserved : cover (!mpp_legal);
      c_mret_from_bad_mpp : cover (mret_i && !mpp_legal);  // mret --> priv_lvl
      c_priv_reserved : cover (!priv_legal);
      c_ldst_reserved : cover (!ldst_legal);
      c_ldst_reserved_via_mprv : cover (mprv_i && !ldst_legal);  // MPRV -> ld/st priv, no mret
    end
endmodule
