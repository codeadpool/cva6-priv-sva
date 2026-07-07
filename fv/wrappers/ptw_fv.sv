// formal top for cva6_ptw: free inputs are module ports (shared PIs),
// Types reproduced verbatim: pte/tlb_update from cva6_mmu.sv:108-131,
// dcache req from cva6.sv:198-224. HYP_EXT=0 (RVH=0, cva6_mmu.sv:36).
module ptw_fv
  import ariane_pkg::*;
#(
    parameter config_pkg::cva6_cfg_t Cfg = build_config_pkg::build_config(
        cva6_config_pkg::cva6_cfg
    ),
    parameter int unsigned N = (Cfg.NrPMPEntries > 0 ? Cfg.NrPMPEntries : 1),
    localparam int unsigned HYP_EXT = 0,

    localparam type pte_cva6_t = struct packed {
      logic [9:0]          reserved;
      logic [Cfg.PPNW-1:0] ppn;
      logic [1:0]          rsw;
      logic                d;
      logic                a;
      logic                g;
      logic                u;
      logic                x;
      logic                w;
      logic                r;
      logic                v;
    },  // cva6_mmu.sv:108

    localparam type tlb_update_cva6_t = struct packed {
      logic                               valid;
      logic [Cfg.PtLevels-2:0][HYP_EXT:0] is_page;
      logic [Cfg.VpnLen-1:0]              vpn;
      logic [Cfg.ASID_WIDTH-1:0]          asid;
      logic [Cfg.VMID_WIDTH-1:0]          vmid;
      logic [HYP_EXT*2:0]                 v_st_enbl;
      pte_cva6_t                          content;
      pte_cva6_t                          g_content;
    },  // cva6_mmu.sv:122

    localparam type dcache_req_i_t = struct packed {
      logic [Cfg.DCACHE_INDEX_WIDTH-1:0] address_index;
      logic [Cfg.DCACHE_TAG_WIDTH-1:0]   address_tag;
      logic [Cfg.XLEN-1:0]               data_wdata;
      logic [Cfg.DCACHE_USER_WIDTH-1:0]  data_wuser;
      logic                              data_req;
      logic                              data_we;
      logic [(Cfg.XLEN/8)-1:0]           data_be;
      logic [1:0]                        data_size;
      logic [Cfg.DcacheIdWidth-1:0]      data_id;
      logic                              kill_req;
      logic                              tag_valid;
    },  // cva6.sv:198

    localparam type dcache_req_o_t = struct packed {
      logic                             data_gnt;
      logic                             data_rvalid;
      logic [Cfg.DcacheIdWidth-1:0]     data_rid;
      logic [Cfg.XLEN-1:0]              data_rdata;
      logic [Cfg.DCACHE_USER_WIDTH-1:0] data_ruser;
    }  // cva6.sv:212
) (
    input logic clk,
    input logic flush_i,
    input logic enable_translation_i,
    input logic enable_g_translation_i,
    input logic en_ld_st_translation_i,
    input logic en_ld_st_g_translation_i,
    input logic v_i,
    input logic ld_st_v_i,
    input logic hlvx_inst_i,
    input logic lsu_is_store_i,
    input dcache_req_o_t req_port_i,
    input logic [Cfg.ASID_WIDTH-1:0] asid_i,
    input logic [Cfg.ASID_WIDTH-1:0] vs_asid_i,
    input logic [Cfg.VMID_WIDTH-1:0] vmid_i,
    input logic shared_tlb_access_i,
    input logic shared_tlb_hit_i,
    input logic [Cfg.VLEN-1:0] shared_tlb_vaddr_i,
    input logic itlb_req_i,
    input logic [Cfg.PPNW-1:0] satp_ppn_i,
    input logic [Cfg.PPNW-1:0] vsatp_ppn_i,
    input logic [Cfg.PPNW-1:0] hgatp_ppn_i,
    input logic mxr_i,
    input logic vmxr_i,
    input riscv::pmpcfg_t [N-1:0] pmpcfg_i,
    input logic [N-1:0][Cfg.PLEN-3:0] pmpaddr_i
);
  // one-shot reset: low at cycle 0, high forever; checker gates on past_valid
  logic rst_done = 1'b0;
  always_ff @(posedge clk) rst_done <= 1'b1;

  logic ptw_active, walking_instr, ptw_error, ptw_error_at_g_st, ptw_err_at_g_int_st;
  logic ptw_access_exception, shared_tlb_miss;
  logic [Cfg.VLEN-1:0] update_vaddr;
  logic [Cfg.PLEN-1:0] bad_paddr;
  logic [Cfg.GPLEN-1:0] bad_gpaddr;
  dcache_req_i_t req_port_o;
  tlb_update_cva6_t shared_tlb_update;

  cva6_ptw #(
      .CVA6Cfg          (Cfg),
      .pte_cva6_t       (pte_cva6_t),
      .tlb_update_cva6_t(tlb_update_cva6_t),
      .dcache_req_i_t   (dcache_req_i_t),
      .dcache_req_o_t   (dcache_req_o_t),
      .HYP_EXT          (HYP_EXT)
  ) dut (
      .clk_i                   (clk),
      .rst_ni                  (rst_done),
      .flush_i                 (flush_i),
      .ptw_active_o            (ptw_active),
      .walking_instr_o         (walking_instr),
      .ptw_error_o             (ptw_error),
      .ptw_error_at_g_st_o     (ptw_error_at_g_st),
      .ptw_err_at_g_int_st_o   (ptw_err_at_g_int_st),
      .ptw_access_exception_o  (ptw_access_exception),
      .enable_translation_i    (enable_translation_i),
      .enable_g_translation_i  (enable_g_translation_i),
      .en_ld_st_translation_i  (en_ld_st_translation_i),
      .en_ld_st_g_translation_i(en_ld_st_g_translation_i),
      .v_i                     (v_i),
      .ld_st_v_i               (ld_st_v_i),
      .hlvx_inst_i             (hlvx_inst_i),
      .lsu_is_store_i          (lsu_is_store_i),
      .req_port_i              (req_port_i),
      .req_port_o              (req_port_o),
      .shared_tlb_update_o     (shared_tlb_update),
      .update_vaddr_o          (update_vaddr),
      .asid_i                  (asid_i),
      .vs_asid_i               (vs_asid_i),
      .vmid_i                  (vmid_i),
      .shared_tlb_access_i     (shared_tlb_access_i),
      .shared_tlb_hit_i        (shared_tlb_hit_i),
      .shared_tlb_vaddr_i      (shared_tlb_vaddr_i),
      .itlb_req_i              (itlb_req_i),
      .satp_ppn_i              (satp_ppn_i),
      .vsatp_ppn_i             (vsatp_ppn_i),
      .hgatp_ppn_i             (hgatp_ppn_i),
      .mxr_i                   (mxr_i),
      .vmxr_i                  (vmxr_i),
      .shared_tlb_miss_o       (shared_tlb_miss),
      .pmpcfg_i                (pmpcfg_i),
      .pmpaddr_i               (pmpaddr_i),
      .bad_paddr_o             (bad_paddr),
      .bad_gpaddr_o            (bad_gpaddr)
  );
endmodule
