bind csr_regfile dcsr_vlegal_sva #(
    .CVA6Cfg(CVA6Cfg)
) i_dcsr_vlegal_sva (
    .clk_i     (clk_i),
    .rst_ni    (rst_ni),
    .dcsr_prv  (dcsr_q.prv),
    .dcsr_v    (dcsr_q.v),
    .priv_lvl  (priv_lvl_q),
    .op_v      (v_q),
    .dcsr_wr   (csr_we && (conv_csr_addr.address == riscv::CSR_DCSR)),
    .debug_mode(debug_mode_q),
    .dret_i    (dret)
);
