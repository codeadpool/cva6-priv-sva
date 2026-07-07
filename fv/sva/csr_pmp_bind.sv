bind csr_regfile csr_pmp_sva #(
    .CVA6Cfg(CVA6Cfg)
) i_csr_pmp_sva (
    .clk_i   (clk_i),
    .rst_ni  (rst_ni),
    .pmpcfg_q(pmpcfg_q),
    .pmpaddr_q(pmpaddr_q),
    .csr_addr_i(csr_addr_i),
    .csr_read(csr_read),
    .csr_rdata(csr_rdata)
);
