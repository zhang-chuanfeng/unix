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
            var args: [:null]?[*:0]const u8 = undefined;
            const envp = [_:null]?[*:0]const u8{null};

            const argv_tmp = try std.heap.page_allocator.alloc(?[*:0]const u8, 10);
            defer std.heap.page_allocator.free(argv_tmp);

            var tokenIter = std.mem.tokenize(u8, line, " \t\n\r");
            var i: usize = 0;
            while (tokenIter.next()) |token| : (i += 1) {
                if (i >= 9) break;
                std.debug.print("{s}\n", .{token});
                var buff = try std.heap.page_allocator.alloc(u8, token.len + 1);
                // defer std.heap.page_allocator.free(buff);
                std.debug.print("token.len={d}, buff.len={d}\n", .{ token.len, buff.len });
                buff[token.len] = 0;
                std.debug.print("token.len={d}, buff.len={d}\n", .{ token.len, buff.len });
                buff.len = token.len;
                @memcpy(buff, token);
                buff.len = token.len + 1;
                argv_tmp[i] = buff[0..token.len :0];
            }
            // defer {
            //     var j: usize = 0;
            //     while (j < argv_tmp.len) : (j += 1) {
            //         if (argv_tmp[j] != null) {
            //             // 如何释放上面 buff的内存
            //             // std.heap.page_allocator.free(argv_tmp[j].?.*);
            //         }
            //     }
            // }
            const argv = try std.heap.page_allocator.alloc(?[*:0]const u8, i + 1);
            defer std.heap.page_allocator.free(argv);
            argv[i] = null;
            std.debug.print("i={d}\n", .{i});
            std.debug.print("argv.len={d}\n", .{argv.len});
            while (i > 0) : (i -= 1) {
                argv[argv.len - 1 - i] = argv_tmp[argv.len - 1 - i];
            }

            args = argv[0 .. argv.len - 1 :null];
            _ = std.os.linux.execve(argv[0].?, args.ptr, &envp);
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
