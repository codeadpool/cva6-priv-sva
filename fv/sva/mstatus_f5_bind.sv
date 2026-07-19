// bind the F5 probe into csr_regfile.
bind csr_regfile mstatus_f5_sva #(
    .CVA6Cfg(CVA6Cfg)
) i_mstatus_f5_sva (
    .clk_i       (clk_i),
    .rst_ni      (rst_ni),
    .trap_to_priv(trap_to_priv_lvl),
    .mret_i      (mret),
    .sret_i      (sret),
    .debug_mode  (debug_mode_q),
    .mtval       (mtval_q),
    .stval       (stval_q),
    .ex_valid    (ex_i.valid),
    .ex_cause    (ex_i.cause),
    .ex_tval     (ex_i.tval)
);
