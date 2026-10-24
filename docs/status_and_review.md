# Status — v4, 23 October 2026

The saved v3 core was recovered and all three existing tests were reproduced on Icarus Verilog 12.0. Your earlier Windows/GTKWave work remains prior user-reported evidence; any laptop-only edits outside the saved archive were unavailable to this build.

The v4 release adds shared ALU/shifter logic, an explicit constant x0, ROM padding, a fourth RTL testbench, baseline equivalence, synthesized-netlist ALU checks, generic resource reports and reproducible automation. See README and `reports/2026-10-23/` for the recorded results.

Synthesis is now completed for the core. GitHub-hosted CI, memory-fault improvements and target-specific timing remain pending. No external repository was created or updated.

Known limitations remain documented in README. Scope stays single-cycle through 30 October 2026; see `docs/roadmap.md`.
