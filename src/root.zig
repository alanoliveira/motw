const std = @import("std");
const win = @import("win32.zig");
const mh = @import("minhook.zig");
const emu = @import("emulator.zig");

var originalRunOpcode: emu.RunOpcodeT = undefined;
var originalRunFrame: emu.RunFrameT = undefined;

pub export fn DllMain(_: win.HANDLE, reason: win.DWORD, _: win.LPVOID) callconv(win.WINAPI) win.BOOL {
    switch (reason) {
        win.DLL_PROCESS_ATTACH => {
            initialize() catch return win.FALSE;
        },
        win.DLL_PROCESS_DETACH => {
            deinitialize() catch return win.FALSE;
        },
        else => {},
    }

    return win.TRUE;
}

fn initialize() !void {
    _ = win.AllocConsole();
    errdefer _ = win.FreeConsole();

    std.debug.print("Getting game process address\n", .{});
    const base_addr = win.GetModuleHandleA(null) orelse {
        std.debug.print("Error on getting game base address.\n", .{});
        return error.EmulatorError;
    };
    emu.initialize(@ptrCast(base_addr));

    std.debug.print("Initializing minhook\n", .{});
    mh.initialize() catch |err| {
        std.debug.print("Error on initializing minhook\n", .{});
        return err;
    };
    errdefer _ = mh.uninitialize() catch {};

    mh.createHook(emu.getRunOpcodePtr(), &hookedRunOpcode, @ptrCast(&originalRunOpcode)) catch |err| {
        std.debug.print("Error on hooking RunOpcode {}\n", .{err});
        return err;
    };

    mh.createHook(emu.getRunFramePtr(), &hookedRunFrame, @ptrCast(&originalRunFrame)) catch |err| {
        std.debug.print("Error on hooking RunFrame\n", .{});
        return err;
    };

    std.debug.print("Enabling hooks\n", .{});
    mh.enableHook(mh.ALL_HOOKS) catch |err| {
        std.debug.print("Error on enabling hooks\n", .{});
        return err;
    };
    errdefer _ = mh.disableHook(mh.ALL_HOOKS) catch {};

    std.debug.print("Initialization done\n", .{});
}

fn deinitialize() !void {
    defer _ = win.FreeConsole();

    std.debug.print("Disabling hooks\n", .{});
    mh.disableHook(mh.ALL_HOOKS) catch |err| {
        std.debug.print("Error on disabling hooks\n", .{});
        return err;
    };

    std.debug.print("Uninitializing minhook\n", .{});
    mh.uninitialize() catch |err| {
        std.debug.print("Error on uninitializing minhook\n", .{});
        return err;
    };
}

fn hookedRunOpcode() callconv(.C) void {
    return originalRunOpcode();
}

fn hookedRunFrame() callconv(.C) u32 {
    return originalRunFrame();
}
