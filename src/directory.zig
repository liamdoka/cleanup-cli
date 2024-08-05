const std = @import("std");
const cleanup = @import("main.zig");
const eql = std.mem.eql;
const expect = std.testing.expect;
const test_allocator = std.testing.allocator;

test "get current directory and path" {
    const config: cleanup.Config = .{
        .directory = ".",
    };

    const cwd: std.fs.Dir = std.fs.cwd();
    const realPath: []u8 = try cwd.realpathAlloc(test_allocator, config.directory);
    defer test_allocator.free(realPath);

    var cursor: usize = realPath.len - 1;
    while (cursor > 0) : (cursor -= 1) {
        if (realPath[cursor] == '/' or realPath[cursor] == '\\') {
            break;
        }
    }
    const currentDirSlice = realPath[cursor + 1 ..];

    // std.debug.print("path: {s}\n", .{realPath});
    // std.debug.print("cwd: {s}\n", .{currentDirSlice});

    try expect(eql(u8, "cleanup-cli", currentDirSlice));
}

test "try read environment variables" {
    var envMap: std.process.EnvMap = try std.process.getEnvMap(test_allocator);
    defer envMap.deinit();

    const homeSlice: []const u8 = "/home/lok"; // :)
    const userSlice: []const u8 = "lok";
    const envHome: ?[]const u8 = envMap.get("HOME");
    const envUser: ?[]const u8 = envMap.get("USER");

    try expect(eql(u8, homeSlice, envHome.?));
    try expect(eql(u8, userSlice, envUser.?));
}

test "find basic folders" {
    const homeVar = try std.process.getEnvVarOwned(test_allocator, "HOME");
    defer test_allocator.free(homeVar);

    const dir: std.fs.Dir = std.fs.cwd();
    const homeDir: std.fs.Dir = try dir.openDir(homeVar, .{ .iterate = true });

    // var iter = try homeDir.iterate();

    // while (iter.next()) |entry| {
    //     std.debug.print("{s}\n", .{entry});
    // }

    std.debug.print("{any}\n", .{homeDir});
}
