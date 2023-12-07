const std = @import("std");
const win = struct {
    usingnamespace @import("zigwin32").system.diagnostics.tool_help;
    usingnamespace @import("zigwin32").system.diagnostics.debug;
    usingnamespace @import("zigwin32").foundation;
    usingnamespace @import("zigwin32").system.library_loader;
    usingnamespace @import("zigwin32").system.memory;
    usingnamespace @import("zigwin32").system.threading;
    usingnamespace @import("zigwin32").zig;

    const INFINITE = @import("zigwin32").system.windows_programming.INFINITE;
};

pub const InjectorError = error{
    UnknownError,
    DllNotFound,
    ProcNotFound,
    OpenProcError,
    LoadDllError,
};

pub fn inject(dll_path: []const u8, proc_name: []const u8) InjectorError!void {
    var out_buffer = [_]u8{0} ** std.fs.MAX_PATH_BYTES;
    const dll_abs_path = std.fs.realpath(dll_path, &out_buffer) catch |e| {
        std.debug.print(">>> {s}\n", .{dll_path});
        return switch (e) {
            std.os.RealPathError.FileNotFound => InjectorError.DllNotFound,
            else => InjectorError.UnknownError,
        };
    };

    const pid = getPidByProcName(proc_name) orelse return InjectorError.ProcNotFound;

    const proc_handle = win.OpenProcess(
        .ALL_ACCESS,
        win.FALSE,
        pid,
    ) orelse return InjectorError.OpenProcError;

    if (!load_dll(proc_handle, dll_abs_path)) return InjectorError.LoadDllError;
}

fn getPidByProcName(proc_name: []const u8) ?u32 {
    const snapshot = win.CreateToolhelp32Snapshot(
        .SNAPPROCESS,
        0,
    ) orelse return null;
    defer _ = win.CloseHandle(snapshot);

    var entry: win.PROCESSENTRY32 = undefined;
    while (win.Process32Next(snapshot, &entry) == win.TRUE) {
        const i_name: [*:0]u8 = @ptrCast(&entry.szExeFile);
        if (std.mem.eql(u8, std.mem.span(i_name), proc_name)) {
            return entry.th32ProcessID;
        }
    }

    return null;
}

fn load_dll(proc_handle: win.HANDLE, dll_path: []const u8) bool {
    const buff = win.VirtualAllocEx(
        proc_handle,
        null,
        dll_path.len,
        win.VIRTUAL_ALLOCATION_TYPE.initFlags(.{ .RESERVE = 1, .COMMIT = 1 }),
        .PAGE_READWRITE,
    ) orelse return false;
    defer _ = win.VirtualFreeEx(proc_handle, buff, 0, .RELEASE);

    if (win.WriteProcessMemory(
        proc_handle,
        buff,
        @constCast(dll_path.ptr),
        dll_path.len,
        null,
    ) == win.FALSE) {
        return false;
    }

    const kernel32 = win.GetModuleHandleA("kernel32.dll") orelse return false;
    defer _ = win.FreeLibrary(kernel32);

    const load_lib = win.GetProcAddress(kernel32, "LoadLibraryA") orelse return false;

    const thread = win.CreateRemoteThread(
        proc_handle,
        null,
        0,
        @ptrCast(load_lib),
        buff,
        0,
        null,
    ) orelse return false;

    return win.WaitForSingleObject(thread, win.INFINITE) == 0;
}
