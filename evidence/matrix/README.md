# Fix-side sweep: interpreting the results

`evidence/2x2/` records two properties whose verdicts invert on corrected RTL.
This directory contains the broader sweep behind those cases: 49 archived runs
of the proven checkers against five RTL variants applied to the pinned design.

This is a regression archive, **not a prevalence sample**. Most checker/variant
pairs target different requirements, so their verdicts say nothing about whether
the property accepts the correction. A pair tests fix-acceptance only when the
property encodes the requirement changed by that correction.

Every column starts from CVA6 v5.3.0 (`2ef1c1b1`) and applies one named edit.
Tool versions are recorded in `versions.txt`; the exact edits are archived in
`patches/`.

## RTL variants

| Column | Edit | Origin |
|---|---|---|
| `tor_own` | Mask the current entry's TOR bound in `pmp_entry.sv` | Diagnostic variant created for this experiment; deliberately incomplete |
| `tor_both` | Mask both TOR bounds in `pmp_entry.sv` | [openhwgroup/cva6#3490](https://github.com/openhwgroup/cva6/pull/3490); open and unmerged |
| `prio_3177` | Select the lowest matching PMP entry before evaluating `L` | Experimental correction derived from the ISA rule |
| `csr_mtval` | Zero `mtval`/`stval` on interrupt traps in `csr_regfile.sv` | Candidate fix PR for F5 |
| `ptw_adu` | Reject A/D/U bits in non-leaf PTEs in `cva6_ptw.sv` | Candidate fix PR for F10 |

`tor_own` is not a candidate repair. It masks only one of the two TOR bounds
covered by the specification and is included solely to separate the two halves
of the grain rule. `tor_both` and `prio_3177` are spec-conforming correction
candidates; neither has merged upstream.

## Requirement-linked results

Only two proven-property cells test acceptance of a correction for the
requirement each property encodes. Both invert:

| Property | Column | Pin | Correction |
|---|---|---:|---:|
| `pmp_entry_sva::a_tor_exact` | `tor_both` | PASS | **FAIL** |
| `pmp_ref_sva::a_m_impl_equiv` | `prio_3177` | PASS | **FAIL** |

Both properties reproduce their RTL implementations:

- `a_tor_exact` uses the raw TOR bounds used by `pmp_entry.sv`.
- `a_m_impl_equiv` uses a reference model that, like `pmp.sv:55`, removes
  unlocked entries before selecting the lowest match.

The specification-derived properties give the opposite verdicts on the same
design pairs:

| Property | Column | Pin | Correction |
|---|---|---:|---:|
| `pmp_entry_arch_sva::a_tor_exact_arch` | `tor_both` | FAIL | **PASS** (unbounded) |
| `pmp_mpri_sva::a_m_spec_priority` | `prio_3177` | FAIL | **PASS** |

`a_tor_exact` also fails on `tor_own`, and `a_tor_exact_arch` rejects that
variant as well. Those verdicts show that the one-bound edit is incomplete; they
are not evidence about accepting a repair.

## What the other PASS results mean

The remaining PASS cells are regression results only. They do not validate the
correction or the property. Three mechanisms explain them.

### Common-mode dependency

`fv/sva/pmp_ref_sva.sv:19` instantiates `pmp_entry` inside its reference model. A matcher
edit therefore changes the DUT and reference together, leaving their comparison
unchanged. The edited logic is inside the cone of influence, but its effect
cancels. All five covers remain reachable, showing that the checker is
non-vacuous—not that it is sensitive to matcher changes.

### Antecedent excludes the changed behaviour

The assertions in `pmp_sva` are gated by `all_off`. When every entry is OFF,
neither TOR bounds nor locked-entry priority can affect the result.

### Different requirement

- `csr_warl` checks PMP CSR write-legalisation.
- `trap_priv` checks trap routing and `mcause`/`mepc` capture.
- `vm` checks that a PMP denial raises an access exception and prevents a TLB
  fill.

None constrains `mtval`/`stval` contents or reserved bits in non-leaf PTEs.
Their PASS results on `csr_mtval` and `ptw_adu` therefore do not constitute
fix-acceptance. The requirement-linked properties are `mstatus_f5_sva` and
`ptw_pte_sva`; their fix certifications are archived under `evidence/mstatus/`
and `evidence/probe/`.

`vm` is not structurally isolated from PMP. `ptw_pmp_sva` receives
`allow_access` and asserts on it directly. It is insensitive to these particular
PMP edits, not outside PMP's cone of influence.

## Reading cover verdicts

Antecedent reachability establishes non-vacuity, not sensitivity. Every
antecedent cover remains reachable in every column, including cases where a
checker cannot distinguish the edit.

A failed cover can still be the expected result:

- **Antecedent covers** establish that an assertion's precondition remains
  reachable. They must survive a correction; all of them do.
- **Witness covers** describe the defect itself. They should become unreachable
  when the defect is removed. In `prio_3177/probe_pmp_mpri_cover`,
  `c_f7_witness` becomes unreachable on the corrected arbiter, so the cover task
  reports `FAIL` as expected.

This is ordinary formal-debug practice. Only the loss of an antecedent cover
would indicate that a passing assertion had become vacuous; no such loss occurs
in this sweep.

## Reproducing a column

From the repository root, for example:

```sh
patch="$PWD/evidence/matrix/patches/pmp_tor_grain.patch"
git -C cva6 apply "$patch"

cd fv/checks
for checker in pmp_entry pmp_match pmp_ref vm; do
  for task in bmc prove cover; do
    sby -f -d "../../results/matrix/tor_own/${checker}_${task}" \
      "${checker}.sby" "$task"
  done
done
cd ../..

git -C cva6 apply -R "$patch"
```

All five edits are archived in `patches/`; reproduction does not depend on a
mutable fork branch.

## Soundness and scope

- The PMP models contain zero sequential cells. With free inputs, `bmc` decides
  their complete input space; the configured depth is a harness artifact, not a
  verification bound.
- `csr_warl`, `trap_priv`, and `vm` are sequential. Their unbounded results
  come from the `prove` tasks.
- Every task uses a separate `sby` work directory, so one failing assertion
  cannot hide another task's result.
- Each assertion `FAIL` is attributed to a named assertion in its `logfile.txt`;
  the sole cover-task `FAIL` is the expected unreachable `c_f7_witness` described
  above.
- A verdict applies only to the named property and RTL variant. No PASS here, by
  itself, establishes that either the correction or the property is correct.
