bind csr_regfile mpp_legal_sva #(
    .CVA6Cfg(CVA6Cfg)
) i_mpp_legal_sva (
    .clk_i     (clk_i),
    .rst_ni    (rst_ni),
    .mst_mpp   (mstatus_q.mpp),
    .priv_lvl  (priv_lvl_q),
    .ld_st_priv(ld_st_priv_lvl_o),
    .mret_i    (mret),
    .mprv_i    (mprv)
);
