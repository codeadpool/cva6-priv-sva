// Formal-only, acyclic wrapper around Sail-RISC-V 0.12 PMP helpers: upstream's
// pmpCheck loop, unrolled 16x for the SV backend.
// SPDX-License-Identifier: BSD-2-Clause

function pmpCheckHwBody(
  addr : physaddr,
  width : xlenbits,
  access : MemoryAccessType(mem_payload),
  priv : Privilege,
) -> option(ExceptionType) = {
  let cfg_0 = pmpcfg_n[0];
  match pmpMatchAddr(addr, width, cfg_0, pmpReadAddrReg(0), zeros()) {
    PMP_NoMatch      => (),
    PMP_PartialMatch => return Some(accessFaultFromAccessType(access)),
    PMP_Match        => return (
      if pmpCheckRWX(cfg_0, access) | (priv == Machine & not(pmpLocked(cfg_0)))
      then None()
      else Some(accessFaultFromAccessType(access))
    ),
  };
  let cfg_1 = pmpcfg_n[1];
  match pmpMatchAddr(addr, width, cfg_1, pmpReadAddrReg(1), pmpReadAddrReg(0)) {
    PMP_NoMatch      => (),
    PMP_PartialMatch => return Some(accessFaultFromAccessType(access)),
    PMP_Match        => return (
      if pmpCheckRWX(cfg_1, access) | (priv == Machine & not(pmpLocked(cfg_1)))
      then None()
      else Some(accessFaultFromAccessType(access))
    ),
  };
  let cfg_2 = pmpcfg_n[2];
  match pmpMatchAddr(addr, width, cfg_2, pmpReadAddrReg(2), pmpReadAddrReg(1)) {
    PMP_NoMatch      => (),
    PMP_PartialMatch => return Some(accessFaultFromAccessType(access)),
    PMP_Match        => return (
      if pmpCheckRWX(cfg_2, access) | (priv == Machine & not(pmpLocked(cfg_2)))
      then None()
      else Some(accessFaultFromAccessType(access))
    ),
  };
  let cfg_3 = pmpcfg_n[3];
  match pmpMatchAddr(addr, width, cfg_3, pmpReadAddrReg(3), pmpReadAddrReg(2)) {
    PMP_NoMatch      => (),
    PMP_PartialMatch => return Some(accessFaultFromAccessType(access)),
    PMP_Match        => return (
      if pmpCheckRWX(cfg_3, access) | (priv == Machine & not(pmpLocked(cfg_3)))
      then None()
      else Some(accessFaultFromAccessType(access))
    ),
  };
  let cfg_4 = pmpcfg_n[4];
  match pmpMatchAddr(addr, width, cfg_4, pmpReadAddrReg(4), pmpReadAddrReg(3)) {
    PMP_NoMatch      => (),
    PMP_PartialMatch => return Some(accessFaultFromAccessType(access)),
    PMP_Match        => return (
      if pmpCheckRWX(cfg_4, access) | (priv == Machine & not(pmpLocked(cfg_4)))
      then None()
      else Some(accessFaultFromAccessType(access))
    ),
  };
  let cfg_5 = pmpcfg_n[5];
  match pmpMatchAddr(addr, width, cfg_5, pmpReadAddrReg(5), pmpReadAddrReg(4)) {
    PMP_NoMatch      => (),
    PMP_PartialMatch => return Some(accessFaultFromAccessType(access)),
    PMP_Match        => return (
      if pmpCheckRWX(cfg_5, access) | (priv == Machine & not(pmpLocked(cfg_5)))
      then None()
      else Some(accessFaultFromAccessType(access))
    ),
  };
  let cfg_6 = pmpcfg_n[6];
  match pmpMatchAddr(addr, width, cfg_6, pmpReadAddrReg(6), pmpReadAddrReg(5)) {
    PMP_NoMatch      => (),
    PMP_PartialMatch => return Some(accessFaultFromAccessType(access)),
    PMP_Match        => return (
      if pmpCheckRWX(cfg_6, access) | (priv == Machine & not(pmpLocked(cfg_6)))
      then None()
      else Some(accessFaultFromAccessType(access))
    ),
  };
  let cfg_7 = pmpcfg_n[7];
  match pmpMatchAddr(addr, width, cfg_7, pmpReadAddrReg(7), pmpReadAddrReg(6)) {
    PMP_NoMatch      => (),
    PMP_PartialMatch => return Some(accessFaultFromAccessType(access)),
    PMP_Match        => return (
      if pmpCheckRWX(cfg_7, access) | (priv == Machine & not(pmpLocked(cfg_7)))
      then None()
      else Some(accessFaultFromAccessType(access))
    ),
  };
  let cfg_8 = pmpcfg_n[8];
  match pmpMatchAddr(addr, width, cfg_8, pmpReadAddrReg(8), pmpReadAddrReg(7)) {
    PMP_NoMatch      => (),
    PMP_PartialMatch => return Some(accessFaultFromAccessType(access)),
    PMP_Match        => return (
      if pmpCheckRWX(cfg_8, access) | (priv == Machine & not(pmpLocked(cfg_8)))
      then None()
      else Some(accessFaultFromAccessType(access))
    ),
  };
  let cfg_9 = pmpcfg_n[9];
  match pmpMatchAddr(addr, width, cfg_9, pmpReadAddrReg(9), pmpReadAddrReg(8)) {
    PMP_NoMatch      => (),
    PMP_PartialMatch => return Some(accessFaultFromAccessType(access)),
    PMP_Match        => return (
      if pmpCheckRWX(cfg_9, access) | (priv == Machine & not(pmpLocked(cfg_9)))
      then None()
      else Some(accessFaultFromAccessType(access))
    ),
  };
  let cfg_10 = pmpcfg_n[10];
  match pmpMatchAddr(addr, width, cfg_10, pmpReadAddrReg(10), pmpReadAddrReg(9)) {
    PMP_NoMatch      => (),
    PMP_PartialMatch => return Some(accessFaultFromAccessType(access)),
    PMP_Match        => return (
      if pmpCheckRWX(cfg_10, access) | (priv == Machine & not(pmpLocked(cfg_10)))
      then None()
      else Some(accessFaultFromAccessType(access))
    ),
  };
  let cfg_11 = pmpcfg_n[11];
  match pmpMatchAddr(addr, width, cfg_11, pmpReadAddrReg(11), pmpReadAddrReg(10)) {
    PMP_NoMatch      => (),
    PMP_PartialMatch => return Some(accessFaultFromAccessType(access)),
    PMP_Match        => return (
      if pmpCheckRWX(cfg_11, access) | (priv == Machine & not(pmpLocked(cfg_11)))
      then None()
      else Some(accessFaultFromAccessType(access))
    ),
  };
  let cfg_12 = pmpcfg_n[12];
  match pmpMatchAddr(addr, width, cfg_12, pmpReadAddrReg(12), pmpReadAddrReg(11)) {
    PMP_NoMatch      => (),
    PMP_PartialMatch => return Some(accessFaultFromAccessType(access)),
    PMP_Match        => return (
      if pmpCheckRWX(cfg_12, access) | (priv == Machine & not(pmpLocked(cfg_12)))
      then None()
      else Some(accessFaultFromAccessType(access))
    ),
  };
  let cfg_13 = pmpcfg_n[13];
  match pmpMatchAddr(addr, width, cfg_13, pmpReadAddrReg(13), pmpReadAddrReg(12)) {
    PMP_NoMatch      => (),
    PMP_PartialMatch => return Some(accessFaultFromAccessType(access)),
    PMP_Match        => return (
      if pmpCheckRWX(cfg_13, access) | (priv == Machine & not(pmpLocked(cfg_13)))
      then None()
      else Some(accessFaultFromAccessType(access))
    ),
  };
  let cfg_14 = pmpcfg_n[14];
  match pmpMatchAddr(addr, width, cfg_14, pmpReadAddrReg(14), pmpReadAddrReg(13)) {
    PMP_NoMatch      => (),
    PMP_PartialMatch => return Some(accessFaultFromAccessType(access)),
    PMP_Match        => return (
      if pmpCheckRWX(cfg_14, access) | (priv == Machine & not(pmpLocked(cfg_14)))
      then None()
      else Some(accessFaultFromAccessType(access))
    ),
  };
  let cfg_15 = pmpcfg_n[15];
  match pmpMatchAddr(addr, width, cfg_15, pmpReadAddrReg(15), pmpReadAddrReg(14)) {
    PMP_NoMatch      => (),
    PMP_PartialMatch => return Some(accessFaultFromAccessType(access)),
    PMP_Match        => return (
      if pmpCheckRWX(cfg_15, access) | (priv == Machine & not(pmpLocked(cfg_15)))
      then None()
      else Some(accessFaultFromAccessType(access))
    ),
  };
  if priv == Machine then None() else Some(accessFaultFromAccessType(access))
}

$[sv_module]
function pmpCheckHw(
  addr : physaddr,
  width : xlenbits,
  access : MemoryAccessType(mem_payload),
  priv : Privilege,
) -> option(ExceptionType) = pmpCheckHwBody(addr, width, access, priv)
