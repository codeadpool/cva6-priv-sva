module mstatus_f5_sva #(
    parameter config_pkg::cva6_cfg_t CVA6Cfg = config_pkg::cva6_cfg_empty
) (
    input logic                                clk_i,
    input logic                                rst_ni,
    input riscv::priv_lvl_t                    trap_to_priv,  // trap_to_priv_lvl
    input logic                                mret_i,        // mret
    input logic                                sret_i,        // sret
    input logic                                debug_mode,    // debug_mode_q
    input logic             [CVA6Cfg.XLEN-1:0] mtval,         // mtval_q
    input logic                                ex_valid,      // ex_i.valid
    input logic             [CVA6Cfg.XLEN-1:0] ex_cause,      // ex_i.cause
    input logic             [CVA6Cfg.XLEN-1:0] ex_tval        // ex_i.tval
);
  logic is_irq;
  assign is_irq = ex_cause[CVA6Cfg.XLEN-1];

  logic past_valid;
  always_ff @(posedge clk_i)
    if (!rst_ni) past_valid <= 1'b0;
    else past_valid <= 1'b1;

  // arch.. trap taken (csr_regfile.sv:1814: a debug request is not a trap)
  logic trap_taken;
  assign trap_taken = ex_valid && !debug_mode && (!CVA6Cfg.DebugEn || ex_cause != riscv::DEBUG_REQUEST);

  logic ante_irq_m;
  assign ante_irq_m = trap_taken && is_irq && !mret_i && !sret_i && (trap_to_priv == riscv::PRIV_LVL_M);

  logic ante_irq_m_q;
  always_ff @(posedge clk_i)
    if (!rst_ni) ante_irq_m_q <= 1'b0;
    else ante_irq_m_q <= ante_irq_m;

  always_ff @(posedge clk_i)
    if (rst_ni && past_valid)
      // F5 (MST-6) probe: after an interrupt trap to M, mtval must read 0,
      // interrupts are "other traps", which the spec requires to zero mtval.
      // expected CEX on the golden RTL, proven after the fix in PR #3386.
      a_irq_mtval_zero :
      assert (!ante_irq_m_q || (mtval == '0));

  // antecedent reachability: an interrupt trap to M with nonzero ex.tval
  always_ff @(posedge clk_i) if (rst_ni) c_irq_m_tvalnz : cover (ante_irq_m && ex_tval != '0);
endmodule
