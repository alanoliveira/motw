const std = @import("std");
const injector = @import("injector.zig");

const DEFAULT_PROC_NAME = "Garou.exe";
const DEFAULT_DLL_PATH = "motw.dll";

const CliArgs = struct {
    proc_name: []const u8,
    dll_path: []const u8,
    fn initialize(args: []const []const u8) ?CliArgs {
        if (args.len == 1) {
            return CliArgs{
                .proc_name = DEFAULT_PROC_NAME,
                .dll_path = DEFAULT_DLL_PATH,
            };
        } else if (args.len == 3) {
            return CliArgs{
                .dll_path = args[1],
                .proc_name = args[2],
            };
        } else return null;
    }
};

pub fn main() !void {
    const stdin = std.io.getStdIn();

    const stdout_file = std.io.getStdOut().writer();
    var bw = std.io.bufferedWriter(stdout_file);
    const stdout = bw.writer();

    var gpa = std.heap.GeneralPurposeAllocator(.{}){};
    defer _ = gpa.deinit();
    const allocator = gpa.allocator();

    const args = try std.process.argsAlloc(allocator);
    defer std.process.argsFree(allocator, args);

    const cli_args = CliArgs.initialize(args) orelse {
        std.debug.print("Invalid usage", .{});
        return;
    };

    injector.inject(cli_args.dll_path, cli_args.proc_name) catch |err| {
        const err_msg = switch (err) {
            injector.InjectorError.OpenProcError => "Error on opening game process",
            injector.InjectorError.ProcNotFound => "Game process not found",
            injector.InjectorError.DllNotFound => "Dll not found",
            injector.InjectorError.LoadDllError => "Error on injecting dll",
            else => "Unknown error",
        };
        try stdout.print("Error:\n{s}\n\nPress enter to close...\n", .{err_msg});
        try bw.flush();

        var buff: [1]u8 = undefined;
        _ = try stdin.read(&buff);
    };
}
