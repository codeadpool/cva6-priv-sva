# 2×2 experiments: how to read the verdicts

> In this directory, `FAIL` usually means a property is wrong, not that CVA6 is
> broken or something. A corrected design can expose a property that encoded the old RTL.

The rest of `evidence/` reports verdicts about CVA6. This directory reports
verdicts about **the verification suite** by running each property against RTL
variants that differ from the pin by a single named correction.

`evidence/matrix/` is the full sweep behind these two cases: every proven checker
against every correction, including the pairs where nothing inverts.

Every experiment starts from the pinned golden submodule: CVA6 v5.3.0
(`2ef1c1b1`). Each patched column adds only the named patch. "Golden" here means
the pinned reference revision, not a correct one: both defects below are in it.

## 1. M-mode priority (#3177)

Patch: `pmp_3177_priority.patch` (`pmp.sv:52-62`)

The patch selects the lowest-numbered matching entry before evaluating `L`, as
required by Machine ISA v1.13 §2.1.7.1.3:

> If the L bit is clear and the privilege mode of the access is M, the
> operation succeeds.

| Property | Golden v5.3.0 | With patch |
|---|---:|---:|
| `pmp_ref_sva::a_m_impl_equiv` — catalogued as **PMP-4** | **PASS** | **FAIL** |
| `pmp_mpri_sva::a_m_spec_priority` — spec rule, **PMP-9** | **FAIL** | **PASS** |

`pmp_ref_sva` filters out unlocked entries before selecting the lowest match,
mirroring `pmp.sv:55`. That is the implementation behavior prohibited by the
ISA. So PMP-4 agrees with the pinned RTL and disagrees with the corrected
arbiter; PMP-9, which encodes the ISA rule, gives the opposite verdicts. PMP-4
is an implementation characterisation, not a conformance oracle. It was
catalogued in architecture-facing terms until `916b426` narrowed the wording and
`581b899` retagged it `RTL-lock`.

## 2. TOR grain bit (#3342)

For `G=1`, Machine ISA v1.13 §2.1.7.1.1 states:

> Bits pmpaddr_i[G-1:0] do not affect the TOR address-matching logic.

CVA6 masks bit 0 only when reading `pmpaddr` (`csr_regfile.sv:866-868`) but
stores it raw (`csr_regfile.sv:1738`), so the bit reaches the matcher.

That sentence is indexed to `pmpaddr_i`, and it applies wherever `pmpaddr_i`
participates in TOR matching: including as the **lower** bound of entry `i+1`.
This was asked and answered in
[riscv-isa-manual #884](https://github.com/riscv/riscv-isa-manual/issues/884#issuecomment-3631302703)
(opened 2022-08-23, closed 2025-12-09 by the comment linked here): *"It doesn't
say which PMP register's matching logic that statement applies to: i.e. it is
true for both i and i+1."*

We test two corrections:

- `pmp_tor_grain.patch` masks the entry's **own** bound only: an **incomplete**
  fix, useful here because it separates the two halves of the rule.
- `pmp_tor_grain_both_pr3490.patch` is the RTL from upstream PR #3490 and masks
  **both** bounds. This is the architectural behaviour. The PR is an open
  candidate correction, not an accepted fix: unmerged at head `661e447b`.

| Property | Golden v5.3.0 | Incomplete (own bound) | Both bounds (#3490) |
|---|---:|---:|---:|
| `pmp_entry_sva::a_tor_exact` — **PMP-5** | **PASS** | **FAIL** | **FAIL** |
| `pmp_entry_sva::a_tor_lo_inclusive` — **PMP-5** | **PASS** | **FAIL** | — |
| `pmp_entry_sva::a_tor_hi_exclusive` — **PMP-5** | **PASS** | **PASS** (proven with `abc pdr`) | — |
| `pmp_entry_arch_sva::a_tor_exact_arch` — spec-derived, **PMP-10** | **FAIL** | **FAIL** | **PASS** |

### What the table shows

- **PMP-5 encodes the implementation.** `pmp_entry_sva.sv:15` computes the TOR
  upper bound with the same expression as `pmp_entry.sv:54`. Any correction
  that removes the grain bit from matching makes it fail. Isolation runs show
  exactly which properties invert: two reject the variant, while
  `a_tor_hi_exclusive` is proven to survive it.
- **PMP-10 is written from the specification and tracks it.** It rejects golden
  and the incomplete fix, and accepts #3490. Same DUT, same harness, opposite
  verdicts to PMP-5: the only difference is where the range came from.

## Patches

| File | Edit region | Origin |
|---|---|---|
| `pmp_3177_priority.patch` | `pmp.sv:52-62` | Created only for this experiment |
| `pmp_tor_grain.patch` | `pmp_entry.sv:54` | Created only for this experiment |
| `pmp_tor_grain_both_pr3490.patch` | `pmp_entry.sv` | Upstream PR #3490 by KnightGOKU, head `661e447b`; RTL hunk copied verbatim |

None of these patches is proposed upstream by this suite. Both defects were
reported by others:

- TOR grain bit: [#3342](https://github.com/openhwgroup/cva6/issues/3342),
  reported 2026-06-09.
- M-mode priority: [#3177](https://github.com/openhwgroup/cva6/issues/3177),
  reported 2026-01-06.

We did not discover either defect and do not claim them. They are fixed
reference points used to measure the properties.

`pmp_entry.sv` is byte-identical between v5.3.0 and PR #3490's base. The PR
hunk therefore applies unchanged to the pinned version, and the experimental
result carries to the PR head.

## Reproducing

Example for the own-bound TOR correction:

```sh
git -C cva6 apply ../evidence/2x2/pmp_tor_grain.patch
cd fv/checks
sby -f -d ../../results/inv/pmp_entry_masked_bmc pmp_entry.sby bmc
# Expected: FAIL
sby -f -d ../../results/inv/arch_masked_bmc probe_pmp_entry_arch.sby bmc
# Expected: FAIL  (this patch masks one bound of two, so PMP-10 rejects it too)
cd ../..
git -C cva6 checkout core/pmp/src/pmp_entry.sv
```

The other patches use the same flow. These are the commands run by the
`verdict-inversion` CI job, so the documented path is also the tested path.

## Soundness

- Every model has **zero sequential cells**. With free inputs, `bmc` decides the
  complete input space; its configured depth is a harness artifact, not a
  verification bound.
- Each property is run in isolation because one failing assertion can hide
  later failures in a combined run.
- Covers are checked alongside the assertions. Antecedent covers remain
  reachable, so a passing result is not caused by vacuity. Witness covers, which
  state the negation of a now-proven assertion, deliberately become unreachable
  after a correction; that is the expected signature, not a regression.

