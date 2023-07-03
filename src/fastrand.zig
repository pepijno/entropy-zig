const std = @import("std");

pub const FastRand = struct {
    const multiplier: u64 = 6364136223846793005;
    const increment: u64 = 1442695040888963407;

    state: u64,

    pub fn init(seed: u64) @This() {
        var fastRand: @This() = .{
            .state = 2 * seed + 1,
        };

        _ = fastRand.rand();
        return fastRand;
    }

    pub fn rand(self: *@This()) u32 {
        var x: u64 = self.state;
        var count: u6 = @truncate(u6, x >> 61);
        _ = @mulWithOverflow(u64, x, multiplier, &self.state);
        x ^= x >> 22;
        return @truncate(u32, x >> (22 + count));
    }

    pub fn rangedRand(self: *@This(), range: u32) u32 {
        const r = self.rand();
        var tmp = @intCast(u64, r) * @intCast(u64, range);
        var leftover = @truncate(u32, tmp);
        if (leftover < range) {
            var threshold: u32 = 0;
            _ = @subWithOverflow(u32, 0, range, &threshold);
            threshold = threshold % range;
            while (leftover < threshold) {
                const r2 = self.rand();
                tmp = @intCast(u64, r2) * @intCast(u64, r2);
                leftover = @intCast(u32, tmp);
            }
        }
        return @truncate(u32, tmp >> 32);
    }
};
