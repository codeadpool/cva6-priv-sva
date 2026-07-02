// PMP-CSR WARL invariants, bound into csr_regfile.
module csr_pmp_sva #(
    parameter config_pkg::cva6_cfg_t CVA6Cfg = config_pkg::cva6_cfg_empty
) (
    input logic clk_i,
    input logic rst_ni,
    input riscv::pmpcfg_t [63:0] pmpcfg_q,
    input logic [63:0][CVA6Cfg.PLEN-3:0] pmpaddr_q
);
  logic past_valid;
  always_ff @(posedge clk_i)
    if (!rst_ni) past_valid <= 1'b0;
    else past_valid <= 1'b1;

  for (genvar i = 0; i < CVA6Cfg.NrPMPEntries; i++) begin : gen_warl
    always_ff @(posedge clk_i)
      if (rst_ni) begin
        a_never_na4 : assert (pmpcfg_q[i].addr_mode != riscv::NA4);
        a_never_r0w1 :
        assert (!(pmpcfg_q[i].access_type.r == 1'b0 && pmpcfg_q[i].access_type.w == 1'b1));
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
        a_locked_cfg_stable : assert (pmpcfg_q[i] == pmpcfg_q1);
        a_locked_addr_stable : assert (pmpaddr_q[i] == pmpaddr_q1);
      end

    always_ff @(posedge clk_i) if (rst_ni) c_locked_seen : cover (pmpcfg_q[i].locked);
  end
endmodule
