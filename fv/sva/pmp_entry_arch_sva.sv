// architectural TOR range (G=1 grain bit excluded from both bounds), checker
// for pmp_entry. Companion to pmp_entry_sva, whose PMP-5 uses raw stored
// addresses (tagged RTL-tor). The pair disagrees on golden by construction.
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
  // Machine ISA v1.13 2.1.7.1.1: at G=1 the low bit of a pmpaddr does not affect
  // TOR matching. The rule follows pmpaddr_i wherever it takes part in that
  // logic, so it masks entry i's own upper bound and entry i+1's lower bound
  // alike (riscv-isa-manual #884, closed 2025-12-09).
  logic [CVA6Cfg.PLEN-1:0] tor_lo_arch, tor_hi_arch;
  assign tor_lo_arch = ({2'b00, conf_addr_prev_i[CVA6Cfg.PLEN-3:1], 1'b0} << 2);
  assign tor_hi_arch = ({2'b00, conf_addr_i[CVA6Cfg.PLEN-3:1], 1'b0} << 2);

  always_comb begin
    // PMP-5 restated over the architectural range
    a_tor_exact_arch :
    assert (!(conf_addr_mode_i == riscv::TOR) ||
        (match_o == ((addr_i >= tor_lo_arch) && (addr_i < tor_hi_arch))));
  end

  always_comb begin
    // antecedent reachability, and that the deciding input is reachable
    c_tor_match_arch : cover (conf_addr_mode_i == riscv::TOR && match_o);
    c_grain_bit_set : cover (conf_addr_mode_i == riscv::TOR && conf_addr_i[0]);
  end
endmodule
