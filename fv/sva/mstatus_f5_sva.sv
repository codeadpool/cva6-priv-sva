// F5 witness probe (MST-6) - EXPECTED CEX, do not "fix" the assert.
// csr_regfile.sv:1919 gates M-trap mtval zeroing on cause[GPLEN-1] (bit 40)
// instead of the IRQ bit cause[XLEN-1]; with ariane_pkg::ZERO_TVAL=0 (default,
// non-SPIKE_TANDEM) the zeroing arm is off entirely, so an interrupt trap to M
// writes ex_i.tval into mtval. Priv spec v1.13 3.1.1.16: "For other traps,
// mtval is set to zero." Evidence chain: docs/FINDINGS.md F5.
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

  // architectural trap taken (csr_regfile.sv:1814: a debug request is not a trap)
  logic trap_taken;
  assign trap_taken = ex_valid && !debug_mode && (!CVA6Cfg.DebugEn || ex_cause != riscv::DEBUG_REQUEST);

  logic ante_irqM;
  assign ante_irqM = trap_taken && is_irq && !mret_i && !sret_i && (trap_to_priv == riscv::PRIV_LVL_M);

  logic ante_irqM_q;
  always_ff @(posedge clk_i)
    if (!rst_ni) ante_irqM_q <= 1'b0;
    else ante_irqM_q <= ante_irqM;

  always_ff @(posedge clk_i)
    if (rst_ni && past_valid)
      a_irq_mtval_zero : assert (!ante_irqM_q || (mtval == '0));

  always_ff @(posedge clk_i)
    if (rst_ni)
      c_irqM_tvalnz : cover (ante_irqM && ex_tval != '0);
endmodule
