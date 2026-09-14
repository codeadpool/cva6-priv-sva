#!/usr/bin/env bash
# Installs the pinned OSS CAD Suite release into DIR/oss-cad-suite, checked by
# sha256. The Dockerfile and CI both use it, so they run the same toolchain.
# Fetches the release file directly, no GitHub REST API call.
#   bash tools/oss-cad-suite.sh /absolute/dir
set -euo pipefail

[[ $# == 1 && $1 == /* && $1 != / ]] || {
    echo "usage: $0 ABSOLUTE_INSTALL_DIRECTORY" >&2
    exit 2
}
[[ $(uname -s) == Linux && $(uname -m) == x86_64 ]] || {
    echo "this installer is pinned to linux-x64" >&2
    exit 2
}

readonly dest=$1
readonly release=2026-04-07
readonly stamp=${release//-/}
readonly sha256='f207bc8e415e5289f7fd03b3f972726e6402a6fc2d8df95900fe2c28bf0c53e1'
readonly url="https://github.com/YosysHQ/oss-cad-suite-build/releases/download/${release}/oss-cad-suite-linux-x64-${stamp}.tgz"

mkdir -p "$dest"
[[ ! -e "$dest/oss-cad-suite" ]] || {
    echo "$dest/oss-cad-suite already exists" >&2
    exit 1
}

tmp=$(mktemp -d)
trap 'rm -rf "$tmp"' EXIT
archive="$tmp/oss-cad-suite.tgz"

curl --fail --location --silent --show-error \
    --retry 3 --retry-all-errors --retry-delay 2 \
    --proto '=https' --proto-redir '=https' \
    --output "$archive" "$url"

printf '%s  %s\n' "$sha256" "$archive" | sha256sum --check --strict -
tar --no-same-owner -xzf "$archive" -C "$dest"

for t in yosys sby; do
    test -x "$dest/oss-cad-suite/bin/$t" || {
        echo "$dest/oss-cad-suite/bin/$t missing after extraction" >&2
        exit 1
    }
done

# on a GitHub runner, later steps get the tools on PATH
if [[ -n ${GITHUB_PATH:-} ]]; then
    printf '%s\n' "$dest/oss-cad-suite/bin" >>"$GITHUB_PATH"
fi
