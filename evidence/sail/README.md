# CVA6 PMP vs the Sail golden model

Every other proof here checks CVA6 against properties *we* wrote. This one checks
it against the RISC-V Sail model, a formal executable model of the architecture
adopted by RISC-V International: `sail-riscv`'s PMP decision function, compiled
to SystemVerilog and mitered against CVA6's `pmp.sv`.

The miter has no registers (CI checks the model), so `prove` at depth 2 is
exhaustive over the domain below, not a bounded search. Pins and patches:
`versions.txt`. Each result directory lists the files it elaborated in
`sources.sha256`.

## Properties

| | Statement |
|---|---|
| A `a_us_equiv` | `priv != M` implies `sail_allow == cva6_allow` |
| B `a_m_div_is_f7` | in M, a divergence implies the F7 shape |
| C `a_f7_implies_div` | in M, the F7 shape implies a divergence |
| `a_div_sail_allows` | any divergence is Sail allowing what CVA6 denies |
| `a_amatch_arch` | the matcher the F7 shape uses, the DUT's own `pmp_entry`, equals the architectural match relation |
| `a_full_equiv` | `sail_allow == cva6_allow`; c3 only, in place of B and C |

F7 is the M-mode lock-before-priority defect, upstream #3177: the lowest
matching entry is unlocked and the first locked matching entry denies the
access. `a_amatch_arch` encodes the G=1 rule that bit 0 of a `pmpaddr` never
affects TOR matching, for either bound and whatever the predecessor's mode
(riscv-isa-manual #884), and decodes NAPOT as PMP-6 does. It makes the F7 shape
an architectural statement rather than a restatement of the DUT.

## Results

One command, no source edits: `make verify-sail`. The c2 and c3 RTL is the
golden file with the archived patch applied to a copy (`make sail-rtl`).

| Column | RTL | bmc | prove | cover |
|---|---|---|---|---|
| c1 `sail_pmp_*` | v5.3.0 | FAIL | FAIL | PASS 5/5 |
| c2 `sail_pmp_tor_*` | + #3490 | PASS | **PASS** | PASS 5/5 |
| c3 `sail_pmp_full_*` | + #3490 + #3177 | PASS | **PASS** | FAIL: only `c_m_divergence` unreached |

**c2 is the headline.** Its patch is merged upstream. Every property holds: CVA6
agrees with Sail in S and U mode; in M mode the two differ exactly when the F7
shape holds, and only ever with Sail allowing what CVA6 denies. Because
`a_amatch_arch` holds, the F7 shape is stated over the architectural match
relation, so the M-mode divergence set is exactly the #3177 pattern.

c3 adds our own #3177 patch and proves `a_full_equiv`: nothing diverges, so
`c_m_divergence` is unreachable by proof and is the cover run's only miss (CI
checks that it is the only one).

c1 fails on golden, reporting `a_amatch_arch`: the TOR grain-bit defect (#3342)
that #3490 fixes. A `prove` FAIL names only the assertion that fired.

## Domain

Free inputs, with five assumptions in `pmp_sail_ref_fv.sv`. Three are CSR
invariants proven separately in `csr_warl` on `pmpcfg_q`, the register that
drives `conf_i` in the core; that link is argued, not part of this proof:

| Assumption | Proven in `csr_pmp_sva` as |
|---|---|
| `cfg.reserved == 0` | `a_reserved_zero` |
| `cfg.addr_mode != NA4` | `a_never_na4` |
| `!(W && !R)` | `a_never_r0w1` |

The other two are restrictions, not proven: the access is naturally aligned and
does not wrap the top of the physical address space.

| Input | CVA6 `pmp.sv` | Sail `pmpCheckHw` |
|---|---|---|
| operation | read / write / execute | `Load(Data)` / `Store(Data)` / `InstructionFetch` |
| privilege | U / S / M | `User` / `Supervisor` / `Machine` |
| address | 56-bit physical | the same 56 bits |
| width | none: one address | `1 << size_lg2` = 1, 2, 4 or 8 bytes |
| entries | 8 | the same 8; slots 8–63 held OFF |
| `pmpcfg` | `pmpcfg_t`: L, reserved, A, X, W, R | `Pmpcfg_ent`: the same 8 bits, copied as-is |
| `pmpaddr` | 54 bits | zero-extended to 64 |
| result | `allow_o` | `None` means allow |

The 2-bit operation and privilege inputs alias: encoding 3 means execute / M,
the same as 2.

## Scope

Agreement with generated `sail-riscv` **0.12** for `cv64a6_imafdc_sv39` at G=1
with 8 entries, over the domain above. Not ISA conformance: whether Sail matches
the specification is outside the proof, and at one leaf point it does not. For a
TOR entry whose predecessor is NAPOT, Sail's lower bound keeps bit 0, where #884
says it is ignored. That never changes a decision, because the NAPOT predecessor
covers the word with higher priority.

Sail checks every byte of the access, and `a_no_boundary_cross` proves an
aligned access stays inside one 8-byte granule, so CVA6's single-address
decision covers the whole access. Misaligned, wrapping, wider and multi-part
accesses are excluded, as are LR/SC, AMOs, HLVX, shadow-stack and cache-block
operations and the virtual privilege modes.

The RTL is v5.3.0 plus the archived patches. The patched `pmp_entry.sv` is
byte-identical to the one #3490 merged (`6fe7b959`), but in that tree `pmp.sv`
and the config and type packages differ from v5.3.0, so this is not a result
about CVA6 master.

Tier 1, adapter mutation and the port to current releases, is preregistered in
[TIER1_PROTOCOL.md](TIER1_PROTOCOL.md). Section 1, adapter mutation, is done:
every prediction held. All 11 mutants that change a decision are killed, and
the 2 predicted equivalent are proven equivalent
([mutation/summary.txt](mutation/summary.txt)).
