bind cva6_ptw ptw_pte_sva i_ptw_pte_sva (
    .clk_i(clk_i),
    .rst_ni(rst_ni),
    .consuming_pte(state_q == PTE_LOOKUP && data_rvalid_q && !flush_i && allow_access),
    .pte_wellformed(!(!pte.v || (!pte.r && pte.w) || (|pte.reserved && CVA6Cfg.IS_XLEN64)
                      || (!CVA6Cfg.SvnapotEn && pte.n)
                      || (CVA6Cfg.SvnapotEn && !(pte.r || pte.x) && pte.n))),
    .pte_non_leaf(!pte.r && !pte.x),
    .pte_adu(pte.a || pte.d || pte.u),
    .pte_can_descend(ptw_lvl_q[0] != CVA6Cfg.PtLevels - 1),
    .to_error(state_d == PROPAGATE_ERROR),
    .walk_continues(state_d == WAIT_GRANT)
);
