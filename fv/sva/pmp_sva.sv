// PMP priority/permission default rules - checker for pmp.sv.
module pmp_sva #(
    parameter config_pkg::cva6_cfg_t CVA6Cfg = config_pkg::cva6_cfg_empty
) (
    input logic clk_i,
    input logic [CVA6Cfg.PLEN-1:0] addr_i,
    input riscv::pmp_access_t access_type_i,
    input riscv::priv_lvl_t priv_lvl_i,
    input logic [(CVA6Cfg.NrPMPEntries > 0 ? CVA6Cfg.NrPMPEntries-1 : 0):0][CVA6Cfg.PLEN-3:0] conf_addr_i,
    input riscv::pmpcfg_t [(CVA6Cfg.NrPMPEntries > 0 ? CVA6Cfg.NrPMPEntries-1 : 0):0] conf_i,
    input logic allow_i
);
  localparam int unsigned N = CVA6Cfg.NrPMPEntries;

  // all entries OFF -> DUT takes its no-match path
  logic all_off;
  always_comb begin
    all_off = 1'b1;
    for (int i = 0; i < N; i++) if (conf_i[i].addr_mode != riscv::OFF) all_off = 1'b0;
  end

  always_comb begin
    a_pmp1_m_default_allow : assert (!(all_off && priv_lvl_i == riscv::PRIV_LVL_M) || allow_i);
    a_pmp2_su_default_deny :
    assert (!(all_off && (N > 0) && priv_lvl_i != riscv::PRIV_LVL_M) || !allow_i);
  end

  always_comb begin
    c_m_allow : cover (all_off && priv_lvl_i == riscv::PRIV_LVL_M && allow_i);
    c_su_deny : cover (all_off && (N > 0) && priv_lvl_i != riscv::PRIV_LVL_M && !allow_i);
  end

  // TODO: PMP-3 first-match priority, PMP-4 lock-applies-to-M, PMP-8 RWX subset (need internal match[])
endmodule
