// formal top: pmp_entry + checker; free inputs are module ports (shared PIs).
module pmp_entry_fv #(
    parameter config_pkg::cva6_cfg_t Cfg = build_config_pkg::build_config(cva6_config_pkg::cva6_cfg)
) (
    input logic                                 clk,
    input logic                  [Cfg.PLEN-1:0] addr_i,
    input logic                  [Cfg.PLEN-3:0] conf_addr_i,
    input logic                  [Cfg.PLEN-3:0] conf_addr_prev_i,
    input riscv::pmp_addr_mode_t                conf_addr_mode_i
);
  logic match;

  pmp_entry #(
      .CVA6Cfg(Cfg)
  ) dut (
      .addr_i          (addr_i),
      .conf_addr_i     (conf_addr_i),
      .conf_addr_prev_i(conf_addr_prev_i),
      .conf_addr_mode_i(conf_addr_mode_i),
      .match_o         (match)
  );

  pmp_entry_sva #(
      .CVA6Cfg(Cfg)
  ) chk (
      .clk_i           (clk),
      .addr_i          (addr_i),
      .conf_addr_i     (conf_addr_i),
      .conf_addr_prev_i(conf_addr_prev_i),
      .conf_addr_mode_i(conf_addr_mode_i),
      .match_o         (match)
  );
endmodule
