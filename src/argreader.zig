const std = @import("std");
const stdout = std.io.getStdOut().writer();
const test_allocator = std.testing.allocator;
const Allocator = std.mem.Allocator;
const expect = std.testing.expect;
const eql = std.mem.eql;

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

const Config = struct {
    dryRun: bool = undefined,
    recursive: bool = undefined,
    force: bool = undefined,
    patch: bool = undefined,
    magic: bool = undefined,

    directory: []const u8 = undefined,

    fn fromCommand(self: *Config, command: *Command) !void {
        self.directory = command.command.?;

        for (command.flags.items) |flag| {
            // Cannot switch on strings -> should probably start from the beginning and add flags as chars
            //     switch (flag.head) {
            //         "dry-run", "d" => self.dryRun = true,
            //         "recursive", "r" => self.recursive = true,
            //         "force", "f" => self.force = true,
            //         "patch", "p" => self.patch = true,
            //         "magic", "m" => self.magic = true,
            //     }
            if (eql(u8, flag.head, "d") or eql(u8, flag.head, "dry-run")) {
                self.dryRun = true;
            } else if (eql(u8, flag.head, "r") or eql(u8, flag.head, "recursive")) {
                self.recursive = true;
            } else if (eql(u8, flag.head, "f") or eql(u8, flag.head, "force")) {
                self.force = true;
            } else if (eql(u8, flag.head, "p") or eql(u8, flag.head, "patch")) {
                self.patch = true;
            } else if (eql(u8, flag.head, "m") or eql(u8, flag.head, "magic")) {
                self.magic = true;
            } else {
                try stdout.print("ERROR - unknown argument: {s}", .{flag.head});
                break;
            }
        }
    }
};

pub fn readArgsIntoCommand(args: []const u8, allocator: std.mem.Allocator) !Command {
    var command = Command.init(allocator);

    var start: usize = 0;
    var end: usize = 1;

    var prevFlag: ?Flag = null;

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
                if (prevFlag != null) {
                    try command.flags.append(prevFlag.?);
                    prevFlag = null;
                }

                for (0..slice.len) |i| {
                    const tempSlice = slice[i .. i + 1];
                    const newFlag = Flag{
                        .head = tempSlice,
                        .tail = null,
                    };

                    try command.flags.append(newFlag);
                }
            } else {
                if (prevFlag != null and prevFlag.?.tail == null) {
                    prevFlag.?.tail = slice;

                    try command.flags.append(prevFlag.?);
                    prevFlag = null;
                }

                // else update prevflag
            }
            start = end + 1;
        }
    }

    if (prevFlag != null) {
        try command.flags.append(prevFlag.?);
    }

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
    try expect(eql(u8, command.command.?, "downloads"));
    try expect(eql(u8, command.flags.items[0].head, "dry-run"));
    try expect(eql(u8, command.flags.items[1].head, "type"));
    try expect(eql(u8, command.flags.items[1].tail.?, "hard"));
}

test "read shortflags into flag object" {
    const args: []const u8 = "downloads -dhv";
    const command: Command = try readArgsIntoCommand(args, test_allocator);
    defer command.deinit();

    // try printCommand(command);

    // EXPECT
    try expect(eql(u8, command.command.?, "downloads"));
    try expect(eql(u8, command.flags.items[0].head, "d"));
    try expect(eql(u8, command.flags.items[1].head, "h"));
    try expect(eql(u8, command.flags.items[2].head, "v"));
}

test "read both shortflags and long ones" {
    const args: []const u8 = "desktop -sa --force -pe --bruh man";
    const command: Command = try readArgsIntoCommand(args, test_allocator);
    defer command.deinit();

    // try printCommand(command);

    try expect(eql(u8, command.command.?, "desktop"));
    try expect(eql(u8, command.flags.items[0].head, "s"));
    try expect(eql(u8, command.flags.items[1].head, "a"));
    try expect(eql(u8, command.flags.items[2].head, "force"));
}

test "read flags into config" {
    const args: []const u8 = "downloads -rm";
    var command: Command = try readArgsIntoCommand(args, test_allocator);
    defer command.deinit();

    var config = Config{};
    try config.fromCommand(&command);

    try expect(eql(u8, config.directory, "downloads"));
    try expect(config.recursive == true);
    try expect(config.magic == true);
}
