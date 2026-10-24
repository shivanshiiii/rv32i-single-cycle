#!/usr/bin/env python3
"""Check demo ROM with a Python ISA interpreter, NOT a Verilog simulator."""
from pathlib import Path
import json
from isa_reference import run_rom

ROOT = Path(__file__).resolve().parents[1]
meta = json.loads((ROOT / 'programs/demo_meta.json').read_text())
result = run_rom(ROOT / 'programs/demo.hex', meta['halt_pc'])
regs, ram = result['regs'], result['ram']
expected = {
    0: 0, 1: 7, 2: 5, 3: 12, 4: 2, 5: 5, 6: 7, 7: 2, 8: 640,
    9: 5, 10: 1, 11: 20, 12: 0xfffffff8, 13: 0xfffffffe,
    14: 3, 15: 7, 16: 4, 17: 1, 18: 20, 19: 10, 20: 12,
    21: 0, 22: 0x12345000,
    23: 0x1000 + meta['labels']['branch_b'] + 4,
    24: meta['labels']['jal_target'] - 4, 25: 0,
    26: meta['labels']['jalr_target'] - 4,
    27: meta['labels']['jalr_target'], 28: 1, 29: 1,
    30: 0xfffffffe, 31: 0xffffffff,
}
for reg, value in expected.items():
    assert regs[reg] == value, f'x{reg} expected {value:#010x}, got {regs[reg]:#010x}'
assert ram[3] == 12, f'dmem[3] expected 12, got {ram[3]}'
assert len(result['trace']) == 34, f'Unexpected demo path length {len(result["trace"])}'
print(f'PASS: Python demo reference: {len(result["trace"])} executed instructions, '
      f'{len(expected)} registers, RAM[3]')
print('NOTE: Python reference is NOT an RTL simulation.')
