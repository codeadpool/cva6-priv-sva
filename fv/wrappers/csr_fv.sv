// formal top for csr_regfile: free inputs are module ports (shared PIs),
// reset is a structural one-shot, checkers attach via csr_*_bind.sv.
`include "rvfi_types.svh"

module csr_fv
  import ariane_pkg::*;
  import riscv::*;
#(
    parameter config_pkg::cva6_cfg_t Cfg = build_config_pkg::build_config(
        cva6_config_pkg::cva6_cfg
    ),

    localparam type exception_t = struct packed {
      logic [Cfg.XLEN-1:0]  cause;
      logic [Cfg.XLEN-1:0]  tval;
      logic [Cfg.GPLEN-1:0] tval2;
      logic [31:0]          tinst;
      logic                 gva;
      logic                 valid;
    },  // cva6.sv:42

    localparam type jvt_t = struct packed {
      logic [Cfg.XLEN-7:0] base;
      logic [5:0]          mode;
    },  // cva6.sv:90

    localparam type irq_ctrl_t = struct packed {
      logic [Cfg.XLEN-1:0] mie;
      logic [Cfg.XLEN-1:0] mip;
      logic [Cfg.XLEN-1:0] mideleg;
      logic [Cfg.XLEN-1:0] hideleg;
      logic                sie;
      logic                global_enable;
    },  // cva6.sv:145


    localparam type branchpredict_sbe_t = struct packed {
      cf_t                 cf;               // type of control flow prediction
      logic [Cfg.VLEN-1:0] predict_address;  // target address at which to jump, or not
    },

    localparam type scoreboard_entry_t = struct packed {
      logic [Cfg.VLEN-1:0]          pc;
      logic [Cfg.TRANS_ID_BITS-1:0] trans_id;
      fu_t                          fu;
      fu_op                         op;
      logic [REG_ADDR_SIZE-1:0]     rs1;
      logic [REG_ADDR_SIZE-1:0]     rs2;
      logic [REG_ADDR_SIZE-1:0]     rd;
      logic [Cfg.XLEN-1:0]          result;
      logic                         valid;
      logic                         use_imm;
      logic                         use_zimm;
      logic                         use_pc;
      exception_t                   ex;
      branchpredict_sbe_t           bp;
      logic                         is_compressed;
      logic                         is_macro_instr;
      logic                         is_last_macro_instr;
      logic                         is_double_rd_macro_instr;
      logic                         vfp;
      logic                         is_zcmt;
    },  // cva6.sv:96

    localparam type rvfi_probes_csr_t = `RVFI_PROBES_CSR_T(Cfg)  // cva6.sv:28
) (
    input logic                                      clk,
    input logic                                      time_irq_i,
    input scoreboard_entry_t                         commit_instr_i,
    input logic              [Cfg.NrCommitPorts-1:0] commit_ack_i,
    input logic              [         Cfg.VLEN-1:0] boot_addr_i,
    input logic              [         Cfg.XLEN-1:0] hart_id_i,
    input exception_t                                ex_i,
    input fu_op                                      csr_op_i,
    input logic              [                 11:0] csr_addr_i,
    input logic              [         Cfg.XLEN-1:0] csr_wdata_i,
    input logic                                      dirty_fp_state_i,
    input logic                                      csr_write_fflags_i,
    input logic                                      dirty_v_state_i,
    input logic              [         Cfg.VLEN-1:0] pc_i,
    input logic              [                  4:0] acc_fflags_ex_i,
    input logic                                      acc_fflags_ex_valid_i,
    input logic                                      csr_hs_ld_st_inst_i,
    input logic              [         Cfg.XLEN-1:0] perf_data_i,
    input logic              [                  1:0] irq_i,
    input logic                                      ipi_i,
    input logic                                      debug_req_i
);
  // one-shot reset: low at cycle 0, high forever; checkers gate on past_valid
  logic rst_done = 1'b0;
  always_ff @(posedge clk) rst_done <= 1'b1;

  csr_regfile #(
      .CVA6Cfg           (Cfg),
      .exception_t       (exception_t),
      .jvt_t             (jvt_t),
      .irq_ctrl_t        (irq_ctrl_t),
      .scoreboard_entry_t(scoreboard_entry_t),
      .rvfi_probes_csr_t (rvfi_probes_csr_t),
      .MHPMCounterNum    (ariane_pkg::MHPMCounterNum)
  ) dut (
      .clk_i                (clk),
      .rst_ni               (rst_done),
      .time_irq_i           (time_irq_i),
      .commit_instr_i       (commit_instr_i),
      .commit_ack_i         (commit_ack_i),
      .boot_addr_i          (boot_addr_i),
      .hart_id_i            (hart_id_i),
      .ex_i                 (ex_i),
      .csr_op_i             (csr_op_i),
      .csr_addr_i           (csr_addr_i),
      .csr_wdata_i          (csr_wdata_i),
      .dirty_fp_state_i     (dirty_fp_state_i),
      .csr_write_fflags_i   (csr_write_fflags_i),
      .dirty_v_state_i      (dirty_v_state_i),
      .pc_i                 (pc_i),
      .acc_fflags_ex_i      (acc_fflags_ex_i),
      .acc_fflags_ex_valid_i(acc_fflags_ex_valid_i),
      .csr_hs_ld_st_inst_i  (csr_hs_ld_st_inst_i),
      .perf_data_i          (perf_data_i),
      .irq_i                (irq_i),
      .ipi_i                (ipi_i),
      .debug_req_i          (debug_req_i)
  );
endmodule
