# Sail PMP miter: Tier 1 preregistered protocol

Authored 2026-09-12 against the Tier 0 baseline `7ed3e166`, before any
Tier 1 BMC, proof, or cover result was generated. Claims retain the
configuration and domain in [README.md](README.md).

This document records predictions, not results. Before executing Section 1,
all mutation patches, the runner, and the observational-equivalence harness
will be committed together and their hashes recorded in a dated execution
freeze. Before executing Section 2, the ported slice, generated RTL, adapters,
provenance record, and source hashes will likewise be committed together.

After the first result in a section is observed, its protocol and predictions
are immutable. Corrections, deviations, and results are appended as new dated
entries; wrong predictions remain visible.

## 1. Adapter mutation

### Question

Do the c2 properties detect plausible errors in the adapter between the shared
symbolic inputs, CVA6, and generated Sail model?

This experiment qualifies that adapter only. It does not validate the Sail
source, the Sail-to-SystemVerilog translation, or the ISA-to-Sail link.

### Procedure and outcome classes

Each mutant is an archived, localized patch to a fresh copy of
`fv/wrappers/pmp_sail_ref_fv.sv`. No mutant may alter the checker, DUT,
assumptions, or input domain. A baseline run must first reproduce c2 PASS and
all five covers.

Each mutant then runs c2 `bmc`, `prove`, and `cover` in an isolated work
directory. The exact patch, patched-source hash, source manifest, logs, and any
counterexample are archived.

- **Killed:** the mutant elaborates and a named assertion fails. A parse,
  elaboration, timeout, or infrastructure failure is **invalid**, not a kill.
- **Survived:** every c2 assertion still proves. Cover changes are reported
  separately and do not count as kills.
- **Observationally equivalent:** the mutant produces the same Boolean PMP
  decision as the baseline for every input in the domain. For the twelve
  Sail-side mutants, a c2 PASS already proves this: `a_us_equiv` fixes
  `sail_allow` in U/S mode, while `a_m_div_is_f7` and
  `a_f7_implies_div` together fix it in M mode from the unchanged
  `cva6_allow` and `f7_shape`. The direct baseline-versus-mutant miter
  independently checks that implication.
- **Non-equivalent survivor:** c2 proves, but the direct miter finds a changed
  Boolean decision. Within A1–A13, this is possible only for A3 because it
  changes the CVA6 side and therefore also changes signals used to define the
  c2 expectations. Such a result would expose an adapter-sensitivity gap.
- For a Sail-side mutant, c2 PASS combined with a failed direct equivalence check
  would indicate inconsistent domains or experimental plumbing, not a legitimate
  non-equivalent survivor.

An aggregate failing run establishes at least one detecting assertion. It does
not establish that the named assertion is the only detector; any such claim
requires assertion-isolated runs.

For A6 and A7, only the Sail instance's `width_0` connection is changed. The
calculation of `width_bytes`, the alignment and non-wrapping assumptions, and
`a_no_boundary_cross` remain unchanged; otherwise the mutant would change the
proof domain.

### Preregistered mutants and predictions

| ID | Boundary | Fault | Predicted c2 outcome | Expected detector or rationale |
|---|---|---|---|---|
| A1 | Privilege | Sail side: swap U and S | SURVIVE; expected observationally equivalent | `pmpCheck` distinguishes M from non-M, not U from S |
| A2 | Privilege | Sail side: map S to M | KILL | `a_us_equiv` |
| A3 | Privilege | CVA6 side: map S to M | KILL | M-mode classification/direction assertions |
| A4 | Operation | Sail side: swap load and store | KILL | `a_us_equiv` for R/W-asymmetric entries |
| A5 | Operation | Sail side: map fetch to load | KILL | `a_us_equiv` for X/R-asymmetric entries |
| A6 | Width | Connect Sail width as 1 byte | SURVIVE; expected observationally equivalent | all admitted accesses remain inside one G=1 granule |
| A7 | Width | Connect Sail width as 8 bytes | KILL | admitted sub-granule addresses can become partial matches |
| A8 | Address | Sign-extend `pmpaddr` instead of zero-extending it | KILL | high-half bounds change when the implemented top bit is one |
| A9 | `pmpcfg` | Swap R and W on the Sail side | KILL | R/W-asymmetric entries |
| A10 | `pmpcfg` | Clear L on the Sail side | KILL | `a_m_div_is_f7` |
| A11 | Entries | Reverse Sail entry order while preserving each address/config pair | KILL | first-match priority changes |
| A12 | Padding | Make Sail slots 8–63 unlocked NAPOT, all-address, RWX entries instead of OFF | KILL | `a_us_equiv` when the eight implemented entries do not match |
| A13 | Result | Invert the `None`/fault interpretation of `sail_allow` | KILL | output-equivalence and direction assertions |

Two predictions need explicit justification:

- **A1:** in the selected `pmpCheck` function, privilege affects the decision
  only through comparisons with `Machine`; U and S therefore have the same
  observable PMP decision.
- **A6:** at G=1, architectural PMP boundaries are eight-byte aligned. The
  admitted 1/2/4/8-byte accesses are naturally aligned and proven not to cross
  an eight-byte granule. Sail can produce a TOR lower bound that is only
  four-byte aligned when the predecessor is NAPOT and `pmpaddr[i-1][0]` is set.
  The higher-priority NAPOT entry covers that granule first, so the difference
  is unobservable at the final PMP decision.

The predicted equivalents remain in the archive and are excluded from any
mutation-score denominator only if the separate observational-equivalence
proof succeeds.

## 2. Port matrix to frozen current pins

### Pins and pre-run source observations

- `sail-riscv` 0.14: `29e6158f0a88bdb26b9fbcd0718ab919449b5179`
- Sail compiler 0.20.2
- CVA6 master snapshot: `49b5fa9e2f5a803cd52f8430d8e8818089e68865`
- CVA6 configuration: `cv64a6_imafdc_sv39`, PLEN 56, eight PMP entries

At these pins, CVA6 master's `pmp_entry.sv` is byte-identical to the c2
corrected file, while `pmp.sv` still filters unlocked entries before priority;
upstream issue #3177 remains open. Between `sail-riscv` 0.12 and 0.14,
`pmpReadAddrReg`, address matching, first-match priority, and the Machine-mode
tests used here are unchanged. Port-relevant changes include constructor
arities, logging, surrounding configuration machinery, and a new
`LoadExecute(Data)` permission arm requiring R and X. `LoadExecute` represents
HLVX accesses, which are outside this domain.

The 0.14 slice is re-derived with the same declared specialization. Every
non-verbatim edit is recorded in `fv/sail/PROVENANCE` before the first formal
run. The generated SystemVerilog must reproduce byte-for-byte from the pinned
compiler. The 0.12/v5.3.0 columns remain unchanged.

### Separating model drift from RTL drift

Sail and CVA6 are not upgraded in one inseparable step. The following matrix is
run so a changed result can be attributed to the Sail port, the CVA6 port, or
their interaction.

| Column | Sail model | CVA6 RTL | Prediction |
|---|---|---|---|
| P0 — existing c2 | 0.12 | v5.3.0 + #3490 | every c2 assertion proves; 5/5 covers |
| P1 — Sail-only port | 0.14 | v5.3.0 + #3490 | every c2 assertion proves; 5/5 covers |
| P2 — CVA6-only port | 0.12 | master snapshot | every c2 assertion proves; 5/5 covers |
| P3 — current/current | 0.14 | master snapshot | every c2 assertion proves; 5/5 covers |
| P4 — corrected priority | 0.14 | master snapshot + archived #3177 patch | `a_full_equiv` proves; only `c_m_divergence` is unreachable |

If a one-axis column cannot elaborate without importing a change from the other
axis, it is reported as unavailable with the reason; it is not silently omitted
or replaced by P3.

The #3177 patch is used unchanged if it applies. Otherwise, its rebase is
archived and reviewed before P4 runs. A1–A13 are then recreated as the same
semantic faults against the P3 adapter, frozen together before execution, and
predicted to retain their Section 1 outcomes.

These are stability results for the frozen pins and stated domain. They do not
generalize to moving `master`, other CVA6 configurations, or ISA conformance.

## 3. Later experiments

The following experiments require their own dated, immutable protocol entries
before execution:

1. **Leaf discrepancy:** construct the formal leaf counterexample, reproduce it
   first on `sail-riscv` 0.14, and then prove or refute its disappearance at the
   composed PMP decision boundary. No upstream report is based on 0.12 alone.
2. **Native Sail versus generated SystemVerilog:** freeze the common input
   corpus, output projection, mismatch rule, simulator/compiler pins, and seeded
   backend faults before the first differential run.

## Dated amendments and results

Append entries here. Do not rewrite the protocol or predictions above.

### 2026-09-12: Section 1 execution freeze

Committed together before any Section 1 bmc, prove or cover run:

| File | sha256 |
|---|---|
| `fv/validation/sail_mutation.sh` | `894fe3b60da01d1ee45a9706f7d09a9df00f2971311189326113a38489943a15` |
| `fv/validation/sail_mut_eq_fv.sv` | `87ced4caa39cf018a0f93b3c3834a10e520cba1ab8868c28f2ee11c1823a008a` |
| `evidence/sail/mutation/patches/A1.patch` | `f9a7848a7b2f50087c27abfe2985f96d1d5fdc090cf98ee501658d9d5abf255d` |
| `evidence/sail/mutation/patches/A2.patch` | `6b9c21e6ad86326b27069f2146743b78d373522dec9d382ec05fbf419eaf508a` |
| `evidence/sail/mutation/patches/A3.patch` | `75a1f0d1d3a39b30f2aed7bf394cebd714fb3b0c51d9c411a00f9de8605f7d70` |
| `evidence/sail/mutation/patches/A4.patch` | `8725282646edcaf1f051433acfd7bf88fbaad19aba05747903aee1ee7ffccb67` |
| `evidence/sail/mutation/patches/A5.patch` | `afaee4e33670bea40608b9cfc4ed2ac211c502efb1503be3a04c483feae43052` |
| `evidence/sail/mutation/patches/A6.patch` | `55e034d6f29641ed6443f37c59d8ab52e3390b92eccd41e14d1b06efe078e0d7` |
| `evidence/sail/mutation/patches/A7.patch` | `e2667b215a5ef65aee67b90f91eff96586f968b6efe3b631c839a9a0cec5b86c` |
| `evidence/sail/mutation/patches/A8.patch` | `320a81c472d679fb378efc5a2d63330ab8ca07405ab3890df655abf6a68e688a` |
| `evidence/sail/mutation/patches/A9.patch` | `d34aa46aef09e9f7c2fcf43e8df096d721a07cec8722f8d59c9c0b448959f450` |
| `evidence/sail/mutation/patches/A10.patch` | `e33e2c485db0a04a60a876b57aa30f22489d3f36a5b5e8155a6458f2afc13053` |
| `evidence/sail/mutation/patches/A11.patch` | `b86cca4b76117074524bca8a31fbe31b0c9529019f8366cd90bc040127cbf396` |
| `evidence/sail/mutation/patches/A12.patch` | `b523f93aa8a9a3f18a6ee772c89fad17d1fe2719382a304033cf9bff69cc54dd` |
| `evidence/sail/mutation/patches/A13.patch` | `7535fcdc585b854bf8d03f07ba570de54caf5eb9fbdc1b232959ed5a6ca9f168` |

Everything else these runs read is unchanged since tag `sail-tier0`.

Plumbing check, 2026-09-12: all 13 patches apply, and the c2 and equivalence
builds of the baseline and every mutant elaborate in yosys with empty logs. No
bmc, prove or cover task was run.

The runner checks every result against the predictions above. The direct
equivalence miter runs for all 13 mutants, and for the baseline against itself,
not only for survivors. CI job `sail-mutation` (manual dispatch) runs the same
runner.

### 2026-09-12: Section 1 results

Run on the frozen commit `8b9deeb` after its CI passed. Logs, source hashes and
witnesses: `evidence/sail/mutation/`, one directory per run, and `summary.txt`.

| ID | c2 | Detecting assertions | Direct equivalence | Prediction |
|---|---|---|---|---|
| baseline | all PASS, 5/5 covers | — | equal to itself | holds |
| A1 | survived | — | equal | holds |
| A2 | killed | `a_us_equiv` | differs | holds |
| A3 | killed | `a_div_sail_allows`, `a_m_div_is_f7` | differs | holds |
| A4 | killed | `a_us_equiv`, `a_m_div_is_f7` | differs | holds |
| A5 | killed | `a_us_equiv`, `a_div_sail_allows` | differs | holds |
| A6 | survived | — | equal | holds |
| A7 | killed | `a_f7_implies_div` | differs | holds |
| A8 | killed | `a_div_sail_allows`, `a_m_div_is_f7` | differs | holds |
| A9 | killed | `a_m_div_is_f7` | differs | holds |
| A10 | killed | `a_m_div_is_f7` | differs | holds |
| A11 | killed | `a_m_div_is_f7` | differs | holds |
| A12 | killed | `a_us_equiv` | differs | holds |
| A13 | killed | `a_us_equiv` | differs | holds |

Every prediction held. All 11 mutants that change a decision are killed; A1 and
A6 are proven observationally equivalent, so they leave the score. No invalid
run, no non-equivalent survivor. Every mutant still reaches all 5 covers
(reported, not counted). Every model has zero registers, so each prove verdict
covers the whole domain. Detecting assertions are the ones the bmc and prove
runs name, not a claim that they are the only detectors.

### 2026-09-13: Section 2 execution freeze

Committed together before any Section 2 bmc, prove or cover run:

| File | sha256 |
|---|---|
| `fv/validation/sail_port.sh` | `4abeb15e0932131d48c95a1d39abe72a5e244eca77da6116306f6dc201f85c65` |
| `third_party/ported/SHA256SUMS` | `ef37ea09d7791bf06de5c5a058fbc0bf2d0a4ebb17e7c587b1f70e447f80b490` |
| `third_party/ported/ported.sh` | `c7b6f41c774d7fc3669b70a2fd4145fa9f1166f0dec693c9c6f8595fece71385` |
| `fv/sail/slice_0_14/errors.sail` | `2d848d05bd6b20ccfeb054d639aef4c2e03692aa1dfb5d356544e99ecae97d3a` |
| `fv/sail/slice_0_14/pmp_base.sail` | `4b3fbf3bf115d89a6f27272bcfc3488ecf0ba5a53428ee530ee289dc86f66f3a` |
| `fv/sail/slice_0_14/pmp_control.sail` | `a02791151431bc4e071b305d1d66584deb60989d3452048ad6a179cde8afa0ee` |
| `fv/sail/slice_0_14/pmp_hw.sail` | `828ca1bad60cb3667d753398c0b66198ea2c0c5981bb080c6d000fbadc2345d1` |
| `fv/sail/slice_0_14/pmp_slice_prelude.sail` | `496df65ebf0dd435e173dfa2067e9f48bff6165d41e03c870ab255fc2fe49b19` |
| `fv/sail/generated/sail_pmp_0_14.sv` | `530121fe454c4355cc30b6ab189a4566eca80551065653509330a660a97cd860` |
| `fv/sail/PROVENANCE` | `80c754a415f1ae26e64142d701bfdb571b80e7c21816e0b74b0f2f3d4ece502f` |
| `fv/sail/regen.sh` | `e2e05cacaf9b6c7ba732789eb1fe9d4b3f89f6478b782bfd2cf371f3acce17ec` |
| `fv/sail/provenance.sh` | `72b714a3db2e2158011e07b8d560125f153060401bdb1e7490b1ae9fe3bdb9d7` |

`SHA256SUMS` pins the 22 exact copies from sail-riscv `29e6158` and CVA6
`49b5fa9e` in `third_party/ported/`; CI job `ported-sources` re-fetches both
commits and byte-compares every copy. The non-verbatim edits of the 0.14 slice
are listed in `PROVENANCE`. The wrapper, checker, equivalence harness and A1-A13
patches are unchanged since the Section 1 freeze (`8b9deeb`): they are the P3
adapter and faults as they are. The #3177 patch applies to master `pmp.sv`
unchanged (2-line offset).

Pre-run checks, 2026-09-13: `regen.sh 0.12 --verify` reproduces the committed
SV byte for byte; `provenance.sh` passes for 0.12 and 0.14; the five columns and
the 28 P3 mutant builds elaborate in yosys with empty logs. No bmc, prove or
cover task was run.

The runner checks every column and mutant against the predictions above. CI job
`sail-port` (manual dispatch) runs the same runner.

### 2026-09-13: Section 2 results

Run on the frozen commit `f2b6821` after its CI passed. Logs, source hashes and
witnesses: `evidence/sail/port/`, one directory per run, and `summary.txt`.

| Column | Sail | CVA6 | bmc | prove | cover | Prediction |
|---|---|---|---|---|---|---|
| P0 | 0.12 | v5.3.0 + #3490 | PASS | PASS | 5/5 | holds |
| P1 | 0.14 | v5.3.0 + #3490 | PASS | PASS | 5/5 | holds |
| P2 | 0.12 | master `49b5fa9e` | PASS | PASS | 5/5 | holds |
| P3 | 0.14 | master `49b5fa9e` | PASS | PASS | 5/5 | holds |
| P4 | 0.14 | master + #3177 patch | PASS | PASS | 4/5, only `c_m_divergence` unreached | holds |

| ID | c2 on P3 | Detecting assertions | Direct equivalence | Prediction |
|---|---|---|---|---|
| baseline | all PASS, 5/5 covers | — | equal to itself | holds |
| A1 | survived | — | equal | holds |
| A2 | killed | `a_us_equiv` | differs | holds |
| A3 | killed | `a_div_sail_allows`, `a_m_div_is_f7` | differs | holds |
| A4 | killed | `a_div_sail_allows`, `a_us_equiv` | differs | holds |
| A5 | killed | `a_div_sail_allows`, `a_m_div_is_f7` | differs | holds |
| A6 | survived | — | equal | holds |
| A7 | killed | `a_div_sail_allows`, `a_m_div_is_f7` | differs | holds |
| A8 | killed | `a_f7_implies_div` | differs | holds |
| A9 | killed | `a_div_sail_allows`, `a_m_div_is_f7` | differs | holds |
| A10 | killed | `a_m_div_is_f7` | differs | holds |
| A11 | killed | `a_us_equiv` | differs | holds |
| A12 | killed | `a_us_equiv` | differs | holds |
| A13 | killed | `a_f7_implies_div` | differs | holds |

Every prediction held. On CVA6 master `49b5fa9e` with sail-riscv 0.14 (P3) every
c2 theorem proves; with the #3177 patch (P4) full equivalence proves. P1 and P2,
which change one axis at a time, match P0. Every mutant keeps its Section 1
outcome; seven (A4, A5, A7, A8, A9, A11, A13) name different detecting
assertions than in Section 1, because a run names only what its own
counterexample violates and the designs differ. No invalid run. Every prove
model has zero registers, so each prove verdict covers the whole domain.

### 2026-09-14: Section 3.1 preregistration, TOR predecessor grain bit

This entry was written before any Section 3.1 bmc, prove or cover run. It
formalizes a discrepancy already identified by source inspection and noted in
`evidence/sail/README.md`; it is not a blind discovery experiment. After
execution begins, the predictions stay unchanged; corrections and results are
appended as dated entries.

#### Question

At G=1, Sail uses `pmpReadAddrReg(i-1)` as entry i's TOR lower bound. When
entry i-1 is NAPOT, that value retains `pmpaddr[i-1][0]`. The ratified
specification states that `pmpaddr[G-1:0]` does not affect TOR matching, and
riscv-isa-manual issue #884 confirms that this includes a register used as the
following entry's lower bound.

The experiment asks:

1. Can Sail's per-entry TOR match differ from the match obtained after clearing
   that predecessor bit?
2. If so, can replacing Sail's predecessor value with the specification-derived
   value change the Boolean allow/deny decision returned by `pmpCheck`?

#### Source observations before execution

- Primary Sail model: sail-riscv 0.14, `29e6158f0a88bdb26b9fbcd0718ab919449b5179`.
- Historical replication: sail-riscv 0.12, `65ddde80ee2b131bf46c20e6e748343c336c4071`.
- At the time of writing, sail-riscv master is
  `22fad389cb0ca92ef8f3cfff91fe258f14ee8de8`; its `model/pmp/pmp_control.sail`
  and `model/pmp/pmp_regs.sail` are byte-identical to 0.14.
- Specification: riscv-isa-manual `be8cb008612ce2ac1712e4ba3f09fc2109c0d462`,
  `src/priv/machine.adoc:3519-3528`.
- Issue #884 was closed on 2025-12-09 after confirming that the TOR grain rule
  covers both uses of a PMP address register: as its entry's upper bound and as
  the following entry's lower bound.

#### Design

Sail only; no CVA6 RTL is present. Files:

- `fv/wrappers/sail_leaf_fv.sv`
- `fv/sva/sail_leaf_sva.sv`
- `fv/wrappers/sail_leaf_shim_0_12.sv` and `fv/wrappers/sail_leaf_shim_0_14.sv`
- `fv/checks/sail_leaf.sby` for 0.14
- `fv/checks/sail_leaf_0_12.sby` for 0.12

The harness instantiates `pmpCheckHw` and, for each slot used by its 16-entry
loop, the generated `pmpReadAddrReg`, `pmpMatchAddr`, `pmpCheckRWX` and
`pmpLocked` helpers.

The generated 0.12 and 0.14 helper interfaces differ in two mangled port names:
the `pmpMatchAddr` physical-address input and the `pmpCheckRWX` exception
outputs. Each `.sby` file selects its version's shim, which connects the helpers
by named ports. Positional port mapping is not used.

For each entry i:

- `effective[i]` is the result of `pmpReadAddrReg(i)`.
- `m_sail[i]` is `pmpMatchAddr` using `effective[i-1]` as the predecessor when i > 0.
- `m_arch[i]` is the same call, except predecessor bit 0 is cleared.
- `decide(m)` reproduces `pmpCheck`'s first-result rule: NoMatch continues;
  PartialMatch denies; Match allows only when RWX grants the operation, or when
  privilege is M and the entry is unlocked; no match allows only M-mode.

The comparison projects results to Boolean allow/deny. It does not compare
exception causes or other payload fields.

#### Domain

- G=1, PLEN=56.
- Eight symbolic implemented PMP entries; slots 8-63 are fixed OFF.
- The specialized Sail decision loop examines slots 0-15.
- Reserved configuration bits are zero; NA4 is excluded; W=1, R=0 is excluded.
- Operations are `Load(Data)`, `Store(Data)` and `InstructionFetch`.
- Privileges are U, S and M.
- Width is any integer from 1 through 4096 bytes, the range admitted by the
  specialized `pmpCheck` source type.
- Any alignment is admitted.
- The access interval may not wrap past the top of the 56-bit physical-address space.

The generated SystemVerilog port does not retain Sail's dependent width type, so
the wrapper explicitly assumes `1 <= width <= 4096`. This domain is intentionally
wider than the CVA6 miter's naturally aligned 1/2/4/8-byte domain.

Define `c2_domain` as a width in {1, 2, 4, 8} that is naturally aligned and
non-wrapping.

#### Preregistered properties

| Name | Statement | Prediction |
|---|---|---|
| `a_decide_faithful` | `decide(m_sail)` equals the Boolean result of `pmpCheckHw` | PROVE |
| `a_leaf_unobservable` | `decide(m_arch) == decide(m_sail)` | PROVE |
| `a_leaf_shape` | For i = 1..15, a leaf mismatch implies entry i is TOR, entry i-1 is NAPOT, and raw `pmpaddr[i-1][0]` is one | PROVE |
| `a_leaf_preempted` | A leaf mismatch at i implies the predecessor has the same non-NoMatch result in both vectors, so entry i cannot decide either composition | PROVE |
| `a_partial_outside_c2_domain` | A leaf mismatch with a predecessor PartialMatch implies the access is outside `c2_domain` | PROVE |
| `a_top_no_internal_exception` | `pmpCheckHw` raises no internal Sail exception | PROVE |
| `a_helpers_no_internal_exception` | Every directly instantiated `pmpMatchAddr` and `pmpCheckRWX` raises no internal Sail exception | PROVE |
| `c_leaf_diff_aligned4` | A 4-byte, 4-byte-aligned access reaches `m_sail[i] = NoMatch`, `m_arch[i] = Match`, with the predecessor returning Match | REACHED |
| `c_leaf_diff_partial` | A leaf mismatch is reached with the predecessor returning PartialMatch | REACHED |

The first cover supplies a small, aligned witness suitable for an upstream
report. The second establishes that PartialMatch preemption is reachable in the
wider domain. The "only outside `c2_domain`" claim rests on
`a_partial_outside_c2_domain`, not on the cover.

#### Predicted task verdicts

For both 0.14 and 0.12:

| Task | Predicted result |
|---|---|
| `bmc` | PASS |
| `prove` | PASS |
| `cover` | PASS, both named covers reached |

Every proof model is predicted to contain zero registers. The result gate checks
the two cover names individually rather than accepting an aggregate cover status
alone.

#### Interpretation rules

- If `a_decide_faithful` fails, no composed-equivalence conclusion is drawn.
- If either internal-exception assertion fails, the affected run is an invalid
  harness result until diagnosed.
- A reached leaf-difference cover establishes a component-level discrepancy only.
- `a_leaf_unobservable` establishes observational equivalence only for the single
  predecessor-bit transformation, Boolean PMP allow/deny, and the domain above.
- No result validates Sail source against the ISA generally or validates the
  Sail-to-SystemVerilog translation generally.
- Every failed prediction is reported; no failed or inconvenient case is removed
  from the result set.

#### Freeze and execution

Before any bmc, prove or cover run:

1. Perform elaboration-only checks for both generated-model versions.
2. Freeze the wrapper, checker, both `.sby` files, both version shims, the CI
   assumption gate and the README change.
3. Record their SHA-256 hashes and the execution commit in a dated freeze entry.
4. The CI assumption gate allows assumptions only in
   `fv/wrappers/pmp_sail_ref_fv.sv` and `fv/wrappers/sail_leaf_fv.sv`, checks
   the expected assumption count in each file separately, and fails on
   assumptions anywhere else under `fv/`.

After execution, archive each isolated work directory's `sources.sha256`, logs,
witnesses and the register-count check under `evidence/sail/leaf/`. Append
results without editing this protocol. Only then add both `.sby` files to the
permanent `verify-sail` matrix.

#### Scope

The result covers Sail's PMP decision for G=1, PLEN=56, eight symbolic
implemented entries in the specialized 16-entry model, the stated legal CSR
snapshots, Data loads and stores, instruction fetches, widths 1-4096, and
non-wrapping addresses.

It does not cover other grains, entry counts, physical-address widths, access
constructors, virtual privilege modes, exception payload equivalence,
native-Sail versus generated-SystemVerilog fidelity, or general ISA conformance.

#### Upstream reporting

An upstream report is prepared only after:

1. the 0.14 results are complete;
2. current Sail master is checked again;
3. the duplicate search is repeated, including open PMP work such as #1651;
4. the aligned 4-byte witness and the composed-equivalence proof are archived.

The report describes a "per-entry TOR-bound discrepancy that is semantically
inert at the composed `pmpCheck` decision because the preceding NAPOT result
terminates first". It does not call the behavior a Sail defect or claim an
architectural decision mismatch. If master changes before filing, the
experiment is rerun on the new code.
