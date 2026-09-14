// Section 3.1 properties (evidence/sail/TIER1_PROTOCOL.md): Sail's per-slot
// match vs the same match with the predecessor's bit 0 cleared, and pmpCheck's
// first-match decision over both.
module sail_leaf_sva (
    input logic                      m_mode,
    input t_pmpAddrMatch [15:0]      m_sail,
    input t_pmpAddrMatch [15:0]      m_arch,
    input logic          [15:0]      rwx,
    input logic          [15:0]      locked,
    input logic          [15:0][1:0] mode,
    input logic          [15:0]      raw0,
    input logic                      sail_allow,
    input logic                      top_exc,
    input logic          [15:0]      helper_exc,
    input logic          [55:0]      addr,
    input logic          [12:0]      width
);
  localparam logic [1:0] TOR = 2'b01, NAPOT = 2'b11;

  // pmpCheck's loop: the first slot that is not NoMatch decides
  logic dec_sail, dec_arch, done_sail, done_arch;
  always_comb begin
    dec_sail  = m_mode;
    dec_arch  = m_mode;
    done_sail = 1'b0;
    done_arch = 1'b0;
    for (int i = 0; i < 16; i++) begin
      if (!done_sail && m_sail[i] != PMP_NoMatch) begin
        done_sail = 1'b1;
        dec_sail  = m_sail[i] == PMP_Match && (rwx[i] || (m_mode && !locked[i]));
      end
      if (!done_arch && m_arch[i] != PMP_NoMatch) begin
        done_arch = 1'b1;
        dec_arch  = m_arch[i] == PMP_Match && (rwx[i] || (m_mode && !locked[i]));
      end
    end
  end

  // the CVA6 miter's domain: width 1, 2, 4 or 8, naturally aligned
  logic c2;
  assign c2 = (width == 13'd1 || width == 13'd2 || width == 13'd4 || width == 13'd8)
           && (addr[12:0] & (width - 13'd1)) == 13'd0;

  logic [15:0] diff;
  logic aligned4, partial;
  always_comb begin
    aligned4 = 1'b0;
    partial  = 1'b0;
    for (int i = 0; i < 16; i++) diff[i] = m_sail[i] != m_arch[i];
    for (int i = 1; i < 16; i++) begin
      aligned4 |= width == 13'd4 && addr[1:0] == 2'b00 && m_sail[i] == PMP_NoMatch
               && m_arch[i] == PMP_Match && m_sail[i-1] == PMP_Match;
      partial |= diff[i] && m_sail[i-1] == PMP_PartialMatch;
    end
  end

  always_comb begin
    a_decide_faithful : assert (dec_sail == sail_allow);
    a_leaf_unobservable : assert (dec_arch == dec_sail);
    a_top_no_internal_exception : assert (!top_exc);
    a_helpers_no_internal_exception : assert (helper_exc == '0);
    c_leaf_diff_aligned4 : cover (aligned4);
    c_leaf_diff_partial : cover (partial);
  end

  for (genvar i = 1; i < 16; i++) begin : gen_leaf
    always_comb begin
      a_leaf_shape : assert (!diff[i] || (mode[i] == TOR && mode[i-1] == NAPOT && raw0[i-1]));
      a_leaf_preempted :
      assert (!diff[i] || (m_sail[i-1] != PMP_NoMatch && m_sail[i-1] == m_arch[i-1]));
      a_partial_outside_c2_domain : assert (!(diff[i] && m_sail[i-1] == PMP_PartialMatch) || !c2);
    end
  end
endmodule
