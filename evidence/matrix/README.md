# Fix-side census: does a proven property accept the repair?

`evidence/2x2/` shows two properties inverting. This directory is the sweep behind
them: every proven checker run against every correction we can apply to the pin,
including the pairs where nothing happens. Reporting the boring cells is the point
— without them "two properties inverted" has no denominator.

Every column starts from CVA6 v5.3.0 (`2ef1c1b1`) and differs by one named edit.
Tool versions in `versions.txt`.

## Corrections

| Column | Edit | Origin |
|---|---|---|
| `tor_own` | `pmp_entry.sv`, masks the entry's own TOR bound | ours, deliberately incomplete |
| `tor_both` | `pmp_entry.sv`, masks both TOR bounds | upstream PR #3490, open |
| `prio_3177` | `pmp.sv`, selects lowest match before evaluating `L` | ours, from the ISA rule |
| `csr_mtval` | `csr_regfile.sv`, zeroes mtval/stval on interrupt traps | ours, fix PR for F5 |
| `ptw_adu` | `cva6_ptw.sv`, rejects A/D/U in non-leaf PTEs | ours, fix PR for F10 |

## The pairs that count

A cell only tests fix-acceptance if the property can observe the edit. Six pairs
qualify: the property is proven on the pin and compiles the patched file.

| Property | Column | Pin | On correction | |
|---|---|---:|---:|---|
| `pmp_entry_sva::a_tor_exact` | `tor_own` | PASS | **FAIL** | inverted |
| `pmp_entry_sva::a_tor_exact` | `tor_both` | PASS | **FAIL** | inverted |
| `pmp_ref_sva::a_m_impl_equiv` | `prio_3177` | PASS | **FAIL** | inverted |
| `csr_warl` | `csr_mtval` | PASS | PASS | accepted |
| `trap_priv` | `csr_mtval` | PASS | PASS | accepted |
| `vm` | `ptw_adu` | PASS | PASS | accepted |

Three rejections, from **two** distinct properties. Both transcribe the RTL:
`a_tor_exact` reuses `pmp_entry.sv`'s bounds, `a_m_impl_equiv` compares against a
reference that filters unlocked entries first, like `pmp.sv:55`. Their
spec-derived counterparts give the opposite verdicts (`evidence/2x2/`).

## The cells that do not count, and why

Eight further cells passed a corrected column without testing anything. The
property compiles the patched file but cannot observe the edit:

- **Shared component.** `pmp_ref_sva:19` instantiates `pmp_entry` to build its
  reference. Patch the matcher and both sides move together, so the difference
  cancels. Its 10 covers all stay reachable — it is not vacuous, just scoped to
  arbitration, as its own comment says.
- **Antecedent scope.** `pmp_sva`'s assertions are gated on `all_off`. With every
  entry OFF neither TOR bounds nor lock priority can matter.
- **Module scope.** `vm`'s properties target the page walker; the PMP columns do
  not reach them.

This is worth stating because cover reachability does not flag it. Every cover in
every column stayed reachable except one, below. Non-vacuity is not sensitivity.

## Reading cover verdicts

A `cover` FAIL here is usually correct, not a regression.

- **Witness covers** state the defect. They *should* die once it is fixed.
  `prio_3177/probe_pmp_mpri_cover` FAILs because `c_f7_witness` is unreachable on
  the corrected arbiter — the signature of the fix working.
- **Antecedent covers** state reachability of the property's precondition. They
  must survive a correction. All of them did, in every column.

Only an antecedent cover going unreachable would mean a property had gone vacuous.
None did.

## Reproducing

Per column, from the repo root:

```sh
git -C cva6 apply "$PWD/evidence/2x2/pmp_tor_grain.patch"
cd fv/checks
for c in pmp_entry pmp_match pmp_ref vm; do for t in bmc prove cover; do
  sby -f -d ../../results/matrix/tor_own/${c}_${t} $c.sby $t
done; done
cd ../..
git -C cva6 checkout core/pmp/src/pmp_entry.sv
```

The `csr_mtval` and `ptw_adu` patches are generated from the fix branches:

```sh
git -C cva6-fork diff 'fix/mtval-interrupt-zero~1..fix/mtval-interrupt-zero' -- core/csr_regfile.sv
git -C cva6-fork diff 'fix/ptw-nonleaf-adu~1..fix/ptw-nonleaf-adu'           -- core/cva6_mmu/cva6_ptw.sv
```

## Soundness

- Every PMP model has zero sequential cells. With free inputs, `bmc` decides the
  complete input space; its depth is a harness artifact, not a bound.
- Each cell is a separate `sby` workdir, so one failing assertion cannot mask
  another.
- `FAIL` cells are attributed to a named assertion in their `logfile.txt`.
