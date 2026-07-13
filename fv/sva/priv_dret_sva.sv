// F8 (PRIV-4) probe. Debug spec v1.0: dcsr.prv is a WARL field over the
// supported privilege modes. The CSR_DCSR write path (csr_regfile.sv:1054-1066)
// legalizes xdebugver/nmip/stopcount/stoptime but stores prv raw, so prv can
// hold 2'b10 (PRIV_LVL_HS, notimplemented on this RVH=0 build). dret then loads
// priv_lvl_d from dcsr_q.prv (:2166), leaving the hart at a privilege none of
// M/S/U. Expected CEX on the golden RTL, proven after the fix in PR #3387.
module priv_dret_sva #(
    parameter config_pkg::cva6_cfg_t CVA6Cfg = config_pkg::cva6_cfg_empty
) (
    input logic                   clk_i,
    input logic                   rst_ni,
    input riscv::priv_lvl_t       priv_lvl,   // priv_lvl_q
    input logic             [1:0] dcsr_prv,   // dcsr_q.prv
    input logic                   dret_i,     // dret
    input logic                   debug_mode  // debug_mode_q
);
  logic prv_legal, priv_legal;
  assign prv_legal = (dcsr_prv == riscv::PRIV_LVL_M)
      || (CVA6Cfg.RVS && dcsr_prv == riscv::PRIV_LVL_S)
      || (CVA6Cfg.RVU && dcsr_prv == riscv::PRIV_LVL_U);
  assign priv_legal = (priv_lvl == riscv::PRIV_LVL_M)
      || (CVA6Cfg.RVS && priv_lvl == riscv::PRIV_LVL_S)
      || (CVA6Cfg.RVU && priv_lvl == riscv::PRIV_LVL_U);

  // F8 (PRIV-4): priv_lvl must stay in M,S, U. asserting the consequence (not
  // just that dcsr.prv can be illegal) forces CEX to drive dret from an
  // unlegalized dcsr.prv and witness unimplemented-mode corruption itself.
  always_ff @(posedge clk_i) if (rst_ni) a_priv_legal : assert (priv_legal);

  always_ff @(posedge clk_i)
    if (rst_ni) begin
      // reachability of debug entry, dret, and dret-in-debug
      c_debug_mode_seen : cover (debug_mode);
      c_dret_seen : cover (dret_i);
      c_dret_in_debug : cover (dret_i && debug_mode);
      // illegal dcsr.prv precondition is reachable on the golden RTL,
      // after the PR #3387 fix this becomes unreachable, which confirms the fix.
      c_dcsr_prv_illegal : cover (!prv_legal);
    end
endmodule
