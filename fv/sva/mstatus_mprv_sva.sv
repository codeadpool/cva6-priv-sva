module mstatus_mprv_sva #(
    parameter config_pkg::cva6_cfg_t CVA6Cfg = config_pkg::cva6_cfg_empty
) (
    input logic             clk_i,
    input logic             rst_ni,
    input riscv::priv_lvl_t mst_mpp,     // mstatus_q.mpp
    input logic             mst_mprv,    // mstatus_q.mprv
    input logic             mret_i,      // mret
    input logic             sret_i,      // sret
    input logic             debug_mode,  // debug_mode_q
    input logic             ex_valid     // ex_i.valid
);
  logic past_valid;
  always_ff @(posedge clk_i)
    if (!rst_ni) past_valid <= 1'b0;
    else past_valid <= 1'b1;

  // xret with MPRV set, returning to a mode below M
  logic ante_mretU, ante_sret;
  assign ante_mretU = mret_i && !ex_valid && !debug_mode && mst_mprv
                      && (mst_mpp != riscv::PRIV_LVL_M);
  assign ante_sret = sret_i && !ex_valid && !debug_mode && mst_mprv;

  logic ante_mretU_q, ante_sret_q;
  always_ff @(posedge clk_i)
    if (!rst_ni) begin
      ante_mretU_q <= 1'b0;
      ante_sret_q  <= 1'b0;
    end else begin
      ante_mretU_q <= ante_mretU;
      ante_sret_q  <= ante_sret;
    end

  always_ff @(posedge clk_i)
    if (rst_ni && past_valid) begin
      a_mret_clears_mprv : assert (!ante_mretU_q || !mst_mprv);
      a_sret_clears_mprv : assert (!ante_sret_q || !mst_mprv);
    end

  always_ff @(posedge clk_i)
    if (rst_ni) begin
      c_mretU_mprv1 : cover (ante_mretU);
      c_sret_mprv1 : cover (ante_sret);
    end
endmodule
