#!/usr/bin/env bash
# Adapter mutation for the Sail miter (evidence/sail/TIER1_PROTOCOL.md §1).
# Each mutant is a patch applied to a copy of the wrapper; committed files are
# never edited. from the repo root, after `make sail-rtl`:
#   bash fv/validation/sail_mutation.sh           baseline, A1-A13, equivalence
#   bash fv/validation/sail_mutation.sh --elab    apply and elaborate only
set -u
cd "$(dirname "$0")/../.." || exit 2
root=$PWD
out=$root/results/sail_mut
W=fv/wrappers/pmp_sail_ref_fv.sv
P=evidence/sail/mutation/patches
ids="A1 A2 A3 A4 A5 A6 A7 A8 A9 A10 A11 A12 A13"
[ -f results/sail_rtl/pr3490/pmp_entry.sv ] || {
    echo "run make sail-rtl first"
    exit 2
}
command -v patch >/dev/null || {
    echo "patch not found (it is in the Dockerfile)"
    exit 2
}
rm -rf "$out"
mkdir -p "$out"

# c2 sby with absolute paths and the wrapper from $1
c2sby() {
    sed -e "s|^\.\./\.\./|$root/|" -e "s|^\.\./|$root/fv/|" \
        -e "s|^$root/$W\$|$1/pmp_sail_ref_fv.sv|" fv/checks/sail_pmp_tor.sby
}

# the same run on base_fv and mut_fv side by side (sail_mut_eq_fv.sv)
eqsby() {
    c2sby "$1" | sed -e 's/--top pmp_sail_ref_fv /--top sail_mut_eq_fv /' \
        -e 's/^prep -top pmp_sail_ref_fv$/prep -top sail_mut_eq_fv/' \
        -e 's/pmp_sail_ref_sva\.sv pmp_sail_ref_fv\.sv$/base.sv mut.sv sail_mut_eq_fv.sv/' \
        -e '/\/pmp_sail_ref_sva\.sv$/d' \
        -e "s|^$1/pmp_sail_ref_fv\.sv\$|$1/base.sv\n$1/mut.sv\n$root/fv/validation/sail_mut_eq_fv.sv|"
}

# wrapper copy as module $2: decisions as outputs, checker and asserts removed
eqcopy() {
    sed -e "s/^module pmp_sail_ref_fv /module $2 /" \
        -e '/^ *input riscv::pmpcfg_t .* cfg_i$/s/$/,\n    output logic sail_allow_o,\n    output logic cva6_allow_o/' \
        -e '/^  pmp_sail_ref_sva #($/,/^  );$/d' \
        -e 's/^\( *\)\(a_[a-z_]* : assert\)/\1\/\/ \2/' \
        -e 's/^endmodule$/  assign sail_allow_o = sail_allow;\n  assign cva6_allow_o = cva6_allow;\nendmodule/' "$1"
}

# $out/<id>: wrapper (patched unless base), c2.sby, base.sv, mut.sv, eq.sby
prep() {
    local d=$out/$1 f
    mkdir -p "$d"
    if [ "$1" = base ]; then
        cp "$W" "$d/pmp_sail_ref_fv.sv"
    else
        patch -s -o "$d/pmp_sail_ref_fv.sv" "$W" "$P/$1.patch" >/dev/null || return 1
    fi
    c2sby "$d" >"$d/c2.sby"
    eqcopy "$W" base_fv >"$d/base.sv"
    eqcopy "$d/pmp_sail_ref_fv.sv" mut_fv >"$d/mut.sv"
    eqsby "$d" >"$d/eq.sby"
    for f in base mut; do
        grep -q 'pmp_sail_ref_sva #(' "$d/$f.sv" && return 1
        grep -qE '^ *a_[a-z_]+ : assert' "$d/$f.sv" && return 1
        [ "$(grep -c '_allow_o' "$d/$f.sv")" = 4 ] || return 1
        [ "$(grep -cE '^ *assum[e] \(' "$d/$f.sv")" = 5 ] || return 1
    done
}

# yosys only: [files] linked into one dir (as sby does), then [script]
elab() {
    local e=$1.d p s
    mkdir -p "$e"
    for p in $(awk '/^\[files\]/{f=1;next} /^\[/{f=0} f&&NF' "$1"); do ln -sf "$p" "$e/"; done
    s=$(awk '/^\[script\]/{f=1;next} /^\[/{f=0} f&&NF{printf "%s; ", $0}' "$1")
    (cd "$e" && yosys -q -p "$s") >"$e.log" 2>&1
}

# $1 id, $2 c2|eq, then tasks -> $out/<id>_<task> or $out/<id>_eq_<task>
run() {
    local id=$1 s=$2 t w
    shift 2
    for t in "$@"; do
        w=$out/${id}_$t
        [ "$s" = eq ] && w=$out/${id}_eq_$t
        sby -f -d "$w" "$out/$id/$s.sby" "$t" >/dev/null 2>&1
        [ -d "$w/src" ] && (cd "$w/src" && sha256sum *) >"$w/sources.sha256"
    done
}

st() {
    local m
    for m in PASS FAIL ERROR UNKNOWN TIMEOUT; do [ -f "$1/$m" ] && {
        echo "$m"
        return
    }; done
    echo NONE
}

report() {
    local b p n a v e x ok=no
    b=$(st "$out/${1}_bmc")
    p=$(st "$out/${1}_prove")
    n=$(grep -c 'summary: *reached cover' "$out/${1}_cover/logfile.txt" 2>/dev/null)
    if [ "$b$p" = PASSPASS ]; then
        v=SURVIVED
    else
        a=$(cat "$out/${1}_bmc/logfile.txt" "$out/${1}_prove/logfile.txt" 2>/dev/null |
            grep -o 'failed assertion [^ ]*' | sed 's/.*\.//' | sort -u | paste -sd, -)
        if [ -n "$a" ]; then v="KILLED $a"; else v="INVALID $b/$p"; fi
    fi
    case "$(st "$out/${1}_eq_prove")/$(st "$out/${1}_eq_cover")" in
    PASS/PASS) e=equivalent ;;
    FAIL/PASS) e=differs ;;
    *) e=INVALID ;;
    esac
    case $1 in A1 | A6) x=survive ;; base) x=c2 ;; *) x=kill ;; esac
    case "$x/$v/$e" in survive/SURVIVED/equivalent | kill/KILLED* | c2/SURVIVED/equivalent) ok=yes ;; esac
    [ "$x" = c2 ] && [ "${n:-0}" != 5 ] && ok=no
    printf '%-5s %-40s covers %s/5  eq %-10s predicted %-7s %s\n' "$1" "$v" "${n:-0}" "$e" "$x" "$ok"
}

bad=0
for id in base $ids; do
    if ! prep "$id"; then
        echo "$id INVALID: patch or copy failed"
        bad=1
        continue
    fi
    if [ "${1:-}" = --elab ]; then
        for s in c2 eq; do
            if elab "$out/$id/$s.sby"; then
                echo "$id $s elaborates"
            else
                echo "$id $s FAILS: $out/$id/$s.sby.d.log"
                bad=1
            fi
        done
        continue
    fi
    run "$id" c2 bmc prove cover
    run "$id" eq prove cover
    line=$(report "$id")
    echo "$line" | tee -a "$out/summary.txt"
    case "$line" in
    *" yes") ;;
    base*)
        echo "baseline does not reproduce c2"
        exit 2
        ;;
    *) bad=1 ;;
    esac
done
exit $bad
