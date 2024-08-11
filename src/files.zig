const std = @import("std");
const ansi = @import("ansi_helper.zig");
const cleanup = @import("main.zig");

const stdout = std.io.getStdOut().writer();
const stdin = std.io.getStdOut().reader();

pub fn main() !void {
    const allocator = std.heap.page_allocator;
    // const args = std.process.argsAlloc(allocator);
    // defer std.process.argsFree(allocator, args);

    const args: [][]const u8 = try allocator.alloc([]const u8, 3);
    defer allocator.free(args);

    args[0] = "./zig-out/bin/cleanup";
    args[1] = "test-folder";
    args[2] = "--all";

    const config = try cleanup.Config.fromArgs(args);

    var cwd = std.fs.cwd();
    var targetDir = try cwd.openDir(config.directory, .{ .iterate = true });
    defer targetDir.close();

    var targetDirIter = targetDir.iterate();
    while (try targetDirIter.next()) |result| {
        const prompt = try std.fmt.allocPrint(allocator, "Would you like to handle\n\t{s}\n\n['d','r','m','n','?']: ", .{result.name});
        _ = try stdout.write(prompt);

        const buf: []u8 = undefined;
        if (try stdin.readUntilDelimiterOrEof(buf[0..], '\n')) |input| {
            if (input.len == 1) {
                const action: cleanup.FileAction = switch (input[0]) {
                    'r' => .Rename,
                    'd' => .Delete,
                    'm' => .Move,
                    'n' => .Nothing,
                    else => .TryAgain,
                };

                if (action != .TryAgain) {
                    try cleanup.handleFile(cwd, result.name, action);
                } else {}
            }
        }
    }

    try stdout.write("\x1B[2J\x1B[H");
    try stdout.write("Cleanup completed :)\n");
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

        std.debug.print("{s}{s}{s}{s}  =>  {s}{s}{s}{s}\n", .{
            // zig fmt:off
            offset,   color,              result.name, ansi.RESET,
            ansi.RED, ansi.STRIKETHROUGH, result.name, ansi.RESET,
        });
    }

    try std.testing.expect(results.items.len == 4);

    results.clearAndFree();

    try hostDir.deleteDir("new-dir");
    try hostDir.deleteDir("dir");
    try hostDir.deleteFile("test.txt");

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

    var results = std.ArrayList(std.fs.Dir.Entry).init(allocator);
    defer results.deinit();

    var hostIter = hostDir.iterate();
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
    hostIter = hostDir.iterate();

    while (try hostIter.next()) |result| {
        try results.append(result);
    }

    try std.testing.expect(results.items.len == 1);
    try std.testing.expect(std.ascii.eqlIgnoreCase(results.items[0].name, "new-name.txt"));

    try hostDir.rename("new-name.txt", "file.txt");

    std.debug.print("\n", .{});
}

test "create a folder and move files into it" {
    const allocator = std.testing.allocator;
    const args = try allocator.alloc([]const u8, 3);
    defer allocator.free(args);

    args[0] = "zig-out/bin/cleanup";
    args[1] = "test-folder";
    args[2] = "--all";

    const config = try cleanup.Config.fromArgs(args);

    const cwd = std.fs.cwd();
    var hostDir = try cwd.openDir(config.directory, .{ .iterate = true });
    defer hostDir.close();

    var hostIter = hostDir.iterate();

    var results = std.ArrayList(std.fs.Dir.Entry).init(allocator);
    defer results.deinit();

    while (try hostIter.next()) |result| {
        try results.append(result);
        std.debug.print("{s}  =>  {s}{s}nested-folder/{s}{s}{s}{s}\n", .{
            // zig fmt:off
            result.name,
            ansi.BOLD,
            ansi.BLUE,
            ansi.RESET,
            ansi.UNDERLINE,
            result.name,
            ansi.RESET,
        });
    }

    try std.testing.expect(results.items.len == 1);
    try std.testing.expect(results.items[0].kind == .file);

    _ = try hostDir.makeDir("nested-folder");

    var nestedDir = try hostDir.openDir("nested-folder", .{ .iterate = true });
    defer nestedDir.close();

    for (results.items) |result| {
        try hostDir.copyFile(result.name, nestedDir, result.name, .{});
        try hostDir.deleteFile(result.name);
    }

    results.clearAndFree();
    hostIter = hostDir.iterate();
    while (try hostIter.next()) |result| {
        try results.append(result);
    }

    try std.testing.expect(results.items.len == 1);
    try std.testing.expect(results.items[0].kind == .directory);

    results.clearAndFree();

    nestedDir = try nestedDir.openDir(".", .{ .iterate = true });
    var nestedIter = nestedDir.iterate();

    while (try nestedIter.next()) |result| {
        try results.append(result);
    }

    try std.testing.expect(results.items.len == 1);
    try std.testing.expect(results.items[0].kind == .file);

    try nestedDir.deleteFile("file.txt");
    try hostDir.deleteDir("nested-folder");
    var newFile = try hostDir.createFile("file.txt", .{});
    defer newFile.close();

    std.debug.print("\n", .{});
}

test "use an open dir once a new thing has been added" {
    const allocator = std.testing.allocator;
    const args = try allocator.alloc([]const u8, 3);
    defer allocator.free(args);

    args[0] = "zig-out/bin/cleanup";
    args[1] = "test-folder";
    args[2] = "--all";

    const config = try cleanup.Config.fromArgs(args);

    const cwd = std.fs.cwd();
    var hostDir = try cwd.openDir(config.directory, .{ .iterate = true });
    var hostIter = hostDir.iterate();

    var results = std.ArrayList(std.fs.Dir.Entry).init(allocator);
    defer results.deinit();

    while (try hostIter.next()) |result| {
        try results.append(result);
    }

    try std.testing.expect(results.items.len == 1);
    results.clearAndFree();

    const newFile = try hostDir.createFile("new-file.txt", .{});
    newFile.close();

    hostIter = hostDir.iterate();

    while (try hostIter.next()) |result| {
        try results.append(result);
    }

    try std.testing.expect(results.items.len == 2);
    try hostDir.deleteFile("new-file.txt");
}
