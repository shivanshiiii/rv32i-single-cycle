# Yosys synthesis on your Windows laptop

Your previous three Icarus 12 tests and GTKWave inspection are the starting point. This package was developed from the saved v3 source. Extract it into a separate folder, so any laptop-only edits remain available for comparison.

## 1. Make Yosys available

If `yosys -V` already works in Command Prompt, continue to step 2.

Otherwise download the Windows x64 OSS CAD Suite package from the official [YosysHQ releases](https://github.com/YosysHQ/oss-cad-suite-build/releases). Extract it, for example to `C:\tools\oss-cad-suite`.

Open **Command Prompt** and activate it (replace the path with your actual extraction location):

```bat
call C:\tools\oss-cad-suite\environment.bat
yosys -V
iverilog -V
python --version
```

The official [installation guide](https://github.com/YosysHQ/oss-cad-suite-build#installation) specifies `environment.bat` for Windows. Activate it again in each new terminal. This may select the suite's bundled tools; record their displayed versions.

## 2. Open the project folder

Open the extracted `rv32i-single-cycle` folder in File Explorer. Click its address bar, type `cmd`, and press Enter. If this is a new terminal, run the activation command from step 1 in it.

Check that `dir` lists `rtl`, `tb`, `tools` and `README.md`.

## 3. Run the complete flow

```bat
run_synthesis_windows.bat
```

This runs the original tests, new ALU checks, both synthesis comparisons, RTL equivalence, and the synthesized-netlist ALU check. Success ends with:

```text
FLOW PASSED: all
```

If a command fails, the runner stops. Read the named log and the first error; do not edit expectations to force a pass. RTL-only checks remain available with `run_windows.bat`.

## 4. Read the actual results

```bat
type build\synth\resource_analysis.md
type build\tool_versions.txt
```

The 23 October reference measurement used Yosys 0.33 and showed 8,003 to 7,543 cells. A different Yosys/ABC release can change these counts. Use the baseline and optimized results from the same local run.

Useful files:

| File | Meaning |
|---|---|
| `build\synth\optimized\synthesis.log` | Complete synthesis transcript |
| `build\synth\optimized\stats.json` | Counts by generic cell type |
| `build\synth\optimized\rv32i_core_netlist.v` | Generated generic gate-level core |
| `build\synth\comparison.json` | Both results and source hashes |
| `build\equivalence.log` | Baseline-to-optimized proof result |
| `build\logs\netlist_alu.log` | Netlist scoreboard result |

## 5. Explain the numbers

- A flip-flop stores one bit. The optimized core has 992 writable register bits plus 31 synthesized PC bits. PC bit 0 is constant; x0 uses no storage.
- Combinational cells implement arithmetic, decoding and selection. A mux chooses one input according to a control signal.
- Zero latches means synthesis did not infer level-sensitive storage.
- The core-only synthesis does not include the wrapper's ROM/RAM.
- A 10 ns testbench clock is stimulus, not proof of 100 MHz operation. Real timing needs a device/cell library and constraints.

## 6. GitHub preparation

The archive includes `.github/workflows/rtl-tests.yml` and `.gitignore`. Commit the source, documentation and recorded reports. Keep regenerated `build/` outputs out of source control. No GitHub repository was created or updated by this release; see `docs/github_checklist.md`.
