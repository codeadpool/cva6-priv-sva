# cva6-priv-sva

Open-source formal verification (SystemVerilog Assertions, proven with
**Yosys + yosys-slang + SymbiYosys**) of the **RISC-V privileged architecture** PMP,
trap delegation, `mret`/`sret`, mstatus stacking, and the MMU↔PMP interaction
as implemented in the **CVA6** application-class core (v5.3.0, pinned submodule).

> Status (2026-07-06): base properties proven (bmc + induction + cover, every
> antecedent cover-witnessed) across PMP incl. a multi-entry reference model,
> PMP-CSR WARL, trap delegation/return, mstatus stacking, privilege invariants,
> and the MMU-PMP interaction. Four probes fail by design, each a
> machine-checked witness of a spec nonconformance: F5 (interrupt mtval, filed
> upstream), F6 (MPRV-on-xret, upstream #3294), F7 (PMP M-mode priority,
> upstream #3177), F8 (unlegalized `dcsr.prv` lets `dret` set priv_lvl to an
> unimplemented encoding). Findings: `docs/FINDINGS.md`; full table:
> `docs/PROPERTY_PLAN.md`.

## Layout
```
cva6/                  GOLDEN upstream CVA6 v5.3.0 @ 2ef1c1b (submodule, never edited)
fv/
  sva/<m>_sva.sv       checkers
  sva/<m>_bind.sv
  wrappers/<m>_fv.sv   formal tops
  checks/<cat>.sby     sby scripts - tasks: bmc / prove / cover
docs/
Makefile               verify-<cat>, verify-all, results, versions, clean
Dockerfile             pins one OSS-CAD-Suite release (yosys + sby + solvers + slang)
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
make verify-probe   TASKS="bmc cover" # F7 + F8 witness probes
make results                          # status table
```

CVA6 is pinned and never modified; the checkers only observe it via `bind`.
