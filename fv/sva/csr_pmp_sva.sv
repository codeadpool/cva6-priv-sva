// PMP-CSR WARL invariants, bound into csr_regfile.
module csr_pmp_sva #(
    parameter config_pkg::cva6_cfg_t CVA6Cfg = config_pkg::cva6_cfg_empty
) (
    input logic clk_i,
    input logic rst_ni,
    input riscv::pmpcfg_t [63:0] pmpcfg_q,
    input logic [63:0][CVA6Cfg.PLEN-3:0] pmpaddr_q,
    input logic [11:0] csr_addr_i,
    input logic csr_read,
    input logic [CVA6Cfg.XLEN-1:0] csr_rdata
);
  logic past_valid;
  always_ff @(posedge clk_i)
    if (!rst_ni) past_valid <= 1'b0;
    else past_valid <= 1'b1;

  for (genvar i = 0; i < CVA6Cfg.NrPMPEntries; i++) begin : gen_warl
    always_ff @(posedge clk_i)
      if (rst_ni) begin
        // CSR-1: NA4 is never a stored mode (write reverts at G=1(grain))
        a_never_na4 : assert (pmpcfg_q[i].addr_mode != riscv::NA4);
        // CSR-3: the reserved R=0,W=1 encoding is never stored
        a_never_r0w1 :
        assert (!(pmpcfg_q[i].access_type.r == 1'b0 && pmpcfg_q[i].access_type.w == 1'b1));
        // CSR-6: pmpcfg reserved bits read 0
        a_reserved_zero : assert (pmpcfg_q[i].reserved == 2'b0);
      end

    riscv::pmpcfg_t                    pmpcfg_q1;
    logic           [CVA6Cfg.PLEN-3:0] pmpaddr_q1;
    always_ff @(posedge clk_i) begin
      pmpcfg_q1  <= pmpcfg_q[i];
      pmpaddr_q1 <= pmpaddr_q[i];
    end

    always_ff @(posedge clk_i)
      if (rst_ni && past_valid && pmpcfg_q1.locked) begin
        // CSR-4: a locked entry's cfg and addr cannot change
        a_locked_cfg_stable : assert (pmpcfg_q[i] == pmpcfg_q1);
        a_locked_addr_stable : assert (pmpaddr_q[i] == pmpaddr_q1);
      end

    always_ff @(posedge clk_i) if (rst_ni) c_locked_seen : cover (pmpcfg_q[i].locked);
  end

  // CSR-5: a locked TOR entry write-protects the pmpaddr below it (csr:1737)
  for (genvar i = 0; i < CVA6Cfg.NrPMPEntries - 1; i++) begin : gen_tor_shield
    logic [CVA6Cfg.PLEN-3:0] addr_q1;
    logic shield_q1;
    always_ff @(posedge clk_i) begin
      addr_q1   <= pmpaddr_q[i];
      shield_q1 <= pmpcfg_q[i+1].locked && pmpcfg_q[i+1].addr_mode == riscv::TOR;
    end
    always_ff @(posedge clk_i)
      if (rst_ni && past_valid && shield_q1)
        // CSR-5: the pmpaddr below a locked TOR entry is frozen
        a_tor_shield_below :
        assert (pmpaddr_q[i] == addr_q1);
    always_ff @(posedge clk_i)
      if (rst_ni)
        c_tor_shield_seen : cover (pmpcfg_q[i+1].locked && pmpcfg_q[i+1].addr_mode == riscv::TOR);
  end

  // CSR-2: G=1 readback. pmpaddr[0] reads addr_mode[1] (csr:862-868).
  // conv_csr_addr == csr_addr_i with RVH=0 (csr:305-307).
  localparam logic [11:0] PmpAddrBase = riscv::CSR_PMPADDR0;
  logic pmpaddr_rd;
  logic [11:0] rd_idx;
  assign rd_idx = csr_addr_i - PmpAddrBase;
  assign pmpaddr_rd = csr_read && csr_addr_i >= PmpAddrBase
      && csr_addr_i < PmpAddrBase + 12'(CVA6Cfg.NrPMPEntries);
  always_comb
    if (pmpaddr_rd) begin
      // CSR-2: bit 0 reads 1 for NAPOT, 0 for OFF/TOR (the G=1 grain bit)
      a_pmpaddr_g_bit : assert (csr_rdata[0] == pmpcfg_q[rd_idx].addr_mode[1]);
      // CSR-2: the bits above the grain read back the stored address
      a_pmpaddr_body : assert (csr_rdata[CVA6Cfg.PLEN-3:1] == pmpaddr_q[rd_idx][CVA6Cfg.PLEN-3:1]);
    end
  always_comb begin
    c_pmpaddr_rd_napot : cover (pmpaddr_rd && pmpcfg_q[rd_idx].addr_mode == riscv::NAPOT);
    c_pmpaddr_rd_tor : cover (pmpaddr_rd && pmpcfg_q[rd_idx].addr_mode == riscv::TOR);
  end
endmodule
