const std = @import("std");

pub fn main() !void {
    var args = std.process.args();
    _ = args.next();
    while (args.next()) |arg| {
        std.fs.accessAbsolute(arg, .{}) catch |err| {
            std.debug.print("{s}: {}\n", .{ arg, err });
            continue;
        };

        var st = std.mem.zeroes(std.posix.system.Stat);
        _ = std.posix.system.lstat(arg, &st);
        const stat = std.fs.File.Stat.fromSystem(st);
        std.debug.print("{s}: {s}\n", .{ arg, @tagName(stat.kind) });
    }
}
