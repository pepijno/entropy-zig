const std = @import("std");
const constants = @import("constants.zig");
const Board = @import("board.zig");
const Side = constants.Side;
const Move = @import("move.zig").Move;
const Allocator = std.mem.Allocator;
const magic = @import("magic.zig");
const FastRand = @import("fastrand.zig").FastRand;

const Self = @This();

moves_left: std.ArrayList(Move),
children: std.ArrayList(*Self),
visits: u64 = 0,
score: u64 = 0,
min_score: u64 = 1000000,
max_score: u64 = 0,
prog_score: u64,
uct_exploit: f64 = 0.0,
sqrt_visits: f64 = 0.0,
prog_bias: f64 = 0.0,
parent_node: ?*Self,
move: Move,
color: u3 = 0,
amount: u8 = 0,
side: Side,
is_chance_node: bool = false,
is_initialized: bool = false,

pub fn new(b: Board, move: Move, parent_node: ?*Self, allocator: Allocator) !*Self {
    const score = b.finalScore();
    var node = try allocator.create(Self);
    node.moves_left = std.ArrayList(Move).init(allocator);
    node.children = std.ArrayList(*Self).init(allocator);
    node.visits = 0;
    node.score = 0;
    node.min_score = 1000000;
    node.max_score = 0;
    node.prog_score = if (b.side == .Order) (score & 0xFFFF) else ((score >> 16) & 0xFFFF);
    node.uct_exploit = 0.0;
    node.sqrt_visits = 0.0;
    node.prog_bias = 0.0;
    node.parent_node = parent_node;
    node.move = move;
    node.color = 0;
    node.amount = 0;
    node.side = b.side;
    node.is_chance_node = false;
    node.is_initialized = false;
    return node;
}

pub fn deinit(self: *Self, allocator: Allocator) void {
    self.moves_left.deinit();
    for (self.children.items) |node| {
        node.deinit(allocator);
    }
    self.children.deinit();
    allocator.destroy(self);
}

pub fn init(self: *Self, b: Board, allocator: Allocator) !void {
    switch (b.side) {
        .Chaos => {
            self.is_chance_node = true;
            var i: u8 = 0;
            while (i < 7) : (i += 1) {
                const color_amount = b.bags[i + 1];
                if (color_amount != 0) {
                    var node = try Self.new(b, Move.empty(), self, allocator);
                    node.is_initialized = true;
                    node.color = @truncate(u3, i);
                    node.amount = color_amount;
                    try self.children.append(node);
                }
            }
            var frees = (~b.pieces) & constants.BOARD_MASK;
            while (frees != 0) {
                const sq = @truncate(u6, @ctz(frees));
                for (self.children.items) |node| {
                    try node.moves_left.append(.{ .Chaos = .{
                        .color = node.color + 1,
                        .to = sq,
                    } });
                }
                frees &= frees - 1;
            }
        },
        .Order => {
            try self.moves_left.append(Move.empty());
            if (b.bags[0] > 24) {
                var pieces = b.pieces;
                while (pieces != 0) {
                    const from = @truncate(u6, @ctz(pieces));
                    var tos = magic.moves(b.pieces, from);
                    while (tos != 0) {
                        const to = @truncate(u6, @ctz(tos));
                        try self.moves_left.append(.{ .Order = .{
                            .from = from,
                            .to = to,
                        } });
                        tos &= tos - 1;
                    }
                    pieces &= pieces - 1;
                }
            } else {
                var empties = ~b.pieces & constants.BOARD_MASK;
                while (empties != 0) {
                    const to = @truncate(u6, @ctz(empties));
                    var froms = magic.movesTo(b.pieces, to);
                    while (froms != 0) {
                        const from = @truncate(u6, @ctz(froms));
                        try self.moves_left.append(.{ .Order = .{
                            .from = from,
                            .to = to,
                        } });
                        froms &= froms - 1;
                    }
                    empties &= empties - 1;
                }
            }
        },
    }
    self.is_initialized = true;
}

pub fn print(self: Self, buf_out: std.fs.File.Writer, comptime depth: u8, comptime curr_depth: u8) !void {
    try buf_out.print("Node side: {s},  ", .{if (self.side == .Order) "ORDER" else "CHAOS"});
    try self.move.print(buf_out);
    try buf_out.print(", v: {}, s: {d:.4}, min: {}, max: {}, prog: {}, nChilds: {}, mvsL: {}", .{ self.visits, @intToFloat(f64, self.score) / @intToFloat(f64, self.visits), self.min_score, self.max_score, self.prog_score, self.children.items.len, self.moves_left.items.len });

    if (self.parent_node) |parent_node| {
        if (parent_node.is_chance_node) {
            try buf_out.print(", color: {}, amount: {}", .{ self.color + 1, self.amount });
        }
    }
    try buf_out.print("\n", .{});
    if (depth == 0) {
        return;
    }

    for (self.children.items) |node| {
        try buf_out.print("{s}", .{" " ** (curr_depth + 2)});
        try node.print(buf_out, depth - 1, curr_depth + 1);
    }
}

fn uct(self: Self, parent_sqrt_log_visits: f64) f64 {
    const uct_explore = parent_sqrt_log_visits * self.sqrt_visits;
    return self.uct_exploit + uct_explore + self.prog_bias;
}

fn updateScores(self: *Self, chaos_score: u64, order_score: u64) void {
    self.visits += 1;
    switch (self.side) {
        .Chaos => {
            self.score += chaos_score;
            self.max_score = @max(self.max_score, chaos_score);
            self.min_score = @min(self.min_score, chaos_score);
        },
        .Order => {
            self.score += order_score;
            self.max_score = @max(self.max_score, order_score);
            self.min_score = @min(self.min_score, order_score);
        },
    }
    self.updateUct();
}

fn updateUct(self: *Self) void {
    self.uct_exploit = @intToFloat(f64, self.score) / (@intToFloat(f64, self.visits) + constants.EPSILON);
    self.sqrt_visits = constants.uncertainty(self.visits);
    self.prog_bias = @intToFloat(f64, self.prog_score) / (200.0 * (@intToFloat(f64, self.visits) + 1.0));
}

fn isNodeExpanded(self: Self) bool {
    return self.moves_left.items.len == 0 and self.is_initialized;
}

fn isNodeTerminal(b: Board) bool {
    return b.bags[0] == 0;
}

fn expandNode(self: *Self, b: *Board, fast_rand: *FastRand, allocator: Allocator) !*Self {
    if (!self.is_initialized) {
        try self.init(b.*, allocator);
        if (self.is_chance_node) {
            var n = self.selectNextNode(fast_rand);
            return n.expandNode(b, fast_rand, allocator);
        }
    }

    const i = fast_rand.rangedRand(@intCast(u32, self.moves_left.items.len));
    const move = self.moves_left.swapRemove(i);
    b.makeMove(move);

    var node = try Self.new(b.*, move, self, allocator);
    try self.children.append(node);

    return node;
}

fn selectNextNode(self: Self, fast_rand: *FastRand) *Self {
    if (self.is_chance_node) {
        var total_weight: u32 = 0;
        for (self.children.items) |node| {
            total_weight += node.amount;
        }
        var r = @intCast(i64, fast_rand.rangedRand(total_weight));
        var next_node: *Self = self.children.items[0];
        var i: u8 = 0;
        while (r >= 0) {
            next_node = self.children.items[i];
            i += 1;
            r -= next_node.amount;
        }
        return next_node;
    } else {
        const r = fast_rand.rangedRand(6);
        if (r == 0) {
            const c = fast_rand.rangedRand(@intCast(u32, self.children.items.len));
            return self.children.items[c];
        }

        const c = @max(@as(u64, 1), self.max_score - self.min_score) / 10;
        const sqrt_log_visits = @intToFloat(f64, c) * constants.exploration(self.visits);
        var best_score: f64 = -1000000.0;
        var best_node: *Self = self.children.items[0];

        for (self.children.items) |node| {
            const r_uct = node.uct(sqrt_log_visits);
            if (r_uct > best_score) {
                best_node = node;
                best_score = r_uct;
            }
        }

        return best_node;
    }
}

pub fn step(self: *Self, b: Board, fast_rand: *FastRand, allocator: Allocator) !void {
    var board_copy = b;

    var node = self;

    while (node.isNodeExpanded() and !Self.isNodeTerminal(board_copy)) {
        if (!node.is_chance_node) {
            node = node.selectNextNode(fast_rand);
            board_copy.makeMove(node.move);
        } else {
            node = node.selectNextNode(fast_rand);
        }
    }

    if (!Self.isNodeTerminal(board_copy)) {
        node = try node.expandNode(&board_copy, fast_rand, allocator);
    }

    var chaos_score: u16 = 0;
    var order_score: u16 = 0;
    var amount: u8 = 4;
    var i: u8 = 0;
    while (i < amount) : (i += 1) {
        var score: u32 = 0;
        if (!Self.isNodeTerminal(board_copy)) {
            var bb = board_copy;
            bb.randomPlayout(fast_rand);
            score = bb.finalScore();
        } else {
            score = board_copy.finalScore();
        }

        chaos_score += @truncate(u16, score & 0xFFFF);
        order_score += @truncate(u16, (score >> 16) & 0xFFFF);
    }
    chaos_score /= amount;
    order_score /= amount;

    var nn: ?*Self = node;
    while (nn) |n| {
        n.updateScores(chaos_score, order_score);
        nn = n.parent_node;
    }
}
