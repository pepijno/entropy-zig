const std = @import("std");

pub const Side = enum(u1) {
    Chaos,
    Order,
};

pub const Bitboard = u64;

pub const BOARD_MASK: u64 = 0x1FFFFFFFFFFFF;

pub const EPSILON: f64 = 0.0000000001;

pub const cols: [49]u8 = blk: {
    var cs = [_]u8{0} ** 49;
    var i: u8 = 0;
    while (i < 49) : (i += 1) {
        cs[i] = i % 7;
    }
    break :blk cs;
};

pub const rows: [49]u8 = blk: {
    var rs = [_]u8{0} ** 49;
    var i: u8 = 0;
    while (i < 49) : (i += 1) {
        rs[i] = i / 7;
    }
    break :blk rs;
};

const c = @sqrt(2.0);

pub fn exploration(visits: u64) f64 {
    return c * @sqrt(@log(@intToFloat(f64, visits) + 1.0));
}

pub fn uncertainty(visits: u64) f64 {
    return 1.0 / @sqrt(@intToFloat(f64, visits) + EPSILON);
}
