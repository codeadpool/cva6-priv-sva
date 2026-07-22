// #1984 / #1985 FIX-CERTIFICATION probe (NOT an original finding): reserved
// DCSR fields and dcsr.cause were reported upstream before this work. Golden
// writes the whole dcsr word from csr_wdata, so zero1/zero2 (#1984) and cause
// (#1985) stay software writable. Expected CEX on golden, proves after #3387.
module dcsr_reserved_sva #(
    parameter config_pkg::cva6_cfg_t CVA6Cfg = config_pkg::cva6_cfg_empty
) (
    input logic       clk_i,
    input logic       rst_ni,
    input logic       dcsr_zero1,  // dcsr_q.zero1 (bit 14)
    input logic [9:0] dcsr_zero2,  // dcsr_q.zero2 (bits 27:18)
    input logic [2:0] dcsr_cause,  // dcsr_q.cause (bits 8:6)
    input logic       dcsr_sw_wr,  // csr_we & addr==CSR_DCSR: a software dcsr write
    input logic       debug_mode   // debug_mode_q
);
  logic reserved_zero;
  assign reserved_zero = (dcsr_zero1 == 1'b0) && (dcsr_zero2 == '0);

  // #1984: reserved fields read zero
  always_ff @(posedge clk_i) if (rst_ni) a_dcsr_reserved_zero : assert (reserved_zero);

  // #1985: a software dcsr write cannot change cause (hardware written only).
  // Guarded by debug_mode, which isolates it from the debug-entry cause-write
  // (that runs only when !debug_mode_q).
  logic       past_valid;
  logic [2:0] cause_q1;
  logic       sw_wr_indebug_q;
  always_ff @(posedge clk_i)
    if (!rst_ni) begin
      past_valid      <= 1'b0;
      sw_wr_indebug_q <= 1'b0;
      cause_q1        <= '0;
    end else begin
      past_valid      <= 1'b1;
      sw_wr_indebug_q <= dcsr_sw_wr && debug_mode;  // sw wrote dcsr in debug
      cause_q1        <= dcsr_cause;  // cause before that write
    end

  always_ff @(posedge clk_i)
    if (rst_ni && past_valid)
      a_dcsr_cause_preserved : assert (!sw_wr_indebug_q || (dcsr_cause == cause_q1));

  always_ff @(posedge clk_i)
    if (rst_ni) begin
      c_debug_mode_seen : cover (debug_mode);
      c_reserved_nonzero : cover (!reserved_zero);  // defect: reserved nonzero
      c_dcsr_sw_write : cover (dcsr_sw_wr && debug_mode);
      c_cause_changed : cover (sw_wr_indebug_q && dcsr_cause != cause_q1);  // defect: cause changed
    end
endmodule
