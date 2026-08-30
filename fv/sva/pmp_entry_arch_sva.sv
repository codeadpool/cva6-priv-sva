// architectural TOR bound (G=1 grain bit excluded), checker for pmp_entry.
// pmp_entry_sva checks PMP-5 using the raw stored addresses (tagged RTL-tor).
// Keeping both oracles: on golden RTL they intentionally disagree. Neither
// is design-independent, though: a matcher that masks both TOR bounds fails both.
module pmp_entry_arch_sva #(
    parameter config_pkg::cva6_cfg_t CVA6Cfg = config_pkg::cva6_cfg_empty
) (
    input logic clk_i,
    input logic [CVA6Cfg.PLEN-1:0] addr_i,
    input logic [CVA6Cfg.PLEN-3:0] conf_addr_i,
    input logic [CVA6Cfg.PLEN-3:0] conf_addr_prev_i,
    input riscv::pmp_addr_mode_t conf_addr_mode_i,
    input logic match_o
);
  // Machine ISA v1.13 2.1.7.1.1: at G=1 the low bit of an OFF/TOR entry's own
  // pmpaddr does not affect TOR matching. Leaving the predecessor bound raw is
  // an interpretation choice, and pmp_entry has no port
  // carrying the predecessor's mode anyway. Upstream PR #3490 masks both bounds,
  // so this property fails against that design too.
  logic [CVA6Cfg.PLEN-1:0] tor_lo, tor_hi_arch;
  assign tor_lo = ({2'b00, conf_addr_prev_i} << 2);
  assign tor_hi_arch = ({2'b00, conf_addr_i[CVA6Cfg.PLEN-3:1], 1'b0} << 2);

  always_comb begin
    // PMP-5 restated over the architectural upper bound
    a_tor_exact_arch :
    assert (!(conf_addr_mode_i == riscv::TOR) ||
        (match_o == ((addr_i >= tor_lo) && (addr_i < tor_hi_arch))));
  end

  always_comb begin
    // antecedent reachability
    c_tor_match_arch : cover (conf_addr_mode_i == riscv::TOR && match_o);
    c_grain_bit_set : cover (conf_addr_mode_i == riscv::TOR && conf_addr_i[0]);
  end
endmodule
