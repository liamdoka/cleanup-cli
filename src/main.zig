const std = @import("std");
const directory = @import("directory.zig");
const eql = std.mem.eql;

pub const Config = struct {
    dryRun: bool = undefined,
    recursive: bool = undefined,
    force: bool = undefined,
    patch: bool = undefined,
    magic: bool = undefined,

    directory: []const u8 = undefined,

    fn fromArgs(self: *Config, args: [][]const u8) void {
        self.directory = args[1];

        if (args.len <= 2) return;
        for (args[2..], 2..) |arg, i| {
            std.debug.print("{d}: {s}\n", .{ i, arg });

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
                        else => {
                            std.debug.print("Unknown flag: {c}\n", .{flag});
                        },
                    }
                }
            }
        }
    }
};

pub fn main() !void {
    const stdout = std.io.getStdOut().writer();

    const allocator = std.heap.page_allocator;
    const args = try std.process.argsAlloc(allocator);
    defer allocator.free(args);

    var config = Config{};
    config.fromArgs(args);

    var cwd = std.fs.cwd();
    cwd = try cwd.openDir(".", .{ .iterate = true });

    var cwdIterator = cwd.iterate();
    var found: bool = false;
    var foundDirectory: []const u8 = undefined;

    while (try cwdIterator.next()) |result| {
        // int compare quickly
        if (result.name.len != config.directory.len) continue;
        if (std.ascii.eqlIgnoreCase(result.name, config.directory)) {
            foundDirectory = result.name;
            found = true;
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
            if (result.name.len != config.directory.len) continue;
            if (std.ascii.eqlIgnoreCase(result.name, config.directory)) {
                foundDirectory = result.name;
                found = true;
            }
        }
    }

    if (!found) {
        try stdout.print("Directory {?s} not found! Please try again\n", .{config.directory});
    } else {
        const realpath = try cwd.realpathAlloc(allocator, foundDirectory);
        defer allocator.free(realpath);

        try stdout.print("Weehee you found {s}\n\tat {s}\n", .{ config.directory, " " });
    }
}

test "readArgs" {
    // &.{ "./zig-out/bin/cleanup", "documents", "--dry-run" };
    const stdout = std.io.getStdOut().writer();
    const allocator = std.testing.allocator;

    const args: [][]const u8 = try allocator.alloc([]const u8, 3);
    defer allocator.free(args);

    args[0] = "./zig-out/bin/cleanup";
    args[1] = "documents";
    args[2] = "--dry-run";

    var config = Config{};
    config.fromArgs(args);

    var cwd = std.fs.cwd();
    cwd = try cwd.openDir(".", .{ .iterate = true });

    var cwdIterator = cwd.iterate();
    var found: bool = false;
    var foundDirectory: []const u8 = undefined;

    while (try cwdIterator.next()) |result| {
        // int compare quickly
        if (result.name.len != config.directory.len) continue;
        if (std.ascii.eqlIgnoreCase(result.name, config.directory)) {
            foundDirectory = result.name;
            found = true;
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
            if (result.name.len != config.directory.len) continue;
            if (std.ascii.eqlIgnoreCase(result.name, config.directory)) {
                foundDirectory = result.name;
                found = true;
            }
        }
    }

    if (!found) {
        try stdout.print("Directory {?s} not found! Please try again\n", .{config.directory});
    } else {
        const realpath = try cwd.realpathAlloc(allocator, foundDirectory);
        defer allocator.free(realpath);

        try stdout.print("Weehee you found {s}\n\tat {s}\n", .{ config.directory, " " });
    }
}
