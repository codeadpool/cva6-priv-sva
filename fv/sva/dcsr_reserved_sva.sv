// #1984 FIX-CERTIFICATION probe NOT an original finding. dcsr.v and the DCSR
// reserved fields were reported upstream as #1984 before this work; this probe
// exists to machine-check our fix not to claim the defect.
// Debug spec v1.0: DCSR reserved fields are read-only zero, CSR_DCSR write
// path assigns whole word from csr_wdata and legalizes only some fields, so
// zero1 (bit 14) and zero2 (bits 27:18) stay software-writable.
// Expected CEX on the golden RTL,proves after the reserved-field fix (PR #3387)
module dcsr_reserved_sva #(
    parameter config_pkg::cva6_cfg_t CVA6Cfg = config_pkg::cva6_cfg_empty
) (
    input logic       clk_i,
    input logic       rst_ni,
    input logic       dcsr_zero1,  // dcsr_q.zero1 (bit 14)
    input logic [9:0] dcsr_zero2,  // dcsr_q.zero2 (bits 27:18)
    input logic       debug_mode   // debug_mode_q
);
  logic reserved_zero;
  assign reserved_zero = (dcsr_zero1 == 1'b0) && (dcsr_zero2 == '0);

  // DCSR reserved fields read as zero
  always_ff @(posedge clk_i) if (rst_ni) a_dcsr_reserved_zero : assert (reserved_zero);

  always_ff @(posedge clk_i)
    if (rst_ni) begin
      // debug entry is required to write dcsr at all
      c_debug_mode_seen : cover (debug_mode);
      // witness: a reserved field actually holds a nonzero value. Reachable on
      // the golden RTL (the defect); unreachable after the fix: that transition
      // from reachable to unreachable is what certifes it.
      c_reserved_nonzero : cover (!reserved_zero);
    end
endmodule
