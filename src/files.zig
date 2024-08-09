const std = @import("std");
const ansi = @import("ansi_helper.zig");
const cleanup = @import("main.zig");
const FileAction = enum { Nothing, Move, Delete, Rename, TryAgain };

const stdout = std.io.getStdOut().writer();
const stdin = std.io.getStdOut().reader();

pub fn main() !void {
    const allocator = std.heap.page_allocator;
    const args = std.process.argsAlloc(allocator);
    defer std.process.argsFree(allocator, args);

    const config = try cleanup.Config.fromArgs(args);

    var cwd = std.fs.cwd();
    var targetDir = try cwd.openDir(config.directory, .{ .iterate = true });
    defer targetDir.close();

    var targetDirIter = targetDir.iterate();
    while (try targetDirIter.next()) |result| {
        try stdout.write("\x1B[2J\x1B[H");

        const prompt = try std.fmt.allocPrint(allocator, "Would you like to handle\n\t{s}\n\n['d','r','m','n','?']: ", .{result.name});
        try stdout.write(prompt);

        const input: [16]u8 = undefined;
        const inputLen = try stdin.read(input);

        if (inputLen != 1) {
            const action: FileAction = switch (input[0]) {
                'r' => FileAction.Rename,
                'd' => FileAction.Delete,
                'm' => FileAction.Move,
                'n' => FileAction.Nothing,
                else => FileAction.TryAgain,
            };

            if (action != .TryAgain) {
                try handleFile(cwd, result.name, action);
            } else {}
        }
    }

    try stdout.write("\x1B[2J\x1B[H");
    try stdout.write("Cleanup completed :)\n");
}

pub fn handleFile(cwd: std.fs.Dir, file: []const u8, action: FileAction) !void {
    switch (action) {
        .Nothing => return,
        .Delete => try cwd.deleteFile(file),
        .Move => {
            // prompt for new destination
            const buf: [256]u8 = undefined;
            const newPath = try stdin.read(buf);
            // try open dir
            // try cwd.copyFile(source_path: []const u8, dest_dir: Dir, dest_path: []const u8, options: CopyFileOptions)

            // try delete original file
            _ = newPath;
        },
        .Rename => {
            //prompt for new name
            const buf: [256]u8 = undefined;
            const newName = try stdin.read(buf);
            _ = try cwd.rename(file, newName);
        },
    }
}

test "delete files" {
    const allocator = std.testing.allocator;
    const args: [][]const u8 = try allocator.alloc([]const u8, 3);
    defer allocator.free(args);

    args[0] = "./zig-out/bin/cleanup";
    args[1] = "test-folder";
    args[2] = "--all";

    const config = try cleanup.Config.fromArgs(args);

    var cwd = std.fs.cwd();
    var hostDir = try cwd.openDir(config.directory, .{ .iterate = true });
    defer hostDir.close();

    // CREATE EMPTY FILES IN FOLDER
    var testFile = try hostDir.createFile("test.txt", .{});
    testFile.close();

    _ = hostDir.makeDir("new-dir") catch null;
    _ = hostDir.makeDir("dir") catch null;

    var hostIter = hostDir.iterate();

    var results: std.ArrayList(std.fs.Dir.Entry) = std.ArrayList(std.fs.Dir.Entry).init(allocator);
    defer results.deinit();

    var maxLen: usize = 0;
    while (try hostIter.next()) |result| {
        try results.append(result);
        if (maxLen < result.name.len) {
            maxLen = result.name.len;
        }
    }

    for (results.items) |result| {
        const color = switch (result.kind) {
            .directory => ansi.BLUE ++ ansi.BOLD,
            else => "",
        };

        const offsetLen: usize = maxLen - result.name.len;
        const offset = try allocator.alloc(u8, offsetLen);
        defer allocator.free(offset);

        for (offset, 0..) |_, i| {
            offset[i] = ' ';
        }

        std.debug.print("{s}{s}{s}  =>  {s}{s}{s}{s}\n", .{
            // zig fmt:off
            offset,     color,              result.name,
            ansi.RED,   ansi.STRIKETHROUGH, result.name,
            ansi.RESET,
        });
    }

    try std.testing.expect(results.items.len == 4);

    results.clearAndFree();

    try hostDir.deleteDir("new-dir");
    try hostDir.deleteDir("dir");
    try hostDir.deleteFile("test.txt");

    hostDir = try hostDir.openDir(".", .{ .iterate = true });
    hostIter = hostDir.iterate();

    while (try hostIter.next()) |result| {
        try results.append(result);
    }

    try std.testing.expect(results.items.len == 1);
    std.debug.print("\n", .{});
}

test "rename a file" {
    const allocator = std.testing.allocator;
    const args: [][]const u8 = try allocator.alloc([]const u8, 3);
    defer allocator.free(args);

    args[0] = "zig-out/bin/cleanup";
    args[1] = "test-folder";
    args[2] = "--dry-run";

    const config = try cleanup.Config.fromArgs(args);

    var cwd = std.fs.cwd();
    var hostDir = try cwd.openDir(config.directory, .{ .iterate = true });
    defer hostDir.close();

    var hostIter = hostDir.iterate();

    var results = std.ArrayList(std.fs.Dir.Entry).init(allocator);
    defer results.deinit();

    while (try hostIter.next()) |result| {
        try results.append(result);
        std.debug.print("{s}  =>  {s}new-name.txt{s}\n", .{ result.name, ansi.UNDERLINE, ansi.RESET });
    }

    try std.testing.expect(results.items.len == 1);
    try std.testing.expect(std.ascii.eqlIgnoreCase(results.items[0].name, "file.txt"));

    for (results.items) |result| {
        try hostDir.rename(result.name, "new-name.txt");
    }

    results.clearAndFree();

    hostDir = try hostDir.openDir(".", .{ .iterate = true });
    hostIter = hostDir.iterate();

    while (try hostIter.next()) |result| {
        try results.append(result);
    }

    try std.testing.expect(results.items.len == 1);
    try std.testing.expect(std.ascii.eqlIgnoreCase(results.items[0].name, "new-name.txt"));

    try hostDir.rename("new-name.txt", "file.txt");

    std.debug.print("\n", .{});
}
