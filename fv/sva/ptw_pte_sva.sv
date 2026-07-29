// PTE legality on the page walk: a non-leaf PTE must not carry A/D/U (VM-4)
module ptw_pte_sva (
    input logic clk_i,
    input logic rst_ni,
    input logic consuming_pte,    // PTE_LOOKUP + rvalid, no flush, PMP allowed
    input logic pte_wellformed,   // survives the invalid-PTE predicate
    input logic pte_non_leaf,     // !r && !x: a pointer to the next level
    input logic pte_adu,          // a | d | u: reserved on a non-leaf PTE
    input logic pte_can_descend,  // not already at the last level
    input logic to_error,         // state_d == PROPAGATE_ERROR
    input logic walk_continues    // state_d == WAIT_GRANT
);
  // pte_can_descend excludes the last level, where a non-leaf PTE already
  // faults for an unrelated reason. without it the antecedent could be
  // witnessed by that already correct path rather than the descent path
  logic bad_nonleaf;
  assign bad_nonleaf = consuming_pte && pte_wellformed && pte_non_leaf && pte_adu
                       && pte_can_descend;

  always_ff @(posedge clk_i)
    if (rst_ni) begin
      // VM-4: a reserved non-leaf encoding raises a page fault
      a_nonleaf_adu_faults : assert (!bad_nonleaf || to_error);
      // VM-4: and the walker never advances past it
      a_nonleaf_adu_no_walk : assert (!bad_nonleaf || !walk_continues);
    end

  always_ff @(posedge clk_i)
    if (rst_ni)
      // reachability, violation is witnessed by the baseline assertion cex; its absence after
      // the fix follows from the unbounded proof, not from a bounded cover.
      c_nonleaf_adu_seen :
      cover (bad_nonleaf);
endmodule
