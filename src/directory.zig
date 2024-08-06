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
    const config: cleanup.Config = cleanup.Config{ .directory = "Downloads" };

    const homeVar = try std.process.getEnvVarOwned(test_allocator, "HOME");
    defer test_allocator.free(homeVar);

    const dir: std.fs.Dir = std.fs.cwd();
    const homeDir: std.fs.Dir = try dir.openDir(homeVar, .{ .iterate = true });
    // std.debug.print("{any}\n", .{homeDir});
    try homeDir.setAsCwd();

    const homePath = try homeDir.realpathAlloc(test_allocator, ".");
    defer test_allocator.free(homePath);

    try expect(eql(u8, homePath, homeVar));

    var homeIter: std.fs.Dir.Iterator = homeDir.iterate();
    var found: bool = false;
    while (try homeIter.next()) |result| {
        switch (result.kind) {
            std.fs.File.Kind.directory => {
                // std.debug.print("dir: {s}\n", .{result.name});
                if (eql(u8, result.name, config.directory)) {
                    std.debug.print("MATCH :)\n", .{});
                    found = true;
                    break;
                }
            },
            else => continue,
        }
    }

    try expect(found);
}

test "case sensitivity" {
    const config = cleanup.Config{
        .directory = "downloads",
    };

    const foundDir = "DownLoaDs";
    var buf: [foundDir.len]u8 = undefined;
    const lowerDir = std.ascii.lowerString(&buf, foundDir);

    try expect(eql(u8, lowerDir, config.directory));
}

test "case sensitivity in the wild" {
    const config = cleanup.Config{ .directory = "deskTOP" };

    var buf: [config.directory.len]u8 = undefined;
    const configDirLower = std.ascii.lowerString(&buf, config.directory);

    const homeVar = try std.process.getEnvVarOwned(test_allocator, "HOME");
    defer test_allocator.free(homeVar);

    const cwd = std.fs.cwd();
    const homeDir = try cwd.openDir(homeVar, .{ .iterate = true });

    var homeIter = homeDir.iterate();
    var found = false;
    while (try homeIter.next()) |result| {
        if (result.kind == .directory) {
            if (result.name.len != configDirLower.len) {
                // cut it early if it wont be a match
                continue;
            }

            var resultBuf: [config.directory.len]u8 = undefined;
            const resultLower = std.ascii.lowerString(&resultBuf, result.name);

            if (eql(u8, resultLower, configDirLower)) {
                found = true;
                break;
            }
        }
    }

    try expect(found);
    try expect(eql(u8, configDirLower, "desktop"));
}

test "get all files and subdirectories in dir" {
    const config = cleanup.Config{ .directory = "DownLoads" };

    var buf: [config.directory.len]u8 = undefined;
    const configDirLower = std.ascii.lowerString(&buf, config.directory);

    const homeVar = try std.process.getEnvVarOwned(test_allocator, "HOME");
    defer test_allocator.free(homeVar);

    const cwd = std.fs.cwd();
    const homeDir = try cwd.openDir(homeVar, .{ .iterate = true });

    var homeIter = homeDir.iterate();
    var found = false;
    var configDirPath: []const u8 = undefined;
    while (try homeIter.next()) |result| {
        if (result.kind == .directory) {
            if (result.name.len != configDirLower.len) {
                // cut it early if it wont be a match
                continue;
            }

            var resultBuf: [config.directory.len]u8 = undefined;
            const resultLower = std.ascii.lowerString(&resultBuf, result.name);

            if (eql(u8, resultLower, configDirLower)) {
                found = true;
                configDirPath = result.name;
                break;
            }
        }
    }

    if (found) {
        const configDir = try homeDir.openDir(configDirPath, .{ .iterate = true });
        const testFileName: []const u8 = "testfile.txt";

        const testFile: std.fs.File = try configDir.createFile(testFileName, .{});
        testFile.close();

        var outBuf: [1024]u8 = undefined;
        const realpath = try configDir.realpath(".", &outBuf);
        std.debug.print("{s}\n", .{realpath});

        var dirIter = configDir.iterate();
        var foundTestFile = false;
        while (try dirIter.next()) |result| {
            if (std.ascii.eqlIgnoreCase(result.name, testFileName)) {
                foundTestFile = true;
                break;
            }
        }

        if (foundTestFile) {
            try configDir.deleteFile(testFileName);
        }

        try expect(foundTestFile);
    }
}
