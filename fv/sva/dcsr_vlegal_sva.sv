// #3387 dcsr.v RVH=1 clamp cert: dcsr.v must never pair with prv=M (M-mode is
// never virtualized). Two scoped properties, one per clamp; the global invariant
// !(dcsr.prv==M && dcsr.v) stays with the separate mret+mpv fix (#3313). RVH=1
// only, CEX on golden / proves on the #3387 fork.
module dcsr_vlegal_sva #(
    parameter config_pkg::cva6_cfg_t CVA6Cfg = config_pkg::cva6_cfg_empty
) (
    input logic             clk_i,
    input logic             rst_ni,
    input riscv::priv_lvl_t dcsr_prv,    // dcsr_q.prv
    input logic             dcsr_v,      // dcsr_q.v
    input riscv::priv_lvl_t priv_lvl,    // priv_lvl_q
    input logic             op_v,        // v_q
    input logic             dcsr_wr,     // csr_we & addr==CSR_DCSR
    input logic             debug_mode,  // debug_mode_q
    input logic             dret_i       // dret
);
  logic past_valid, wr_indebug_q, dret_q;
  always_ff @(posedge clk_i)
    if (!rst_ni) begin
      past_valid   <= 1'b0;
      wr_indebug_q <= 1'b0;
      dret_q       <= 1'b0;
    end else begin
      past_valid   <= 1'b1;
      wr_indebug_q <= dcsr_wr && debug_mode;
      dret_q       <= dret_i;
    end

  // write clamp: an in-debug dcsr write can't store {prv=M, v=1}. guarded by
  // debug_mode, else the debug-entry capture (csr:2173) reintroduces #3313's CEX.
  always_ff @(posedge clk_i)
    if (rst_ni && past_valid)
      a_dcsr_wr_vlegal : assert (!wr_indebug_q || !(dcsr_prv == riscv::PRIV_LVL_M && dcsr_v));

  // dret clamp: resumed state is never M with V=1 (dret clamps its own output)
  always_ff @(posedge clk_i)
    if (rst_ni && past_valid)
      a_dret_vlegal : assert (!dret_q || !(priv_lvl == riscv::PRIV_LVL_M && op_v));

  // c_wr_illegal/c_dret_illegal are the M+V=1 defect: reached on golden, closed
  // on the fork. c_wr_indebug/c_dret_seen just show the write/dret events occur
  always_ff @(posedge clk_i)
    if (rst_ni && past_valid) begin
      c_wr_indebug : cover (wr_indebug_q);
      c_dret_seen : cover (dret_q);
      c_wr_illegal : cover (wr_indebug_q && dcsr_prv == riscv::PRIV_LVL_M && dcsr_v);
      c_dret_illegal : cover (dret_q && priv_lvl == riscv::PRIV_LVL_M && op_v);
    end
endmodule
