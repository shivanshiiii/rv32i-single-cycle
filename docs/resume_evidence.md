# Resume and interview evidence

Use these statements after reviewing the design and reproducing the flow so you can explain the work. The counts below describe this saved v4 release on Yosys 0.33, not an arbitrary future version.

**32-bit Single-Cycle RISC-V Processor | Verilog, Icarus Verilog, GTKWave, Yosys, Python**

- Developed and verified a single-cycle processor implementing a 29-instruction RV32I subset, with arithmetic, branch/jump control and aligned word load/store operations.
- Reduced Yosys generic cell count by **5.75% (8,003 to 7,543)** through shared ALU/shifter logic and explicit x0 handling; verified RTL equivalence against the preserved baseline.
- Built a reproducible regression flow with four RTL testbenches, **6,801 additional ALU result checks**, and generic-netlist ALU simulation; prepared GitHub Actions automation and synthesis reports.

Use “prepared GitHub Actions automation” until the hosted workflow actually runs successfully. Your earlier GTKWave inspection was reported from the Windows session; this release reran simulation and generated VCDs but did not repeat that GUI inspection.

## Evidence map

| Claim | Evidence |
|---|---|
| 29-instruction subset | README ISA list and `rtl/rv32i_core.v` |
| Original three tests pass | `reports/2026-10-23/tb_soc.log`, `tb_soc_edge.log`, `tb_core_decode.log` |
| New 6,801 result checks | `alu_vectors.json`, `rtl_alu.log` |
| 5.75% generic cell reduction | `comparison.json`, `resource_analysis.md`, both synthesis logs |
| No inferred latches | synthesis script assertions and mapped cell statistics |
| RTL equivalence | `equivalence.log` |
| Netlist ALU checks | `netlist_alu.log` |
| Tested source identity | `source_sha256.json` |

## Explain these points in an interview

1. Fetch, decode, ALU, memory and writeback occur combinationally between clock edges; state commits at the edge.
2. A single-cycle core's clock period must accommodate its longest complete path, potentially including external memory. Fewer cells does not guarantee lower delay.
3. Signed and unsigned comparisons differ when bit 31 is set. SRA copies the sign bit; SRL inserts zeros; shifts use five shift-amount bits.
4. Shared operations save duplicated logic but add selection muxes. The measured improvement is tool- and flow-specific.
5. x0 is constant. The optimized physical register storage is 31 x 32 = 992 bits, plus 31 synthesized PC bits.
6. Simulation checks examples. Equivalence checks preservation of the existing design under its proof model. Neither establishes full ISA compliance for an intentionally incomplete processor.
7. Be ready to explain out-of-range address aliasing and why a valid/error interface is the next improvement.
