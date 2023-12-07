const std = @import("std");
const win = @import("win32.zig");
const mh = @import("minhook.zig");
const emu = @import("emulator.zig");
const input = @import("input.zig");

var SELF_HANDLE: win.HANDLE = undefined;
var originalRunOpcode: emu.RunOpcodeT = undefined;
var originalRunFrame: emu.RunFrameT = undefined;

pub export fn DllMain(handle: win.HANDLE, reason: win.DWORD, _: win.LPVOID) callconv(win.WINAPI) win.BOOL {
    switch (reason) {
        win.DLL_PROCESS_ATTACH => {
            SELF_HANDLE = handle;
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

    std.debug.print("Initializing win32 api\n", .{});
    win.initialize();

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
    std.time.sleep(100 * std.time.ns_per_ms); // wait to make sure no hook is running anymore

    std.debug.print("Uninitializing minhook\n", .{});
    mh.uninitialize() catch |err| {
        std.debug.print("Error on uninitializing minhook\n", .{});
        return err;
    };

    _ = win.FreeConsole();
}

fn shutdown() void {
    std.debug.print("Shutting down\n", .{});

    std.debug.print("Disabling hooks\n", .{});
    mh.disableHook(mh.ALL_HOOKS) catch {
        std.debug.print("Error on disabling hooks\n", .{});
    };

    // run in a separated thread to not uninitialize minhook inside a hook.
    _ = win.CreateThread(
        null,
        0,
        @ptrCast(&win.FreeLibrary),
        SELF_HANDLE,
        .THREAD_CREATE_RUN_IMMEDIATELY,
        null,
    ) orelse {
        std.debug.print("Error on creating FreeLibrary thread\n", .{});
    };
}

fn hookedRunOpcode() callconv(.C) void {
    return originalRunOpcode();
}

fn hookedRunFrame() callconv(.C) u32 {
    input.poll();

    if (input.isPressed(.{ .Keyboard = .F7 })) {
        defer shutdown();
    }

    return originalRunFrame();
}
