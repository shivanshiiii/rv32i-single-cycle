# 32-bit Single-Cycle RISC-V Processor

A Verilog implementation of a **29-instruction RV32I subset**, with reproducible simulation, generic Yosys synthesis, and RTL equivalence checking. Single-cycle execution uses external asynchronous-read instruction/data memory.

**Release v4 — 23 October 2026. Deadline: 30 October 2026.**

For a complete beginner walkthrough, start with [PROJECT_GUIDE.md](PROJECT_GUIDE.md).

## Measured results

The preserved v3 core and optimized v4 core use the same synthesis flow and tool version.

| Core-only generic mapping | v3 baseline | v4 optimized |
|---|---:|---:|
| Total cells | 8,003 | 7,543 |
| Flip-flops | 1,055 | 1,023 |
| Combinational cells | 6,948 | 6,520 |
| Inferred latches | 0 | 0 |

**460 fewer generic cells (5.75%).** ALU sharing and a constant x0 reduce hardware while preserving the original subset's behavior. Generic cell counts are not ASIC area, NAND2-equivalent gate counts, FPGA LUT counts, power or Fmax. Instruction/data memories are excluded.

Tool versions: **Icarus Verilog 12.0**, **Yosys 0.33 (2584903a060)**, Python 3.12.14. Different synthesis releases may produce different counts; always compare both sources with the same tool/flow.

## Verification

| Check | Recorded result |
|---|---|
| Python demo and edge ISA references | PASS |
| Original demo RTL test | PASS: 34 instruction cycles |
| Original edge RTL test | PASS: 50 instruction steps and PC trace |
| Original decoder/reset test | PASS: 11 instruction steps |
| New ALU port-level scoreboard | PASS: 33,302 instructions; 6,801 result checks |
| Baseline-to-v4 RTL equivalence | PASS using Yosys equivalence passes |
| Optimized generic netlist ALU simulation | PASS: same 6,801 result checks |
| Yosys structural checks / latch checks | PASS |
| GitHub-hosted Actions run | Pending repository publication |
| Physical timing / power / FPGA deployment | Not performed |

Evidence is under `reports/2026-10-23/`. Equivalence proves preservation of the baseline under the documented reset/use model; it does not prove full RISC-V ISA conformance or fix baseline limitations.

## Run

Install Python 3, Icarus Verilog (`iverilog`, `vvp`) and Yosys with ABC on PATH. Run from this repository directory:

```bash
python tools/run_flow.py test     # references plus four RTL testbenches
python tools/run_flow.py synth    # baseline and optimized synthesis, logs and comparison
python tools/run_flow.py equiv    # optimized RTL against preserved baseline
python tools/run_flow.py netlist  # port-only checks on synthesized core
python tools/run_flow.py all      # complete flow
```

On systems where Python is named `python3`, use that name. Linux/WSL also provides `make test`, `make synth`, `make equiv`, `make netlist`, and `make verify`.

Windows: run `run_windows.bat` for RTL checks, or `run_synthesis_windows.bat` for the complete flow. See [Windows synthesis steps](docs/yosys_windows.md). Batch wrappers are supplied; the underlying Python/tool commands were validated on Linux.

## What changed in v4

- Register/immediate instructions share bitwise, compare and shift execution units through an operand mux.
- Logical and arithmetic right shifts share a signed 33-bit shifter with controlled sign extension.
- x0 is a constant; only x1–x31 have physical register storage. Packed read selection implements balanced mux trees.
- Demo/edge ROM generators pad unused locations with NOPs, removing incomplete `$readmemh` warnings without altering executed programs.
- Added deterministic ALU edge/random vectors, a port-only scoreboard usable after synthesis, formal equivalence scripts, fail-fast Python automation, machine-readable resource reports, source hashes and an expanded CI workflow.

## Layout

| Path | Purpose |
|---|---|
| `rtl/` | Optimized core and educational memory wrapper |
| `baseline/rv32i_core.v` | Byte-for-byte original v3 core for comparison |
| `tb/` | Three original testbenches plus ALU scoreboard |
| `programs/` | ROM files, listings, reference metadata |
| `tools/` | ROM generation, reference model, regression and synthesis runners |
| `synth/equivalence.ys` | RTL equivalence script |
| `reports/2026-10-23/` | Recorded logs, cell statistics, source hashes |
| `docs/` | Architecture, testing, Windows steps, roadmap and resume evidence |
| `.github/workflows/rtl-tests.yml` | CI definition; not yet run on GitHub |
| `build/` | Regenerated logs, waveforms and netlists; ignored by Git |

## Instruction subset

- **Register ALU (10):** ADD, SUB, AND, OR, XOR, SLT, SLTU, SLL, SRL, SRA.
- **Immediate ALU (9):** ADDI, ANDI, ORI, XORI, SLTI, SLTIU, SLLI, SRLI, SRAI.
- **Memory (2):** LW, SW; aligned words only.
- **Branches (4):** BEQ, BNE, BLT, BGE.
- **Upper immediate (2):** LUI, AUIPC.
- **Jumps (2):** JAL, JALR.

## Known limitations

This is an educational RV32I subset, not a fully compliant processor. Illegal encodings and misaligned LW/SW assert `illegal_instr`, suppress writes, and advance PC rather than trap. Instruction target alignment is not trapped. The SoC's 1 KiB memories alias out-of-range addresses through `[9:2]`; this is a next-stage issue. No byte/halfword accesses, unsigned branches, CSRs, interrupts, bus stalls or pipeline are implemented. Asynchronous memory reads must be reconsidered before using synchronous FPGA block RAM.

Scope stays single-cycle through the deadline. See [roadmap](docs/roadmap.md), [resource analysis](reports/2026-10-23/resource_analysis.md), [verification details](docs/testing.md), and [resume evidence](docs/resume_evidence.md).
