const std = @import("std");
const constants = @import("constants.zig");
const Side = constants.Side;

pub const Move = union(Side) {
    const Self = @This();

    Chaos: packed struct {
        color: u3,
        to: u6,
        _padding: u3 = 0,
    },
    Order: struct {
        from: u6,
        to: u6,
    },

    pub fn empty() Self {
        return .{
            .Chaos = .{
                .color = 0,
                .to = 0,
            },
        };
    }

    pub fn isEmpty(self: Self) bool {
        return switch (self) {
            .Order => false,
            .Chaos => |move| move.to == 0 and move.color == 0,
        };
    }

    pub fn print(self: Self, buf_out: std.fs.File.Writer) !void {
        if (self.isEmpty()) {
            try buf_out.print("AaAa", .{});
            return;
        }

        switch (self) {
            .Chaos => |m| {
                const col = constants.cols[m.to];
                const row = constants.rows[m.to];
                try buf_out.print("{c}{c}", .{ 6 + 'A' - row, 'a' + col });
            },
            .Order => |m| {
            const from_col = constants.cols[m.from];
            const from_row = constants.rows[m.from];
            const to_col = constants.cols[m.to];
            const to_row = constants.rows[m.to];
            try buf_out.print("{c}{c}{c}{c}", .{ 6 + 'A' - from_row, 'a' + from_col, 6 + 'A' - to_row, 'a' + to_col });
            },
        }
    }
};
