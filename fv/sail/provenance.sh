#!/usr/bin/env bash
# ============================================================================
# Provenance check for the Sail golden-model PMP reference. Needs NO Sail
# toolchain: only the pinned sail-riscv submodule and the files in fv/sail/.
#   1. sail-riscv submodule sits at the pinned 0.12 commit;
#   2. slice/errors.sail is verbatim upstream;
#   3. slice/pmp_control.sail is upstream + EXACTLY the documented specialization
#      (re-derived here from upstream, then compared byte for byte);
#   4. slice/pmp_slice_prelude.sail's pmpReadAddrReg/pmpLocked match upstream
#      pmp_regs.sail modulo the same specialization;
#  4b. every type the slice re-declares matches its upstream declaration;
#  4c. pmp_hw.sail is upstream's pmpCheck loop body 16x, same terminal default;
#   5. slice + generated SV hashes match fv/sail/PROVENANCE.
# ============================================================================
set -euo pipefail

here="$(cd "$(dirname "$0")" && pwd)"
repo="$(cd "$here/../.." && pwd)"
sub="$repo/sail-riscv"
up="$sub/model"
tmp="$(mktemp -d)"
trap 'rm -rf "$tmp"' EXIT

SAIL_RISCV_COMMIT=65ddde80ee2b131bf46c20e6e748343c336c4071
fail=0
note() { printf '%s\n' "$*"; }
bad() {
    printf 'FAIL  %s\n' "$*"
    fail=1
}
# comments out, whitespace out: compare code, not layout
strip() { sed 's,//.*,,' "$1" | tr -d '[:space:]'; }

# --- 1. submodule pin ------------------------------------------------------
note "== sail-riscv submodule pin =="
if [ ! -e "$sub/.git" ]; then
    bad "sail-riscv not checked out - run: git submodule update --init sail-riscv"
    exit 1
fi
got="$(git -C "$sub" rev-parse HEAD)"
if [ "$got" = "$SAIL_RISCV_COMMIT" ]; then note "OK    $got (0.12)"; else bad "commit $got != $SAIL_RISCV_COMMIT"; fi
# commit alone isn't enough: a modified working tree would let every check
# below compare the slice against locally edited "upstream" sources.
if git -C "$sub" diff --quiet && git -C "$sub" diff --cached --quiet; then
    note "OK    working tree clean"
else
    bad "sail-riscv has local modifications; provenance needs a clean $SAIL_RISCV_COMMIT tree"
fi

# --- 2. verbatim upstream file --------------------------------------------
note "== slice/errors.sail is verbatim upstream =="
if diff -q "$up/prelude/errors.sail" "$here/slice/errors.sail" >/dev/null; then
    note "OK    identical to model/prelude/errors.sail"
else
    bad "slice/errors.sail differs from model/prelude/errors.sail"
fi

# --- 3. the specialization, re-derived from upstream -----------------------
# The ONLY changes to pmp_control.sail: drop `private` from the 3 functions
# the top calls and the enum in their signature, fix the entry count at 16, and
# specialize the NA4 grain assertion to G=1. Re-derived, so it cannot grow.
note "== slice/pmp_control.sail == upstream + documented specialization =="
sed -E \
    -e 's/^private (function (pmpCheckRWX|pmpRangeMatch|pmpMatchAddr)\()/\1/' \
    -e 's/^private (enum pmpAddrMatch )/\1/' \
    -e 's/assert\(sys_pmp_grain < 1,/assert(1 < 1,/' \
    -e 's/if sys_pmp_count == 0 then/if 16 == 0 then/' \
    -e 's/foreach \(i from 0 to sys_pmp_count - 1\)/foreach (i from 0 to 16 - 1)/' \
    "$up/pmp/pmp_control.sail" >"$tmp/expected_pmp_control.sail"
if diff -u "$tmp/expected_pmp_control.sail" "$here/slice/pmp_control.sail"; then
    note "OK    byte-identical to the re-derived specialization"
else
    bad "slice/pmp_control.sail carries changes beyond the documented specialization"
fi

# --- 4. the two helpers lifted out of pmp_regs.sail ------------------------
# the slice re-states them without the upstream comments and with its own
# layout, so compare the code with comments stripped and all whitespace
# removed: same characters = same function.
note "== slice prelude helpers == upstream pmp_regs.sail =="
# fn:end-pattern (pmpReadAddrReg is a block, pmpLocked is a one-expression body)
for spec in 'pmpReadAddrReg:^}' 'pmpLocked:^$'; do
    fn="${spec%%:*}"
    end="${spec##*:}"
    awk -v f="^private function $fn" -v e="$end" \
        'BEGIN{on=0} $0 ~ f {on=1} on {print} on && NR>1 && $0 ~ e && $0 !~ f {exit}' \
        "$up/pmp/pmp_regs.sail" |
        sed -e 's/^private //' -e 's/let G = sys_pmp_grain;/let G = 1;/' >"$tmp/up_$fn"
    awk -v f="^function $fn" -v e="$end" \
        'BEGIN{on=0} $0 ~ f {on=1} on {print} on && NR>1 && $0 ~ e && $0 !~ f {exit}' \
        "$here/slice/pmp_slice_prelude.sail" >"$tmp/sl_$fn"
    if [ ! -s "$tmp/up_$fn" ] || [ ! -s "$tmp/sl_$fn" ]; then
        bad "$fn: could not extract it from one of the two sources"
    elif [ "$(strip "$tmp/up_$fn")" = "$(strip "$tmp/sl_$fn")" ]; then
        note "OK    $fn matches upstream (G specialized to 1)"
    else
        bad "$fn differs from upstream pmp_regs.sail"
        diff -u "$tmp/up_$fn" "$tmp/sl_$fn" || true
    fi
done

# --- 4b. every type the slice re-declares from core/ and pmp_regs.sail ------
# The slice cannot `$include` the whole model, so it restates the types the PMP
# helpers need. Restating them is where a slice silently drifts from the model,
# so each declaration is compared against its upstream original. Compared modulo
# comments, whitespace and a trailing comma before a closing brace.
note "== slice prelude type declarations == upstream =="
tnorm() { sed 's,//.*,,' | tr -d '[:space:]' | sed 's/,}/}/g'; }
extract() { awk -v s="$2" -v e="$3" 'BEGIN{on=0} $0~s{on=1} on{print} on&&NR>1&&$0~e{exit}' "$1" | sed 's/^private //'; }
# name | upstream file | start regex | end regex
decls='union MemoryAccessType|core/types.sail|^union MemoryAccessType|^}
bitfield Pmpcfg_ent|pmp/pmp_regs.sail|^bitfield Pmpcfg_ent|^}
union cacheop|core/types.sail|^union cacheop|^}
enum Privilege|core/types.sail|^enum Privilege|^enum Privilege
enum mem_payload|core/vmem_types.sail|^enum mem_payload|^enum mem_payload
enum amoop|extensions/A/aext_types.sail|^enum amoop|^enum amoop
enum cbop_zicbom|extensions/Zicbom/zicbom_types.sail|^enum cbop_zicbom|^enum cbop_zicbom
enum cbop_zicbop|extensions/Zicbop/zicbop_types.sail|^enum cbop_zicbop|^enum cbop_zicbop
enum PmpAddrMatchType|pmp/pmp_regs.sail|enum PmpAddrMatchType|enum PmpAddrMatchType
mapping pmpAddrMatchType_encdec|pmp/pmp_regs.sail|mapping pmpAddrMatchType_encdec|^}
register pmpcfg_n|pmp/pmp_regs.sail|^register pmpcfg_n|^register pmpcfg_n
register pmpaddr_n|pmp/pmp_regs.sail|^register pmpaddr_n|^register pmpaddr_n'
while IFS='|' read -r name file start end; do
    [ -n "$name" ] || continue
    u="$(extract "$up/$file" "$start" "$end" | tnorm)"
    v="$(extract "$here/slice/pmp_slice_prelude.sail" "$start" "$end" | tnorm)"
    if [ -z "$u" ]; then
        bad "$name: not found in $file"
    elif [ -z "$v" ]; then
        bad "$name: not found in the slice prelude"
    elif [ "$u" = "$v" ]; then
        note "OK    $name"
    else
        bad "$name differs from upstream $file"
    fi
done <<<"$decls"
# Deliberate, documented exceptions (see fv/sail/README.md):
#   ExceptionType         - reduced to the three access faults; the miter only
#                           distinguishes None from Some, so the cause is unused.
#   accessFaultFromAccessType - upstream's nested prefetch match is flattened;
#                           every arm still returns Some, so allow/deny is unchanged.
#   mem_payload_name/str  - stubbed; only feed internal_error strings, and
#                           --sv-no-strings removes strings from the output anyway.

# --- 4c. the acyclic expansion ---------------------------------------------
# pmp_hw.sail is the one hand-written file: upstream's `foreach` over entries,
# unrolled because the SV backend needs a statically unrollable CFG. Check that
# all 16 blocks are the SAME block modulo the index, and that the terminal
# default is upstream's character for character. What the blocks do is then
# fixed by the upstream helpers they call.
note "== pmp_hw.sail is upstream's loop body, 16x =="
hw="$here/slice/pmp_hw.sail"
block() {
    local i=$1
    awk -v tag="cfg_$i = pmpcfg_n[$i]" 'BEGIN{on=0} index($0,tag){on=1} on {print} on && /^  };$/ {exit}' "$hw" |
        sed -e "s/cfg_$i/CFG/g" -e "s/pmpcfg_n\[$i\]/pmpcfg_n[IDX]/" \
            -e "s/pmpReadAddrReg($i)/pmpReadAddrReg(IDX)/" \
            -e "s/pmpReadAddrReg($((i - 1)))/PREV/" -e "s/zeros()/PREV/" |
        sed 's,//.*,,' | tr -d '[:space:]'
}
# the blocks matching each other only proves self-consistency. Normalize
# upstream's foreach body the same way and require block 0 to equal it.
upstream_block() {
    awk 'BEGIN{on=0} index($0,"let cfg = pmpcfg_n[i]"){on=1} on{print} on&&/^    };$/{exit}' \
        "$up/pmp/pmp_control.sail" |
        sed -e 's/pmpcfg_n\[i\]/pmpcfg_n[IDX]/' -e 's/pmpReadAddrReg(i)/pmpReadAddrReg(IDX)/g' \
            -e 's/prev_pmpaddr/PREV/g' -e 's/let cfg =/let CFG =/' -e 's/, cfg,/, CFG,/' \
            -e 's/pmpCheckRWX(cfg,/pmpCheckRWX(CFG,/' -e 's/pmpLocked(cfg)/pmpLocked(CFG)/' |
        sed 's,//.*,,' | tr -d '[:space:]'
}
ref="$(block 0)"
up_ref="$(upstream_block)"
if [ -z "$up_ref" ]; then
    bad "could not extract the loop body from upstream pmpCheck"
elif [ "$ref" = "$up_ref" ]; then
    note "OK    entry block equals upstream's pmpCheck loop body"
else
    bad "entry block differs from upstream's pmpCheck loop body"
fi
if [ -z "$ref" ]; then
    bad "could not extract entry block 0 from pmp_hw.sail"
else
    same=1
    for i in $(seq 0 15); do [ "$(block "$i")" = "$ref" ] || {
        bad "pmp_hw.sail block $i is not block 0 modulo the index"
        same=0
    }; done
    [ "$same" = 1 ] && note "OK    all 16 entry blocks identical modulo the index"
fi
n_entries="$(grep -c 'pmpcfg_n\[' "$hw" || true)"
[ "$n_entries" = 16 ] && note "OK    exactly 16 entries expanded" || bad "expected 16 entry blocks, found $n_entries"
term='if priv == Machine then None() else Some(accessFaultFromAccessType(access))'
if grep -qF "$term" "$hw" && grep -qF "$term" "$up/pmp/pmp_control.sail"; then
    note "OK    terminal default identical to upstream pmpCheck"
else
    bad "terminal default does not match upstream pmpCheck"
fi

# --- 5. hashes -------------------------------------------------------------
# What the checks above do not diff against upstream is pinned by hash here:
# pmp_base.sail, the prelude's XLEN/PLEN specializations and its three
# documented exceptions, and the generated SV. See fv/sail/README.md.
note "== slice + generated hashes (fv/sail/PROVENANCE) =="
grep -E '^[0-9a-f]{64}  (slice|generated)/' "$here/PROVENANCE" >"$tmp/sums" || true
# a hash per line is not enough: a file omitted from PROVENANCE would simply go
# unchecked. Require the manifest to name exactly the files on disk.
(cd "$here" && find slice generated -type f \( -name '*.sail' -o -name '*.sv' \) -print |
    LC_ALL=C sort) >"$tmp/on_disk"
awk '{print $2}' "$tmp/sums" | LC_ALL=C sort >"$tmp/in_manifest"
if [ ! -s "$tmp/sums" ]; then
    bad "no hash lines found in PROVENANCE"
elif ! diff -u "$tmp/on_disk" "$tmp/in_manifest"; then
    bad "PROVENANCE does not name exactly one hash per Sail/SV file"
elif (cd "$here" && sha256sum -c "$tmp/sums"); then
    note "OK    every file covered, all hashes match"
else
    bad "hash mismatch - regenerate or update PROVENANCE deliberately"
fi

echo
if [ "$fail" = 0 ]; then echo "PROVENANCE OK"; else
    echo "PROVENANCE FAILED"
    exit 1
fi
