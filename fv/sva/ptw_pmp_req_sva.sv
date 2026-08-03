// MMU<->PMP: a PMP-denied PTE address must never be requested on the memory
// interface, not merely faulted after the data comes back (VM-5)
module ptw_pmp_req_sva (
    input logic clk_i,
    input logic rst_ni,
    input logic in_wait_grant,  // state_q == WAIT_GRANT, the request cycle
    input logic allow_access,   // PMP verdict for ptw_pptr_q
    input logic ptw_req         // req_port_o.data_req
);
  // allow_access is combinational on ptw_pptr_q, the same address the request
  // drives onto address_index/address_tag, so it is this request's verdict and
  // it is already available in this cycle
  logic denied_req;
  assign denied_req = in_wait_grant && !allow_access;

  always_ff @(posedge clk_i)
    if (rst_ni)
      // VM-5: PMP denies the PTE read => the walker never issues it
      a_no_req_when_denied :
      assert (!denied_req || !ptw_req);

  always_ff @(posedge clk_i)
    if (rst_ni)
      // reachability. stays reachable after a fix that gates the request: the
      // walk still reaches WAIT_GRANT with a denied address, only the verdict
      // is enforced there instead of after the data returns
      c_wait_grant_denied :
      cover (denied_req);
endmodule
