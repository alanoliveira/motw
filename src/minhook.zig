const std = @import("std");
const mh = @cImport(@cInclude("minhook.h"));

pub const ALL_HOOKS = mh.MH_ALL_HOOKS;

pub fn initialize() !void {
    return switch (mh.MH_Initialize()) {
        mh.MH_OK => {},
        mh.MH_ERROR_ALREADY_INITIALIZED => error.AlreadyInitialized,
        else => error.Unknown,
    };
}

pub fn uninitialize() !void {
    return switch (mh.MH_Uninitialize()) {
        mh.MH_OK => {},
        mh.MH_ERROR_NOT_INITIALIZED => error.NotInitialized,
        else => error.Unknown,
    };
}

pub fn createHook(target: *const anyopaque, detour: *const anyopaque, original: ?**anyopaque) !void {
    return switch (mh.MH_CreateHook(@constCast(target), @constCast(detour), @ptrCast(original))) {
        mh.MH_OK => {},
        mh.MH_ERROR_NOT_INITIALIZED => error.NotInitialized,
        mh.MH_ERROR_ALREADY_CREATED => error.AlreadyCreated,
        else => error.Unknown,
    };
}

pub fn enableHook(hook: ?*const anyopaque) !void {
    return switch (mh.MH_EnableHook(@constCast(hook))) {
        mh.MH_OK => {},
        mh.MH_ERROR_NOT_INITIALIZED => error.NotInitialized,
        mh.MH_ERROR_NOT_CREATED => error.NotCreated,
        else => error.Unknown,
    };
}

pub fn disableHook(hook: ?*const anyopaque) !void {
    return switch (mh.MH_DisableHook(@constCast(hook))) {
        mh.MH_OK => {},
        mh.MH_ERROR_NOT_INITIALIZED => error.NotInitialized,
        else => error.Unknown,
    };
}
