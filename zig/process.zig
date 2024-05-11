const std = @import("std");

fn signalHandler(sig: i32) align(1) callconv(.C) void {
    std.debug.print("Received signal {}\n", .{sig});
}

fn signal(sig: u6, handler_fun: std.os.linux.Sigaction.handler_fn) void {
    const sigAction = std.os.linux.sigaction;
    var action = std.os.linux.Sigaction{ .handler = undefined, .mask = std.os.linux.empty_sigset, .flags = 0 };
    action.handler.handler = handler_fun;
    _ = sigAction(sig, &action, null);
}

pub fn main() !void {
    signal(std.os.linux.SIG.INT, signalHandler);
    std.debug.print("%% ", .{});

    const allocator = std.heap.page_allocator;
    const stdin = std.io.getStdIn().reader();
    const line = try stdin.readUntilDelimiterAlloc(allocator, '\n', 1024);

    var pid: usize = undefined;
    var status: u32 = undefined;
    pid = std.os.linux.fork();
    if (pid < 0) {
        std.debug.print("fork error");
        std.os.linux.exit(-1);
    } else if (pid == 0) {
        // child
        // const args: [:null]?[*:0]const u8 = undefined;
        const envp = [_:null]?[*:0]const u8{null};

        var argv = try std.heap.page_allocator.alloc(?[*:0]const u8, 10);
        defer std.heap.page_allocator.free(argv);

        var tokenIter = std.mem.tokenize(u8, line, " \t\n\r");
        var i: usize = 0;
        while (tokenIter.next()) |token| : (i += 1) {
            std.debug.print("{s}\n", .{token});
            argv[i] = token[0..token.len :0];
        }

        var argall = try std.heap.page_allocator.alloc([*]?[*:0]const u8, argv.len + 1);
        defer std.heap.page_allocator.free(argall);

        // args = argall.ptr;

        for (argv, 0..) |_, ii| {
            argall[ii][0] = argv[ii];
        }
        // args = argall[0];
        // const args: [*:null]?[*:0]const u8 = argall[0];
        // args = argall[0];

        // const args: [_:null]?[*:0]const u8 = ;
        // ar = argv[0..argv.len :null];
        _ = std.os.linux.execve(argv[0].?, argall, &envp);
        std.debug.panic("couldn't execute: {}", .{line});
        std.os.linux.exit(127);
    }

    pid = std.os.linux.waitpid(pid, &status, 0);
    if (pid < 0) {
        std.debug.panic("waitpid {} fail", .{pid});
    }
    std.debug.print("%% ");
    // test execve()
    // const args = [_:null]?[*:0]const u8{ "ls".ptr, "-l".ptr, "./".ptr, null };
    // const envp = [_:null]?[*:0]const u8{null};
    // _ = std.os.linux.execve("/usr/bin/ls".ptr, &args, &envp);
    // std.os.linux.fork()
    // std.time.sleep(100 * std.time.ns_per_hour);
}
