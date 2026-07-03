bind csr_regfile csr_priv_sva #(
    .CVA6Cfg(CVA6Cfg)
) i_csr_priv_sva (
    .clk_i       (clk_i),
    .rst_ni      (rst_ni),
    .priv_lvl    (priv_lvl_q),
    .mst_mie     (mstatus_q.mie),
    .mst_mpie    (mstatus_q.mpie),
    .mst_mpp     (mstatus_q.mpp),
    .mst_sie     (mstatus_q.sie),
    .mst_spie    (mstatus_q.spie),
    .mst_spp     (mstatus_q.spp),
    .trap_to_priv(trap_to_priv_lvl),
    .mret_i      (mret),
    .sret_i      (sret),
    .debug_mode  (debug_mode_q),
    .medeleg     (medeleg_q),
    .ex_valid    (ex_i.valid),
    .ex_cause    (ex_i.cause)
);
