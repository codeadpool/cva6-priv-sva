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
    input logic                                dret_i,        // dret (NOT debug_mode-gated)
    input logic                                debug_mode,    // debug_mode_q
    input logic             [CVA6Cfg.XLEN-1:0] medeleg,       // medeleg_q
    input logic             [CVA6Cfg.XLEN-1:0] mideleg,       // mideleg_q
    input logic                                ex_valid,      // ex_i.valid
    input logic             [CVA6Cfg.XLEN-1:0] ex_cause,      // ex_i.cause
    input logic             [CVA6Cfg.VLEN-1:0] pc,            // pc_i
    input logic             [CVA6Cfg.XLEN-1:0] mepc,          // mepc_q
    input logic             [CVA6Cfg.XLEN-1:0] mcause,        // mcause_q
    input logic             [CVA6Cfg.XLEN-1:0] sepc,          // sepc_q
    input logic             [CVA6Cfg.XLEN-1:0] scause         // scause_q
);
  localparam int unsigned CW = $clog2(CVA6Cfg.XLEN);
  logic is_irq;
  assign is_irq = ex_cause[CVA6Cfg.XLEN-1];

  logic past_valid;
  always_ff @(posedge clk_i)
    if (!rst_ni) past_valid <= 1'b0;
    else past_valid <= 1'b1;

  // arch. trap taken (csr_regfile.sv:1814: a debug request is not a trap)
  logic trap_taken;
  assign trap_taken = ex_valid && !debug_mode && (!CVA6Cfg.DebugEn || ex_cause != riscv::DEBUG_REQUEST);
  logic ante_mret, ante_sret, ante_mtrap_m, ante_strap_s, ante_trap6;
  assign ante_mret = mret_i && !ex_valid && !debug_mode;
  assign ante_sret = sret_i && !ex_valid && !debug_mode;
  assign ante_mtrap_m = trap_taken && !mret_i && !sret_i && (trap_to_priv == riscv::PRIV_LVL_M);
  assign ante_strap_s = trap_taken && !mret_i && !sret_i && (trap_to_priv == riscv::PRIV_LVL_S);

  // dret writes priv_lvl_d after the trap block (csr:2166) and is not
  // debug_mode-gated, so TRAP-6 must exclude it
  assign ante_trap6 = trap_taken && !mret_i && !sret_i && !dret_i;

  // epc capture uses the RTLS own sign-ext shape (csr:1871/:1909)
  logic [CVA6Cfg.XLEN-1:0] epc_exp;
  assign epc_exp = {{CVA6Cfg.XLEN - CVA6Cfg.VLEN{pc[CVA6Cfg.VLEN-1]}}, pc};

  // previous-cycle copies for the |=> stacking/return checks
  logic ante_mret_q, ante_sret_q, ante_mtrap_m_q, ante_strap_s_q, ante_trap6_q;
  logic mst_mie_q, mst_mpie_q, mst_sie_q, mst_spie_q, mst_spp_q;
  riscv::priv_lvl_t mst_mpp_q, priv_lvl_q1, trap_to_priv_q1;
  logic [CVA6Cfg.XLEN-1:0] ex_cause_q1, epc_exp_q1;

  always_ff @(posedge clk_i) begin
    mst_mie_q       <= mst_mie;
    mst_mpie_q      <= mst_mpie;
    mst_mpp_q       <= mst_mpp;
    mst_sie_q       <= mst_sie;
    mst_spie_q      <= mst_spie;
    mst_spp_q       <= mst_spp;
    priv_lvl_q1     <= priv_lvl;
    trap_to_priv_q1 <= trap_to_priv;
    ex_cause_q1     <= ex_cause;
    epc_exp_q1      <= epc_exp;
  end

  always_ff @(posedge clk_i)
    if (!rst_ni) begin
      ante_mret_q <= 1'b0;
      ante_sret_q <= 1'b0;
      ante_mtrap_m_q <= 1'b0;
      ante_strap_s_q <= 1'b0;
      ante_trap6_q <= 1'b0;
    end else begin
      ante_mret_q <= ante_mret;
      ante_sret_q <= ante_sret;
      ante_mtrap_m_q <= ante_mtrap_m;
      ante_strap_s_q <= ante_strap_s;
      ante_trap6_q <= ante_trap6;
    end

  always_ff @(posedge clk_i)
    if (rst_ni && past_valid) begin
      // MST-3: mret restores mie from mpie, sets mpie=1, priv from mpp, mpp to U
      a_mret :
      assert (!ante_mret_q || (
            (mst_mpie == 1'b1)
         && (mst_mie  == mst_mpie_q)
         && (priv_lvl == mst_mpp_q)
         && (mst_mpp  == (CVA6Cfg.RVU ? riscv::PRIV_LVL_U : riscv::PRIV_LVL_M))));

      // MST-1: an M-trap stacks the interrupt-enable and records the prior priv
      a_mtrap_stack :
      assert (!ante_mtrap_m_q || (
            (mst_mie  == 1'b0)
         && (mst_mpie == mst_mie_q)
         && (mst_mpp  == priv_lvl_q1)));

      // TRAP-5 (M): mepc/mcause capture pc/cause (csr:1907-1909)
      a_mtrap_capture : assert (!ante_mtrap_m_q || (mcause == ex_cause_q1 && mepc == epc_exp_q1));

      // TRAP-6: the trap lands in the routed privilege (csr:1945)
      a_trap_priv_target : assert (!ante_trap6_q || (priv_lvl == trap_to_priv_q1));
    end

  if (CVA6Cfg.RVS) begin : gen_sret
    always_ff @(posedge clk_i)
      if (rst_ni && past_valid)
        // MST-4: sret restores sie from spie, sets spie=1, priv from spp, spp to U
        a_sret :
        assert (!ante_sret_q || (
              (mst_spie == 1'b1)
           && (mst_sie  == mst_spie_q)
           && (priv_lvl == riscv::priv_lvl_t'({1'b0, mst_spp_q}))
           && (mst_spp  == 1'b0)));
  end

  if (CVA6Cfg.RVS) begin : gen_strap
    always_ff @(posedge clk_i)
      if (rst_ni && past_valid) begin
        // MST-2: an S-trap stacks the S interruptenable and records the prior priv
        a_strap_stack :
        assert (!ante_strap_s_q || (
              (mst_sie  == 1'b0)
           && (mst_spie == mst_sie_q)
           && (mst_spp  == priv_lvl_q1[0])));

        // TRAP-5 (S): sepc/scause capture pc/cause (csr:1869-1871)
        a_strap_capture : assert (!ante_strap_s_q || (scause == ex_cause_q1 && sepc == epc_exp_q1));
      end
  end

  always_ff @(posedge clk_i)
    if (rst_ni)
      // TRAP-3: a trap never moves to a less privileged mode (M stays in M)
      a_trap_monotonic :
      assert (!(ex_valid && priv_lvl == riscv::PRIV_LVL_M) || (trap_to_priv == riscv::PRIV_LVL_M));

  if (CVA6Cfg.RVS) begin : gen_deleg
    always_ff @(posedge clk_i)
      if (rst_ni) begin
        // TRAP-2: a delegated exception taken in S/U routes to S
        a_deleg_to_s :
        assert (
          !(trap_taken && !is_irq && (priv_lvl != riscv::PRIV_LVL_M) && medeleg[ex_cause[CW-1:0]])
          || (trap_to_priv == riscv::PRIV_LVL_S));
        // TRAP-1: an undelegated exception below M routes to M
        a_no_deleg_to_m :
        assert (
          !(trap_taken && !is_irq && (priv_lvl != riscv::PRIV_LVL_M) && !medeleg[ex_cause[CW-1:0]])
          || (trap_to_priv == riscv::PRIV_LVL_M));

        // TRAP-4: interrupt routing mirrors mideleg (csr:1822-1829)
        a_irq_deleg_to_s :
        assert (
          !(trap_taken && is_irq && (priv_lvl != riscv::PRIV_LVL_M) && mideleg[ex_cause[CW-1:0]])
          || (trap_to_priv == riscv::PRIV_LVL_S));
        a_irq_no_deleg_to_m :
        assert (
          !(trap_taken && is_irq && (priv_lvl != riscv::PRIV_LVL_M) && !mideleg[ex_cause[CW-1:0]])
          || (trap_to_priv == riscv::PRIV_LVL_M));
      end
  end

  // PRIV-1 / MST-5 as a step property: a legal stays legal, except via
  // dret, which loads priv_lvl from the unlegalized dcsr.prv (csr:1056,:2166)
  // that hole is probed in priv_dret_sva.sv
  logic priv_legal, mpp_legal, legal_q1, dret_q1;
  assign priv_legal = (priv_lvl == riscv::PRIV_LVL_M)
      || (CVA6Cfg.RVS && priv_lvl == riscv::PRIV_LVL_S)
      || (CVA6Cfg.RVU && priv_lvl == riscv::PRIV_LVL_U);
  assign mpp_legal = (mst_mpp == riscv::PRIV_LVL_M)
      || (CVA6Cfg.RVS && mst_mpp == riscv::PRIV_LVL_S)
      || (CVA6Cfg.RVU && mst_mpp == riscv::PRIV_LVL_U);
  always_ff @(posedge clk_i)
    if (!rst_ni) begin
      legal_q1 <= 1'b0;
      dret_q1  <= 1'b0;
    end else begin
      legal_q1 <= priv_legal && mpp_legal;
      dret_q1  <= dret_i;
    end
  always_ff @(posedge clk_i)
    if (rst_ni && past_valid && legal_q1 && !dret_q1) begin
      a_priv_legal_step : assert (priv_legal);
      a_mpp_legal_step : assert (mpp_legal);
    end

  always_ff @(posedge clk_i)
    if (rst_ni) begin
      c_mret_seen : cover (ante_mret);
      c_mtrap_m_seen : cover (ante_mtrap_m);
      c_trap_m_from_m : cover (ex_valid && priv_lvl == riscv::PRIV_LVL_M && trap_taken);
      c_trap6_seen : cover (ante_trap6);
      c_dret_seen : cover (dret_i);
      c_priv_u_seen : cover (priv_lvl == riscv::PRIV_LVL_U);
    end

  if (CVA6Cfg.RVS) begin : gen_scov
    always_ff @(posedge clk_i)
      if (rst_ni) begin
        c_sret_seen : cover (ante_sret);
        c_strap_s_seen : cover (ante_strap_s);
        c_priv_s_seen : cover (priv_lvl == riscv::PRIV_LVL_S);
        c_deleg_to_s_seen :
        cover (trap_taken && !is_irq && (priv_lvl != riscv::PRIV_LVL_M) && medeleg[ex_cause[CW-1:0]]);
        c_no_deleg_to_m_seen :
        cover (trap_taken && !is_irq && (priv_lvl != riscv::PRIV_LVL_M) && !medeleg[ex_cause[CW-1:0]]);
        c_irq_deleg_to_s_seen :
        cover (trap_taken && is_irq && (priv_lvl != riscv::PRIV_LVL_M) && mideleg[ex_cause[CW-1:0]]);
        c_irq_no_deleg_to_m_seen :
        cover (trap_taken && is_irq && (priv_lvl != riscv::PRIV_LVL_M) && !mideleg[ex_cause[CW-1:0]]);
      end
  end
endmodule
