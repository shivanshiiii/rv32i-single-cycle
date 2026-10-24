# Generic synthesis resource comparison

Core only; generic ABC gate mapping; external instruction/data RAM excluded.

| Metric | Baseline v3 | Optimized v4 |
|---|---:|---:|
| Total generic cells | 8003 | 7543 |
| Flip-flops | 1055 | 1023 |
| Combinational cells | 6948 | 6520 |
| Latches | 0 | 0 |

Total generic cell reduction: **5.75%**.

Each flip-flop stores one bit. The optimized state is 992 writable register bits
plus 31 PC bits = 1,023 flip-flops. PC bit 0 is constant after reset.
The baseline retains 32 redundant x0 storage bits; v4 explicitly ties x0 to zero.

Generic cell counts are not NAND2-equivalent gates, ASIC area, FPGA LUT utilization,
power, or maximum clock frequency. Cell types have different physical costs.
Resource sharing adds input muxes; fewer cells does not prove faster timing.

## Mapped cell types

| Type | Baseline | Optimized v4 |
|---|---:|---:|
| `$_ANDNOT_` | 1976 | 1750 |
| `$_AND_` | 136 | 163 |
| `$_MUX_` | 2689 | 2518 |
| `$_NAND_` | 123 | 177 |
| `$_NOR_` | 165 | 240 |
| `$_NOT_` | 243 | 185 |
| `$_ORNOT_` | 222 | 155 |
| `$_OR_` | 1066 | 942 |
| `$_SDFFCE_PN0P_` | 992 | 0 |
| `$_SDFFE_PP0P_` | 1 | 993 |
| `$_SDFF_PN0_` | 32 | 0 |
| `$_SDFF_PP0_` | 30 | 30 |
| `$_XNOR_` | 109 | 124 |
| `$_XOR_` | 219 | 266 |

## Coarse operator counts before generic mapping

| Operator | Baseline | Optimized v4 |
|---|---:|---:|
| `$add` | 7 | 7 |
| `$sub` | 1 | 1 |
| `$shl` | 2 | 1 |
| `$shr` | 2 | 0 |
| `$sshr` | 2 | 1 |
| `$lt` | 5 | 3 |
| `$and` | 2 | 2 |
| `$or` | 3 | 1 |
| `$xor` | 2 | 1 |

Source hashes and exact cell counts: `comparison.json`.
Tool version: `tool_versions.txt` (beside this archived report). Reproduce with `python tools/run_flow.py synth`.
