"""Deterministic ALU checks with Python-computed expected store results.

Only core ports are observed, so the same checks run against the synthesized
netlist. Vectors exercise register/immediate operations and all shift amounts.
"""
import json
import random
from collections import Counter
from pathlib import Path

from rv32i_encode import i, r, s, shift_i, u

ROOT = Path(__file__).resolve().parents[1]
MASK = 0xFFFFFFFF
SEED = 20261023


def signed(x):
    return x if x < 0x80000000 else x - 0x100000000


def main():
    out = ROOT / 'build'
    out.mkdir(exist_ok=True)
    vectors = []
    coverage = Counter()

    def emit(word, store=False, expected=0):
        vectors.append((word << 33) | (int(store) << 32) | (expected & MASK))

    def load(rd, value):
        value &= MASK
        low = value & 0xFFF
        low = low if low < 0x800 else low - 0x1000
        upper = ((value - low) >> 12) & 0xFFFFF
        emit(u(upper, rd, 0x37))
        emit(i(low, rd, 0, rd))

    ops = [
        ('ADD', 0, 0, lambda a, b: a + b),
        ('SUB', 32, 0, lambda a, b: a - b),
        ('AND', 0, 7, lambda a, b: a & b),
        ('OR', 0, 6, lambda a, b: a | b),
        ('XOR', 0, 4, lambda a, b: a ^ b),
        ('SLT', 0, 2, lambda a, b: int(signed(a) < signed(b))),
        ('SLTU', 0, 3, lambda a, b: int(a < b)),
        ('SLL', 0, 1, lambda a, b: a << (b & 31)),
        ('SRL', 0, 5, lambda a, b: a >> (b & 31)),
        ('SRA', 32, 5, lambda a, b: signed(a) >> (b & 31)),
    ]
    edge = [0, 1, 31, 32, 0x7FFFFFFF, 0x80000000, MASK, 0xAAAAAAAA, 0x55555555]
    rng = random.Random(SEED)
    pairs = [(a, b) for a in edge for b in edge]
    pairs += [(rng.getrandbits(32), rng.getrandbits(32)) for _ in range(128)]
    pairs += [(a, sh) for a in [0x80000000, MASK, 0x7FFFFFFF] for sh in range(32)]
    for name, f7, f3, operation in ops:
        for a, b in pairs:
            load(1, a)
            load(2, b)
            emit(r(f7, 2, 1, f3, 3))
            emit(s(0, 3, 0), True, operation(a, b))
            coverage[name] += 1

    for name, f7, f3, operation in ops:
        if name == 'SUB':
            continue
        shift = name in ('SLL', 'SRL', 'SRA')
        immediates = list(range(32)) if shift else [-2048, -1025, -1, 0, 1, 31, 32, 1024, 2047]
        for a in edge + [rng.getrandbits(32) for _ in range(16)]:
            for imm in immediates:
                load(1, a)
                emit(shift_i(f7, imm, 1, f3, 3) if shift else i(imm, 1, f3, 3))
                emit(s(0, 3, 0), True, operation(a, imm & MASK))
                coverage['SLTIU' if name == 'SLTU' else name + 'I'] += 1

    emit(i(123, 0, 0, 0))
    emit(s(0, 0, 0), True, 0)
    coverage['x0_write_ignored'] += 1
    (out / 'alu_vectors.hex').write_text(''.join(f'{v:017x}\n' for v in vectors))
    metadata = {'seed': SEED, 'instruction_vectors': len(vectors),
                'result_checks': sum(coverage.values()), 'checks_by_operation': dict(coverage)}
    (out / 'alu_vectors.json').write_text(json.dumps(metadata, indent=2) + '\n')
    print(f"Generated {len(vectors)} instruction vectors; {sum(coverage.values())} result checks")


if __name__ == '__main__':
    main()
