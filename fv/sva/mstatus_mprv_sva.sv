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
  logic ante_mret_u, ante_sret;
  assign ante_mret_u = mret_i && !ex_valid && !debug_mode && mst_mprv
                      && (mst_mpp != riscv::PRIV_LVL_M);
  assign ante_sret = sret_i && !ex_valid && !debug_mode && mst_mprv;

  logic ante_mret_u_q, ante_sret_q;
  always_ff @(posedge clk_i)
    if (!rst_ni) begin
      ante_mret_u_q <= 1'b0;
      ante_sret_q   <= 1'b0;
    end else begin
      ante_mret_u_q <= ante_mret_u;
      ante_sret_q   <= ante_sret;
    end

  always_ff @(posedge clk_i)
    if (rst_ni && past_valid) begin
      // F6 (MST-7) probe: mret to a mode below M must clear mstatus.MPRV.
      // expected CEX, corroborates known-open upstream #3294/#1981.
      a_mret_clears_mprv : assert (!ante_mret_u_q || !mst_mprv);
      // F6 (MST-7) probe: sret returning below M must also clear MPRV
      a_sret_clears_mprv : assert (!ante_sret_q || !mst_mprv);
    end

  always_ff @(posedge clk_i)
    if (rst_ni) begin
      // antecedent reachability: xret below M with MPRV set
      c_mret_u_mprv1 : cover (ante_mret_u);
      c_sret_mprv1 : cover (ante_sret);
    end
endmodule
