const std = @import("std");
const test_allocator = std.testing.allocator;
const expect = std.testing.expect;

// const Flag = struct { head: []const u8, tail: ?[]const u8 };

// pub fn main() !void {
//     var arena = std.heap.ArenaAllocator.init(std.heap.page_allocator);
//     defer arena.deinit();
//     const allocator = arena.allocator();

//     const stdout = std.io.getStdOut().writer();
//     var args = try std.process.argsWithAllocator(allocator);
//     defer args.deinit();

//     // pop the path to this command
//     _ = args.next();

//     // PRINT THIS SHIT OUT NICELY MAN
//     try stdout.print("Command: {?s}\n\n", .{command});
//     for (flags.items, 0..) |flag, i| {
//         try stdout.print("Flag {d}\nHead: {?s}\nTail: {?s}\n\n", .{ i, flag.head, flag.tail });
//     }
// }

// const CleanupArgs = struct {

// };

// pub fn readArgsIntoFlags(std.process.ArgIterator args, std.heap.g allocator) []Flag {
//     // take note of the main command
//     const command: []const u8 = args.next() orelse " ";
//     var flags: std.ArrayList(Flag) = std.ArrayList(Flag).init(allocator);

//     // instantiate the previous args
//     var prevFlag: ?Flag = null;
//     var prevWasFlag: bool = false;

//     while (args.next()) |arg| {
//         if (std.mem.eql(u8, arg[0..2], "--")) {
//             // if arg begins with "--"
//             if (prevFlag != null) {
//                 try flags.append(prevFlag.?);
//             }
//             const newFlag: Flag = .{ .head = arg, .tail = null };
//             prevFlag = newFlag;
//             prevWasFlag = true;
//         } else if (prevWasFlag) {
//             // if previous arg began with --
//             if (prevFlag != null) {
//                 prevFlag.?.tail = arg;
//                 prevWasFlag = false;
//             } else unreachable;
//         } else {
//             //throw syntax error, perhaps pull up the help page.
//         }
//     }

//     if (prevFlag != null and prevFlag.?.head.len > 0) {
//         try flags.append(prevFlag.?);
//     }
// }

// test "commandline test" {
//     var args = try std.process.argsWithAllocator(test_allocator);
//     defer args.deinit();

//     while (args.next()) |arg| {
//         std.debug.print("{s}\n", .{arg});
//     }
// }
