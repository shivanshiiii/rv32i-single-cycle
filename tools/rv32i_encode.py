"""Small RV32I encoding helpers shared by the demonstration and edge-case ROM generators."""

def check_signed(value, bits):
    if not -(1 << (bits - 1)) <= value < (1 << (bits - 1)):
        raise ValueError(f'{value} out of signed {bits}-bit range')
    return value & ((1 << bits) - 1)


def r(f7, rs2, rs1, f3, rd):
    return (f7 << 25) | (rs2 << 20) | (rs1 << 15) | (f3 << 12) | (rd << 7) | 0x33


def i(imm, rs1, f3, rd, opcode=0x13):
    v = check_signed(imm, 12)
    return (v << 20) | (rs1 << 15) | (f3 << 12) | (rd << 7) | opcode


def shift_i(f7, shamt, rs1, f3, rd):
    assert 0 <= shamt < 32
    return i((f7 << 5) | shamt, rs1, f3, rd)


def s(imm, rs2, rs1, f3=2):
    v = check_signed(imm, 12)
    return ((v >> 5) << 25) | (rs2 << 20) | (rs1 << 15) | (f3 << 12) | ((v & 31) << 7) | 0x23


def b(offset, rs2, rs1, f3):
    if offset % 2:
        raise ValueError('branch offset must be even')
    v = check_signed(offset, 13)
    return (((v >> 12) & 1) << 31) | (((v >> 5) & 63) << 25) | (rs2 << 20) | (rs1 << 15) | (f3 << 12) | (((v >> 1) & 15) << 8) | (((v >> 11) & 1) << 7) | 0x63


def u(imm20, rd, op):
    assert 0 <= imm20 < (1 << 20)
    return (imm20 << 12) | (rd << 7) | op


def j(offset, rd):
    if offset % 2:
        raise ValueError('jal offset must be even')
    v = check_signed(offset, 21)
    return (((v >> 20) & 1) << 31) | (((v >> 1) & 1023) << 21) | (((v >> 11) & 1) << 20) | (((v >> 12) & 255) << 12) | (rd << 7) | 0x6F


