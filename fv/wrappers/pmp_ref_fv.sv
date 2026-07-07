// formal top: pmp + reference-model checker; free inputs are module ports.
module pmp_ref_fv #(
    parameter config_pkg::cva6_cfg_t Cfg = build_config_pkg::build_config(
        cva6_config_pkg::cva6_cfg
    ),
    parameter int unsigned N = (Cfg.NrPMPEntries > 0 ? Cfg.NrPMPEntries : 1)
) (
    input logic                                            clk,
    input logic               [Cfg.PLEN-1:0]               addr_i,
    input riscv::pmp_access_t                              access_type_i,
    input riscv::priv_lvl_t                                priv_lvl_i,
    input logic               [       N-1:0][Cfg.PLEN-3:0] conf_addr_i,
    input riscv::pmpcfg_t     [       N-1:0]               conf_i
);
  logic allow;

  pmp #(
      .CVA6Cfg(Cfg)
  ) dut (
      .addr_i       (addr_i),
      .access_type_i(access_type_i),
      .priv_lvl_i   (priv_lvl_i),
      .conf_addr_i  (conf_addr_i),
      .conf_i       (conf_i),
      .allow_o      (allow)
  );

  pmp_ref_sva #(
      .CVA6Cfg(Cfg)
  ) chk (
      .addr_i       (addr_i),
      .access_type_i(access_type_i),
      .priv_lvl_i   (priv_lvl_i),
      .conf_addr_i  (conf_addr_i),
      .conf_i       (conf_i),
      .allow_i      (allow)
  );
endmodule
