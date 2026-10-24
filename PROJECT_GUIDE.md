# Your RISC-V processor: complete project guide

**Version:** v4, 23 October 2026. **GitHub release target:** 30 October 2026.

This guide explains what the project does, how to use the files, how each part of the code works, and what the verified results mean. Read it alongside `rtl/rv32i_core.v`; the complete source code is included in this package.

## 1. What you have built

You have an educational **32-bit, single-cycle processor implementing a 29-instruction subset of RV32I**.

A processor reads a machine instruction, decides what it means, performs the operation, and saves the result. For example, an ADD instruction tells it to take two numbers from registers, add them, and place the answer in another register.

- **RISC-V** is an instruction-set architecture: the agreement between software and hardware about instruction encodings and behavior.
- **RV32** means integer registers and the basic integer datapath are 32 bits wide in this design.
- **I** identifies the base integer instruction set. Our implementation supports part of it, so call it an **RV32I subset**.
- **Single-cycle** means instruction processing occurs between consecutive active clock edges. At the edge, PC and register/memory updates commit. This model has no wait states and assumes combinational memory reads.
- **RTL** means register-transfer level: Verilog describes state registers and the logic that transforms their values.

This is not a five-stage pipeline. Fetch, decode, execute, memory access and writeback are conceptual activities inside one cycle, rather than separate pipeline stages.

The project is currently simulated and synthesized to generic logic. It has not been placed on an FPGA or fabricated as an ASIC.

## 2. What to install and what each tool does

| Tool | Job |
|---|---|
| Python 3 | Generates instruction hex files, calculates reference results and runs the verification flow |
| Icarus Verilog (`iverilog`) | Compiles the Verilog design and testbench into a simulation executable |
| Icarus runtime (`vvp`) | Runs that executable and prints PASS/FAIL results |
| GTKWave | Displays time-changing signals from generated VCD waveform files |
| Yosys with ABC | Converts synthesizable Verilog into generic logic cells and performs equivalence checking |
| Git | Tracks source changes on your laptop |
| GitHub | Hosts the repository and can run the included Actions workflow |

You already reported using Icarus Verilog 12 and GTKWave. Local v4 validation also used Icarus 12.0. The recorded synthesis uses Yosys 0.33. The supplied scripts require only Python's standard library.

## 3. Exact Windows steps

### A. Extract and open

1. Download the project ZIP and choose **Extract All**.
2. Keep it in a separate folder from your old project so laptop-only edits remain available.
3. Open the extracted `rv32i-single-cycle` folder. You should see `README.md`, `rtl`, `tb`, `tools`, `programs`, `reports` and the Windows batch files.
4. Click File Explorer's address bar, type `cmd`, and press Enter.

### B. Check the tools

```bat
python --version
iverilog -V
vvp -V
yosys -V
```

Use capital `-V` for Icarus/Yosys version output. If Yosys is not available, follow `docs/yosys_windows.md`: download the Windows OSS CAD Suite from the official YosysHQ releases and activate its `environment.bat` in the terminal.

### C. Run everything

```bat
run_synthesis_windows.bat
```

This runs reference checks, four RTL testbenches, baseline and optimized synthesis, RTL equivalence and a synthesized-netlist ALU test. Success ends with:

```text
FLOW PASSED: all
```

For RTL only:

```bat
run_windows.bat
```

You can also run stages individually:

```bat
python tools\run_flow.py test
python tools\run_flow.py synth
python tools\run_flow.py equiv
python tools\run_flow.py netlist
```

Run synthesis before the netlist target. It checks the current core's hash and refuses an out-of-date netlist.

### D. Open results

```bat
type build\synth\resource_analysis.md
type build\tool_versions.txt
gtkwave build\rv32i_edge.vcd
```

If `gtkwave` is not on PATH, open GTKWave normally and open that VCD through its File menu.

Generated outputs go into `build/`. Recorded results shipped with this version are in `reports/2026-10-23/`. `build/` is safely regenerable; do not edit a generated netlist as the design source.

## 4. How an instruction moves through the processor

Consider:

```text
ADDI x1, x0, 7
ADDI x2, x0, 5
ADD  x3, x1, x2
SW   x3, 12(x0)
LW   x4, 12(x0)
```

The first two instructions put 7 and 5 in registers. ADD produces x3 = 12. SW writes 12 to byte address 12, which is word index 3. LW reads that memory word into x4. This illustrates the datapath; use the supplied program generator to produce actual machine words.

For an ADD at PC = 8:

1. `instr_addr` presents 8 to instruction memory.
2. Memory returns the 32-bit encoded instruction through `instr_data`.
3. The decoder extracts opcode, destination/source register indices and function fields.
4. Register reads provide operands `a = x1` and `b = x2`.
5. The ALU computes 7 + 5.
6. Writeback selects 12 and asserts `reg_write` for x3.
7. `next_pc` defaults to PC + 4 = 12.
8. At the next rising edge, x3 becomes 12 and PC becomes 12.

Combinational signals may change and settle between edges. They are not additional clock cycles.

## 5. Core ports: signals entering and leaving the CPU

The top module for core synthesis is `rv32i_core`.

| Signal | Direction | Meaning |
|---|---|---|
| `clk` | Input | Clock; architectural state changes on the rising edge |
| `reset` | Input | Synchronous reset; sampled on a rising edge |
| `instr_addr[31:0]` | Output | Address of the current instruction, equal to PC |
| `instr_data[31:0]` | Input | Current machine instruction |
| `dmem_addr[31:0]` | Output | Byte address for a load/store |
| `dmem_wdata[31:0]` | Output | Value to store |
| `dmem_we` | Output | Store-write enable |
| `dmem_rdata[31:0]` | Input | Value returned by data memory |
| `illegal_instr` | Output | Unsupported encoding or misaligned word-access indication |

There is currently no memory-request valid input/output pair, ready signal, wait state or complete trap interface. These are documented future improvements.

## 6. Walkthrough of `rtl/rv32i_core.v`

### PC and state

`pc` stores the current byte address. `next_pc` is combinationally calculated. The sequential PC block uses nonblocking assignments:

```verilog
always @(posedge clk) begin
    if (reset) pc <= 32'b0;
    else pc <= next_pc;
end
```

The core starts at address 0 after a reset edge. Ordinary 32-bit instructions advance by four bytes. Branches/jumps can select another address.

### Register file and x0

RISC-V exposes 32 architectural register names, x0 through x31. x0 always reads as zero; writes to it have no effect.

v4 physically stores only x1–x31. A `generate` loop creates 31 registers of 32 bits each, each with reset and a write condition. `genvar` is used while elaborating hardware; it does not mean the CPU executes a software loop every cycle.

The condition `reg_write && rd == r` enables only the selected destination register. `regfile[0]` and its packed read slot are tied to zero.

`regfile_flat` is a 1024-bit view containing the 32 architectural words. The indexed part-select:

```verilog
regfile_flat[rs1 * 32 +: 32]
```

selects 32 bits starting at `rs1 * 32`. `+: 32` means a fixed-width ascending slice, not addition to the register data. Synthesis implements this selection with muxes. The diagnostic `regfile[0:31]` view preserves the original waveform/testbench names.

### Instruction fields

| Field | Bits | Purpose |
|---|---|---|
| `opcode` | `[6:0]` | Broad instruction group |
| `rd` | `[11:7]` | Destination register |
| `funct3` | `[14:12]` | Operation within a group |
| `rs1` | `[19:15]` | First source register |
| `rs2` | `[24:20]` | Second source register, or shift-amount field in immediate shifts |
| `funct7` | `[31:25]` | Further operation distinction, such as ADD versus SUB |

The meaning of some bits depends on instruction format. For example, immediate instructions reuse bits that an R-type instruction treats as `rs2`/`funct7`.

### Immediate generation

`imm_i`, `imm_s`, `imm_b`, `imm_u` and `imm_j` rearrange encoded bits into usable 32-bit values.

- I-type: arithmetic immediates, LW offsets and JALR offsets.
- S-type: store offsets split across two instruction fields.
- B-type: branch offsets with an implicit low zero bit.
- U-type: upper immediate placed in bits 31:12, with twelve low zeros.
- J-type: JAL offset with an implicit low zero bit.

Most immediates are sign-extended. For example, a 12-bit immediate representing -1 becomes `0xffffffff` at 32 bits. Verilog replication such as `{20{instr_data[31]}}` repeats the sign bit twenty times.

### Combinational decode

`always @*` recalculates whenever an input it uses changes. Defaults are assigned before the opcode case: PC+4, no register write, no store, and zeroed inactive outputs.

Defaults matter because incomplete assignment in a combinational block can infer a latch. Our synthesis checks found zero latches.

The opcode case enables the desired operation. Nested `case`/`if` statements validate `funct3` and `funct7`. Invalid shift encodings are still rejected after optimization.

### Shared ALU

`alu_b` chooses the sign-extended immediate for immediate ALU instructions and source register `b` otherwise. The selected operand feeds shared add/logic/compare/shift expressions.

Examples:

- `a & alu_b`: AND/ANDI.
- `a | alu_b`: OR/ORI.
- `$signed(a) < $signed(alu_b)`: SLT/SLTI.
- `a < alu_b`: unsigned SLTU/SLTIU.
- `a << alu_b[4:0]`: SLL/SLLI.

Five shift bits select amounts 0–31. For a register shift, higher bits of the shift-amount register are ignored as required for RV32.

Sharing does not mean every adder in the processor disappeared. PC+4, target/address calculations and other arithmetic still require logic. The report shows measured operators and final cell counts rather than an assumed saving.

### Shared right shifter

The optimized code creates a signed 33-bit value with an extra bit equal to `instr_data[30] & a[31]`, then shifts it arithmetically and uses the low 32 output bits.

For SRL/SRLI, the extra bit is zero, so zeros enter from the left. For SRA/SRAI, it equals the sign bit, so the sign is replicated. The decoder independently checks legal function encodings.

Example: shifting `0x80000000` right by one gives `0x40000000` logically and `0xc0000000` arithmetically.

### Branches and jumps

BEQ/BNE compare equality; BLT/BGE use signed comparison. When taken, `next_pc = pc + imm_b`; otherwise PC+4 remains selected.

JAL writes PC+4 to `rd` and jumps to PC+`imm_j`. JALR writes PC+4 and selects `(a + imm_i) & 0xfffffffe`, clearing target bit 0. This implementation does not trap targets that remain misaligned for a 32-bit-only instruction stream.

### Word loads and stores

LW computes `a + imm_i`, uses the memory read value as writeback and enables a register write. SW computes `a + imm_s`, places `b` on the store bus and enables memory writing.

Aligned word addresses end in binary `00`. A nonzero `dmem_addr[1:0]` causes the current design to assert `illegal_instr` and suppress the writes. It advances PC rather than entering an architectural exception handler.

## 7. `rtl/rv32i_soc.v`: the educational memory wrapper

The SoC connects the core to two arrays: 256 instruction words and 256 data words. Each word is 32 bits = 4 bytes, so each memory contains 1 KiB.

Instruction/data reads are continuous combinational assignments. Data writes occur on a clock edge when `dmem_we` is asserted and reset is inactive. The initial block fills instruction locations with NOPs, initializes data memory, and loads the selected program via `$readmemh`.

The wrapper uses address bits `[9:2]` as a word index. For address 12, `12 >> 2 = 3`. Higher address bits are ignored, so an out-of-range access can alias a valid location. This is a known limitation, not an implemented protection feature.

The wrapper supports `IMEM_HEX` to select the demo or edge ROM. It is used for simulation; the resource comparison synthesizes only `rv32i_core` so ROM content cannot make one program's CPU appear artificially smaller.

## 8. Instruction support

| Category | Implemented instructions |
|---|---|
| Register arithmetic/logic | ADD, SUB, AND, OR, XOR, SLT, SLTU, SLL, SRL, SRA |
| Immediate arithmetic/logic | ADDI, ANDI, ORI, XORI, SLTI, SLTIU, SLLI, SRLI, SRAI |
| Memory | LW, SW |
| Branches | BEQ, BNE, BLT, BGE |
| Upper immediates | LUI, AUIPC |
| Jumps | JAL, JALR |

Total: 29. BLTU/BGEU, byte/halfword accesses and other base/system behavior are not implemented. Do not advertise the core as complete RV32I.

## 9. Every source/test/script file

| File | Purpose |
|---|---|
| `rtl/rv32i_core.v` | Optimized processor described above |
| `rtl/rv32i_soc.v` | Simulation memory wrapper |
| `baseline/rv32i_core.v` | Unchanged v3 comparison core; never compile together with the optimized core |
| `tb/tb_soc.v` | Demo self-checker: 34 cycles, registers and memory |
| `tb/tb_soc_edge.v` | Edge test: 50-step PC path, signedness, branches, loop and jumps |
| `tb/tb_core_decode.v` | Invalid encodings, misaligned words, x0 and reset |
| `tb/tb_core_alu.v` | New port-only ALU scoreboard for both RTL and netlist |
| `tb/demo_expected.vh` | Generated demo constants such as halt/link PCs |
| `tb/edge_expected.vh` | Generated edge-program constants |
| `tb/edge_trace_expected.vh` | Generated expected trace length |
| `tools/rv32i_encode.py` | Encodes R/I/S/B/U/J instructions into 32-bit words |
| `tools/build_program.py` | Builds demo ROM, listing and expected constants |
| `tools/build_edge_program.py` | Builds edge ROM, listing and expected constants |
| `tools/isa_reference.py` | Python interpreter for the implemented instruction subset |
| `tools/reference_model.py` | Checks demo architectural results |
| `tools/edge_reference.py` | Checks edge-program results and writes expected PC trace |
| `tools/build_alu_vectors.py` | Generates deterministic edge/random ALU tests with independent expected arithmetic results |
| `tools/run_flow.py` | Runs stages, captures logs, checks failures and writes source hashes |
| `tools/summarize_synthesis.py` | Reads Yosys JSON and creates the resource comparison |
| `synth/equivalence.ys` | Yosys script proving baseline-to-v4 behavior preservation |
| `Makefile` | Short Linux/WSL commands for the flow |
| `run_windows.bat` | Windows RTL-test entry point |
| `run_synthesis_windows.bat` | Windows complete-flow entry point |
| `.github/workflows/rtl-tests.yml` | GitHub Actions validation and evidence upload |
| `.gitignore` | Excludes generated build products and caches |
| `.gitattributes` | Consistent text/newline handling across platforms |

`programs/*.hex` contains machine words; `*.lst` is the human-readable listing; `*_meta.json` contains generated program metadata. Hex files are padded with NOPs to the wrapper's depth. Their active programs still contain 41 and 53 words; execution follows 34 and 50 instructions respectively because branches skip or repeat instructions.

## 10. Why the tests are useful

A testbench is simulation code around the design. It supplies a clock/reset, programs and checks, and calls `$fatal` when an expectation fails. It is not synthesized as part of the CPU.

The edge test compares PC at every executed step, so a wrong branch decision is detected even if later instructions accidentally restore a final register value.

The new ALU generator uses fixed boundary values plus a deterministic random seed. It loads operands, executes an operation, then stores the result to expose it on output ports. This avoids depending on internal names and allows the same test to run on the generated netlist.

Recorded ALU coverage: **33,302 applied instructions, including operand setup, and 6,801 checked results**. All 19 ALU instructions are covered, including every shift amount. This is not exhaustive coverage of all possible inputs or formal ISA conformance testing.

Python reference checks and RTL tests are separate: a correct Python answer does not prove Verilog correctness. Both are retained.

## 11. Synthesis: what happened and what the numbers mean

The flow reads the core, checks the hierarchy, converts procedural blocks, optimizes the design, records coarse operators, runs generic synthesis/ABC mapping, checks structure/latches, and writes a Verilog netlist plus JSON reports.

Both the saved baseline and optimized source use the same commands and Yosys version.

| Metric | Baseline | Optimized |
|---|---:|---:|
| Total generic cells | 8,003 | 7,543 |
| Flip-flops | 1,055 | 1,023 |
| Combinational cells | 6,948 | 6,520 |
| Latches | 0 | 0 |

Cell reduction = `(8003 - 7543) / 8003 * 100` = **5.75%**.

The optimized flip-flops contain 31 x 32 = 992 writable register bits and 31 PC bits. PC bit 0 is constant in this design after reset. The baseline mapping retained 32 redundant x0 storage bits; v4's explicit constant removes them.

Generic counts treat different cell types as separate countable objects. A mux and a NAND do not necessarily occupy the same physical area. Therefore these counts cannot directly establish chip area, power, physical gate equivalents or an FPGA's LUT usage.

A smaller circuit may still have a longer critical path if extra muxes precede an ALU. No frequency or power claim is made here. The testbench's clock period is only a simulation stimulus.

## 12. Equivalence and netlist checks

`equivalence.ys` reads both core versions, gives them separate names, maps their state, creates comparison points and uses Yosys proof passes. The final release log reports **1,475 proven equivalence points and zero unproven**.

This demonstrates preservation of the existing design under the reset/proof model. It does not prove that all baseline behavior matches the complete RISC-V specification. Known baseline limitations remain known limitations.

The netlist ALU simulation then checks the synthesis output with the same 6,801 externally observed results. This is zero-delay functional simulation, not a timing simulation with extracted delays.

## 13. Waveforms to inspect

Open `build/rv32i_edge.vcd`. Add clock, reset, PC/instruction, operands, write-data/write-enable, data-memory address/write-data/write-enable, and `illegal_instr`.

- First locate reset deassertion and the next rising edge.
- Observe normal PC increments of four.
- Find a taken branch and see the target PC replace PC+4.
- Find a not-taken branch and see the normal increment.
- For SW, inspect address/data and enable before the committing rising edge.
- For LW, inspect memory read data and register writeback.
- Compare SRL and SRA on a negative operand.

The original testbenches provide stable hierarchy names for PC/register observation. The netlist may rename internal signals, which is why its scoreboard uses only ports.

## 14. GitHub and resume handoff

The planned repository name is `rv32i-single-cycle` under the connected account `shivanshiiii`. Source, documentation, selected evidence and CI configuration are ready. Repository creation/public visibility currently requires explicit approval; this package has not yet been pushed and hosted Actions has not run.

Commit source/docs and `reports/`, excluding `build/` and installed tool binaries. Once published, run the workflow, link the actual successful run and tag the checked release. See `docs/github_checklist.md`.

A supportable resume statement is:

> Developed a 29-instruction RV32I single-cycle processor in Verilog; reduced Yosys generic cell count by 5.75% through shared ALU/shifter logic and x0 optimization, with RTL equivalence and self-checking RTL/netlist validation.

Do not add FPGA deployment, 100 MHz, ASIC area or full ISA compliance without corresponding evidence. Read `docs/resume_evidence.md` before copying the bullets.

## 15. What to do next

1. Read sections 1–7 with `rtl/rv32i_core.v` open beside the guide.
2. Run `run_synthesis_windows.bat` and check for `FLOW PASSED: all`.
3. Read the measured comparison and inspect one branch and one load/store waveform.
4. Complete GitHub publication/CI, documentation review and an interview walkthrough by **30 October 2026**.

The verified v4 subset is the release scope. Extra instructions, memory-fault interfaces and target-specific timing can be later improvements; they do not need to delay this deadline.
