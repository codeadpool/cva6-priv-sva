# Property Catalogue

Status tags: PLANNED (designed, not written), DRAFT (written, unproven),
PASS(bmc) (bounded + cover pass), PROVEN (bmc + an unbounded proof + cover pass;
the proof is k-induction, or PDR where k-induction needs an invariant it cannot
discover), CEX (counterexample found). Nothing counts as proven without a logged
sby run.

## Results (authoritative; supersedes per-row tags)

| Checker | DUT | IDs | Result | Date |
|---|---|---|---|---|
| pmp_entry_sva | pmp_entry | PMP-5,6,7 + TOR bounds | PROVEN (bmc/prove/cover) | 2026-06-30 |
| pmp_sva | pmp | PMP-1,2 | PROVEN (bmc/prove/cover) | 2026-06-30 |
| pmp_ref_sva | pmp | PMP-3,4,8, GAP-1 | PROVEN (bmc/prove/cover) | 2026-07-06 |
| csr_pmp_sva | csr_regfile | CSR-1,3,4,6 / CSR-2,5 | PROVEN 2026-07-02 / PROVEN 2026-07-06 | 2026-07-06 |
| csr_priv_sva | csr_regfile | MST-1..4, TRAP-1..3, PRIV-2 / TRAP-4,5,6, MST-5, PRIV-1 | PROVEN 2026-07-03 / PROVEN 2026-07-06 | 2026-07-06 |
| mstatus_f5_sva | csr_regfile | MST-6,8 / F5 | CEX on v5.3.0; PROVEN (k-induction) on PR #3386 head 3250ed48 | 2026-07-19 |
| mstatus_mprv_sva | csr_regfile | MST-7 / F6 | CEX (expected, upstream #3294/#1981) | 2026-07-06 |
| pmp_mpri_sva | pmp | PMP-9 / F7 | CEX (expected, upstream #3177) | 2026-07-06 |
| priv_dret_sva | csr_regfile | PRIV-4,6 / F8 | CEX on v5.3.0; PROVEN (PDR) on PR #3387 head 8f74af4a; also CEX at RVH=1 (the dcsr.prv defect is not RVH-gated) | 2026-07-19 |
| dcsr_reserved_sva | csr_regfile | PRIV-5, PRIV-8 | CEX on v5.3.0; PROVEN (k-induction) on PR #3387 head 8f74af4a | 2026-07-21 |
| mpp_legal_sva | csr_regfile | PRIV-7 / F9 | RVH=1: CEX (v5.3.0 & #3387 head, step 3). RVH=0: CEX on v5.3.0 (via F8/#3383), PROVEN (PDR) on #3387 head | 2026-07-20 |
| dcsr_vlegal_sva | csr_regfile | PRIV-9 / #3387 RVH=1 | RVH=1: CEX on golden; PROVEN (k-induction) on #3387 head with the write+dret v-clamps | 2026-07-22 |
| ptw_pmp_sva | cva6_ptw | VM-1,3 (VM-2 structural) | PROVEN (bmc/prove/cover) | 2026-07-06 |

All checkers use immediate assertions only (yosys-slang lowers no concurrent
SVA); every asserted antecedent has a reachable cover witness.
Counts are distinct properties; the x8 per-PMP-entry generate replication is
not counted. Run per the README quickstart; probes (expected-CEX checkers)
run bmc+cover on golden, and additionally `prove` against the PR head wherever we
submitted a fix. Engines: `smtbmc boolector` throughout, except `priv_dret` and
`mpp_legal`, whose `prove` task runs `smtbmc boolector` and `abc pdr` in parallel
and takes the first conclusive result. Both need PDR for the same reason: a
`mstatus.mpp` legality invariant is not k-inductive at a fixed depth (mret loads
priv_lvl from mpp, so the induction step can start from an unreachable mpp),
and PDR derives the strengthening automatically; where the property is false PDR
would search indefinitely for a proof that does not exist, so listing both
engines lets smtbmc return the counterexample in seconds instead.
Not yet authored: PRIV-3 (TSR is enforced in the
decoder, outside the csr_regfile harness; future decoder-level checker).

Each property cites its RTL basis (file:line) and a shorthand tag for its
privileged-spec basis. Smepmp is absent from CVA6 (no `mseccfg` CSR), so
Layer 1 checks what the RTL implements plus one gap-characterisation property
(GAP-1).

---

## Layer 1

### pmp: combinational PMP check (pmp.sv + pmp_entry.sv + lzc)
| ID | Property | RTL | Spec | Status |
|---|---|---|---|---|
| PMP-1 | M-mode + no matching entry => allow | pmp.sv:63-69 | PMP-priv | PROVEN 2026-06-30 |
| PMP-2 | S/U + NrPMP>0 + no match => deny | pmp.sv:67-69 | PMP-priv | PROVEN 2026-06-30 |
| PMP-3 | first (lowest-index) match decides | pmp.sv:52-62 | PMP-prio | PROVEN 2026-07-06 (pmp_ref) |
| PMP-4 | locked entry enforced even in M-mode | pmp.sv:55 | PMP-lock | PROVEN 2026-07-06 (pmp_ref) |
| PMP-5 | TOR match <=> prev <= addr < this | pmp_entry.sv:48-66 | PMP-tor | PROVEN 2026-06-30 |
| PMP-6 | NAPOT match <=> (addr & mask) == base | pmp_entry.sv:67-106 | PMP-napot | PROVEN 2026-06-30 |
| PMP-7 | OFF and stored NA4 never match | pmp_entry.sv:107-118 | PMP-na4 | PROVEN 2026-06-30 |
| PMP-8 | allow => access type within matched RWX | pmp.sv:56-62 | PMP-rwx | PROVEN 2026-07-06 (pmp_ref) |
| PMP-9 | F7 probe: M-mode spec priority (lowest match decides, locked or not) | pmp.sv:55 | PMP-prio | CEX 2026-07-06 (expected, #3177) |

### csr: PMP CSR WARL (csr_regfile.sv)
| ID | Property | RTL | Spec | Status |
|---|---|---|---|---|
| CSR-1 | write A=NA4 => addr_mode unchanged (G=1) | csr:2708-2710 | PMP-na4 | PROVEN 2026-07-02 |
| CSR-2 | OFF/TOR => pmpaddr[0] reads 0; NAPOT => 1 | csr:862-868 | PMP-grain | PROVEN 2026-07-06 |
| CSR-3 | write r=0,w=1 => access_type unchanged | csr:2713-2714 | PMP-rwx | PROVEN 2026-07-02 |
| CSR-4 | locked entry not updatable | csr:1639-1666,1736-1738 | PMP-lock | PROVEN 2026-07-02 |
| CSR-5 | entry below a locked TOR not updatable | csr:1639-1642,1737 | PMP-lock | PROVEN 2026-07-06 |
| CSR-6 | pmpcfg reserved bits read 0 | csr:1778 | PMP-warl | PROVEN 2026-07-02 |

### vm: MMU-PMP interaction (cva6_ptw.sv)
| ID | Property | RTL | Spec | Status |
|---|---|---|---|---|
| VM-1 | PMP-denied PTE fetch => access exception | ptw:561-566,580-582 | VM-pmp | PROVEN 2026-07-06 |
| VM-2 | PTE-fetch PMP check is S-mode READ always | ptw:237-239 | VM-pmp | STRUCTURAL (hardwired constants at the i_pmp_ptw instantiation) |
| VM-3 | PMP-denied PTE fetch => no TLB update | ptw:562 | VM-pmp | PROVEN 2026-07-06 |

### gap: characterise the Smepmp absence
| ID | Property | RTL | Status |
|---|---|---|---|
| GAP-1 | non-locked entry always bypassed in M-mode (the invariant MML would break) | pmp.sv:55 | PROVEN 2026-07-06 (pmp_ref) |

---

## Layer 2 (cv64a6_imafdc_sv39: RVS=RVU=1)

### trap: delegation and routing (csr_regfile.sv)
| ID | Property | RTL | Spec | Status |
|---|---|---|---|---|
| TRAP-1 | medeleg[cause]=0 below M => traps to M | csr:1822-1841 | TRAP-deleg | PROVEN 2026-07-03 |
| TRAP-2 | medeleg[cause]=1 in S/U => traps to S | csr:1824-1829 | TRAP-deleg | PROVEN 2026-07-03 |
| TRAP-3 | a trap never lowers privilege | csr:1829 | TRAP-mono | PROVEN 2026-07-03 |
| TRAP-4 | interrupt routing mirrors mideleg | csr:1822-1829 | TRAP-deleg | PROVEN 2026-07-06 |
| TRAP-5 | xepc/xcause capture pc/cause | csr:1869-1871,1907-1909 | TRAP-csr | PROVEN 2026-07-06 |
| TRAP-6 | trap lands in the routed privilege (!dret guarded) | csr:1945,2166 | TRAP-deleg | PROVEN 2026-07-06 |

### mstatus: trap/return stacking (csr_regfile.sv)
| ID | Property | RTL | Spec | Status |
|---|---|---|---|---|
| MST-1 | M-trap: mie<-0, mpie<-mie, mpp<-priv | csr:1903-1906 | MST-stack | PROVEN 2026-07-03 |
| MST-2 | S-trap: sie<-0, spie<-sie, spp<-priv[0] | csr:1864-1867 | MST-stack | PROVEN 2026-07-03 |
| MST-3 | mret: mie<-mpie, mpie<-1, mpp<-U, priv<-mpp | csr:2101-2123 | MST-ret | PROVEN 2026-07-03 |
| MST-4 | sret: sie<-spie, spie<-1, spp<-0, priv<-spp | csr:2125-2143 | MST-ret | PROVEN 2026-07-03 |
| MST-5 | mpp stays legal (WARL legalisation, csr:1382-1385); step property, dret excluded | csr:1382-1385 | MST-warl | PROVEN 2026-07-06 |
| MST-6 | F5 probe: interrupt trap to M leaves mtval nonzero | csr:1919 | TRAP-tval | CEX on v5.3.0; PROVEN (k-induction) on #3386 head 2026-07-19 |
| MST-7 | mprv probe: xret below M must clear MPRV, RVH=0 build skips it | csr:2116-2122,2136-2142 | MST-ret | CEX 2026-07-06 (expected, #3294) |
| MST-8 | F5 probe, S half: interrupt trap to S leaves stval nonzero. PR #3386 changes mtval/stval/vstval; this covers the stval site (vstval needs RVH=1, uncovered) | csr:1880 | TRAP-tval | CEX on v5.3.0; PROVEN (k-induction) on #3386 head 2026-07-19 |

### priv: privilege invariants
| ID | Property | RTL | Spec | Status |
|---|---|---|---|---|
| PRIV-1 | priv_lvl stays in {M,S,U}; step property, dret excluded (see PRIV-4) | csr priv_lvl_q | PRIV | PROVEN 2026-07-06 |
| PRIV-2 | after mret/sret, priv = saved xPP | csr:2108,2131 | MST-ret | PROVEN 2026-07-03 (conjunct of MST-3/4) |
| PRIV-3 | sret traps under mstatus.TSR in S | decoder-level (out of csr harness scope) | PRIV-tsr | PLANNED (future decoder checker) |
| PRIV-4 | F8 probe: priv_lvl legal after dret (dcsr.prv unlegalized) | csr:1056,2166 | PRIV | CEX on v5.3.0; PROVEN (PDR) on #3387 head 2026-07-19 |
| PRIV-5 | DCSR reserved zero1/zero2 read 0; fix-certification for upstream #1984, not an original finding | csr:1056 | PRIV-warl | CEX on v5.3.0; PROVEN (k-induction) on #3387 head 2026-07-19 |
| PRIV-6 | dcsr.prv itself stays WARL-legal; added as PRIV-4 induction strengthening, but a real invariant in its own right | csr:1056 | PRIV-warl | CEX on v5.3.0; PROVEN (PDR) on #3387 head 2026-07-19 |
| PRIV-7 | F9 probe: mstatus.mpp rejects the reserved encoding 2'b10; guard csr:1382 is `!RVH`-gated but 2'b10 is reserved in every config | csr:1382 | PRIV-warl | RVH=1: CEX (v5.3.0 & #3387 head). RVH=0: CEX on v5.3.0 via F8, PROVEN (PDR) on #3387 head 2026-07-20 |
| PRIV-8 | dcsr.cause preserved across a software dcsr write (hardware-written only); fix-certification for upstream #1985, not an original finding | csr:1056 | PRIV-warl | CEX on v5.3.0; PROVEN (k-induction) on #3387 head 2026-07-21 |
| PRIV-9 | dcsr.v never pairs with prv=M (M+V=1) at RVH=1: an in-debug dcsr write cannot store {M,v=1} (write clamp), and dret never resumes M with V=1 (dret clamp). Global invariant left to #3313 (mret+mpv). Fix-cert for the #3387 RVH=1 clamps | csr:1179,2390 | PRIV-warl | CEX on golden RVH=1; PROVEN (k-induction) on #3387 head 2026-07-22 |
