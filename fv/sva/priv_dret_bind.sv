bind csr_regfile priv_dret_sva #(
    .CVA6Cfg(CVA6Cfg)
) i_priv_dret_sva (
    .clk_i        (clk_i),
    .rst_ni       (rst_ni),
    .priv_lvl     (priv_lvl_q),
    .dcsr_prv     (dcsr_q.prv),
    .dret_i       (dret),
    .debug_mode   (debug_mode_q),
    .csr_we       (csr_we),
    .csr_addr     (conv_csr_addr.address),
    .csr_wdata_prv(csr_wdata[1:0])
);
