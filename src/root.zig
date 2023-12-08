const std = @import("std");
const win = @import("win32.zig");
const mh = @import("minhook.zig");
const emu = @import("emulator.zig");
const hooks = @import("hooks.zig");
const view = @import("view.zig");

var SELF_HANDLE: win.HANDLE = undefined;

pub export fn DllMain(handle: win.HANDLE, reason: win.DWORD, _: win.LPVOID) callconv(win.WINAPI) win.BOOL {
    switch (reason) {
        win.DLL_PROCESS_ATTACH => {
            SELF_HANDLE = handle;
            // running in a separated thread, otherwise directx hooking will fail
            _ = std.Thread.spawn(.{}, initialize, .{}) catch {
                std.debug.print("Error on creating initialize thread\n", .{});
                return win.FALSE;
            };
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

    view.clean();

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

    try createHooks();

    std.debug.print("Enabling hooks\n", .{});
    mh.enableHook(mh.ALL_HOOKS) catch |err| {
        std.debug.print("Error on enabling hooks\n", .{});
        return err;
    };
    errdefer _ = mh.disableHook(mh.ALL_HOOKS) catch {};

    std.debug.print("Initialization done\n", .{});
}

fn createHooks() !void {
    mh.createHook(emu.getRunOpcodePtr(), &hooks.runOpcode, @ptrCast(&hooks.originalRunOpcode)) catch |err| {
        std.debug.print("Error on hooking RunOpcode {}\n", .{err});
        return err;
    };

    mh.createHook(emu.getRunFramePtr(), &hooks.runFrame, @ptrCast(&hooks.originalRunFrame)) catch |err| {
        std.debug.print("Error on hooking RunFrame\n", .{});
        return err;
    };

    mh.createHook(emu.getGameTickPtr(), &hooks.gameTick, @ptrCast(&hooks.originalGameTick)) catch |err| {
        std.debug.print("Error on hooking GameTick\n", .{});
        return err;
    };

    mh.createHook(emu.getWriteInputPtr(), &hooks.writeInput, @ptrCast(&hooks.originalWriteInput)) catch |err| {
        std.debug.print("Error on hooking WriteInput\n", .{});
        return err;
    };

    if (getD3d9EndScenePtr()) |end_scene_ptr| {
        mh.createHook(end_scene_ptr, &hooks.endScene, @ptrCast(&hooks.originalEndScene)) catch |err| {
            std.debug.print("Error on hooking EndScene\n", .{});
            return err;
        };
    } else {
        std.debug.print("Error on getting EndScene address\n", .{});
        return error.UnkownError;
    }
}

fn deinitialize() !void {
    std.debug.print("Disabling hooks\n", .{});
    mh.disableHook(mh.ALL_HOOKS) catch {
        std.debug.print("Error on disabling hooks\n", .{});
    };

    std.time.sleep(100 * std.time.ns_per_ms); // wait to make sure no hook is running anymore

    std.debug.print("Uninitializing minhook\n", .{});
    mh.uninitialize() catch |err| {
        std.debug.print("Error on uninitializing minhook\n", .{});
        return err;
    };

    _ = win.FreeConsole();
}

pub fn shutdown() void {
    std.debug.print("Shutting down\n", .{});

    // run in a separated thread to not uninitialize minhook inside a hook.
    _ = win.CreateThread(
        null,
        0,
        @ptrCast(&win.FreeLibrary),
        @import("root").SELF_HANDLE,
        .THREAD_CREATE_RUN_IMMEDIATELY,
        null,
    ) orelse {
        std.debug.print("Error on creating FreeLibrary thread\n", .{});
    };
}

fn getD3d9EndScenePtr() ?std.meta.FieldType(win.IDirect3DDevice9.VTable, .EndScene) {
    const d3d9 = win.Direct3DCreate9(win.D3D_SDK_VERSION) orelse return null;
    defer _ = d3d9.IUnknown_Release();

    var present_params: win.D3DPRESENT_PARAMETERS = std.mem.zeroes(win.D3DPRESENT_PARAMETERS);
    present_params.Windowed = win.TRUE;
    present_params.SwapEffect = win.D3DSWAPEFFECT_DISCARD;

    var device: ?*win.IDirect3DDevice9 = null;
    if (d3d9.IDirect3D9_CreateDevice(
        win.D3DADAPTER_DEFAULT,
        win.D3DDEVTYPE_HAL,
        win.GetDesktopWindow(),
        win.D3DCREATE_SOFTWARE_VERTEXPROCESSING,
        &present_params,
        &device,
    ) != win.S_OK) return null;
    defer _ = device.?.IUnknown_Release();

    return @ptrCast(device.?.vtable.EndScene);
}
