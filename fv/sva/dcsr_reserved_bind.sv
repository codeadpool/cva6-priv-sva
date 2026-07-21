bind csr_regfile dcsr_reserved_sva #(
    .CVA6Cfg(CVA6Cfg)
) i_dcsr_reserved_sva (
    .clk_i     (clk_i),
    .rst_ni    (rst_ni),
    .dcsr_zero1(dcsr_q.zero1),
    .dcsr_zero2(dcsr_q.zero2),
    .dcsr_cause(dcsr_q.cause),
    .dcsr_sw_wr(csr_we && (conv_csr_addr.address == riscv::CSR_DCSR)),
    .debug_mode(debug_mode_q)
);
