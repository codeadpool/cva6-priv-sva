// revision-neutral: state_q/WAIT_GRANT, allow_access and req_port_o.data_req
// all exist unchanged on v5.3.0 and on upstream master, so serves both
bind cva6_ptw ptw_pmp_req_sva i_ptw_pmp_req_sva (
    .clk_i        (clk_i),
    .rst_ni       (rst_ni),
    .in_wait_grant(state_q == WAIT_GRANT),
    .allow_access (allow_access),
    .ptw_req      (req_port_o.data_req)
);
