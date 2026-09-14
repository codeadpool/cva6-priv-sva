// Named-port shim for the Sail 0.12 leaf helpers used by sail_leaf_fv.
// 0.14 differs only in two generated port names: sail_leaf_shim_0_14.sv.
module sail_leaf_match (
    input  logic          [55:0] addr,
    input  logic          [63:0] width,
    input  t_Pmpcfg_ent          cfg,
    input  logic          [63:0] pmpaddr,
    input  logic          [63:0] prev,
    output t_pmpAddrMatch        m,
    output bit                   exc
);
  t_exception cur;
  pmpMatchAddr u (
      .z3zE70_0              (addr),
      .width_0               (width),
      .ent_0                 (cfg),
      .pmpaddr_0             (pmpaddr),
      .prev_pmpaddr_0        (prev),
      .zassert_reachablez3   (1'b1),
      .sail_return_1         (m),
      .sail_have_exception   (exc),
      .sail_current_exception(cur)
  );
endmodule

module sail_leaf_rwx (
    input  t_Pmpcfg_ent                          cfg,
    input  t_zMemoryAccessTypezIEmem_payloadz5zK access,
    output bit                                   ok,
    output bit                                   exc
);
  t_exception cur;
  pmpCheckRWX u (
      .ent_0                   (cfg),
      .access_0                (access),
      .sail_return_2           (ok),
      .sail_have_exception_6   (exc),
      .sail_current_exception_6(cur)
  );
endmodule
