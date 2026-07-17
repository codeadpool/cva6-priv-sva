#!/usr/bin/env bash
# Mutation testing for the property suite.
# Golden cva6/ (pinned submodule) is never edited: mutated a throwaway copy and
# symlink cva6 -> it, restoring golden on exit (even on error/interrupt).

set -u
cd "$(dirname "$0")/../.." || exit 2
[ -e cva6/core/csr_regfile.sv ] || {
    echo "run from repo root with the cva6 submodule present"
    exit 2
}

MUT=cva6.mut
GOLD=cva6.golden
cleanup() {
    [ -L cva6 ] && rm -f cva6
    [ -d "$GOLD" ] && mv "$GOLD" cva6
    rm -rf "$MUT"
}
trap cleanup EXIT INT TERM

cp -r cva6 "$MUT"
mv cva6 "$GOLD"
ln -s "$MUT" cva6

declare -a M=(
    "M1~core/pmp/src/pmp.sv~s@ || conf_i\[i\].locked@@~pmp"
    "M2~core/pmp/src/pmp.sv~s@if (priv_lvl_i == riscv::PRIV_LVL_M) allow_o = 1'b1;@allow_o = 1'b0;@~pmp"
    "M3~core/pmp/src/pmp.sv~s@^\( *\)break;@\1// MUT-break@~pmp"
    "M4~core/pmp/src/pmp.sv~s@!= access_type_i) allow_o = 1'b0;@== access_type_i) allow_o = 1'b0;@~pmp"
    "M5~core/pmp/src/pmp_entry.sv~s@match_o = 0;@match_o = 1;@~pmp"
    "M6~core/csr_regfile.sv~s@pmpcfg_next\[i\].addr_mode = pmpcfg_q\[i\].addr_mode;@pmpcfg_next[i].addr_mode = pmpcfg_d[i].addr_mode;@~csr"
    "M7~core/csr_regfile.sv~s@pmpcfg_next\[i\].access_type = pmpcfg_q\[i\].access_type;@pmpcfg_next[i].access_type = pmpcfg_d[i].access_type;@~csr"
    "M8~core/csr_regfile.sv~s@pmpcfg_d\[i\].reserved = 2'b0;@pmpcfg_d[i].reserved = 2'b1;@~csr"
    "M9~core/csr_regfile.sv~s@priv_lvl_d    = mstatus_q.mpp;@priv_lvl_d    = riscv::PRIV_LVL_M;@~trap"
    "M10~core/csr_regfile.sv~s@? riscv::PRIV_LVL_M : riscv::PRIV_LVL_S;@? riscv::PRIV_LVL_M : riscv::PRIV_LVL_M;@~trap"
    "M11~core/csr_regfile.sv~s@mstatus_d.mpp = priv_lvl_q;@mstatus_d.mpp = riscv::PRIV_LVL_M;@~trap"
    "M12~core/csr_regfile.sv~s@mstatus_d.spp = priv_lvl_q\[0\];@mstatus_d.spp = 1'b0;@~trap"
    "M13~core/csr_regfile.sv~s@riscv::priv_lvl_t'({1'b0, mstatus_q.spp})@riscv::PRIV_LVL_M@~trap"
    "M14~core/csr_regfile.sv~s@mstatus_d.mpp == riscv::PRIV_LVL_HS@mstatus_d.mpp == riscv::PRIV_LVL_M@~trap"
    "M15~core/cva6_mmu/cva6_ptw.sv~s@if (!allow_access) begin@if (1'b0) begin@~vm"
    "M16~core/pmp/src/pmp_entry.sv~s@(addr_i & mask) == base@(addr_i \& mask) != base@~pmp"
    "M17~core/pmp/src/pmp.sv~68s@allow_o = 1'b0;@allow_o = 1'b1;@~pmp"
    "M18~core/pmp/src/pmp_entry.sv~s@addr_i < ({2'b0, conf_addr_i}@addr_i <= ({2'b0, conf_addr_i}@~pmp"
    "M19~core/csr_regfile.sv~s@addr_mode\[1\] == 1'b1@addr_mode[1] == 1'b0@~csr"
    "M20~core/csr_regfile.sv~s@if (!pmpcfg_q\[index\*4+i\].locked) pmpcfg_d@if (1'b1) pmpcfg_d@~csr"
    "M21~core/csr_regfile.sv~s@ && !(pmpcfg_q\[index+1\].locked && pmpcfg_q\[index+1\].addr_mode == riscv::TOR)@@~csr"
    "M22~core/csr_regfile.sv~1945s@= trap_to_priv_lvl;@= riscv::PRIV_LVL_M;@~trap"
    "M23~core/csr_regfile.sv~s@mcause_d = ex_i.cause;@mcause_d = '0;@~trap"
    "M24~core/csr_regfile.sv~1829s@? riscv::PRIV_LVL_M :@? riscv::PRIV_LVL_S :@~trap"
    "M25~core/csr_regfile.sv~1810s@riscv::PRIV_LVL_M;@riscv::PRIV_LVL_S;@~trap"
    "M26~core/csr_regfile.sv~1822s@mideleg_q@medeleg_q@~trap"
)

survivors=0
for row in "${M[@]}"; do
    IFS='~' read -r id f sedexpr cat <<<"$row"
    cp "$GOLD/$f" "$MUT/$f"
    before=$(md5sum "$MUT/$f" | cut -d' ' -f1)
    sed -i "$sedexpr" "$MUT/$f"
    after=$(md5sum "$MUT/$f" | cut -d' ' -f1)
    if [ "$before" = "$after" ]; then
        echo "== $id [$cat] -> NO-OP (sed did not match; fix pattern)"
        survivors=$((survivors + 1))
        continue
    fi
    out=$(make verify-"$cat" TASKS=bmc 2>&1)
    killed=$(echo "$out" | grep -oE 'results/[a-z]+/[a-z_0-9]+_bmc\] DONE \(FAIL' | grep -oE '[a-z_0-9]+_bmc' | paste -sd, -)
    cp "$GOLD/$f" "$MUT/$f"
    if [ -n "$killed" ]; then echo "== $id [$cat] -> KILLED [$killed]"; else
        echo "== $id [$cat] -> SURVIVED (INVESTIGATE)"
        survivors=$((survivors + 1))
    fi
done

echo "----"
echo "mutants: ${#M[@]}  survivors: $survivors"
[ "$survivors" -eq 0 ] && echo "PASS: all mutants killed" || echo "FAIL: $survivors survivor(s)"
exit "$survivors"
