const std = @import("std");
const argreader = @import("argreader.zig");
const eql = std.mem.eql;

pub fn main() !void {}

pub const Config = struct {
    dryRun: bool = undefined,
    recursive: bool = undefined,
    force: bool = undefined,
    patch: bool = undefined,
    magic: bool = undefined,

    directory: []const u8 = undefined,

    fn fromCommand(self: *Config, command: *argreader.Command) !void {
        self.directory = command.command.?;

        for (command.flags.items) |flag| {
            // Cannot switch on strings -> should probably start from the beginning and add flags as chars, switch on int.
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
                try std.debug.print("ERROR - unknown argument: {s}", .{flag.head});
                break;
            }
        }
    }
};
