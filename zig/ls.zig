const std = @import("std");

pub fn main() !void {
    var args = std.process.args();
    _ = args.next();

    var gpa = std.heap.GeneralPurposeAllocator(.{}){};
    defer {
        const deinit_status = gpa.deinit();
        if (deinit_status == .leak) @panic("memory leak");
    }

    const alloc = gpa.allocator();

    while (args.next()) |arg| {
        var dir = try std.fs.openDirAbsolute(arg, .{ .iterate = true });
        defer dir.close();
        var walk = try dir.walk(alloc);
        defer walk.deinit();

        while (walk.next() catch |err| {
            std.debug.print("{}", .{err});
            return err;
        }) |entry| {
            std.debug.print("{s}\n", .{entry.basename});
        }
    }
}
