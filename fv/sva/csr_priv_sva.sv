// Layer-2 trap/mstatus/priv checks, bound into csr_regfile (cv64a6_imafdc_sv39).
module csr_priv_sva #(
    parameter config_pkg::cva6_cfg_t CVA6Cfg = config_pkg::cva6_cfg_empty
) (
    input logic                                clk_i,
    input logic                                rst_ni,
    input riscv::priv_lvl_t                    priv_lvl,      // priv_lvl_q
    input logic                                mst_mie,       // mstatus_q.mie
    input logic                                mst_mpie,      // mstatus_q.mpie
    input riscv::priv_lvl_t                    mst_mpp,       // mstatus_q.mpp
    input logic                                mst_sie,       // mstatus_q.sie
    input logic                                mst_spie,      // mstatus_q.spie
    input logic                                mst_spp,       // mstatus_q.spp
    input riscv::priv_lvl_t                    trap_to_priv,  // trap_to_priv_lvl
    input logic                                mret_i,        // mret
    input logic                                sret_i,        // sret
    input logic                                debug_mode,    // debug_mode_q
    input logic             [CVA6Cfg.XLEN-1:0] medeleg,       // medeleg_q
    input logic             [CVA6Cfg.XLEN-1:0] mtval,         // mtval_q
    input logic                                ex_valid,      // ex_i.valid
    input logic             [CVA6Cfg.XLEN-1:0] ex_cause,      // ex_i.cause
    input logic             [CVA6Cfg.XLEN-1:0] ex_tval        // ex_i.tval
);
  localparam int unsigned CW = $clog2(CVA6Cfg.XLEN);
  logic is_irq;
  assign is_irq = ex_cause[CVA6Cfg.XLEN-1];

  logic past_valid;
  always_ff @(posedge clk_i)
    if (!rst_ni) past_valid <= 1'b0;
    else past_valid <= 1'b1;

  // architectural trap taken (csr_regfile.sv:1814: a debug request is not a trap)
  logic trap_taken;
  assign trap_taken = ex_valid && !debug_mode && (!CVA6Cfg.DebugEn || ex_cause != riscv::DEBUG_REQUEST);
  logic ante_mret, ante_sret, ante_mtrapM, ante_strapS, ante_irqM;
  assign ante_mret = mret_i && !ex_valid && !debug_mode;
  assign ante_sret = sret_i && !ex_valid && !debug_mode;
  assign ante_mtrapM = trap_taken && !mret_i && !sret_i && (trap_to_priv == riscv::PRIV_LVL_M);
  assign ante_strapS = trap_taken && !mret_i && !sret_i && (trap_to_priv == riscv::PRIV_LVL_S);
  assign ante_irqM = trap_taken && is_irq && !mret_i && !sret_i && (trap_to_priv == riscv::PRIV_LVL_M);

  // previous-cycle copies for the |=> stacking/return checks
  logic ante_mret_q, ante_sret_q, ante_mtrapM_q, ante_strapS_q, ante_irqM_q;
  logic mst_mie_q, mst_mpie_q, mst_sie_q, mst_spie_q, mst_spp_q;
  riscv::priv_lvl_t mst_mpp_q, priv_lvl_q1;

  always_ff @(posedge clk_i) begin
    mst_mie_q   <= mst_mie;
    mst_mpie_q  <= mst_mpie;
    mst_mpp_q   <= mst_mpp;
    mst_sie_q   <= mst_sie;
    mst_spie_q  <= mst_spie;
    mst_spp_q   <= mst_spp;
    priv_lvl_q1 <= priv_lvl;
  end

  always_ff @(posedge clk_i)
    if (!rst_ni) begin
      ante_mret_q   <= 1'b0;
      ante_sret_q   <= 1'b0;
      ante_mtrapM_q <= 1'b0;
      ante_strapS_q <= 1'b0;
      ante_irqM_q   <= 1'b0;
    end else begin
      ante_mret_q   <= ante_mret;
      ante_sret_q   <= ante_sret;
      ante_mtrapM_q <= ante_mtrapM;
      ante_strapS_q <= ante_strapS;
      ante_irqM_q   <= ante_irqM;
    end

  always_ff @(posedge clk_i)
    if (rst_ni && past_valid) begin
      a_mret :
      assert (!ante_mret_q || (
            (mst_mpie == 1'b1)
         && (mst_mie  == mst_mpie_q)
         && (priv_lvl == mst_mpp_q)
         && (mst_mpp  == (CVA6Cfg.RVU ? riscv::PRIV_LVL_U : riscv::PRIV_LVL_M))));

      a_mtrap_stack :
      assert (!ante_mtrapM_q || (
            (mst_mie  == 1'b0)
         && (mst_mpie == mst_mie_q)
         && (mst_mpp  == priv_lvl_q1)));

      // F5: csr_regfile.sv:1919 tests ex_cause[GPLEN-1]=cause[40], not the IRQ bit
      // cause[63] -> interrupt mtval not zeroed. EXPECTED CEX (prior-cycle ex_tval!=0).
      a_irq_mtval_zero : assert (!ante_irqM_q || (mtval == '0));
    end

  if (CVA6Cfg.RVS) begin : gen_sret
    always_ff @(posedge clk_i)
      if (rst_ni && past_valid)
        a_sret :
        assert (!ante_sret_q || (
              (mst_spie == 1'b1)
           && (mst_sie  == mst_spie_q)
           && (priv_lvl == riscv::priv_lvl_t'({1'b0, mst_spp_q}))
           && (mst_spp  == 1'b0)));
  end

  if (CVA6Cfg.RVS) begin : gen_strap
    always_ff @(posedge clk_i)
      if (rst_ni && past_valid)
        a_strap_stack :
        assert (!ante_strapS_q || (
              (mst_sie  == 1'b0)
           && (mst_spie == mst_sie_q)
           && (mst_spp  == priv_lvl_q1[0])));
  end

  always_ff @(posedge clk_i)
    if (rst_ni)
      a_trap_monotonic :
      assert (!(ex_valid && priv_lvl == riscv::PRIV_LVL_M) || (trap_to_priv == riscv::PRIV_LVL_M));

  if (CVA6Cfg.RVS) begin : gen_deleg
    always_ff @(posedge clk_i)
      if (rst_ni) begin
        a_deleg_to_s :
        assert (
          !(trap_taken && !is_irq && (priv_lvl != riscv::PRIV_LVL_M) && medeleg[ex_cause[CW-1:0]])
          || (trap_to_priv == riscv::PRIV_LVL_S));
        a_no_deleg_to_m :
        assert (
          !(trap_taken && !is_irq && (priv_lvl != riscv::PRIV_LVL_M) && !medeleg[ex_cause[CW-1:0]])
          || (trap_to_priv == riscv::PRIV_LVL_M));
      end
  end

  // F5 isolation: assume interrupts carry no tval -> a_irq_mtval_zero PASSES.
  // always_ff @(posedge clk_i) if (rst_ni)
  //   au_irq_tval0 : assume (!is_irq || (ex_tval == '0));

  always_ff @(posedge clk_i)
    if (rst_ni) begin
      c_mret_seen : cover (ante_mret);
      c_mtrapM_seen : cover (ante_mtrapM);
      c_irqM_tvalnz : cover (ante_irqM && ex_tval != '0);
    end
endmodule
