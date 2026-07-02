// PMP single-entry match (TOR/NAPOT/OFF/NA4) - checker for pmp_entry.sv.
module pmp_entry_sva #(
    parameter config_pkg::cva6_cfg_t CVA6Cfg = config_pkg::cva6_cfg_empty
) (
    input logic clk_i,
    input logic [CVA6Cfg.PLEN-1:0] addr_i,
    input logic [CVA6Cfg.PLEN-3:0] conf_addr_i,
    input logic [CVA6Cfg.PLEN-3:0] conf_addr_prev_i,
    input riscv::pmp_addr_mode_t conf_addr_mode_i,
    input logic match_o
);
  // TOR range [prev<<2, this<<2)
  logic [CVA6Cfg.PLEN-1:0] tor_lo, tor_hi;
  assign tor_lo = ({2'b00, conf_addr_prev_i} << 2);
  assign tor_hi = ({2'b00, conf_addr_i} << 2);

  // NAPOT region decoded independently of the DUT lzc: lowmask = x^(x+1) = 2^(t+1)-1
  logic [CVA6Cfg.PLEN-3:0] lowmask;
  logic [CVA6Cfg.PLEN-1:0] gran, napot_mask, napot_base;
  assign lowmask    = conf_addr_i ^ (conf_addr_i + 1'b1);
  assign gran       = ({2'b00, lowmask} + 1'b1) << 2;
  assign napot_mask = ~(gran - 1'b1);
  assign napot_base = ({2'b00, conf_addr_i} << 2) & napot_mask;

  always_comb begin
    a_off_never_match : assert (!(conf_addr_mode_i == riscv::OFF) || !match_o);
    a_na4_never_match : assert (!(conf_addr_mode_i == riscv::NA4) || !match_o);
    a_tor_exact :
    assert (!(conf_addr_mode_i == riscv::TOR) ||
        (match_o == ((addr_i >= tor_lo) && (addr_i < tor_hi))));
    a_napot_exact :
    assert (!(conf_addr_mode_i == riscv::NAPOT) ||
        (match_o == ((addr_i & napot_mask) == napot_base)));
    a_tor_lo_inclusive :
    assert (!(conf_addr_mode_i == riscv::TOR && (tor_lo < tor_hi) && addr_i == tor_lo) || match_o);
    a_tor_hi_exclusive : assert (!(conf_addr_mode_i == riscv::TOR && addr_i == tor_hi) || !match_o);
  end

  always_comb begin
    c_tor_match : cover (conf_addr_mode_i == riscv::TOR && match_o);
    c_napot_match : cover (conf_addr_mode_i == riscv::NAPOT && match_o);
    c_off_seen : cover (conf_addr_mode_i == riscv::OFF);
  end
endmodule
