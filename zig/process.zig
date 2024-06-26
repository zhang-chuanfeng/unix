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
// ziglang.cc https://github.com/orgs/zigcc/discussions/123

pub fn main() !void {
    signal(std.os.linux.SIG.INT, signalHandler);
    std.debug.print("%% ", .{});

    var gpa = std.heap.GeneralPurposeAllocator(.{}){};
    defer {
        const deinit_status = gpa.deinit();
        if (deinit_status == .leak) @panic("memory leak");
    }
    const gpa_allocator = gpa.allocator();
    const stdin = std.io.getStdIn().reader();

    var pid: usize = undefined;
    var status: u32 = undefined;
    while (true) {
        var arena = std.heap.ArenaAllocator.init(gpa_allocator);
        defer arena.deinit();
        const arena_allocator = arena.allocator();
        const line = try stdin.readUntilDelimiterAlloc(arena_allocator, '\n', 1024);
        pid = std.os.linux.fork();
        if (pid < 0) {
            std.debug.print("fork error", .{});
            std.os.linux.exit(-1);
        } else if (pid == 0) {
            // child
            const envp = [_:null]?[*:0]const u8{ "PATH=/usr/bin:/bin".ptr, null };
            // const envp = @as([*:null]const ?[*:0]const u8, @ptrCast(std.os.environ.ptr));
            // const envp = std.c.environ;

            var tokenIter = std.mem.tokenize(u8, line, std.ascii.whitespace[0..]);

            // 使用ArrayList自动增长
            var argvs = std.ArrayList([]const u8).init(arena_allocator);
            while (tokenIter.next()) |token| {
                try argvs.append(token);
            }
            // 这里参考 std.ChildProcess.spawnPosix()
            // 使用allocSentinel 和  dupeZ

            const argv_buf = try arena_allocator.allocSentinel(?[*:0]const u8, argvs.items.len, null);
            // dupeZ alloc需要退出释放  使用arena
            for (argvs.items, 0..) |arg, i| argv_buf[i] = (try arena_allocator.dupeZ(u8, arg)).ptr;

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
