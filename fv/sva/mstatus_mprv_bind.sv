bind csr_regfile mstatus_mprv_sva #(
    .CVA6Cfg(CVA6Cfg)
) i_mstatus_mprv_sva (
    .clk_i     (clk_i),
    .rst_ni    (rst_ni),
    .mst_mpp   (mstatus_q.mpp),
    .mst_mprv  (mstatus_q.mprv),
    .mret_i    (mret),
    .sret_i    (sret),
    .debug_mode(debug_mode_q),
    .ex_valid  (ex_i.valid)
);
