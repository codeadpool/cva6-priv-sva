# Findings

CVA6 v5.3.0 (`2ef1c1b`, `cv64a6_imafdc_sv39`) against the RISC-V privileged
spec v1.13. Two unreported nonconformances (F5, filed upstream; F8), two known
upstream (F6, F7), and two design characterizations (F1, F2). Each has a witness
under `evidence/`: the F5-F8 probes fail in bmc by design, the base properties
pass bmc/prove/cover. Inventory: `PROPERTY_PLAN.md`.

## F5 - interrupt traps leave the instruction encoding in mtval/stval

Filed upstream 2026-07-06; both defects live on master `b30e7db`.

**F5a, wrong bit-select.** `csr_regfile.sv:1919` gates mtval zeroing on
`ex_i.cause[GPLEN-1]` (bit 40); every sibling site uses the interrupt flag
`cause[XLEN-1]` (stval `:1880`, vstval `:1852/:1861`, mtinst `:1939`, delegation
`:1822`). Bit 40 is 0 for every valid cause, so the interrupt term is
constant-false. Fix: `GPLEN` -> `XLEN`.

**F5b, default builds skip zeroing.** `ZERO_TVAL=0` unless `SPIKE_TANDEM`
(`ariane_pkg.sv:104-109`). The decoder preloads `ex.tval` with the instruction
bits (`decoder.sv:1588`), the interrupt attach (`:1682-1717`) never clears it,
and `csr_regfile` writes it into mtval/stval.

Spec: "For other traps, mtval is set to zero" (Machine-Level ISA, mtval; stval
identical); interrupts are "other traps". #898/#448 + PR #3226 covered only
ecall/ebreak - interrupts and F5a survived.
Witness: `mstatus_f5_sva.sv::a_irq_mtval_zero`, cover `c_irqM_tvalnz` reachable.

## F6 - xRET below M does not clear mstatus.MPRV (RVH=0)

The MPRV clear on mret/sret is nested under `if (CVA6Cfg.RVH)`
(`csr_regfile.sv:2116-2122`, `:2136-2142`), so RVH=0 builds never clear it.
Reachable because RVU=1 makes MPRV writable (`:1378-1381`). Spec: "An MRET or
SRET instruction that changes the privilege mode to a mode less privileged than
M also sets MPRV=0" (Machine-Level ISA, mstatus).
Known upstream (#3294, #1981). Probe `mstatus_mprv_sva.sv` (expected bmc CEX) =
machine-checked corroboration.

## F7 - M-mode PMP: lock filter applied before priority

Spec (v1.13 3.7.1): the lowest-numbered matching entry decides, then its L bit
governs M-mode enforcement. `pmp.sv:55` skips non-locked entries before priority
selection, so in M-mode a later locked entry overrules a lower-numbered unlocked
match - spec allows, CVA6 denies.
Known upstream (#3177). Probe `pmp_mpri_sva.sv` (expected bmc CEX against a
spec-priority reference model).

## F8 - dcsr.prv stored unlegalized; dret enters a reserved privilege mode

`csr_regfile.sv:1054-1066`: the DCSR write path legalizes
xdebugver/nmip/stopcount/stoptime but stores `prv` raw, so prv can hold 2'b10
(reserved, H not implemented). `dret` loads `priv_lvl_d` from `dcsr_q.prv`
(`:2166`), so the hart enters 2'b10 - unequal to M/S/U, and downstream privilege
checks (delegation, PMP M-bypass, CSR access) run on an undefined mode. Debug
spec v1.0 makes prv WARL over the supported modes.
Adjacent #1984/#1985 cover other dcsr fields, not prv or the post-dret
corruption (checked 2026-07-05). Unreported; issue draft ready.
Witness: `priv_dret_sva.sv::a_priv_legal` - the CEX enters debug mode, writes
dcsr prv=2'b10, executes dret, and `priv_lvl_q` reads back 2'b10; cover
`c_dcsr_prv_illegal` reachable.

## F1 - Smepmp is not implemented

No `mseccfg` CSR and no MML/MMWP/RLB; `pmp.sv`'s only M-mode rule is base PMP
(`priv != M || locked`, `pmp.sv:55`). The suite verifies base PMP plus GAP-1: a
non-locked entry is always bypassed in M-mode, the invariant Smepmp MML would
break.

## F2 - NA4 is not selectable (spec-compliant at G=1)

G=1 8-byte grain (`csr_regfile.sv:862`); the spec makes NA4 unselectable at
G >= 1. WARL enforced: writing `A=NA4` reverts to the previous mode (`:2708-2710`),
and `pmp_entry.sv` has no NA4 match arm. Verified by CSR-1 and PMP-7.
