const std = @import("std");
const directory = @import("directory.zig");
const ansi = @import("ansi_helper.zig");

const FileAction = enum { Nothing, Move, Delete, Rename, TryAgain };
const ConfigError = error{ OutOfMemory, InvalidArgs };

pub const Config = struct {
    all: bool = false,
    delete: bool = false,
    directory: []const u8 = ".",

    pub fn fromArgs(args: [][]const u8) !Config {
        var self: Config = Config{};

        for (args[1..], 1..) |arg, i| {
            if (std.ascii.startsWithIgnoreCase(arg, "--")) {
                if (std.ascii.eqlIgnoreCase(arg[2..], "all")) {
                    self.all = true;
                } else if (std.ascii.eqlIgnoreCase(arg[2..], "delete")) {
                    self.delete = true;
                } else {
                    std.debug.print("Unknown arg: {s}\n", .{arg});
                }
            } else if (std.ascii.startsWithIgnoreCase(arg, "-")) {
                for (arg[1..]) |flag| {
                    switch (flag) {
                        'a' => self.all = true,
                        'd' => self.delete = true,
                        else => {
                            std.debug.print("Unknown flag: {c}\n", .{flag});
                        },
                    }
                }
            } else {
                if (i == 1) {
                    self.directory = arg;
                } else {
                    return ConfigError.InvalidArgs;
                }
            }
        }
        return self;
    }
};

pub fn main() !void {
    const stdin = std.io.getStdIn().reader();
    const stdout = std.io.getStdOut().writer();

    const allocator = std.heap.page_allocator;
    const args = try std.process.argsAlloc(allocator);
    defer std.process.argsFree(allocator, args);

    try stdout.print("\u{001b}7", .{});

    const config = try Config.fromArgs(args);

    var cwd = try std.fs.cwd().openDir(".", .{ .iterate = true });
    defer cwd.close();

    var found: bool = false;
    var foundPathString: []const u8 = "";
    var foundDirectory: ?std.fs.Dir = cwd.openDir(config.directory, .{ .iterate = true }) catch null;

    if (foundDirectory != null) {
        foundPathString = config.directory;
        found = true;
    }

    if (!found) {
        var cwdIterator = cwd.iterate();
        while (try cwdIterator.next()) |result| {
            // int compare real quick
            if (result.name.len != config.directory.len or result.kind != .directory) continue;
            if (std.ascii.eqlIgnoreCase(result.name, config.directory)) {
                foundDirectory = try cwd.openDir(result.name, .{ .iterate = true });

                var paths: [][]const u8 = try allocator.alloc([]const u8, 2);
                defer allocator.free(paths);
                paths[0] = ".";
                paths[1] = result.name;
                foundPathString = try std.fs.path.join(allocator, paths);

                found = true;
                break;
            }
        }
    }

    // if not in the current directory
    // search the HOME directory
    if (!found) {
        const homeVar = try std.process.getEnvVarOwned(allocator, "HOME");
        defer allocator.free(homeVar);

        cwd = try cwd.openDir(homeVar, .{ .iterate = true });
        var cwdIterator = cwd.iterate();

        while (try cwdIterator.next()) |result| {
            if (result.name.len != config.directory.len or result.kind != .directory) continue;
            if (std.ascii.eqlIgnoreCase(result.name, config.directory)) {
                foundDirectory = try cwd.openDir(result.name, .{ .iterate = true });

                var paths: [][]const u8 = try allocator.alloc([]const u8, 2);
                defer allocator.free(paths);
                paths[0] = homeVar;
                paths[1] = result.name;

                foundPathString = try std.fs.path.join(allocator, paths);

                found = true;
                break;
            }
        }
    }

    var results = std.ArrayList(std.fs.Dir.Entry).init(allocator);
    defer results.deinit();

    if (!found) {
        try stdout.print("Directory {s}{s}{s}{s} not found! Please try again\n", .{
            // zig fmt:off
            ansi.BLUE, ansi.BOLD, config.directory, ansi.RESET,
        });
        return;
    } else {
        var foundIter = foundDirectory.?.iterate();
        try stdout.print("Found directory at {s}{s}{s}{s}\n", .{ ansi.BOLD, ansi.BLUE, foundPathString, ansi.RESET });
        while (try foundIter.next()) |result| {
            if (config.all == false and result.kind == .directory) continue;
            try results.append(result);
        }
    }

    for (results.items) |result| {
        try stdout.print("{s}", .{ansi.SAVE_CURSOR});

        const style = if (result.kind == .directory) ansi.BOLD ++ ansi.BLUE else "";
        const verb = if (result.kind == .directory) "folder" else "file";

        const action: FileAction = while (true) {
            if (config.delete) break .Delete;

            try stdout.print("\n\t\"{s}{s}{s}\"\n\n{s}{s}What to do with this {s}? [d,r,n,?]:{s} ", .{
                // zig fmt:off
                style,      result.name,    ansi.RESET,
                ansi.BOLD,  ansi.DARK_BLUE, verb,
                ansi.RESET,
            });

            const input = try stdin.readUntilDelimiterOrEofAlloc(allocator, '\n', 12) orelse "";
            defer allocator.free(input);
            if (input.len == 1) {
                const actionFromChar = mapCharToFileAction(input[0]);
                if (actionFromChar != .TryAgain) {
                    break actionFromChar;
                }
            }

            try stdout.print("invalid action: {s}\"{s}\"{s}, please try again\n", .{ ansi.BOLD, input, ansi.RESET });
        };

        try handleFile(foundDirectory.?, result, action);
        try stdout.print("{s}{s}", .{ ansi.RESTORE_CURSOR, ansi.CLEAR_BELOW_CURSOR });
    }

    try stdout.print("\u{001b}[1F\u{001b}[0KCleaned {s}{s}{s}{s} successfully!\n", .{ ansi.BOLD, ansi.BLUE, foundPathString, ansi.RESET });

    if (foundDirectory != null) {
        foundDirectory.?.close();
    }

    return;
}

pub fn handleFile(cwd: std.fs.Dir, file: std.fs.Dir.Entry, action: FileAction) !void {
    const stdin = std.io.getStdIn().reader();
    const stdout = std.io.getStdOut().writer();
    const allocator = std.heap.page_allocator;

    switch (action) {
        .Nothing => return,
        .Delete => {
            try stdout.print("{s}{s}", .{ ansi.RESTORE_CURSOR, ansi.CLEAR_BELOW_CURSOR });

            const color = if (file.kind == .directory) ansi.BLUE ++ ansi.BOLD else "";

            while (true) {
                try stdout.print("\n\t{s}\"{s}\"{s}\n\t\t=> {s}{s}{s}{s}\n\n{s}{s}Delete the file for real? [y,n]: {s}", .{
                    // zig fmt:off
                    color,      file.name,          ansi.RESET,
                    ansi.RED,   ansi.STRIKETHROUGH, file.name,
                    ansi.RESET, ansi.DARK_BLUE,     ansi.BOLD,
                    ansi.RESET,
                });
                const response = stdin.readUntilDelimiterAlloc(allocator, '\n', 128) catch "";
                defer allocator.free(response);

                if (response.len == 1) {
                    switch (response[0]) {
                        'y' => {
                            if (file.kind == .file) {
                                try cwd.deleteFile(file.name);
                                try stdout.print("File deleted\n", .{});
                            } else if (file.kind == .directory) {
                                try cwd.deleteDir(file.name);
                                try stdout.print("Directory deleted\n", .{});
                            }
                            break;
                        },
                        'n' => {
                            try stdout.print("File not deleted\n", .{});
                            break;
                        },
                        else => continue,
                    }
                }
                try stdout.print("Invalid file name, try again\n", .{});
            }
        },
        .Move => {
            try stdout.print("not implemented sorry", .{});
            return;
        },
        .Rename => {
            std.debug.print("{s}{s}", .{ ansi.RESTORE_CURSOR, ansi.CLEAR_BELOW_CURSOR });

            while (true) {
                try stdout.print("\n\t\"{s}\"\n\t\t=>  ", .{file.name});
                const newName = stdin.readUntilDelimiterAlloc(allocator, '\n', 128) catch "";
                defer allocator.free(newName);

                if (newName.len > 0) {
                    try cwd.rename(file.name, newName);
                    break;
                } else {
                    try stdout.print("Invalid file name, try again\n", .{});
                }
            }
        },
        else => return,
    }
}

pub fn mapCharToFileAction(char: u8) FileAction {
    return switch (char) {
        'r' => .Rename,
        'd' => .Delete,
        'm' => .Move,
        'n' => .Nothing,
        else => .TryAgain,
    };
}
