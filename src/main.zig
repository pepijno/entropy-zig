const std = @import("std");
const Board = @import("board.zig");
const Move = @import("move.zig").Move;
const Side = @import("constants.zig").Side;
const initScores = @import("scores.zig").initScores;
const FastRand = @import("fastrand.zig").FastRand;
const initMagics = @import("magic.zig").initMagics;
const Node = @import("node.zig");

fn parseMove(move: []const u8) Move {
    return switch (move[0]) {
        '0'...'9' => .{
            .Chaos = .{
                .color = @truncate(u3, move[0] - '0'),
                .to = @truncate(u6, move[2] - 'a' + 7 * (6 + 'A' - move[1])),
            },
        },
        else => .{
            .Order = .{
                .from = @truncate(u6, move[1] - 'a' + 7 * (6 + 'A' - move[0])),
                .to = @truncate(u6, move[3] - 'a' + 7 * (6 + 'A' - move[2])),
            },
        },
    };
}

fn getBestNode(node: Node) *Node {
    var best_node = node.children.items[0];
    for (node.children.items) |n| {
        if (n.visits > best_node.visits) {
            best_node = n;
        }
    }
    return best_node;
}

pub fn main() !void {
    const allocator = std.heap.page_allocator;
    const stdout_file = std.io.getStdOut().writer();
    const stderr_file = std.io.getStdErr().writer();
    const reader = std.io.getStdIn().reader();

    const seed = @truncate(u64, @bitCast(u128, std.time.nanoTimestamp()));
    try stderr_file.print("{}\n", .{seed});
    var fast_rand = FastRand.init(seed);

    initScores();
    initMagics();

    var b = Board.newBoard();
    var node = try Node.new(b, Move.empty(), null, allocator);

    while (true) {
        var buffer = [_]u8{undefined} ** 16;
        _ = try reader.read(&buffer);

        var eval = false;
        var start_move = false;

        var timer = try std.time.Timer.start();

        var color: u8 = 1;
        if (std.mem.startsWith(u8, buffer[0..], "Quit")) {
            return;
        } else if (std.mem.startsWith(u8, buffer[0..], "Start")) {} else if (std.mem.startsWith(u8, buffer[0..], "Eval")) {
            eval = true;
        } else if (std.mem.startsWith(u8, buffer[0..], "Move ")) {
            const move = parseMove(buffer[5..]);
            try move.print(stderr_file);
            try stderr_file.print("\n", .{});
            b.makeMove(move);
            node.deinit(allocator);
            node = try Node.new(b, Move.empty(), null, allocator);
            try b.print(stderr_file);
            continue;
        } else {
            if (buffer[0] >= '0' and buffer[0] <= '9' and !(buffer[1] >= 'A' and buffer[1] <= 'Z')) {
                try node.init(b, allocator);
                color = buffer[0] - '0';
                for (node.children.items) |n| {
                    if (n.color + 1 == color) {
                        node = n;
                        break;
                    }
                }
                start_move = true;
            } else {
                const move = parseMove(buffer[0..]);
                b.makeMove(move);
                node.deinit(allocator);
                node = try Node.new(b, move, null, allocator);
                try b.print(stderr_file);
                start_move = true;
            }
        }

        var move = Move.empty();
        if (start_move or eval) {
            const max_time = 0.5;
            var i: u64 = 0;
            while (i < 1000000000000) : (i += 1) {
                try node.step(b, &fast_rand, allocator);

                if ((i & 1023) == 1023) {
                    const end = timer.read();
                    const seconds = @intToFloat(f64, end) / std.time.ns_per_s;
                    if (seconds >= max_time) {
                        try stderr_file.print("Time: {d:.6}, NPS: {d:.2}\n", .{ seconds, @intToFloat(f64, i) / seconds });
                        break;
                    }
                }
            }

            try node.print(stderr_file, 1, 0);
        }

        if (!eval and start_move) {
            move = getBestNode(node.*).move;

            if (move.isEmpty()) {
                const sq = @truncate(u6, @ctz(b.pieces));
                move = .{
                    .Order = .{
                        .from = sq,
                        .to = sq,
                    },
                };
            }
            try move.print(stdout_file);
            try stdout_file.print("\n", .{});
            try move.print(stderr_file);
            try stderr_file.print("\n", .{});
            b.makeMove(move);
            try b.print(stderr_file);
            node.deinit(allocator);
            node = try Node.new(b, move, null, allocator);
        } else if (eval) {
            const m = getBestNode(node.*);
            try stderr_file.print("Best move: ", .{});
            try m.move.print(stderr_file);
            try stderr_file.print("\n", .{});
        }
    }
}
