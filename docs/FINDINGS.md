# Findings

CVA6 v5.3.0 (`2ef1c1b`) against the RISC-V privileged spec v1.13, on
`cv64a6_imafdc_sv39` (RVH=0) except F9, which needs `cv64a6_imafdch_sv39`
(RVH=1). Five findings: three our own F5 and F8 (reported upstream, fixes
submitted as pull requests under review) and F9 (RVH=1 only, being written up,
not yet filed) and two that rediscover known open upstream issues (F6, F7).
Each has a witness under `evidence/`: the finding probes fail in bmc by design,
the base properties pass bmc/prove/cover. Inventory: `PROPERTY_PLAN.md`.

## F5: interrupt traps leave the instruction encoding in mtval/stval

Reported 2026-07-06 as openhwgroup/cva6 #3379, fixed in PR #3386; both defects
live on master.

**F5a, wrong bit-select.** `csr_regfile.sv:1919` gates mtval zeroing on
`ex_i.cause[GPLEN-1]` (bit 40); every sibling site uses the interrupt flag
`cause[XLEN-1]` (stval `:1880`, vstval `:1861`, vscause `:1852`, mtinst `:1939`,
delegation `:1822`). Bit 40 is 0 for every valid cause, so the interrupt term is
constant-false. Fix: `GPLEN` -> `XLEN`.

**F5b, default builds skip zeroing.** `ZERO_TVAL=0` unless `SPIKE_TANDEM`
(`ariane_pkg.sv:104-109`). The decoder preloads `ex.tval` with the instruction
bits (`decoder.sv:1588`), the interrupt attach (`:1682-1717`) never clears it,
and `csr_regfile` writes it into mtval/stval.

Spec: "For other traps, mtval is set to zero" (Machine-Level ISA, mtval; stval
identical); interrupts are "other traps". #898/#448 + PR #3226 covered only
ecall/ebreak; interrupts and F5a survived.
Witness: `mstatus_f5_sva.sv::a_irq_mtval_zero`, cover `c_irq_m_tvalnz` reachable.
Proven on the PR head (`3250ed48`, v5.3.0-185) by k-induction, RVH=0 config, for
the M-mode `mtval` and S-mode `stval` sites: `c_irq_m_tvalnz` and
`c_irq_s_tvalnz` still reach, and both witness covers are the negations of
proven assertions and therefore unreachable. The third site the patch changes,
`vstval`, needs RVH=1 and is not covered by this harness.

## F6: xRET below M does not clear mstatus.MPRV (RVH=0)

The MPRV clear on mret/sret is nested under `if (CVA6Cfg.RVH)`
(`csr_regfile.sv:2116-2122`, `:2136-2142`), so RVH=0 builds never clear it.
Reachable because RVU=1 makes MPRV writable (`:1378-1381`). Spec: "An MRET or
SRET instruction that changes the privilege mode to a mode less privileged than
M also sets MPRV=0" (Machine-Level ISA, mstatus).
Known upstream (#3294, #1981). Probe `mstatus_mprv_sva.sv` (expected bmc CEX) =
machine-checked corroboration.

## F7: M-mode PMP lock filter applied before priority

Spec (v1.13 3.7.1): the lowest-numbered matching entry decides, then its L bit
governs M-mode enforcement. `pmp.sv:55` skips non-locked entries before priority
selection, so in M-mode a later locked entry overrules a lower-numbered unlocked
match. The spec allows this, CVA6 denies it.
Known upstream (#3177). Probe `pmp_mpri_sva.sv` (expected bmc CEX against a
spec-priority reference model).

## F8: dcsr.prv is not WARL-legalized; dret sets priv_lvl to an unimplemented encoding

`csr_regfile.sv:1054-1066`: the DCSR write path legalizes
xdebugver/nmip/stopcount/stoptime but stores `prv` raw. `dret` loads `priv_lvl_d`
from `dcsr_q.prv` (`:2166`) with no clamp, so a debugger can drive `priv_lvl` to
2'b10. CVA6's enum labels 2'b10 `PRIV_LVL_HS` (riscv_pkg.sv), a hypervisor-CSR
access level, not a distinct operating mode; with RVH=0 the H extension is absent,
so 2'b10 is unimplemented. `priv_lvl` then equals none of M/S/U, and this build's
privilege logic compares only against those (delegation, PMP M-bypass), so the
hart runs at an unimplemented privilege, losing the M-mode PMP bypass, with traps
routing as if below M. This is a WARL/robustness conformance gap (the same class
as #1984/#1985 for other dcsr fields), not an escalation. Debug spec v1.0 makes
prv WARL over the supported modes.
Adjacent #1984/#1985 cover other dcsr fields, not prv or the post-dret
corruption (checked 2026-07-05). Reported 2026-07-07 as openhwgroup/cva6 #3383,
fixed in PR #3387.
Witness: `priv_dret_sva.sv`. On golden the bmc counterexample fires first on
`a_dcsr_prv_legal` (step 4, the raw dcsr.prv write). The post-`dret` corruption
itself is the cover `c_f8_witness` (step 5): the trace enters debug mode, writes
dcsr prv=2'b10, executes dret, and `priv_lvl_q` reads back 2'b10.
Proven on the PR head (`8f74af4a`) by PDR, RVH=0 config; the probe also proves
`dcsr.prv` itself stays WARL-legal (`a_dcsr_prv_legal`). `c_dret_in_debug` still
reaches; `c_dcsr_prv_illegal` and `c_f8_witness` are the negations of the proven
assertions and are therefore unreachable.

**Sibling fields (PRIV-5).** The same write path left `v`, `cause` and the
reserved fields raw. PR #3387 hardwires `v` to 0 when RVH=0, preserves
hardwareowned `cause` (closing #1985), and added 2026-07-18 (`8f74af4a`)
zeroes `zero1` (bit 14) and `zero2` (bits 27:18), completing #1984. The
reserved-field half is a fix-certification, not an original finding: #1984 and
#1985 predate this work and were filed by others. Probe `dcsr_reserved_sva.sv`
certifies both halves: `a_dcsr_reserved_zero` (reserved bits, #1984) and
`a_dcsr_cause_preserved` (a software dcsr write cannot change `cause`, #1985).
Both CEX on v5.3.0 at step 4 and are proven by k-induction on the PR head, so
`c_reserved_nonzero` and `c_cause_changed` are unreachable there; the antecedent
cover `c_dcsr_sw_write` still reaches.

## F9: mstatus.MPP retains the reserved encoding 2'b10 when the hypervisor extension is enabled (RVH=1)

`csr_regfile.sv:1382` legalizes `mstatus.mpp` against 2'b10 only when RVH=0: the
term is `!CVA6Cfg.RVH & mstatus_d.mpp == PRIV_LVL_HS`. But 2'b10 is not a
privilege mode in any configuration: HS is S-mode (2'b01) with V=0, and CVA6
uses `PRIV_LVL_HS` only as a CSR access level (`riscv_pkg.sv:33`), never as a
mode the hart runs at. With RVH=1 the guard is switched off, and a plain M-mode
`csrw mstatus` leaves `mpp = 2'b10`.

This is the RVH=1 case left open by the fixes for #1988 and #2274 (both on
CV32A65X, no hypervisor). PR #2035 first rejected `2'b10` only when
`!CVA6Cfg.RVH`; PR #2285 (fixing #2274) generalized MPP legalization to the
unsupported S and U encodings but kept the same RVH-dependent treatment of
`2'b10`. The encoding is reserved in the RVH=1 configuration too. So this is an
incomplete fix, not a new defect, and it does not affect the default `cv64a6_imafdc_sv39`
(RVH=0). Writing `mstatus` requires M-mode, so it is not a privilege escalation;
it is a WARL/robustness gap that places the hart in an undefined privilege
encoding.

Once set, 2'b10 propagates: `mret` copies it into `priv_lvl` unclamped (`:2108`),
and with `mstatus.mprv` it becomes the load/store privilege with no `mret` at all
(`:2074`, `:2088`). The MMU's user/supervisor page check is an equality against S
and U (`cva6_mmu.sv:371-372` fetch, `:523-524` load/store), so 2'b10 matches
neither and that one check is skipped: a hart at 2'b10 may read both user and
supervisor pages. Stated no more strongly than that: the PTE R/W/X and dirty
checks do not depend on privilege and still fire (`cva6_mmu.sv:586`), and PMP is
unaffected: it treats any non-M privilege as subject to the rules (`pmp.sv:55`)
and fails safe. The similar guard in the CSR_SSTATUS write case (`:1172`) is not a
second site: `SMODE_STATUS_WRITE_MASK` (0x000C6122) excludes the MPP field (bits
12:11), so an sstatus write cannot alter MPP and that guard is already a no-op.

Witness: `mpp_legal_sva.sv::a_mpp_legal`, run as a differential the same
assertion on the same RTL at both RVH settings. On the #3387 branch it proves
unbounded (PDR) at RVH=0 and fails (bmc, step 3) at RVH=1; the RVH=1
counterexample keeps `priv_lvl` legal throughout, which is what separates it from
F8 (#3383). On unpatched v5.3.0 the assertion also fails at RVH=0, but by F8's
`dcsr.prv` → trap-stack route (`:1906`), three steps later and with `priv_lvl`
corrupted first a different mechanism, not this one. Being written up as an
incomplete-fix follow-up to #1988 / #2274; not yet filed upstream.
