# GitHub handoff

Suggested repository name: `rv32i-single-cycle`. Suggested description: `29-instruction RV32I subset in Verilog with self-checking tests, Yosys synthesis and RTL equivalence checks.`

The saved v3 source was recovered; no existing matching GitHub repository was found. This release is prepared for publication, not already pushed. Remote Actions execution remains pending.

## Contents to commit

Commit `rtl/`, `baseline/`, `tb/`, `programs/`, `tools/`, `synth/`, `docs/`, `reports/`, README, Makefile, Windows scripts, `.gitattributes`, `.gitignore` and `.github/workflows/rtl-tests.yml`.

Do not commit generated executables, `build/`, Python caches, tool installations or the outer ZIP. The included `.gitignore` covers normal build products. Keep the recorded `reports/2026-10-23/` snapshot as evidence; it contains no simulator executables.

## First local commit

From the extracted project directory:

```bash
git init -b main
git add .
git diff --cached --stat
git commit -m "Add verified RV32I subset with synthesis and equivalence flow"
```

Use your own Git author configuration. Create/select your repository before adding its exact remote URL; no owner or URL is assumed here. Push this source, check the Actions tab, then record the actual workflow run URL in the README after it passes.

Recommended first release tag after CI passes: `v0.4.0`.

## Review checklist

- README says **RV32I subset**, includes all 29 implemented instructions and known limitations.
- Both synthesis runs use the same tool version, top and mapping flow.
- Evidence source hashes match this release's files.
- No claims of FPGA implementation, ASIC area, 100 MHz, power saving or complete ISA compliance.
- Future functional changes retain tests and have a clear before/after explanation.
