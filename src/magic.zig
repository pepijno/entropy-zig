const std = @import("std");
const constants = @import("constants.zig");

const rookMasks = [_]u64{
    0x0008102040BE, 0x00102040813C, 0x00204081023A, 0x004081020436,
    0x00810204082E, 0x01020408101E, 0x02040810203E, 0x000810205F00,
    0x001020409E00, 0x002040811D00, 0x004081021B00, 0x008102041700,
    0x010204080F00, 0x020408101F00, 0x0008102F8080, 0x0010204F0100,
    0x0020408E8200, 0x0040810D8400, 0x0081020B8800, 0x010204079000,
    0x0204080FA000, 0x000817C04080, 0x001027808100, 0x002047410200,
    0x004086C20400, 0x008105C40800, 0x010203C81000, 0x020407D02000,
    0x000BE0204080, 0x0013C0408100, 0x0023A0810200, 0x004361020400,
    0x0082E2040800, 0x0101E4081000, 0x0203E8102000, 0x01F010204080,
    0x01E020408100, 0x01D040810200, 0x01B081020400, 0x017102040800,
    0x00F204081000, 0x01F408102000, 0xF80810204080, 0xF01020408100,
    0xE82040810200, 0xD84081020400, 0xB88102040800, 0x790204081000,
    0xFA0408102000,
};

const rookAttackMasks = [_]u64{
    0x00408102040FE, 0x008102040817D, 0x010204081027B, 0x0204081020477,
    0x040810204086F, 0x081020408105F, 0x102040810203F, 0x0040810207F01,
    0x008102040BE82, 0x0102040813D84, 0x0204081023B88, 0x0408102043790,
    0x0810204082FA0, 0x1020408101FC0, 0x00408103F8081, 0x00810205F4102,
    0x01020409EC204, 0x02040811DC408, 0x04081021BC810, 0x081020417D020,
    0x10204080FE040, 0x004081FC04081, 0x008102FA08102, 0x010204F610204,
    0x020408EE20408, 0x040810DE40810, 0x081020BE81020, 0x1020407F02040,
    0x0040FE0204081, 0x00817D0408102, 0x01027B0810204, 0x0204771020408,
    0x04086F2040810, 0x08105F4081020, 0x10203F8102040, 0x007F010204081,
    0x00BE820408102, 0x013D840810204, 0x023B881020408, 0x0437902040810,
    0x082FA04081020, 0x101FC08102040, 0x1F80810204081, 0x1F41020408102,
    0x1EC2040810204, 0x1DC4081020408, 0x1BC8102040810, 0x17D0204081020,
    0x0FE0408102040,
};

const magics = [_]u64{
    0x420008080012,  0x50005000800,   0x20100100400,
    0x84005a0a0080,  0x20020300200,   0x1400c0e00500,
    0x60004100080,   0x260408001000,  0x210408080800,
    0x180a004121,    0x1001048120,    0x600801200201,
    0x2020005c4404,  0x212400200840,  0x408001004,
    0x10060c020800,  0x1004008040041, 0x35110200400,
    0x100c08010100,  0x140204000a490, 0x380848100080,
    0x40400101000,   0x808201000,     0xc4008100800,
    0x1c05130200400, 0x100401009010,  0x1044080802842,
    0x400100080,     0x28c404002000,  0x804006003006,
    0x202004080,     0x40488020c031,  0x1001002028024,
    0x1000100510008, 0x2000820800c,   0x400080440,
    0x8088080440,    0x10202004080,   0x1082802020080,
    0x12040108040,   0x240101029a01,  0x1905400200040,
    0x34d20202062,   0x90808080011,   0x29048042422,
    0x4010020805,    0x21001042a0a,   0x111901e2030c,
    0x4040c0884842,
};

const bits = [_]u8{ 10, 9, 9, 9, 9, 9, 10, 9, 8, 8, 8, 8, 8, 9, 9, 8, 8, 8, 8, 8, 9, 9, 8, 8, 8, 8, 8, 9, 9, 8, 8, 8, 8, 8, 9, 9, 8, 8, 8, 8, 8, 9, 10, 9, 9, 9, 9, 9, 10 };

const magicIndex = [_]u16{ 0, 1024, 1536, 2048, 2560, 3072, 3584, 4608, 5120, 5376, 5632, 5888, 6144, 6400, 6912, 7424, 7680, 7936, 8192, 8448, 8704, 9216, 9728, 9984, 10240, 10496, 10752, 11008, 11520, 12032, 12288, 12544, 12800, 13056, 13312, 13824, 14336, 14592, 14848, 15104, 15360, 15616, 16128, 17152, 17664, 18176, 18688, 19200, 19712 };

var attacks = [_]constants.Bitboard{0} ** 20736;

fn indexToU64(idx: u32, bs: u8, m: u64) constants.Bitboard {
    var mm = m;
    var result: constants.Bitboard = 0;
    var i: u5 = 0;
    while (i < bs) : (i += 1) {
        const j = @truncate(u6, @ctz(mm));
        mm = mm & (mm - 1);
        if (idx & (@as(u32, 1) << i) != 0) {
            result |= (@as(u64, 1) << j);
        }
    }
    return result;
}

fn att(sq: i32, block: u64) constants.Bitboard {
    var result: constants.Bitboard = 0;
    var rk = @divTrunc(sq, 7);
    var fl = @mod(sq, 7);
    var r = rk + 1;
    while (r <= 6) : (r += 1) {
        result |= (@as(u64, 1) << @intCast(u6, fl + r * 7));
        if (block & (@as(u64, 1) << @intCast(u6, fl + r * 7)) != 0) {
            break;
        }
    }
    r = rk - 1;
    while (r >= 0) : (r -= 1) {
        result |= (@as(u64, 1) << @intCast(u6, fl + r * 7));
        if (block & (@as(u64, 1) << @intCast(u6, fl + r * 7)) != 0) {
            break;
        }
    }
    var f = fl + 1;
    while (f <= 6) : (f += 1) {
        result |= (@as(u64, 1) << @intCast(u6, f + rk * 7));
        if (block & (@as(u64, 1) << @intCast(u6, f + rk * 7)) != 0) {
            break;
        }
    }
    f = fl - 1;
    while (f >= 0) : (f -= 1) {
        result |= (@as(u64, 1) << @intCast(u6, f + rk * 7));
        if (block & (@as(u64, 1) << @intCast(u6, f + rk * 7)) != 0) {
            break;
        }
    }
    return result;
}

fn transform(b: constants.Bitboard, magic: u64, bs: i32) u32 {
    var mul: u64 = 0;
    _ = @mulWithOverflow(u64, b, magic, &mul);
    return @intCast(u32, (mul & constants.BOARD_MASK) >> @intCast(u6, 49 - bs));
}

pub fn printBB(bb: constants.Bitboard) void {
    var i: i32 = 6;
    while (i >= 0) : (i -= 1) {
        var j: u32 = 0;
        while (j < 7) : (j += 1) {
            const sq = @intCast(u6, j + 7 * @intCast(u32, i));
            if (bb & (@as(u64, 1) << sq) != 0) {
                std.debug.print("X", .{});
            } else {
                std.debug.print(".", .{});
            }
        }
        std.debug.print("\n", .{});
    }
    std.debug.print("\n", .{});
}

fn populateTable(sq: u8, magic: u64) void {
    var a = [_]constants.Bitboard{0} ** 4096;
    var b = [_]constants.Bitboard{0} ** 4096;

    const m = bits[sq];
    const start = magicIndex[sq];

    const mask = rookMasks[sq];
    const n = @intCast(u5, @popCount(mask));

    var i: u32 = 0;
    while (i < (@as(u32, 1) << n)) : (i += 1) {
        b[i] = indexToU64(i, n, mask);
        a[i] = att(sq, b[i]);
    }
    i = 0;
    while (i < (@as(u32, 1) << n)) : (i += 1) {
        const j = @intCast(u32, transform(b[i], magic, m));
        if (attacks[start + j] == @as(u64, 0)) {
            attacks[start + j] = a[i];
        }
    }
}

pub fn initMagics() void {
    var sq: u8 = 0;
    while (sq < 49) : (sq += 1) {
        populateTable(sq, magics[sq]);
    }
}

pub fn moves(bb: constants.Bitboard, sq: u32) u64 {
    const blockers: u64 = rookMasks[sq] & bb & ~(@as(u64, 1) << @intCast(u6, sq));
    var mul: u64 = 0;
    _ = @mulWithOverflow(u64, blockers, magics[sq], &mul);
    const transformed: u64 = (mul & constants.BOARD_MASK) >> @intCast(u6, 49 - bits[sq]);
    return attacks[magicIndex[sq] + transformed] & ~bb;
}

pub fn movesTo(bb: constants.Bitboard, sq: u32) u64 {
    const blockers: u64 = rookMasks[sq] & bb;
    var mul: u64 = 0;
    _ = @mulWithOverflow(u64, blockers, magics[sq], &mul);
    const transformed: u64 = (mul & constants.BOARD_MASK) >> @intCast(u6, 49 - bits[sq]);
    return attacks[magicIndex[sq] + transformed] & bb;
}
