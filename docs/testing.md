# Verification — v4, 23 October 2026

## Layers and limits

1. **Python reference checks** validate the generated demo/edge programs using an instruction interpreter. They do not run RTL.
2. **Three original RTL testbenches** check program results, PC traces, memory results, illegal decode, alignment, x0 and reset. They pass again with Icarus Verilog 12.0.
3. **ALU scoreboard** checks all 19 implemented register/immediate ALU operations. Python calculates expected results, then the testbench observes only core ports using SW to expose results. It checks instruction PC, illegal flag, store enable, address and data. Inputs include zero, signed extremes, alternating bits, carry/wrap cases, all 32 shift amounts, immediate boundaries and deterministic pseudorandom operands (seed 20261023).
4. **RTL equivalence** compares v4 with `baseline/rv32i_core.v` using Yosys `equiv_make`, `equiv_simple`, `equiv_induct -seq 4`, and `equiv_status -assert`. All equivalence points must be proven. Both designs use the same synchronous reset protocol; the testbenches establish post-reset behavior. Yosys induction establishes that matched states/observations do not diverge. This is baseline preservation, not an independent ISA compliance proof.
5. **Generic netlist simulation** runs the ALU port scoreboard on Yosys's generated Verilog. It is zero-delay functional simulation, not timing-annotated gate simulation. It does not exhaustively test every instruction or every netlist path.
6. **Synthesis checks** fail on structural errors or inferred latches. Separate baseline/optimized logs and JSON statistics enable repeatable comparison.

## Recorded counts

- Demo: 34 instruction cycles; register and RAM checks.
- Edge: 50 executed instructions; PC path, signedness, branches, loop/jumps and RAM checks.
- Decode: 11 instruction steps plus reset checks.
- ALU: 33,302 applied instruction vectors and 6,801 checked results, on both RTL and the optimized netlist. Setup LUI/ADDI instructions account for the difference between vector count and result count.

This is directed and deterministic randomized coverage, not measured code coverage or full RISC-V architecture-test compliance. The generated `alu_vectors.json` lists counts by operation; only the 19 ALU instructions receive the new dense coverage. Control/memory instructions retain the original directed coverage.

## Commands

```bash
python tools/run_flow.py all
```

See README for individual targets. All stages use checked subprocess return codes. Yosys writes its log directly; no shell `tee` pipeline can hide a failed synthesis command. The netlist test rejects a synthesized core whose source hash differs from the current RTL.

Generated `build/` artifacts are excluded from Git; selected completed evidence is copied into a dated `reports/` folder. No checked-in PASS text substitutes for rerunning validation after a source change.

## Reset and memory assumptions

Assert synchronous reset across at least one rising edge before execution; testbenches use two or three. Inputs should be stable before the committing edge. Reads are combinational; there is no ready/wait mechanism. The wrapper initializes RAM for simulation and indexes only address bits `[9:2]`. Tests use valid in-range addresses. Misaligned memory accesses flag an error and suppress writes rather than implementing an architectural trap.

## Warning cleanup

Original demo/edge hex files contained only active program words, causing Icarus to warn when reading a 256-word memory. Generators now append NOPs to exactly 256 words. Program listings, halt locations, reference expectations and executed instruction counts are unchanged. Warnings were removed by fixing the image length, not by hiding simulator diagnostics.

The generic netlist's Icarus compile log includes a missing-timescale warning because Yosys does not emit a timescale directive. The netlist has no delay statements; the scoreboard clock is explicitly timed. This warning does not change the zero-delay functional result and does not establish physical timing.
