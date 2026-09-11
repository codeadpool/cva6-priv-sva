# Sail golden-model PMP reference

The PMP decision function of the RISC-V Sail model (`sail-riscv` 0.12, a formal
executable model adopted by RISC-V International), specialized and compiled to
SystemVerilog for comparison with CVA6's `pmp.sv`. The miter is
`fv/wrappers/pmp_sail_ref_fv.sv` + `fv/sva/pmp_sail_ref_sva.sv`, run by
`fv/checks/sail_pmp*.sby`; results and scope are in `evidence/sail/README.md`.

```
slice/              Sail sources we compile
generated/          compiler output: committed, never hand-edited
PROVENANCE          every pin: commits, versions, sha256
NOTICE              upstream licences for slice/ and generated/
Containerfile.sail  Sail 0.20.2, official binary pinned by digest
regen.sh            slice -> generated (needs Sail)
provenance.sh       re-checks the pins without Sail (make sail-provenance)
```

## slice/

| File | Origin |
|---|---|
| `pmp_control.sail` | upstream `model/pmp/pmp_control.sail`, seven lines specialized (below) |
| `pmp_slice_prelude.sail` | upstream types and `pmpReadAddrReg`/`pmpLocked`, at XLEN=64, PLEN=56, G=1 |
| `errors.sail` | upstream `model/prelude/errors.sail`, verbatim |
| `pmp_base.sail` | prelude definitions, mostly verbatim from `model/prelude/prelude.sail` |
| `pmp_hw.sail` | upstream's `pmpCheck` loop unrolled 16x: the SV backend needs an acyclic top |

The seven lines drop `private` from `pmpCheckRWX`, `pmpRangeMatch`,
`pmpMatchAddr` and the enum `pmpAddrMatch` (4), fix `sys_pmp_count` at 16 (2),
and fix the NA4 grain assertion at G=1 (1).

`provenance.sh` checks the slice against the pinned upstream: it re-derives the
seven lines, compares `errors.sail`, every unrolled block and every restated
declaration (exceptions are listed in the script), and checks every hash in
`PROVENANCE`.

## Regenerating

From the repository root:

```sh
podman build -f fv/sail/Containerfile.sail -t cva6-sail:0.20.2 fv/sail
podman run --rm -v "$PWD":/workspace:ro -w /tmp cva6-sail:0.20.2 \
    bash /workspace/fv/sail/regen.sh --verify
```

`--verify` must report both files byte-identical; CI runs the same check.
Without it the script rewrites `generated/`: drop `:ro`, and update the hashes
in `PROVENANCE` in the same commit.

## Licence

`slice/` and `generated/` derive from sail-riscv and the Sail compiler, both
BSD-2-Clause: see [NOTICE](NOTICE). The rest of the repository is
[Apache-2.0](../../LICENSE).
