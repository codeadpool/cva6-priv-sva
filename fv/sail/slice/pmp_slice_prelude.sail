// sail-riscv model types and helpers, restated with XLEN=64, PLEN=56, G=1.
// SPDX-License-Identifier: BSD-2-Clause

type xlen : Int = 64
type xlenbits = bits(xlen)
let xlen = sizeof(xlen)

type physaddrbits_len : Int = 56
type physaddrbits = bits(physaddrbits_len)
newtype physaddr = Physaddr : physaddrbits

enum amoop = { AMOSWAP, AMOAND, AMOOR, AMOXOR, AMOADD, AMOMIN, AMOMAX, AMOMINU, AMOMAXU, AMOCAS }
enum cbop_zicbom = {CBO_CLEAN, CBO_FLUSH, CBO_INVAL}
enum cbop_zicbop = {PREFETCH_I, PREFETCH_R, PREFETCH_W}

union cacheop = {
  CB_manage   : cbop_zicbom,
  CB_zero     : unit,
  CB_prefetch : cbop_zicbop,
}

union MemoryAccessType ('a : Type) = {
  Load             : 'a,
  Store            : 'a,
  LoadReserved     : 'a,
  StoreConditional : 'a,
  Atomic           : (amoop, 'a, 'a),
  InstructionFetch : unit,
  CacheAccess      : cacheop,
}

enum mem_payload = { Data, Vector, PageTableEntry, ShadowStack }
function mem_payload_name(p : mem_payload) -> string = "payload"
function mem_payload_str(p : mem_payload) -> string = "payload"

enum Privilege = {User, VirtualUser, Supervisor, VirtualSupervisor, Machine}

union ExceptionType = {
  E_Fetch_Access_Fault : unit,
  E_Load_Access_Fault  : unit,
  E_SAMO_Access_Fault  : unit,
}

function accessFaultFromAccessType(access : MemoryAccessType(mem_payload)) -> ExceptionType =
  match access {
    InstructionFetch()                  => E_Fetch_Access_Fault(),
    Load(Data)                          => E_Load_Access_Fault(),
    Load(Vector)                        => E_Load_Access_Fault(),
    Load(PageTableEntry)                => E_Load_Access_Fault(),
    LoadReserved(Data)                  => E_Load_Access_Fault(),
    Store(Data)                         => E_SAMO_Access_Fault(),
    Store(Vector)                       => E_SAMO_Access_Fault(),
    Store(PageTableEntry)               => E_SAMO_Access_Fault(),
    StoreConditional(Data)              => E_SAMO_Access_Fault(),
    Atomic(_, Data, Data)               => E_SAMO_Access_Fault(),
    Load(ShadowStack)                   => E_SAMO_Access_Fault(),
    Store(ShadowStack)                  => E_SAMO_Access_Fault(),
    Atomic(_, ShadowStack, ShadowStack) => E_SAMO_Access_Fault(),
    LoadReserved(_)                     => E_Load_Access_Fault(),
    StoreConditional(_)                 => E_SAMO_Access_Fault(),
    Atomic(_, _, _)                     => E_SAMO_Access_Fault(),
    CacheAccess(CB_manage(_))           => E_SAMO_Access_Fault(),
    CacheAccess(CB_zero())              => E_SAMO_Access_Fault(),
    CacheAccess(CB_prefetch(PREFETCH_R)) => E_Load_Access_Fault(),
    CacheAccess(CB_prefetch(PREFETCH_W)) => E_SAMO_Access_Fault(),
    CacheAccess(CB_prefetch(PREFETCH_I)) => E_Fetch_Access_Fault(),
  }

enum PmpAddrMatchType = {OFF, TOR, NA4, NAPOT}
mapping pmpAddrMatchType_encdec : PmpAddrMatchType <-> bits(2) = {
  OFF   <-> 0b00,
  TOR   <-> 0b01,
  NA4   <-> 0b10,
  NAPOT <-> 0b11,
}

bitfield Pmpcfg_ent : bits(8) = {
  L : 7,
  A : 4 .. 3,
  X : 2,
  W : 1,
  R : 0,
}

register pmpcfg_n : vector(64, Pmpcfg_ent)
register pmpaddr_n : vector(64, xlenbits)

function pmpReadAddrReg(n : range(0, 63)) -> xlenbits = {
  let G = 1;
  let match_type = pmpcfg_n[n][A];
  let addr = pmpaddr_n[n];
  match match_type[1] {
    0b1 if G >= 2 => {
      let mask : xlenbits = zero_extend(ones(min(G - 1, xlen)));
      addr | mask
    },
    0b0 if G >= 1 => {
      let mask : xlenbits = zero_extend(ones(min(G, xlen)));
      addr & ~(mask)
    },
    _ => addr,
  }
}

function pmpLocked(cfg : Pmpcfg_ent) -> bool = cfg[L] == 0b1
