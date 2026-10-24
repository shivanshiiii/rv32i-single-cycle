# GitHub release plan — by 30 October 2026

The processor project is due on GitHub by **30 October 2026**. The broader portfolio deadline of 19 November does not extend this project's schedule. Release the verified single-cycle design with honest scope and reproducible results.

| Dates | Deliverable | Completion test |
|---|---|---|
| 23 October | Optimized v4 source, synthesis and verification evidence | Completed locally: four RTL tests, baseline equivalence, netlist ALU checks, 5.75% generic cell reduction |
| 24–25 October | Reproduce on Windows; review datapath and resource report | Full flow passes locally; explain x0, shared shifter and measured counts |
| 26–27 October | Repository setup, README, diagrams and hosted CI | Source and evidence on the intended repository; GitHub workflow passes |
| 28–29 October | Final review, short waveform walkthrough and resume wording | Clean clone reproduces results; links and every numerical claim checked |
| 30 October | Published, reviewed project milestone | Repository accessible, CI evidence linked, source frozen and release tagged |

These are latest target dates, not reasons to delay work that can finish sooner. Source development and local checks are already complete for v4. GitHub publication can proceed once the intended repository is available.

## Release scope

Keep the verified 29-instruction subset, shared ALU/right shifter, explicit constant x0, four RTL testbenches, equivalence flow, generic synthesis comparison and documentation. This is a coherent intermediate-level project.

Memory faults, unsigned branches, byte/halfword accesses and physical timing are future enhancements; they are not prerequisites for the 30 October release. Do not advertise them as implemented. A pipeline, UVM, caches and coherence are outside this release.

## Technical backlog after this release (optional, unscheduled)

1. Add explicit memory request validity and error responses, full-address range checks and tests that failed accesses cannot commit.
2. Add instruction fetch/target alignment checks; JALR clears bit 0 but may still leave bit 1 set.
3. Extend the ISA only alongside corresponding tests and an updated instruction count.
4. Select an FPGA or ASIC library before making timing/area/power claims. A simulation clock is not measured Fmax.
5. Functional extensions require a reviewed equivalence contract for unchanged instructions; preserve the v3 baseline rather than replacing it to force a proof pass.
