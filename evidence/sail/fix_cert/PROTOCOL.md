# Fix certification: `riscv/sail-riscv#1959`

This is post-freeze confirmation, not a new discovery experiment. Tier 1
Section 3.3 closed the experimental scope in
[`../TIER1_PROTOCOL.md`](../TIER1_PROTOCOL.md); nothing here is appended to or
counted as part of that experiment.

The question is narrow: does the correction submitted as
`riscv/sail-riscv#1959` remove the Section 3.1 leaf discrepancy, and does the
Section 3.3 extracted oracle accept the corrected CVA6 matcher once Sail is
corrected?

## Correction under test

For TOR entry `i`, `pmpCheck` passes `pmpReadAddrReg(i-1)` to
`pmpMatchAddr` as the lower bound. When entry `i-1` is NAPOT, low grain bits in
that readback may be nonzero even though the privileged specification says
they do not affect TOR matching. `riscv-isa-manual#884` confirms that the rule
applies when a PMP address register supplies either TOR bound.

The discrepancy was reported as `riscv/sail-riscv#1951`. The proposed
correction is `riscv/sail-riscv#1959`, head `25002553`, currently labelled
`will be merged`. It normalizes both TOR bounds inside `pmpMatchAddr` without
changing CSR readback behavior.

## Execution gate

No BMC, prove, or cover task runs before the pull request merges.

Before execution:

1. Pin the merged commit and the SHA-256 of its
   `model/pmp/pmp_control.sail`.
2. Confirm that the merged PMP hunk is identical to head `25002553`.
3. If maintainers changed the hunk, append a dated amendment, update the
   specialization patch and hashes, and refreeze before running.
4. Record the hashes of the specialized slice and regenerated SystemVerilog.

The results must not be described as certification of the merged correction
unless these checks pass.

## Method

The canonical `fv/sail/slice_0_14/`, `fv/sail/generated/`, and
`fv/sail/PROVENANCE` remain unchanged.

`regen.sh <outdir>` changes only the output directory; it still reads the slice
beside the script. The certification therefore uses a private working copy:

1. Copy `fv/sail/` to `results/sail_fixcert/work/fv/sail/`.
2. Dry-run and then apply `slice_0_14_fix.patch` with
   `-p1 -d results/sail_fixcert/work`.
3. Run the copied `regen.sh 0.14`, writing generated files to
   `results/sail_fixcert/generated/`.
4. Run the three `fixcert_*.sby` files directly into
   `results/sail_fixcert/`.
5. Curate the checked logs, verdict markers, source hashes, and traces manually
   into `evidence/sail/fix_cert/`.

`make evidence` is not used because it re-sweeps every result category. The
`fixcert_` prefix also keeps these files outside the `sail*.sby` glob expanded
by `make verify-sail`. The GitHub Sail matrix is explicit, so these one-off
checks do not enter permanent CI.

The slice patch is a mechanical specialization of #1959. Upstream passes
`sys_pmp_grain`; the slice fixes `G=1`, so the specialized call passes literal
`1`. The upstream `$[test]` and `private` qualifier are not copied because the
slice has no native unit-test runner and does not preserve private visibility.
No PMP decision logic differs otherwise.

The frozen Section 3.1 and 3.3 wrappers are reused unchanged. They instantiate
their property modules by bare module name, so the `fixcert_` checker files
declare the same module names and port lists as the frozen checkers.

## Frozen inputs

The following files were frozen together before any BMC, prove, or cover task:

| File | SHA-256 |
|---|---|
| `fv/sva/fixcert_leaf_sva.sv` | `a177dc4aad80be145989abf43cb9e300833a685e499f16c4caa7d793234bc74a` |
| `fv/sva/fixcert_oracle_sva.sv` | `d965d8dfb87d1076115d42a4071467f90531e1f9694285d9730c9fb3cf684c79` |
| `fv/checks/fixcert_leaf.sby` | `723b1e8c8b12dc84e39262a7553ef7fa7750dbaebb3a1cfa22a5354191c40278` |
| `fv/checks/fixcert_oracle.sby` | `f361aaaa208f7b35ff0c81aa729a45f2998acf2bf0a45f5d26091fc46f231924` |
| `fv/checks/fixcert_oracle_reject.sby` | `da415635177271d14822e8104b26c4a6a43e8becda126a45b91b8823b19110de` |
| `evidence/sail/fix_cert/slice_0_14_fix.patch` | `48a6c44e13364866cea8fb6fb6650019d9a7d3c8c6f1338f0df3205e373c6775` |

The patch applies to this frozen 0.14 slice:

| File | SHA-256 |
|---|---|
| `fv/sail/slice_0_14/pmp_control.sail` | `a02791151431bc4e071b305d1d66584deb60989d3452048ad6a179cde8afa0ee` |
| `fv/sail/slice_0_14/pmp_slice_prelude.sail` | `496df65ebf0dd435e173dfa2067e9f48bff6165d41e03c870ab255fc2fe49b19` |
| `fv/sail/slice_0_14/pmp_hw.sail` | `828ca1bad60cb3667d753398c0b66198ea2c0c5981bb080c6d000fbadc2345d1` |
| `fv/sail/slice_0_14/pmp_base.sail` | `4b3fbf3bf115d89a6f27272bcfc3488ecf0ba5a53428ee530ee289dc86f66f3a` |
| `fv/sail/slice_0_14/errors.sail` | `2d848d05bd6b20ccfeb054d639aef4c2e03692aa1dfb5d356544e99ecae97d3a` |

The #3490 `pmp_entry.sv`, Section 3.1 shim, wrappers, and other unchanged
dependencies remain those of the Section 3.3 freeze. Each archived work
directory records the complete elaborated source set in `sources.sha256`.

## Pre-run checks

On 2026-09-21, all three models elaborated in yosys-slang with zero errors and
zero warnings. Yosys `check` reported no problems, and none of the models
contained a register or latch. No BMC, prove, or cover task was run.

These checks establish only that the frozen plumbing elaborates. They disclose
no solver verdict.

## Added properties

The frozen `sail_leaf_sva.sv` and `sail_oracle_sva.sv` remain unchanged. Their
`fixcert_` counterparts add:

| Property | Checker | Statement |
|---|---|---|
| `a_no_leaf_diff_after_fix` | leaf | Every slot's Sail match equals the externally bit-masked match. |
| `c_relevant_tor_after_napot` | leaf | A TOR entry after a NAPOT predecessor with raw `pmpaddr[0]=1` remains reachable. |
| `c_aligned4_extracted_accepts` | oracle | The Section 3.3 rejection class, an aligned four-byte access with a TOR entry after a NAPOT predecessor with raw `pmpaddr[0]=1`, is reached with corrected CVA6 matching and fixed Sail returning `Match`. |

Both new covers pin the TOR-after-NAPOT configuration. The leaf cover keeps it
reachable in the leaf harness; the oracle cover requires that same class to be
reached with an acceptance outcome, so it witnesses the Section 3.3 rejection
class being accepted rather than merely some acceptance existing. The old
defect-witness covers are expected to become unreachable, while both new
reachability covers must survive.

The oracle cover's reachability is not assumed: the Section 3.3 aligned witness
is already an input of exactly this class, differing only in that the unfixed
helper returned `NoMatch` there.

## Structural consequence in the leaf harness

`sail_leaf_fv.sv` instantiates the same leaf matcher twice, differing only in
whether the predecessor is passed directly or with bit 0 cleared. Once the
matcher performs that normalization internally, the external mask is
redundant and the two instances compute the same function.

Consequently, after the fix:

- `a_no_leaf_diff_after_fix` and `a_leaf_unobservable` are structural checks;
- `a_leaf_shape`, `a_leaf_preempted`, and
  `a_partial_outside_c2_domain` are vacuous;
- the old leaf-difference covers are unreachable.

These results are expected but are not independent evidence. The load-bearing
leaf checks are `a_decide_faithful`, which still ties the reconstructed
first-match loop to generated `pmpCheckHw`, and
`c_relevant_tor_after_napot`, which keeps the relevant configuration
reachable.

The oracle comparison remains independent at its boundary: `cva6_match` is
computed by CVA6 `pmp_entry` RTL from the raw PMP inputs, while `m_sail` is
computed by generated Sail logic. The certification rests on
`a_extracted_sail_leaf_equiv` changing from FAIL on the frozen Section 3.3
model to PASS here, with the positive acceptance cover reached.

## Predictions

| Check | BMC | Prove | Cover |
|---|---:|---:|---|
| `fixcert_leaf` | PASS | PASS | Expected FAIL: `c_relevant_tor_after_napot` reached; `c_leaf_diff_aligned4` and `c_leaf_diff_partial` unreachable. |
| `fixcert_oracle` | PASS | PASS | Expected FAIL: `c_aligned4_extracted_accepts` reached; `c_aligned4_extracted_rejects` unreachable. |
| `fixcert_oracle_reject` | PASS | PASS | Expected FAIL with the same named-cover accounting. |

`fixcert_oracle_reject` is the headline paired result:
`a_extracted_sail_leaf_equiv` failed on the unfixed Section 3.3 model and is
predicted to pass after the correction.

All three models are combinational. With zero registers, depth 2 covers the
complete stated symbolic domain rather than a bounded execution prefix.

Every aggregate verdict and named-cover result must match the table. Any
unexpected result stops the certification and must be diagnosed; no cause is
inferred merely from an aggregate PASS or FAIL.

## Interpretation

Within the checked G=1 domain, a successful certification establishes that:

- the extracted Sail leaf oracle accepts the corrected CVA6 matcher after the
  Sail correction;
- the TOR-after-NAPOT input class that produced the Section 3.3 rejection
  remains reachable, and is reached with an acceptance outcome in the oracle
  harness;
- the reconstructed first-match decision still agrees with generated
  `pmpCheckHw`.

It does **not** establish:

- decision neutrality. The old-versus-corrected decision-equivalence result is
  the frozen Section 3.1 proof and is not re-derived here;
- independent confirmation from the post-fix leaf comparison, whose two match
  instances become structurally identical;
- anything about sail-riscv 0.12, for which applying the correction would be a
  semantic backport;
- a new composed-miter result. Existing c2/P1 results and Section 3.1 provide
  the related decision-level argument within their respective domains, but
  this certification does not rerun it;
- native-Sail versus generated-SystemVerilog translation fidelity, which
  Section 3.2 left deferred;
- any result outside G=1 or the frozen Section 3.1/3.3 domains.

## Deliberate exclusions

The 0.12 backport, a composed-miter rerun, permanent CI integration, and any
new discovery claim are excluded as diminishing-return work outside the frozen
research scope.

## Dated amendments and results

### 2026-09-21: execution preparation

The execution gate governs the `fixcert_*` tasks only; CI keeps running the
frozen suite.

From a clean checkout, before the first `fixcert_*` task:

1. Start from an empty `results/sail_fixcert/`, so the working copy is rebuilt
   from the frozen inputs.
2. Initialize the `cva6` submodule.
3. Run `make sail-rtl`. It builds `results/sail_rtl/pr3490/pmp_entry.sv`, which
   both oracle `.sby` files read; its SHA-256 must be
   `d460cad15eafe78c9c1de689238ec4579279ef28c556d8ac231715afff84c702`.

`make sail-rtl` only applies the frozen #3490 patch; it runs no solver and
discloses no result. The regenerated `sail_pmp_0_14.sv` must hash to
`d0e0400debfe9815776d138223f5114fbe50efba92e35d9e6205dae79b83147a`, the file
elaborated in the pre-run checks, and `sail_modules.sv` must match `PROVENANCE`.
