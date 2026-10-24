"""Instruction-level RV32I-subset interpreter for ROM sanity checks.

This is NOT an RTL simulator. It decodes machine words in Python and returns
architectural state and a program-counter trace for deterministic tests.
"""
from pathlib import Path

MASK = 0xFFFFFFFF


def sx(value, bits):
    value &= (1 << bits) - 1
    return value - (1 << bits) if value & (1 << (bits - 1)) else value


def u32(value):
    return value & MASK


def run_rom(path, halt_pc, max_steps=500):
    words = [int(w, 16) for w in Path(path).read_text().split()]
    regs = [0] * 32
    ram = [0] * 256
    pc = 0
    trace = []
    branch_events = []
    for _ in range(max_steps):
        if pc == halt_pc:
            break
        assert pc % 4 == 0 and 0 <= pc // 4 < len(words), f'PC out of ROM: {pc:#x}'
        trace.append(pc)
        inst = words[pc // 4]
        op, rd = inst & 0x7f, (inst >> 7) & 31
        f3, rs1, rs2 = (inst >> 12) & 7, (inst >> 15) & 31, (inst >> 20) & 31
        f7 = (inst >> 25) & 127
        a, b = regs[rs1], regs[rs2]
        imm_i = sx(inst >> 20, 12)
        imm_s = sx(((inst >> 25) << 5) | ((inst >> 7) & 31), 12)
        imm_b = sx((((inst >> 31) & 1) << 12) | (((inst >> 7) & 1) << 11) |
                   (((inst >> 25) & 63) << 5) | (((inst >> 8) & 15) << 1), 13)
        imm_u = inst & 0xfffff000
        imm_j = sx((((inst >> 31) & 1) << 20) | (((inst >> 12) & 255) << 12) |
                   (((inst >> 20) & 1) << 11) | (((inst >> 21) & 1023) << 1), 21)
        next_pc, result = u32(pc + 4), None
        if op == 0x33:
            table = {
                (0, 0): a + b, (32, 0): a - b, (0, 7): a & b,
                (0, 6): a | b, (0, 4): a ^ b,
                (0, 2): int(sx(a, 32) < sx(b, 32)),
                (0, 3): int(a < b), (0, 1): a << (b & 31),
                (0, 5): a >> (b & 31), (32, 5): sx(a, 32) >> (b & 31),
            }
            assert (f7, f3) in table, f'Unsupported R-type at PC {pc:#x}'
            result = table[f7, f3]
        elif op == 0x13:
            table = {
                0: a + imm_i, 7: a & imm_i, 6: a | imm_i,
                4: a ^ imm_i, 2: int(sx(a, 32) < imm_i),
                3: int(a < u32(imm_i)),
            }
            if f3 == 1:
                assert f7 == 0
                result = a << rs2
            elif f3 == 5:
                assert f7 in (0, 32)
                result = (a >> rs2) if f7 == 0 else (sx(a, 32) >> rs2)
            else:
                assert f3 in table
                result = table[f3]
        elif op == 0x03:
            assert f3 == 2
            addr = u32(a + imm_i)
            assert addr % 4 == 0 and 0 <= addr // 4 < len(ram), f'Bad LW addr {addr:#x}'
            result = ram[addr // 4]
        elif op == 0x23:
            assert f3 == 2
            addr = u32(a + imm_s)
            assert addr % 4 == 0 and 0 <= addr // 4 < len(ram), f'Bad SW addr {addr:#x}'
            ram[addr // 4] = b
        elif op == 0x63:
            table = {0: a == b, 1: a != b,
                     4: sx(a, 32) < sx(b, 32), 5: sx(a, 32) >= sx(b, 32)}
            assert f3 in table
            taken = table[f3]
            branch_events.append((pc, f3, taken))
            if taken:
                next_pc = u32(pc + imm_b)
        elif op == 0x37:
            result = imm_u
        elif op == 0x17:
            result = pc + imm_u
        elif op == 0x6f:
            result = pc + 4
            next_pc = u32(pc + imm_j)
        elif op == 0x67:
            assert f3 == 0
            result = pc + 4
            next_pc = u32(a + imm_i) & ~1
        else:
            raise AssertionError(f'Unknown opcode {op:#x} at PC {pc:#x}')
        if result is not None and rd != 0:
            regs[rd] = u32(result)
        regs[0] = 0
        pc = next_pc
    else:
        raise AssertionError(f'ROM did not reach halt within {max_steps} steps')
    return {'regs': regs, 'ram': ram, 'pc': pc, 'trace': trace,
            'branch_events': branch_events}
