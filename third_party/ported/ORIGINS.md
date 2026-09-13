# Ported sources

Exact copies of upstream files for Tier 1 §2 (`evidence/sail/TIER1_PROTOCOL.md`).
The port reads only these copies; `ported.sh` ties them to the pinned commits.

| Directory | Repository | Commit |
|---|---|---|
| `sail-riscv-29e6158/` | https://github.com/riscv/sail-riscv | `29e6158f0a88bdb26b9fbcd0718ab919449b5179` (tag 0.14) |
| `cva6-49b5fa9e/` | https://github.com/openhwgroup/cva6 | `49b5fa9e2f5a803cd52f8430d8e8818089e68865` (master, 2026-09-11) |

Every file keeps its upstream path, bytes and header. `SHA256SUMS` lists them all.

    bash third_party/ported/ported.sh            fetch both commits, compare every copy (online)
    bash third_party/ported/ported.sh --offline  check SHA256SUMS only
    bash third_party/ported/ported.sh --fetch    rewrite the copies from the commits

## Licences

- sail-riscv files: BSD-2-Clause, `sail-riscv-29e6158/LICENCE`.
- CVA6 files: Solderpad Hardware License 0.51, `cva6-49b5fa9e/LICENSE` and
  `cva6-49b5fa9e/vendor/pulp-platform/common_cells/LICENSE`. Two exceptions:
  `config_pkg.sv` and `cv64a6_imafdc_sv39_config_pkg.sv` are Apache-2.0 WITH
  SHL-2.0, as their headers state (the SHL-2.0 text is not in the CVA6 tree;
  the headers carry the notice and its URL). `build_config_pkg.sv` has no
  header and falls under `cva6-49b5fa9e/LICENSE`.
