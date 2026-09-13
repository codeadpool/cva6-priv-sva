#!/usr/bin/env bash
# ============================================================================
# Regenerate generated/*.sv from a slice with the Sail SystemVerilog backend.
# Requires Sail 0.20.2 on PATH: use the pinned image, from the repo root:
#   podman build -f fv/sail/Containerfile.sail -t cva6-sail:0.20.2 fv/sail
#   podman run --rm -v "$PWD":/workspace:ro -w /tmp cva6-sail:0.20.2 \
#       bash /workspace/fv/sail/regen.sh --verify
#
#   regen.sh [0.12|0.14]              overwrite generated/ in place (default 0.12)
#   regen.sh [0.12|0.14] --verify     regenerate into a temp dir and compare
#   regen.sh [0.12|0.14] <outdir>     write somewhere else
# 0.12 reads slice/ and writes sail_pmp_0_12.sv; 0.14 reads slice_0_14/ and
# writes sail_pmp_0_14.sv.
# ============================================================================
set -euo pipefail

here="$(cd "$(dirname "$0")" && pwd)"
ver=0.12
case "${1:-}" in
0.12 | 0.14)
    ver=$1
    shift
    ;;
esac
case "$ver" in
0.12) slice="$here/slice" ;;
0.14) slice="$here/slice_0_14" ;;
esac
out_sv="sail_pmp_${ver/./_}.sv"
tmp="$(mktemp -d)"
trap 'rm -rf "$tmp"' EXIT

verify=0
case "${1:-}" in
--verify)
    verify=1
    out_dir="$tmp/out"
    ;;
"") out_dir="$here/generated" ;;
*) out_dir="$1" ;;
esac

command -v sail >/dev/null || {
    echo "sail 0.20.2 must be on PATH (see Containerfile.sail)" >&2
    exit 1
}
have="$(sail --version 2>/dev/null | head -1)"
# Exact match: "*0.20.2*" would also accept 0.20.20, and a different compiler
# silently produces output that will not match the hashes in PROVENANCE.
case "$have" in
*[0-9]0.20.2* | *0.20.2[0-9]*)
    echo "ERROR: expected Sail 0.20.2, got: $have" >&2
    exit 1
    ;;
*0.20.2*) ;;
*)
    echo "ERROR: expected Sail 0.20.2, got: $have" >&2
    exit 1
    ;;
esac
mkdir -p "$out_dir"

sail_dir="$(sail --dir)"
sail \
    --sv --sv-nomem --sv-no-strings --sv-no-assertions --sv-inregs \
    --sv-toplevel pmpCheckHw \
    -o sail_pmp_raw \
    --sv-output-dir "$tmp" \
    "$slice/pmp_base.sail" \
    "$slice/errors.sail" \
    "$slice/pmp_slice_prelude.sail" \
    "$slice/pmp_control.sail" \
    "$slice/pmp_hw.sail"

[ -s "$tmp/sail_pmp_raw.sv" ] || {
    echo "ERROR: sail produced no sail_pmp_raw.sv" >&2
    exit 1
}

# Slang compatibility cleanup (reviewable, no PMP logic touched):
#  - give generated enums the explicit base type slang requires;
#  - zero the pre-top undefined PMP-config placeholder;
#  - keep the declarations through pmpCheckHw, drop the simulator setup emitted
#    after that module.
sed -E \
    -e 's/^typedef enum (\[[^]]+\]) \{/typedef enum logic \1 {/' \
    -e "s/(zz[0-9]+_[0-9]+) = undefined_bitvector\(128'h8\);/\1 = '{9'd8, 128'd0};/" \
    "$tmp/sail_pmp_raw.sv" >"$tmp/patched.sv"
awk 'BEGIN { seen=0 } /^module pmpCheckHw\(/ { seen=1 } { print } seen && /^endmodule$/ { exit }' \
    "$tmp/patched.sv" >"$out_dir/$out_sv"
cp "$sail_dir/lib/sv/sail_modules.sv" "$out_dir/sail_modules.sv"

if grep -q 'undefined_bitvector' "$out_dir/$out_sv"; then
    echo "ERROR: undefined_bitvector survived in the generated module - re-derive the sed" >&2
    exit 1
fi

tops="$(grep -c '^module pmpCheckHw(' "$out_dir/$out_sv" || true)"
if [ "$tops" != 1 ] || [ "$(tail -n1 "$out_dir/$out_sv")" != "endmodule" ]; then
    echo "ERROR: expected exactly one complete pmpCheckHw module, found $tops" >&2
    exit 1
fi

echo "Generated:"
sha256sum "$out_dir/$out_sv" "$out_dir/sail_modules.sv"

if [ "$verify" = 1 ]; then
    echo
    echo "== reproducibility check against committed generated/ =="
    rc=0
    for f in "$out_sv" sail_modules.sv; do
        if cmp -s "$out_dir/$f" "$here/generated/$f"; then
            echo "OK    $f byte-identical"
        else
            echo "FAIL  $f differs from the committed copy"
            rc=1
        fi
    done
    [ "$rc" = 0 ] && echo "REGENERATION REPRODUCES THE COMMITTED SV" || echo "REGENERATION DIFFERS - investigate before committing"
    exit "$rc"
fi
