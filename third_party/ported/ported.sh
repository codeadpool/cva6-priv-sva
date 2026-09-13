#!/usr/bin/env bash
# Exact upstream copies for Tier 1 §2 (evidence/sail/TIER1_PROTOCOL.md).
# The port reads only these copies; this script ties them to the pinned commits.
#   ported.sh            fetch the pinned commits, byte-compare every copy (online)
#   ported.sh --offline  check SHA256SUMS: every listed copy, nothing extra
#   ported.sh --fetch    rewrite the copies from the pinned commits
set -euo pipefail
cd "$(dirname "$0")"

# directory | repository | full commit | files, at their upstream paths
src='sail-riscv-29e6158|https://github.com/riscv/sail-riscv|29e6158f0a88bdb26b9fbcd0718ab919449b5179|LICENCE model/pmp/pmp_control.sail model/pmp/pmp_regs.sail model/core/types.sail model/core/vmem_types.sail model/core/mem_type_utils.sail model/extensions/A/aext_types.sail model/extensions/Zicbom/zicbom_types.sail model/extensions/Zicbop/zicbop_types.sail model/prelude/prelude.sail model/prelude/errors.sail
cva6-49b5fa9e|https://github.com/openhwgroup/cva6|49b5fa9e2f5a803cd52f8430d8e8818089e68865|LICENSE vendor/pulp-platform/common_cells/LICENSE core/include/config_pkg.sv core/include/cv64a6_imafdc_sv39_config_pkg.sv core/include/riscv_pkg.sv core/include/build_config_pkg.sv core/include/ariane_pkg.sv vendor/pulp-platform/common_cells/src/lzc.sv vendor/pulp-platform/common_cells/src/cf_math_pkg.sv core/pmp/src/pmp_entry.sv core/pmp/src/pmp.sv'

listed() {
    local d f files
    while IFS='|' read -r d _ _ files; do
        for f in $files; do echo "$d/$f"; done
    done <<<"$src" | LC_ALL=C sort
}

offline() {
    diff <(listed) <(awk '{print $2}' SHA256SUMS | LC_ALL=C sort) >/dev/null || {
        echo "FAIL  SHA256SUMS does not list exactly the files in ported.sh"
        return 1
    }
    diff <(listed) <(find sail-riscv-* cva6-* -type f | LC_ALL=C sort) >/dev/null || {
        echo "FAIL  the copies on disk are not exactly the listed files"
        return 1
    }
    sha256sum --quiet -c SHA256SUMS || {
        echo "FAIL  a copy does not match SHA256SUMS"
        return 1
    }
    echo "OK    $(listed | wc -l) copies match SHA256SUMS"
}

# every listed file, from its pinned commit, into $tmp/<directory>/
fetch() {
    local d url sha files f g
    while IFS='|' read -r d url sha files; do
        g=$tmp/git-$d
        git init -q "$g"
        git -C "$g" fetch -q --depth=1 --filter=blob:none "$url" "$sha"
        [ "$(git -C "$g" rev-parse FETCH_HEAD)" = "$sha" ] || {
            echo "FAIL  $d: fetched commit is not $sha"
            exit 1
        }
        for f in $files; do
            mkdir -p "$tmp/$d/$(dirname "$f")"
            git -C "$g" show "$sha:$f" >"$tmp/$d/$f"
        done
    done <<<"$src"
}

case "${1:-}" in
--offline)
    offline
    ;;
--fetch)
    tmp=$(mktemp -d)
    trap 'rm -rf "$tmp"' EXIT
    fetch
    while IFS='|' read -r d _; do
        rm -rf "$d"
        mv "$tmp/$d" "$d"
    done <<<"$src"
    listed | xargs sha256sum >SHA256SUMS
    offline
    ;;
"")
    tmp=$(mktemp -d)
    trap 'rm -rf "$tmp"' EXIT
    fetch
    bad=0
    while read -r f; do
        cmp -s "$tmp/$f" "$f" || {
            echo "FAIL  $f differs from its pinned commit"
            bad=1
        }
    done < <(listed)
    offline || bad=1
    [ "$bad" = 0 ] || exit 1
    echo "OK    every copy is byte-identical to its pinned commit"
    ;;
*)
    echo "usage: ported.sh [--offline | --fetch]"
    exit 2
    ;;
esac
