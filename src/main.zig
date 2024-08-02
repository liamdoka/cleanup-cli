const std = @import("std");
const test_allocator = std.testing.allocator;
const expect = std.testing.expect;

const Command = struct {
    destination: ?[]const u8,
    flags: std.ArrayList(Flag),
};

const Flag = struct { head: ?[]const u8, tail: ?[]const u8 };

pub fn main() !void {
    var arena = std.heap.ArenaAllocator.init(std.heap.page_allocator);
    defer arena.deinit();
    const allocator = arena.allocator();

    const stdout = std.io.getStdOut().writer();
    var args = try std.process.argsWithAllocator(allocator);
    defer args.deinit();

    // pop the path to this command
    _ = args.next();

    var command: Command = .{ .destination = args.next(), .flags = std.ArrayList(Flag).init(allocator) };

    var prev: []const u8 = undefined;
    while (args.next()) |arg| {
        if (std.mem.eql(u8, arg[0..2], "--")) {
            const flag: Flag = .{ .head = arg[2..], .tail = null };
            try command.flags.append(flag);
        } else if (std.mem.eql(u8, prev[0..2], "--")) {
            const _flag: *?Flag = command.flags.getLastOrNull();
        }
        prev = arg;
    }

    // PRINT THIS SHIT OUT NICELY MAN
    try stdout.print("Command: {?s}\n\n", .{command.destination});
    for (command.flags.items, 0..) |flag, i| {
        try stdout.print("Flag {d}\nHead: {?s}\nTail: {?s}\n\n", .{ i, flag.head, flag.tail });
    }
}

test "commandline test" {
    var args = try std.process.argsWithAllocator(test_allocator);
    defer args.deinit();

    while (args.next()) |arg| {
        std.debug.print("{s}\n", .{arg});
    }
}
