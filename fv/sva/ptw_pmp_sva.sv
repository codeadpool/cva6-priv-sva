// MMU<->PMP: page-walker honours PMP on each PTE fetch, checker for cva6_ptw.
module ptw_pmp_sva (
    input logic clk_i,
    input logic rst_ni,
    input logic in_access_err,  // state_q == PROPAGATE_ACCESS_ERROR
    input logic allow_access,   // PMP result for the current PTE pointer
    input logic acc_exc,        // ptw_access_exception_o
    input logic tlb_valid       // shared_tlb_update_o.valid
);
  logic past_valid;
  always_ff @(posedge clk_i)
    if (!rst_ni) past_valid <= 1'b0;
    else past_valid <= 1'b1;

  logic allow_access_q;
  always_ff @(posedge clk_i) allow_access_q <= allow_access;

  always_ff @(posedge clk_i)
    if (rst_ni) begin
      // VM-3: a PMP access exception never fills the TLB
      a_acc_exc_no_fill : assert (!acc_exc || !tlb_valid);
      // VM-1: the access-error state raises ptw_access_exception
      a_acc_err_raises : assert (!in_access_err || acc_exc);
      // VM-3: a PMP-denied PTE fetch never fills the TLB
      a_deny_no_fill : assert (allow_access || !tlb_valid);
    end

  always_ff @(posedge clk_i)
    if (rst_ni && past_valid)
      // VM-1: the access-error state is only reached after a PMP deny
      a_acc_err_from_deny :
      assert (!in_access_err || !allow_access_q);

  always_ff @(posedge clk_i)
    if (rst_ni) begin
      // reachability, so the VM asserts are not vacuous
      c_acc_err_seen : cover (in_access_err);
      c_tlb_fill_seen : cover (tlb_valid);
    end
endmodule
