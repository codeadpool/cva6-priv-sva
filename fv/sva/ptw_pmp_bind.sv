bind cva6_ptw ptw_pmp_sva i_ptw_pmp_sva (
    .clk_i        (clk_i),
    .rst_ni       (rst_ni),
    .in_access_err(state_q == PROPAGATE_ACCESS_ERROR),
    .allow_access (allow_access),
    .acc_exc      (ptw_access_exception_o),
    .tlb_valid    (shared_tlb_update_o.valid)
);
