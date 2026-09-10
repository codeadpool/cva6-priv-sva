# Sail golden-model PMP reference

The RISC-V **Sail model** (`sail-riscv`) is a formal, executable model of the
architecture, adopted by RISC-V International. This directory has its PMP
decision function and compiles it to SystemVerilog, so a solver can compare it
with CVA6's `pmp.sv` over the domain stated in `evidence/sail/README.md`.

```
slice/       Sail sources we compile (pinned sail-riscv 0.12, specialized)
generated/   Sail compiler output: SystemVerilog, committed, never hand-edited
PROVENANCE   every pin: commits, versions, sha256
Containerfile.sail   Sail 0.20.2, the toolchain regen.sh needs
regen.sh     slice -> generated  (needs Sail)
provenance.sh  re-checks every pin  (needs no toolchain)
```

The miter itself lives with the rest of the suite: `fv/wrappers/pmp_sail_ref_fv.sv`,
`fv/sva/pmp_sail_ref_sva.sv`, `fv/checks/sail_pmp.sby`. What it proves, the input
domain, and the scope of the claim are in `evidence/sail/README.md`.

## What is in `slice/`

the PMP decision function and what it needs to typecheck

| File | Origin |
|---|---|
| `pmp_control.sail` | upstream `model/pmp/pmp_control.sail` + the specialization below |
| `pmp_slice_prelude.sail` | the model types plus `pmpReadAddrReg`/`pmpLocked` from `model/pmp/pmp_regs.sail`, with XLEN=64, PLEN=56 and G=1 fixed |
| `errors.sail` | upstream `model/prelude/errors.sail`, verbatim |
| `pmp_base.sail` | the prelude definitions this slice needs to typecheck, mostly verbatim from `model/prelude/prelude.sail` |
| `pmp_hw.sail` | upstream's `pmpCheck` loop, unrolled (see below) |

**The specialization** applied to `pmp_control.sail` changes exactly seven source
lines: it drops `private` from the three functions the hardware top calls
(`pmpCheckRWX`, `pmpRangeMatch`, `pmpMatchAddr`) and from `pmpAddrMatch`, the
enum in their signature (4); replaces both uses of `sys_pmp_count` with 16 (2);
and specializes the NA4 grain assertion to G=1 (1). `provenance.sh` re-derives
them from the pinned upstream file and requires the result to be byte-identical,
so the patch cannot silently grow.

**The acyclic top.** Sail's SystemVerilog backend requires a statically
unrollable control-flow graph, while upstream `pmpCheck` loops over the PMP
entries. `pmp_hw.sail` expands that loop into 16 checks in the same order,
followed by the same terminal default.

`provenance.sh` normalizes the pinned upstream loop body and every unrolled
block, requires all 16 blocks to match it, checks that exactly 16 blocks are
present, and checks the terminal default. This verifies that the expansion
changes the control-flow shape without changing PMP priority, matching,
permissions or default behaviour.

**Re-declared types.** The slice cannot `$include` the whole model, so
`pmp_slice_prelude.sail` restates the types the helpers need (`MemoryAccessType`,
`mem_payload`, `Privilege`, `Pmpcfg_ent`, the address-match encoding, the
registers, …). That is where a slice silently drifts, so `provenance.sh`
compares each declaration against its upstream original. Three deliberate
exceptions are listed in the comment beside that check in `provenance.sh`; none
is reachable by the decision.

## Regenerating

`generated/` is committed so that proofs need no Sail toolchain. To reproduce it,
from the repository root:

```sh
podman build -f fv/sail/Containerfile.sail -t cva6-sail:0.20.2 fv/sail
podman run --rm -v "$PWD":/workspace:ro -w /tmp cva6-sail:0.20.2 \
    bash /workspace/fv/sail/regen.sh --verify   # regenerate in a temp dir, compare
make sail-provenance                            # pins + hashes, no toolchain needed
```

`--verify` is the reproducibility gate: it must report both regenerated files
as byte-identical to the committed copies. Without `--verify` the script replaces
the two files under `generated/`: drop the `:ro` for that, and update their
hashes in `PROVENANCE` in the same commit.

## Licence
Every file in `slice/` derives from sail-riscv and is BSD-2-Clause; each carries
an SPDX header. See [this repository's licence](../../LICENSE) and the
[sail-riscv licence](../../sail-riscv/LICENCE).
