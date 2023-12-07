const std = @import("std");
const win = @import("win32.zig");

pub export fn DllMain(_: win.HANDLE, reason: win.DWORD, _: win.LPVOID) callconv(win.WINAPI) win.BOOL {
    switch (reason) {
        win.DLL_PROCESS_ATTACH => {
            initialize();
        },
        win.DLL_PROCESS_DETACH => {
            deinitialize();
        },
        else => {},
    }

    return win.TRUE;
}

fn initialize() void {
    _ = win.AllocConsole();
    errdefer _ = win.FreeConsole();
}

fn deinitialize() void {
    _ = win.FreeConsole();
}
