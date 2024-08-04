const std = @import("std");
const stdout = std.io.getStdOut().writer();
const test_allocator = std.testing.allocator;
const Allocator = std.mem.Allocator;
const expect = std.testing.expect;

const Command = struct {
    command: ?[]const u8,
    flags: std.ArrayList(Flag),

    fn init(allocator: Allocator) Command {
        const command = null;
        const flags = std.ArrayList(Flag).init(allocator);

        return Command{ .command = command, .flags = flags };
    }

    fn deinit(self: Command) void {
        self.flags.deinit();
    }
};

const Flag = struct { head: []const u8, tail: ?[]const u8 };

pub fn readArgsIntoCommand(args: []const u8, allocator: std.mem.Allocator) !Command {
    var command = Command.init(allocator);

    var start: usize = 0;
    var end: usize = 1;

    var prevFlag: ?Flag = null;

    // grab shortflags,
    var shortFlags = std.ArrayList([]u8).init(allocator);
    defer shortFlags.deinit();

    while (end <= args.len) : (end += 1) {
        if (end == args.len or args[end] == ' ') {
            const isFlag: bool = std.mem.eql(u8, args[start .. start + 2], "--");
            const isShortFlag: bool = args[start] == '-';

            if (isFlag) {
                start += 2;
            } else if (isShortFlag) {
                start += 1;
            }

            const slice = args[start..end];

            if (command.command == null) {
                command.command = slice;
            } else if (isFlag) {
                if (prevFlag != null) {
                    try command.flags.append(prevFlag.?);
                }

                prevFlag = Flag{ .head = slice, .tail = null };
            } else if (isShortFlag) {
                // Allocate a slice for each value
                var tempArray = [_]u8{slice};
                const shortSlice: []u8 = tempArray[0..];

                // Store the slice in the ArrayList
                shortFlags.append(shortSlice) catch {
                    std.debug.print("Failed to append\n", .{});
                    return;
                };
            } else {
                if (prevFlag != null and prevFlag.?.tail == null) {
                    prevFlag.?.tail = slice;

                    try command.flags.append(prevFlag.?);
                    prevFlag = null;
                }
            }
            start = end + 1;
        }
    }

    try printCommand(command);

    return command;
}

pub fn printCommand(command: Command) !void {
    try stdout.print("command: {?s}\n\n", .{command.command});

    for (command.flags.items, 0..) |flag, i| {
        try stdout.print("flag: {d}\nh: {s}\nt: {?s}\n\n", .{ i, flag.head, flag.tail });
    }
}

test "read args" {
    const args = try std.process.argsAlloc(test_allocator);
    defer std.process.argsFree(test_allocator, args);

    //try stdout.print("cli args: {s}\n", .{args});
}

test "read slice manually" {
    const args: []const u8 = "downloads --dry-run --type hard";

    var start: usize = 0;
    var end: usize = 1;

    var prevChar: u8 = args[0];

    while (end < args.len) : (end += 1) {
        if (prevChar == ' ') {
            _ = args[start..end];
            start = end;
        }
        prevChar = args[end];
    }
}

test "read slice manually into flag object" {
    const args: []const u8 = "downloads --dry-run --type hard";
    const command: Command = try readArgsIntoCommand(args, test_allocator);
    defer command.deinit();

    //try printCommand(command);

    //EXPECT
    try expect(std.mem.eql(u8, command.command.?, "downloads"));
    try expect(std.mem.eql(u8, command.flags.items[0].head, "dry-run"));
    try expect(std.mem.eql(u8, command.flags.items[1].head, "type"));
    try expect(std.mem.eql(u8, command.flags.items[1].tail.?, "hard"));
}

test "read shortflags into flag object" {
    const args: []const u8 = "downloads -dhv";
    const command: Command = try readArgsIntoCommand(args, test_allocator);
    defer command.deinit();

    try printCommand(command);

    // EXPECT
    try expect(std.mem.eql(u8, command.command.?, "downloads"));
    try expect(std.mem.eql(u8, command.flags.items[0].head, "d"));
    try expect(std.mem.eql(u8, command.flags.items[1].head, "h"));
    try expect(std.mem.eql(u8, command.flags.items[2].head, "v"));
}
