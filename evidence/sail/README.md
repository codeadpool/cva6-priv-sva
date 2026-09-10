# CVA6 PMP vs the Sail golden model

Every other proof here checks CVA6 against properties *we* wrote. This one checks
it against the RISC-V Sail model, a formal executable model of the architecture
adopted by RISC-V International: `sail-riscv`'s PMP decision function, compiled
to SystemVerilog and mitered against CVA6's `pmp.sv`.

The miter has zero flops, so `prove` at depth 2 is exhaustive over the domain
below, not a bounded search. Pins and patches: `versions.txt`.

## Theorems

| | Statement |
|---|---|
| A `a_us_equiv` | `priv != M` implies `sail_allow == cva6_allow` |
| B `a_m_div_is_f7` | in M, a divergence implies the configuration has the F7 shape |
| C `a_f7_implies_div` | in M, the F7 shape implies a divergence |
| `a_full_equiv` | `sail_allow == cva6_allow`, unconditionally (commented out; c3 only) |

F7 is the M-mode lock-before-priority defect, upstream #3177.

## Results

| Column | RTL | Live | prove | cover |
|---|---|---|---|---|
| `c1_golden_*` | v5.3.0 | A,B,C | **FAIL** (C) | PASS 5/5 |
| `c2_tor_*` | + #3490 | A,B,C | **PASS** | PASS 5/5 |
| `c3_full_*` | + #3490 + #3177 | A, full | **PASS** | FAIL |
| `sail_pmp_*` | v5.3.0 | A,B,C | FAIL | PASS |

On the unpatched columns `f7_shape` uses the architectural previous bound while
`pmp.sv` uses the raw stored one, so read those rows as the pre-fix verdict, not
as a characterization of golden. A `prove` FAIL names only the assertion that fired.

**c2 is the headline.** Its patch is merged upstream. A holds, so CVA6 conforms to
Sail in S and U mode. B and C hold together, so the M-mode divergence set is
*exactly* #3177: not merely contained in it. #3490's `pmp_entry` masks bit 0 of
both TOR bounds, so there `f7_shape` is exactly the DUT's own match.

c3 adds our own #3177 patch and proves `a_full_equiv`: no divergence remains. Its
cover FAILs by design, `c_m_divergence` being the only unreached one; there is no
divergence left to witness. B is vacuous and C is refuted there, so cite both from
c2 only.

`sail_pmp_*` is the same RTL as c1 under the names CI asserts.

## Domain

Free inputs, with five assumptions in `pmp_sail_ref_fv.sv`. Three are discharged
by properties proven elsewhere in this suite, so they are lemmas rather than
holes:

| Assumption | Discharged by |
|---|---|
| `cfg.reserved == 0` | `csr_pmp_sva::a_reserved_zero` |
| `cfg.addr_mode != NA4` | `csr_pmp_sva::a_never_na4` |
| `!(W && !R)` | `csr_pmp_sva::a_never_r0w1` |

The other two are stated restrictions, not proven: the access is naturally
aligned, and does not wrap the top of the physical address space. Sail's entry
slots above CVA6's 8 are held OFF so both models decide over the same entries.

## Reproducing

```sh
make sail-provenance          # slice is upstream's code, re-derived not hand-edited
make verify-sail              # golden: bmc FAIL, prove FAIL, cover PASS
```

For c2, apply the patch first and re-run:

```sh
git -C cva6 apply "$PWD/evidence/matrix/patches/pmp_tor_grain_both_pr3490.patch"
cd fv/checks && sby -f -d ../../results/sail/c2_tor_prove sail_pmp.sby prove
cd ../.. && git -C cva6 checkout core/pmp/src/pmp_entry.sv
```

The live theorem set moves with the RTL: c1 and c2 need A, B and C uncommented,
c3 needs A and `a_full_equiv`. See the status block in `fv/sva/pmp_sail_ref_sva.sv`.

## Scope

Conformance to `sail-riscv` **0.12**, for `cv64a6_imafdc_sv39` at G=1 with 8
entries, over the domain above. It is not a claim about other configurations,
other Sail revisions, or access sizes: `pmp.sv` takes no size input, so this
compares single-address decisions.
