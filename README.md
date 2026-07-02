# cva6-priv-sva

Open-source formal verification (SystemVerilog Assertions, proven with
**Yosys + SymbiYosys + Z3**) of the **RISC-V privileged architecture** PMP,
trap delegation, `mret`/`sret`, mstatus stacking, and the MMU↔PMP interaction
as implemented in the **CVA6** application-class core (v5.3.0, pinned submodule).

> Status: **Tier-1 PMP proven** (2026-06-30) `pmp_entry` + `pmp`, 8
> properties, all bmc/prove/cover green (`abc pdr` proofs, `smtbmc boolector`
> bmc/cover). Tier-2/3 (CSR WARL, trap/mstatus, PTW↔PMP) are authored DRAFTs
> pending the `csr_regfile` harness.

## Layout
```
cva6/                  GOLDEN upstream CVA6 v5.3.0 @ 2ef1c1b (submodule, never edited)
fv/
  sva/<m>_sva.sv       checkers
  sva/<m>_bind.sv
  wrappers/<m>_fv.sv   formal tops
  checks/<cat>.sby     sby scripts — tasks: bmc / prove / cover
docs/
Makefile               verify-<cat>, verify-all, results, versions, clean
Dockerfile             pins one OSS-CAD-Suite release (yosys + sby + z3 + slang)
results/
```

## Quickstart
```sh
git submodule update --init cva6      # fetch the pinned golden RTL
docker build -t cva6-priv-sva .
docker run --rm -it -v "$PWD":/workspace cva6-priv-sva
# inside the container:
make versions                         # audit trail (tool + CVA6 versions)
make verify-pmp                       # tier-1 PMP proofs (bmc + prove + cover)
make results                          # status table
```

CVA6 is pinned and never modified the checkers only observe it via `bind`.
