// ============================================================================
// Sail-derived PMP decision-function equivalence miter
// cv64a6_imafdc_sv39 config (N=8), drives the unmodified golden CVA6 v5.3.0
// pmp.sv and the Sail-RISC-V 0.12 generated pmpCheckHw from shared symbolic
// inputs; equivalence properties are in pmp_sail_ref_sva (instantiated below).
//
// The stored OFF/TOR low address bit is free, so #3342 states stay reachable.
// Requires CVA6Cfg.PLEN == 56: the Sail top is generated at XLEN=64 / PLEN=56.
// ============================================================================
module pmp_sail_ref_fv #(
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
  localparam int PMPADDR_W = Cfg.PLEN - 2;

  riscv::pmp_access_t                          cva6_access;
  riscv::priv_lvl_t                            cva6_priv;
  logic                                        cva6_allow;

  logic                                 [63:0] width_bytes;
  logic                                 [63:0] sail_addr              [64];
  t_Pmpcfg_ent                                 sail_cfg               [64];
  t_zMemoryAccessTypezIEmem_payloadz5zK        sail_access;
  t_Privilege                                  sail_priv;
  t_zoptionzIUExceptionTypezK                  sail_result;
  bit                                          sail_have_exception;
  t_exception                                  sail_current_exception;
  logic                                        sail_allow;

  always_comb begin
    width_bytes = 64'b1 << size_lg2_i;

    case (access_kind_i)
      0: begin
        cva6_access = riscv::ACCESS_READ;
        sail_access = zLoadzIEmem_payloadz5zK(Data);
      end
      1: begin
        cva6_access = riscv::ACCESS_WRITE;
        sail_access = zStorezIEmem_payloadz5zK(Data);
      end
      default: begin
        cva6_access = riscv::ACCESS_EXEC;
        sail_access = zInstructionFetchzIEmem_payloadz5zK(SAIL_UNIT);
      end
    endcase

    case (priv_kind_i)
      0: begin
        cva6_priv = riscv::PRIV_LVL_U;
        sail_priv = User;
      end
      1: begin
        cva6_priv = riscv::PRIV_LVL_S;
        sail_priv = Supervisor;
      end
      default: begin
        cva6_priv = riscv::PRIV_LVL_M;
        sail_priv = Machine;
      end
    endcase

    // Sail has 64 entry slots; slots N..63 stay all-zero = OFF (never match), so
    // both models decide over exactly the N implemented entries.
    for (int i = 0; i < 64; i++) begin
      sail_addr[i]     = '0;
      sail_cfg[i].bits = '0;
    end
    for (int i = 0; i < N; i++) begin
      sail_addr[i]     = {{(64 - PMPADDR_W) {1'b0}}, pmpaddr_i[i]};
      sail_cfg[i].bits = cfg_i[i];
    end

    sail_allow = sail_result.tag == ZNONEZIUEXCEPTIONTYPEZK;

    // access_kind_i / priv_kind_i need no assume: both are [1:0] and both case
    // statements above have a default arm, so encoding 3 maps to exactly the
    // same op as encoding 2 (EXEC / Machine).
    assume ((addr_i & (width_bytes - 1)) == 0);
    assume (addr_i <= {Cfg.PLEN{1'b1}} - (width_bytes - 1));

    for (int i = 0; i < N; i++) begin
      // legal G=1 CSR-visible state: reserved cfg bits zero; NA4 unavailable at
      // G>=1; reserved R=0,W=1 excluded.
      assume (cfg_i[i].reserved == 2'b00);
      assume (cfg_i[i].addr_mode != riscv::NA4);
      assume (!(cfg_i[i].access_type.w && !cfg_i[i].access_type.r));
    end

    // Harness lemma: under natural alignment + width in {1,2,4,8} + G=1, the
    // access stays within one 8-byte PMP granule, so it can't partially cross
    // a boundary and CVA6's single-address decision is comparable with Sail's
    // interval decision (pmpRangeMatch never returns PMP_PartialMatch).
    a_no_boundary_cross : assert (({61'b0, addr_i[2:0]} + width_bytes) <= 64'd8);

    // infra sanity: Sail top takes no internal exception path in-domain
    a_sail_no_internal_exception : assert (!sail_have_exception);
  end

  // DUT: golden CVA6 v5.3.0 PMP
  pmp #(
      .CVA6Cfg(Cfg)
  ) cva6_pmp (
      .addr_i       (addr_i),
      .access_type_i(cva6_access),
      .priv_lvl_i   (cva6_priv),
      .conf_addr_i  (pmpaddr_i),
      .conf_i       (cfg_i),
      .allow_o      (cva6_allow)
  );

  // reference: Sail-RISC-V 0.12 generated decision
  pmpCheckHw sail_pmp (
      .addr_0                  (addr_i),
      .width_0                 (width_bytes),
      .access_0                (sail_access),
      .priv_0                  (sail_priv),
      .pmpaddr_n_0             (sail_addr),
      .pmpcfg_n_0              (sail_cfg),
      .zassert_reachablez3     (1'b1),
      .sail_return_2           (sail_result),
      .sail_have_exception_2   (sail_have_exception),
      .sail_current_exception_2(sail_current_exception)
  );

  // equivalence properties
  pmp_sail_ref_sva #(
      .CVA6Cfg(Cfg)
  ) chk (
      .addr_i       (addr_i),
      .access_type_i(cva6_access),
      .priv_lvl_i   (cva6_priv),
      .conf_addr_i  (pmpaddr_i),
      .conf_i       (cfg_i),
      .cva6_allow_i (cva6_allow),
      .sail_allow_i (sail_allow)
  );
endmodule
