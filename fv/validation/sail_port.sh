#!/usr/bin/env bash
# Port matrix for the Sail miter (evidence/sail/TIER1_PROTOCOL.md §2): P0-P4,
# then A1-A13 with direct equivalence on P3. sail-riscv 0.14 and CVA6 master come
# only from third_party/ported/. From the repo root, after `make sail-rtl`:
#   bash fv/validation/sail_port.sh           P0-P4, then base and A1-A13 on P3
#   bash fv/validation/sail_port.sh --elab    apply and elaborate only
set -u
cd "$(dirname "$0")/../.." || exit 2
root=$PWD
out=$root/results/sail_port
W=fv/wrappers/pmp_sail_ref_fv.sv
P=evidence/sail/mutation/patches
M=third_party/ported/cva6-49b5fa9e
ids="A1 A2 A3 A4 A5 A6 A7 A8 A9 A10 A11 A12 A13"
# column:sail:rtl
cols="P0:0.12:v530 P1:0.14:v530 P2:0.12:master P3:0.14:master P4:0.14:master3177"
[ -f results/sail_rtl/pr3490/pmp_entry.sv ] || {
    echo "run make sail-rtl first"
    exit 2
}
command -v patch >/dev/null || {
    echo "patch not found (it is in the Dockerfile)"
    exit 2
}
[ -f fv/sail/generated/sail_pmp_0_14.sv ] || {
    echo "fv/sail/generated/sail_pmp_0_14.sv missing (regen.sh 0.14)"
    exit 2
}
bash third_party/ported/ported.sh --offline >/dev/null || {
    echo "third_party/ported does not match SHA256SUMS"
    exit 2
}
rm -rf "$out"
mkdir -p "$out/rtl"
patch -s -o "$out/rtl/pmp.sv" "$M/core/pmp/src/pmp.sv" evidence/matrix/patches/pmp_3177_priority.patch >/dev/null || {
    echo "the #3177 patch does not apply to master pmp.sv"
    exit 2
}

# c2 sby with absolute paths: $1 sail 0.12|0.14, $2 rtl v530|master|master3177, $3 wrapper dir
colsby() {
    local s
    s=$(sed -e "s|^\.\./\.\./|$root/|" -e "s|^\.\./|$root/fv/|" \
        -e "s|^$root/$W\$|$3/pmp_sail_ref_fv.sv|" fv/checks/sail_pmp_tor.sby)
    if [ "$1" = 0.14 ]; then s=$(printf '%s\n' "$s" | sed 's/sail_pmp_0_12\.sv/sail_pmp_0_14.sv/'); fi
    case $2 in master*)
        s=$(printf '%s\n' "$s" | sed -e "s|^$root/cva6/|$root/$M/|" \
            -e "s|^$root/results/sail_rtl/pr3490/pmp_entry\.sv\$|$root/$M/core/pmp/src/pmp_entry.sv|" \
            -e "s|^$root/$M/core/include/build_config_pkg\.sv\$|&\n$root/$M/core/include/ariane_pkg.sv|" \
            -e 's/build_config_pkg\.sv lzc\.sv/build_config_pkg.sv ariane_pkg.sv lzc.sv/')
        ;;
    esac
    if [ "$2" = master3177 ]; then
        s=$(printf '%s\n' "$s" | sed -e "s|^$root/$M/core/pmp/src/pmp\.sv\$|$out/rtl/pmp.sv|" \
            -e 's/^read_slang /read_slang -D SAIL_FULL_EQUIV /')
    fi
    printf '%s\n' "$s"
}

# a column reads only its own sources: master reads no golden CVA6 file, 0.14 no 0.12 SV
check() {
    case $3 in master*) grep -qE "^$root/(cva6|results/sail_rtl)/" "$1" && return 1 ;; esac
    if [ "$2" = 0.14 ]; then grep -q 'sail_pmp_0_12' "$1" && return 1; fi
    return 0
}

# base and mutant copies side by side on P3 (sail_mut_eq_fv.sv)
eqsby() {
    colsby 0.14 master "$1" | sed -e 's/--top pmp_sail_ref_fv /--top sail_mut_eq_fv /' \
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

# $out/<id>: wrapper (patched unless base), c2.sby and eq.sby on P3
prep() {
    local d=$out/$1 f
    mkdir -p "$d"
    if [ "$1" = base ]; then
        cp "$W" "$d/pmp_sail_ref_fv.sv"
    else
        patch -s -o "$d/pmp_sail_ref_fv.sv" "$W" "$P/$1.patch" >/dev/null || return 1
    fi
    colsby 0.14 master "$d" >"$d/c2.sby"
    eqcopy "$W" base_fv >"$d/base.sv"
    eqcopy "$d/pmp_sail_ref_fv.sv" mut_fv >"$d/mut.sv"
    eqsby "$d" >"$d/eq.sby"
    check "$d/c2.sby" 0.14 master && check "$d/eq.sby" 0.14 master || return 1
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

# $1 id, $2 sby, then tasks -> $out/<id>_<task>
run() {
    local id=$1 sby=$2 t w
    shift 2
    for t in "$@"; do
        w=$out/${id}_$t
        sby -f -d "$w" "$sby" "$t" >/dev/null 2>&1
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

# one line per column; P0-P3 predicted as c2, P4 as c3
colreport() {
    local b p c n u ok=no x=c2
    b=$(st "$out/${1}_bmc")
    p=$(st "$out/${1}_prove")
    c=$(st "$out/${1}_cover")
    n=$(grep -c 'summary: *reached cover' "$out/${1}_cover/logfile.txt" 2>/dev/null)
    u=$(grep -o 'Unreached cover statement.*' "$out/${1}_cover/logfile.txt" 2>/dev/null |
        grep -o 'c_[a-z_0-9]*' | sort -u | paste -sd, -)
    if [ "$1" = P4 ]; then
        x=c3
        [ "$b/$p/$c/${u:-}" = PASS/PASS/FAIL/c_m_divergence ] && ok=yes
    else
        [ "$b/$p/$c/${n:-0}" = PASS/PASS/PASS/5 ] && ok=yes
    fi
    printf '%-5s bmc %-5s prove %-5s cover %-5s reached %s/5 unreached %-15s predicted %-3s %s\n' \
        "$1" "$b" "$p" "$c" "${n:-0}" "${u:--}" "$x" "$ok"
}

# one line per mutant: verdict, covers reached, direct equivalence, prediction
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
for col in $cols; do
    IFS=: read -r c s r <<<"$col"
    d=$out/$c
    mkdir -p "$d"
    cp "$W" "$d/pmp_sail_ref_fv.sv"
    colsby "$s" "$r" "$d" >"$d/c.sby"
    if ! check "$d/c.sby" "$s" "$r"; then
        echo "$c INVALID: reads a file outside its column"
        bad=1
        continue
    fi
    if [ "${1:-}" = --elab ]; then
        if elab "$d/c.sby"; then echo "$c elaborates"; else
            echo "$c FAILS: $d/c.sby.d.log"
            bad=1
        fi
        continue
    fi
    run "$c" "$d/c.sby" bmc prove cover
    line=$(colreport "$c")
    echo "$line" | tee -a "$out/summary.txt"
    case "$line" in *" yes") ;; *) bad=1 ;; esac
done

for id in base $ids; do
    if ! prep "$id"; then
        echo "$id INVALID: patch, copy or column check failed"
        bad=1
        continue
    fi
    if [ "${1:-}" = --elab ]; then
        for s in c2 eq; do
            if elab "$out/$id/$s.sby"; then echo "$id $s elaborates"; else
                echo "$id $s FAILS: $out/$id/$s.sby.d.log"
                bad=1
            fi
        done
        continue
    fi
    run "$id" "$out/$id/c2.sby" bmc prove cover
    run "${id}_eq" "$out/$id/eq.sby" prove cover
    line=$(report "$id")
    echo "$line" | tee -a "$out/summary.txt"
    case "$line" in
    *" yes") ;;
    base*)
        echo "baseline does not reproduce c2 on P3"
        exit 2
        ;;
    *) bad=1 ;;
    esac
done
exit $bad
