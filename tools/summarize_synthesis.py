"""Summarize Yosys generic cell counts without claiming physical area/timing."""
import hashlib
import json
from pathlib import Path

ROOT = Path(__file__).resolve().parents[1]
OUT = ROOT / 'build/synth'


def load(label, name):
    data = json.loads((OUT / label / name).read_text())
    return data['modules']['\\rv32i_core']


def main():
    rows = {}
    for label, source in [('baseline', 'baseline/rv32i_core.v'), ('optimized', 'rtl/rv32i_core.v')]:
        module = load(label, 'stats.json')
        counts = module['num_cells_by_type']
        flip_flops = sum(v for k, v in counts.items() if 'DFF' in k)
        latches = sum(v for k, v in counts.items() if 'LATCH' in k)
        rows[label] = {
            'source': source, 'sha256': hashlib.sha256((ROOT / source).read_bytes()).hexdigest(),
            'total_cells': module['num_cells'], 'flip_flops': flip_flops,
            'combinational_cells': module['num_cells'] - flip_flops - latches,
            'latches': latches, 'memory_bits_after_mapping': module['num_memory_bits'],
            'cells_by_type': counts,
            'coarse_cells_by_type': load(label, 'coarse.json')['num_cells_by_type'],
        }
    baseline, opt = rows['baseline'], rows['optimized']
    reduction = 100 * (baseline['total_cells'] - opt['total_cells']) / baseline['total_cells']
    rows['total_cell_reduction_percent'] = reduction
    rows['measurement_scope'] = 'Core only; generic ABC gate mapping; external instruction/data RAM excluded'
    (OUT / 'comparison.json').write_text(json.dumps(rows, indent=2) + '\n')
    lines = ['# Generic synthesis resource comparison', '', rows['measurement_scope'] + '.', '',
             '| Metric | Baseline v3 | Optimized v4 |', '|---|---:|---:|']
    for key, title in [('total_cells', 'Total generic cells'), ('flip_flops', 'Flip-flops'),
                       ('combinational_cells', 'Combinational cells'), ('latches', 'Latches')]:
        lines.append(f'| {title} | {baseline[key]} | {opt[key]} |')
    lines += ['', f'Total generic cell reduction: **{reduction:.2f}%**.', '',
              'Each flip-flop stores one bit. The optimized state is 992 writable register bits',
              'plus 31 PC bits = 1,023 flip-flops. PC bit 0 is constant after reset.',
              'The baseline retains 32 redundant x0 storage bits; v4 explicitly ties x0 to zero.', '',
              'Generic cell counts are not NAND2-equivalent gates, ASIC area, FPGA LUT utilization,',
              'power, or maximum clock frequency. Cell types have different physical costs.',
              'Resource sharing adds input muxes; fewer cells does not prove faster timing.', '',
              '## Mapped cell types', '', '| Type | Baseline | Optimized v4 |', '|---|---:|---:|']
    for key in sorted(baseline['cells_by_type'].keys() | opt['cells_by_type'].keys()):
        lines.append(f"| `{key}` | {baseline['cells_by_type'].get(key, 0)} | {opt['cells_by_type'].get(key, 0)} |")
    lines += ['', '## Coarse operator counts before generic mapping', '',
              '| Operator | Baseline | Optimized v4 |', '|---|---:|---:|']
    for key in ['$add', '$sub', '$shl', '$shr', '$sshr', '$lt', '$and', '$or', '$xor']:
        lines.append(f"| `{key}` | {baseline['coarse_cells_by_type'].get(key, 0)} | {opt['coarse_cells_by_type'].get(key, 0)} |")
    lines += ['', 'Source hashes and exact cell counts: `comparison.json`.',
              'Tool version: `../tool_versions.txt`. Reproduce with `python tools/run_flow.py synth`.', '']
    (OUT / 'resource_analysis.md').write_text('\n'.join(lines))
    print('\n'.join(lines[:13]))


if __name__ == '__main__':
    main()
