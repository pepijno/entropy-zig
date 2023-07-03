const std = @import("std");
const constants = @import("constants.zig");
const Bitboard = constants.Bitboard;
const Side = constants.Side;
const Move = @import("move.zig").Move;
const scores = @import("scores.zig");
const FastRand = @import("fastrand.zig").FastRand;
const magic = @import("magic.zig");

fn fisherYates(vec: []u3, fast_rand: *FastRand) void {
    if (vec.len == 0) {
        return;
    }

    var last_index: u32 = @intCast(u32, vec.len - 1);
    var i: u8 = 0;
    while (i < vec.len) : (i += 1) {
        const r = fast_rand.rangedRand(last_index + 1);
        if (r == last_index) {
            continue;
        }
        const tmp = vec[r];
        vec[r] = vec[last_index];
        vec[last_index] = tmp;
        last_index -= 1;
    }
}

const score_factors = [7]u32{ 1, 8, 8 * 8, 8 * 8 * 8, 8 * 8 * 8 * 8, 8 * 8 * 8 * 8 * 8, 8 * 8 * 8 * 8 * 8 * 8 };

const Self = @This();

colors: [49]u8,
row_scores: [7]u32,
col_scores: [7]u32,
bags: [8]u8,
pieces: Bitboard,
side: Side,

pub fn newBoard() Self {
    var board = std.mem.zeroes(Self);
    board.bags = [_]u8{ 49, 7, 7, 7, 7, 7, 7, 7 };
    return board;
}

pub fn print(self: Self, buf_out: std.fs.File.Writer) !void {
    var total: u16 = 0;
    var y: i6 = 6;
    while (y >= 0) : (y -= 1) {
        try buf_out.print("{c}", .{6 - @intCast(u8, y) + @as(u8, 'A')});
        var x: u6 = 0;
        while (x < 7) : (x += 1) {
            const sq = 7 * @intCast(u6, y) + x;
            if (((@as(u64, 1) << sq) & self.pieces) != 0) {
                try buf_out.print("  {d}", .{self.colors[sq]});
            } else {
                try buf_out.print("  .", .{});
            }
        }

        const score = scores.scores[self.row_scores[@intCast(u6, y)]];
        // const score = self.row_scores[@intCast(u6, y)];
        if (score < 10) {
            try buf_out.print(" ", .{});
        }
        try buf_out.print("    {}", .{score});
        total += score;

        try buf_out.print("\n\n", .{});
    }

    try buf_out.print(" ", .{});
    y = 0;
    while (y < 7) : (y += 1) {
        try buf_out.print("  {c}", .{@intCast(u8, y) + @as(u8, 'a')});
    }
    try buf_out.print("\n ", .{});
    y = 0;
    while (y < 7) : (y += 1) {
        // const score = self.col_scores[@intCast(u6, y)];
        const score = scores.scores[self.col_scores[@intCast(u6, y)]];
        if (score < 10) {
            try buf_out.print(" ", .{});
        }
        try buf_out.print(" {}", .{score});
        total += score;
    }

    if (total < 10) {
        try buf_out.print(" ", .{});
    }

    try buf_out.print("    {}", .{total});
    try buf_out.print("\n\n", .{});

    try buf_out.print("Side: {s}\n", .{if (self.side == Side.Order) "ORDER" else "CHAOS"});
    try buf_out.print("Bags: {} {} {} {} {} {} {} {}\n", .{
        self.bags[0],
        self.bags[1],
        self.bags[2],
        self.bags[3],
        self.bags[4],
        self.bags[5],
        self.bags[6],
        self.bags[7],
    });
}

pub fn makeMove(self: *Self, move: Move) void {
    if (move.isEmpty()) {
        self.side = switch (self.side) {
            .Chaos => .Order,
            .Order => .Chaos,
        };
        return;
    }

    switch (move) {
        .Chaos => |m| {
            const color = m.color;
            const pos = m.to;
            const row = constants.rows[pos];
            const col = constants.cols[pos];
            self.colors[pos] = color;
            self.pieces |= @as(u64, 1) << pos;
            self.row_scores[row] += color * score_factors[col];
            self.col_scores[col] += color * score_factors[row];
            self.bags[0] -= 1;
            self.bags[color] -= 1;
        },
        .Order => |m| {
            const from = m.from;
            const row_from = constants.rows[from];
            const col_from = constants.cols[from];
            const to = m.to;
            const row_to = constants.rows[to];
            const col_to = constants.cols[to];
            const color = self.colors[from];
            self.colors[from] = 0;
            self.colors[to] = color;
            self.pieces &= ~(@as(u64, 1) << from);
            self.pieces |= @as(u64, 1) << to;
            self.row_scores[row_from] -= color * score_factors[col_from];
            self.col_scores[col_from] -= color * score_factors[row_from];
            self.row_scores[row_to] += color * score_factors[col_to];
            self.col_scores[col_to] += color * score_factors[row_to];
        },
    }
    self.side = switch (self.side) {
        .Order => .Chaos,
        .Chaos => .Order,
    };
}

pub fn randomPlayout(self: *Self, fast_rand: *FastRand) void {
    var numbers = [_]u3{0} ** 49;
    var current: u8 = 0;
    var i: u8 = 1;
    while (i <= 7) : (i += 1) {
        var j: u8 = 0;
        while (j < self.bags[i]) : (j += 1) {
            numbers[current] = @truncate(u3, i);
            current += 1;
        }
    }
    fisherYates(numbers[0..current], fast_rand);

    const num = if (self.side == .Chaos) 2 * self.bags[0] - 1 else 2 * self.bags[0];
    var j: u8 = 0;
    while (j < num) : (j += 1) {
        if (self.side == .Chaos) {
            const color = numbers[j / 2];
            const s = fast_rand.rangedRand(self.bags[0]);
            var pieces = self.pieces ^ constants.BOARD_MASK;
            i = 0;
            while (i < s) : (i += 1) {
                pieces &= pieces - 1;
            }
            const square = @truncate(u6, @ctz(pieces));
            var b = self.*;
            const total = b.totalScore();
            b.makeMove(.{ .Chaos = .{
                .color = color,
                .to = square,
            } });
            const new_total = b.totalScore();
            if (new_total < total) {
                const s2 = fast_rand.rangedRand(self.bags[0]);
                var pieces2 = self.pieces ^ constants.BOARD_MASK;
                i = 0;
                while (i < s2) : (i += 1) {
                    pieces2 &= pieces2 - 1;
                }
                const square2 = @truncate(u6, @ctz(pieces2));
                b.makeMove(.{ .Chaos = .{
                    .color = color,
                    .to = square2,
                } });
            } else {
                b.makeMove(.{ .Chaos = .{
                    .color = color,
                    .to = square,
                } });
            }
        } else {
            const from = @intCast(u6, fast_rand.rangedRand(49));

            if ((@as(u64, 1) << from) & self.pieces != 0) {
                var mvs: u64 = magic.moves(self.pieces, from);
                const c = @popCount(mvs);
                if (c == 0) {
                    self.makeMove(Move.empty());
                } else {
                    const r = fast_rand.rangedRand(c);
                    var k: u32 = 0;
                    while (k < r) : (k += 1) {
                        mvs &= mvs - 1;
                    }
                    const to = @truncate(u6, @ctz(mvs));
                    var b = self.*;
                    const total = b.totalScore();
                    b.makeMove(.{ .Order = .{
                        .from = from,
                        .to = to,
                    } });
                    const new_total = b.totalScore();
                    if (new_total < total) {
                        self.makeMove(Move.empty());
                    } else {
                        b.makeMove(.{ .Order = .{
                            .from = from,
                            .to = to,
                        } });
                    }
                }
            } else {
                self.makeMove(Move.empty());
            }
        }
    }
}

pub fn totalScore(self: Self) u32 {
    var total: u32 = 0;
    var i: u8 = 0;
    while (i < 7) : (i += 1) {
        total += scores.scores[self.row_scores[i]];
        total += scores.scores[self.col_scores[i]];
    }
    return total;
}

pub fn finalScore(self: Self) u32 {
    const total = self.totalScore();
    return (280 - total) | ((120 + total) << 16);
}

pub fn generateOrderMoves(self: *Self, allocator: std.mem.Allocator) !std.ArrayList(Move) {
    var moves = std.ArrayList(Move).init(allocator);
    if (self.bags[0] > 24) {
        var pieces = self.pieces;
        while (pieces != 0) {
            const from = @ctz(pieces);
            var tos = magic.moves(self.pieces, from);
            while (tos != 0) {
                const to = @ctz(tos);
                try moves.append(.{ .Order = .{
                    .from = from,
                    .to = to,
                } });
                tos &= tos - 1;
            }
            pieces &= pieces - 1;
        }
    } else {
        var empties = ~self.pieces & constants.BOARD_MASK;
        while (empties != 0) {
            const to = @ctz(empties);
            var froms = magic.movesTo(self.pieces, to);
            while (froms != 0) {
                const from = @ctz(froms);
                try moves.append(.{ .Order = .{
                    .from = from,
                    .to = to,
                } });
                froms &= froms - 1;
            }
            empties &= empties - 1;
        }
    }

    try moves.append(Move.empty());
    return moves;
}

pub fn Pair(T1: type, T2: type) type {
    return struct {
        left: T1,
        right: T2,
    };
}

pub fn bestMove(self: *Self, depth: u8, allocator: std.mem.Allocator) !struct { left: Move, right: i32 } {
    if (depth == 0) {
        return .{
            .left = Move.empty(),
            .right = try self.calcScore(allocator),
        };
    }

    const order_moves = try self.generateOrderMoves(allocator);
    defer order_moves.deinit();
    var best_score: i32 = try self.calcScore(allocator);
    var best_move = Move.empty();
    var best_t: i32 = -1000000;

    for (order_moves.items) |order_move| {
        var b = self.*;
        b.makeMove(order_move);
        const pair = try b.bestMove(depth - 1, allocator);
        const t = try b.calcScore(allocator);
        if (pair.right > best_score) {
            best_score = pair.right;
            best_move = order_move;
            best_t = t;
        } else if (pair.right == best_score and t > best_t) {
            best_score = pair.right;
            best_move = order_move;
            best_t = pair.right;
        }
    }

    return .{ .left = best_move, .right = best_score };
}

fn calcScore(self: Self, allocator: std.mem.Allocator) !i32 {
    var borders: i32 = -4 * 7;
    var pieces = self.pieces;
    var y: u8 = 0;
    while (y < 6) : (y += 1) {
        var x: u8 = 0;
        while (x < 7) : (x += 1) {
            const square = @truncate(u6, x + 7 * y);
            borders -= @boolToInt((pieces & (@as(u64, 1) << square)) != 0) ^ @boolToInt((pieces & (@as(u64, 1) << (square + 7))) != 0);
            if ((pieces & (@as(u64, 1) << square)) != 0 and (pieces & (@as(u64, 4) << (square + 7))) != 0) {
                if (self.colors[square] != self.colors[square + 7]) {
                    borders -= 3;
                }
            }
        }
    }
    y = 0;
    while (y < 7) : (y += 1) {
        var x: u8 = 0;
        while (x < 6) : (x += 1) {
            const square = @truncate(u6, x + 7 * y);
            borders -= @boolToInt((pieces & (@as(u64, 1) << square)) != 0) ^ @boolToInt((pieces & (@as(u64, 1) << (square + 1))) != 0);
            if ((pieces & (@as(u64, 1) << square)) != 0 and (pieces & (@as(u64, 4) << (square + 1))) != 0) {
                if (self.colors[square] != self.colors[square + 1]) {
                    borders -= 3;
                }
            }
        }
    }

    borders += @boolToInt((pieces & (@as(u64, 1) << 0)) != 0);
    borders += @boolToInt((pieces & (@as(u64, 1) << 1)) != 0);
    borders += @boolToInt((pieces & (@as(u64, 1) << 2)) != 0);
    borders += @boolToInt((pieces & (@as(u64, 1) << 3)) != 0);
    borders += @boolToInt((pieces & (@as(u64, 1) << 4)) != 0);
    borders += @boolToInt((pieces & (@as(u64, 1) << 5)) != 0);
    borders += @boolToInt((pieces & (@as(u64, 1) << 6)) != 0);
    borders += @boolToInt((pieces & (@as(u64, 1) << 0)) != 0);
    borders += @boolToInt((pieces & (@as(u64, 1) << 7)) != 0);
    borders += @boolToInt((pieces & (@as(u64, 1) << 14)) != 0);
    borders += @boolToInt((pieces & (@as(u64, 1) << 21)) != 0);
    borders += @boolToInt((pieces & (@as(u64, 1) << 28)) != 0);
    borders += @boolToInt((pieces & (@as(u64, 1) << 35)) != 0);
    borders += @boolToInt((pieces & (@as(u64, 1) << 42)) != 0);
    borders += @boolToInt((pieces & (@as(u64, 1) << 6)) != 0);
    borders += @boolToInt((pieces & (@as(u64, 1) << 13)) != 0);
    borders += @boolToInt((pieces & (@as(u64, 1) << 20)) != 0);
    borders += @boolToInt((pieces & (@as(u64, 1) << 27)) != 0);
    borders += @boolToInt((pieces & (@as(u64, 1) << 34)) != 0);
    borders += @boolToInt((pieces & (@as(u64, 1) << 41)) != 0);
    borders += @boolToInt((pieces & (@as(u64, 1) << 48)) != 0);
    borders += @boolToInt((pieces & (@as(u64, 1) << 42)) != 0);
    borders += @boolToInt((pieces & (@as(u64, 1) << 43)) != 0);
    borders += @boolToInt((pieces & (@as(u64, 1) << 44)) != 0);
    borders += @boolToInt((pieces & (@as(u64, 1) << 45)) != 0);
    borders += @boolToInt((pieces & (@as(u64, 1) << 46)) != 0);
    borders += @boolToInt((pieces & (@as(u64, 1) << 47)) != 0);
    borders += @boolToInt((pieces & (@as(u64, 1) << 48)) != 0);

    var dists: i32 = 0;

    var ps = [_]std.ArrayList(u32){
        std.ArrayList(u32).init(allocator),
        std.ArrayList(u32).init(allocator),
        std.ArrayList(u32).init(allocator),
        std.ArrayList(u32).init(allocator),
        std.ArrayList(u32).init(allocator),
        std.ArrayList(u32).init(allocator),
        std.ArrayList(u32).init(allocator),
        std.ArrayList(u32).init(allocator),
    };
    defer ps[0].deinit();
    defer ps[1].deinit();
    defer ps[2].deinit();
    defer ps[3].deinit();
    defer ps[4].deinit();
    defer ps[5].deinit();
    defer ps[6].deinit();
    defer ps[7].deinit();

    y = 0;
    while (y < 49) : (y += 1) {
        try ps[self.colors[y]].append(y);
    }

    y = 1;
    while (y < 8) : (y += 1) {
        if (ps[y].items.len <= 1) {
            continue;
        }
        var j: u8 = 0;
        while (j < ps[y].items.len) : (j += 1) {
            var k: u8 = j + 1;
            while (k < ps[y].items.len) : (k += 1) {
                dists -= 2 * (abs(constants.cols[ps[y].items[j]], constants.cols[ps[y].items[k]]) + abs(constants.rows[ps[y].items[j]], constants.rows[ps[y].items[k]]));
            }
        }
    }

    return dists + borders + 10 * @intCast(i32, self.totalScore());
}

fn abs(i: u8, j: u8) u8 {
    return @floatToInt(u8, @fabs(@intToFloat(f32, i) - @intToFloat(f32, j)));
}
