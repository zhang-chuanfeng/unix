const std = @import("std");

fn signalHandler(sig: i32) align(1) callconv(.C) void {
    std.debug.print("Received signal {}\n", .{sig});
    std.os.linux.exit(-1);
}

fn signal(sig: u6, handler_fun: std.os.linux.Sigaction.handler_fn) void {
    const sigAction = std.os.linux.sigaction;
    var action = std.os.linux.Sigaction{ .handler = undefined, .mask = std.os.linux.empty_sigset, .flags = 0 };
    action.handler.handler = handler_fun;
    _ = sigAction(sig, &action, null);
}

// 可以参考std.ChildProcess

pub fn main() !void {
    signal(std.os.linux.SIG.INT, signalHandler);
    std.debug.print("%% ", .{});

    const allocator = std.heap.page_allocator;
    const stdin = std.io.getStdIn().reader();

    var pid: usize = undefined;
    var status: u32 = undefined;
    while (true) {
        const line = try stdin.readUntilDelimiterAlloc(allocator, '\n', 1024);
        pid = std.os.linux.fork();
        if (pid < 0) {
            std.debug.print("fork error", .{});
            std.os.linux.exit(-1);
        } else if (pid == 0) {
            // child
            const envp = [_:null]?[*:0]const u8{ "PATH=/usr/bin:/bin".ptr, null };
            // const envp = @as([*:null]const ?[*:0]const u8, @ptrCast(std.os.environ.ptr));
            // const envp = std.c.environ;

            var tokenIter = std.mem.tokenize(u8, line, " \t\n\r");

            // 使用ArrayList自动增长
            var argvs = std.ArrayList([]const u8).init(allocator);
            defer argvs.deinit();
            while (tokenIter.next()) |token| {
                try argvs.append(token);
            }
            // 这里参考 std.ChildProcess.spawnPosix()
            // 使用allocSentinel 和  dupeZ
            const argv_buf = try std.heap.page_allocator.allocSentinel(?[*:0]const u8, argvs.items.len, null);
            defer std.heap.page_allocator.free(argv_buf);
            for (argvs.items, 0..) |arg, i| argv_buf[i] = (try allocator.dupeZ(u8, arg)).ptr;

            // 第一个参数需要使用绝对路径 std.ChildProcess使用的是searchPath
            _ = std.os.linux.execve(argv_buf.ptr[0].?, argv_buf.ptr, &envp);
            std.debug.panic("couldn't execute: {s}", .{line});
            std.os.linux.exit(127);
        }

        pid = std.os.linux.waitpid(@intCast(pid), &status, 0);
        if (pid < 0) {
            std.debug.panic("waitpid fail", .{});
        }
        std.debug.print("%% ", .{});
    }
    // test execve()
    // const args = [_:null]?[*:0]const u8{ "ls".ptr, "-l".ptr, "./".ptr, null };
    // const envp = [_:null]?[*:0]const u8{null};
    // _ = std.os.linux.execve("/usr/bin/ls".ptr, &args, &envp);
    // std.os.linux.fork()
    // std.time.sleep(100 * std.time.ns_per_hour);
}
