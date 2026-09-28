# cva6-priv-sva

Open-source formal verification (SystemVerilog Assertions, proven with
**Yosys + yosys-slang + SymbiYosys**) of the **RISC-V privileged architecture** PMP,
trap delegation, `mret`/`sret`, mstatus stacking, and the MMU↔PMP interaction
as implemented in the **CVA6** application-class core (v5.3.0, pinned submodule).

> **Status (2026-09-28).** Base properties are proven (bmc, induction and
> cover, every antecedent cover-witnessed) across PMP, PMP-CSR WARL, trap
> delegation and return, mstatus stacking, privilege invariants and the MMU-PMP
> interaction. Witness probes fail by design, each a machine-checked
> counterexample to a spec nonconformance. Five findings are ours, four of them
> fixed upstream by our PRs; two rediscover upstream issues.

| Finding | What | Upstream |
|---|---|---|
| F5 | Interrupt traps leave the instruction encoding in `mtval`/`stval` | #3379, fixed by our PR #3386 |
| F8 | `dret` can set an unimplemented privilege level (`dcsr.prv` not legalized) | #3383, fixed by our PR #3387 |
| F9 | `mstatus.MPP` keeps the reserved encoding 2'b10 at RVH=1 (incomplete fix of #1988/#2274) | #3411, fixed by our PR #3414 |
| F10 | The page-table walker follows a non-leaf PTE with reserved A/D/U bits (RVH=0) | #3420, fixed by our PR #3422 |
| F11 | The walker requests a PMP-denied PTE before enforcing the denial; the fault is still raised | #3430, reported, no fix submitted |
| F6 | Rediscovers: `mstatus.MPRV` not cleared on xRET | #3294, closed by PR #3551 (not ours) |
| F7 | Rediscovers: PMP M-mode priority | #3177, open |

CVA6's PMP is also checked against the RISC-V Sail model with a miter
([evidence/sail/README.md](evidence/sail/README.md)). A leaf-level discrepancy
in Sail's TOR bound (proven decision-neutral at G=1) was reported as sail-riscv
#1951 and fixed by our PR #1959, merged 2026-09-24; its fix certification is in
[evidence/sail/fix_cert/](evidence/sail/fix_cert/PROTOCOL.md). Details:
[docs/FINDINGS.md](docs/FINDINGS.md), [docs/PROPERTY_PLAN.md](docs/PROPERTY_PLAN.md).

## Validation

The suite is validated:

- **Mutation testing.** 26 hand-selected RTL mutations across the proven checker
  set are all killed, each attributed to one or more named assertions. That
  establishes sensitivity to this fault set, not completeness or prevalence.
  Probes are excluded: one already fails on golden, so any mutant against it
  would count as trivially killed.
  Reproducible: `fv/validation/mutation_test.sh`.
- **Probe witness signatures.** Each expected-CEX probe covers its
  exact violation state, so a probe that stops failing for the intended reason is
  caught.
- **Fix certification.** Where we submitted a fix (F5, F8, F9, F10, the DCSR
  reserved and cause fields PRIV-5/PRIV-8, and the RVH=1 dcsr.v clamps PRIV-9), the same probe
  is re-run against the tested PR commit and proven there by induction (PDR for F8, where
  fixed-depth k-induction cannot discover the `mstatus.mpp` invariant). Each
  defect-witness cover is the exact negation of a proven assertion, so its
  unreachability follows from the proof, not from a bounded search. Proven at
  `cv64a6_imafdc_sv39` (RVH=0), except the dcsr.v clamps (PRIV-9), proven at
  `cv64a6_imafdch_sv39` (RVH=1). Both runs are archived under `evidence/`,
  each labelled with the commit it was proven against. F6 and F7 are known
  upstream issues with no fix of ours, so no "after" evidence is claimed.
- **No assumptions.** Outside `fv/wrappers/pmp_sail_ref_fv.sv` and
  `fv/wrappers/sail_leaf_fv.sv`, `fv/` contains no `assume`, so the proven
  properties hold under unconstrained inputs (CI enforces this). Each of those
  two Sail harnesses has five assumes, its stated domain:
  `evidence/sail/README.md` and `evidence/sail/TIER1_PROTOCOL.md`.

## Layout
```
cva6/                  GOLDEN upstream CVA6 v5.3.0 @ 2ef1c1b (submodule, never edited)
sail-riscv/            pinned sail-riscv 0.12 @ 65ddde8 (submodule, never edited)
fv/
  sva/<m>_sva.sv       checkers
  sva/<m>_bind.sv
  wrappers/<m>_fv.sv   formal tops
  checks/<cat>.sby     sby scripts (tasks: bmc / prove / cover)
  sail/                Sail PMP reference: slice, generated SV, provenance
docs/
Makefile               verify-<cat>, verify-all, results, versions, clean
Dockerfile             toolchain image: yosys + sby + solvers + slang
tools/oss-cad-suite.sh the pinned OSS-CAD-Suite release, sha256-checked (Dockerfile and CI)
results/               scratch (gitignored)
evidence/              committed logs + traces (make evidence)
```

## Quickstart
```sh
git submodule update --init cva6      # fetch the pinned golden RTL
docker build -t cva6-priv-sva .
docker run --rm -it -v "$PWD":/workspace cva6-priv-sva
# inside the container:
make versions                         # audit trail (tool + CVA6 versions)
make verify-pmp                       # tier-1 PMP proofs (bmc + prove + cover)
make verify-csr verify-trap verify-vm # PMP-CSR WARL + trap/return/deleg + MMU-PMP
make verify-mstatus TASKS="bmc cover" # F5 + F6 witness probes: bmc FAIL is the finding
make verify-probe   TASKS="bmc cover" # F7-F11 + PRIV-5 witness probes
make results                          # status table
```

Baseline verification uses the pinned CVA6 submodule unchanged. Checkers are
either instantiated beside the DUT or attached with `bind`; mutation and
correction checks use throwaway or reverted variants.
