const std = @import("std");
const directory = @import("directory.zig");
const ansi = @import("ansi_helper.zig");
const FileAction = enum { Nothing, Move, Delete, Rename, TryAgain };

const ConfigError = error{ OutOfMemory, InvalidArgs };

pub const Config = struct {
    all: bool = false,
    force: bool = false,
    patch: bool = false,
    magic: bool = false,
    dryRun: bool = false,
    recursive: bool = false,
    directory: []const u8 = undefined,

    pub fn fromArgs(args: [][]const u8) !Config {
        var self: Config = Config{};
        self.directory = args[1];

        if (args.len < 2) return ConfigError.InvalidArgs;
        for (args[2..], 2..) |arg, i| {
            // std.debug.print("{d}: {s}\n", .{ i, arg });
            _ = i;

            if (std.ascii.startsWithIgnoreCase(arg, "--")) {
                if (std.ascii.eqlIgnoreCase(arg[2..], "dry-run")) {
                    self.dryRun = true;
                } else if (std.ascii.eqlIgnoreCase(arg[2..], "recursive")) {
                    self.recursive = true;
                } else if (std.ascii.eqlIgnoreCase(arg[2..], "force")) {
                    self.force = true;
                } else if (std.ascii.eqlIgnoreCase(arg[2..], "patch")) {
                    self.patch = true;
                } else if (std.ascii.eqlIgnoreCase(arg[2..], "magic")) {
                    self.force = true;
                } else if (std.ascii.eqlIgnoreCase(arg[2..], "all")) {
                    self.all = true;
                } else {
                    std.debug.print("Unknown arg: {s}\n", .{arg});
                }
            } else if (std.ascii.startsWithIgnoreCase(arg, "-")) {
                for (arg[1..]) |flag| {
                    switch (flag) {
                        'd' => self.dryRun = true,
                        'r' => self.recursive = true,
                        'f' => self.force = true,
                        'p' => self.patch = true,
                        'm' => self.magic = true,
                        'a' => self.all = true,
                        else => {
                            std.debug.print("Unknown flag: {c}\n", .{flag});
                        },
                    }
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

    std.debug.print("\u{001b}7", .{});

    const config = try Config.fromArgs(args);

    var cwd = try std.fs.cwd().openDir(".", .{ .iterate = true });
    defer cwd.close();

    var found: bool = false;
    var foundPathString: []u8 = undefined;

    var foundDirectoryString: []const u8 = undefined;
    var foundDirectory: std.fs.Dir = cwd.openDir(config.directory, .{
        .access_sub_paths = false,
    }) catch undefined;

    var cwdIterator = cwd.iterate();
    while (try cwdIterator.next()) |result| {

        // int compare real quick
        if (result.name.len != config.directory.len or result.kind != .directory) continue;
        if (std.ascii.eqlIgnoreCase(result.name, config.directory)) {
            foundDirectoryString = result.name;
            foundDirectory = try cwd.openDir(result.name, .{ .iterate = true });

            var paths: [][]const u8 = try allocator.alloc([]const u8, 2);
            defer allocator.free(paths);
            paths[0] = ".";
            paths[1] = result.name;
            foundPathString = try std.fs.path.join(allocator, paths);
            // deffered later trust me bro

            found = true;
            break;
        }
    }

    // if not in the current directory
    // search the HOME directory
    if (!found) {
        const homeVar = try std.process.getEnvVarOwned(allocator, "HOME");
        defer allocator.free(homeVar);

        cwd = try cwd.openDir(homeVar, .{ .iterate = true });
        cwdIterator = cwd.iterate();

        while (try cwdIterator.next()) |result| {
            if (result.name.len != config.directory.len or result.kind != .directory) continue;
            if (std.ascii.eqlIgnoreCase(result.name, config.directory)) {
                foundDirectoryString = result.name;
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

    defer allocator.free(foundPathString);

    var results = std.ArrayList(std.fs.Dir.Entry).init(allocator);
    defer results.deinit();

    if (!found) {
        try stdout.print("Directory {?s} not found! Please try again\n", .{config.directory});
    } else {
        var foundIter = foundDirectory.iterate();
        std.debug.print("Found directory at\n\t{s}{s}{?s}{s}\nInside is:\n", .{ ansi.BOLD, ansi.BLUE, foundPathString, ansi.RESET });
        while (try foundIter.next()) |result| {
            try results.append(result);
            const color = switch (result.kind) {
                .directory => ansi.BOLD ++ ansi.BLUE,
                else => "",
            };

            std.debug.print("{s}{s}\t{s}", .{ color, result.name, ansi.RESET });
        }
        std.debug.print("\n", .{});
    }

    for (results.items) |result| {
        std.debug.print("\u{001b}[s", .{});

        const actionChar: u8 = while (true) {
            try stdout.print("\t{s}\nWhat to do with this file ['d','r','m','n','?']: ", .{result.name});

            const input = try stdin.readUntilDelimiterOrEofAlloc(allocator, '\n', 12) orelse "";
            defer allocator.free(input);
            if (input.len == 1) {
                break input[0];
            } else {
                try stdout.print("invalid action: {s}, please try again\n", .{input});
            }
        };

        const action = mapCharToFileAction(actionChar);
        try handleFile(foundDirectory, result, action);
    }

    std.debug.print("\u{001b}8\u{001b}[0J\n", .{});
}

pub fn handleFile(cwd: std.fs.Dir, file: std.fs.Dir.Entry, action: FileAction) !void {
    const stdin = std.io.getStdIn().reader();
    const stdout = std.io.getStdOut().writer();
    const allocator = std.heap.page_allocator;

    switch (action) {
        .Nothing => return,
        .Delete => {
            const color = if (file.kind == .directory) ansi.BLUE ++ ansi.BOLD else "";

            while (true) {
                try stdout.print("{s}{s}{s} => {s}{s}{s}{s}\nDelete the file for real? ['y','n']: ", .{
                    // zig fmt:off
                    color,      file.name,          ansi.RESET,
                    ansi.RED,   ansi.STRIKETHROUGH, file.name,
                    ansi.RESET,
                });
                const response = stdin.readUntilDelimiterAlloc(allocator, '\n', 128) catch "";

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
            try stdout.print("Enter a new name for the file:\n", .{});
            while (true) {
                try stdout.print("{s}  =>  ", .{file.name});
                const newName = stdin.readUntilDelimiterAlloc(allocator, '\n', 128) catch "";
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
