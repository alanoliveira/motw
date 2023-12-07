const std = @import("std");

pub usingnamespace @import("zigwin32").foundation;
pub usingnamespace @import("zigwin32").graphics.direct3d9;
pub usingnamespace @import("zigwin32").system.console;
pub usingnamespace @import("zigwin32").system.library_loader;
pub usingnamespace @import("zigwin32").system.system_services;
pub usingnamespace @import("zigwin32").system.threading;
pub usingnamespace @import("zigwin32").ui.input.keyboard_and_mouse;
pub usingnamespace @import("zigwin32").ui.windows_and_messaging;
pub usingnamespace @import("zigwin32").zig;
pub const DWORD = std.os.windows.DWORD;
pub const LPVOID = std.os.windows.LPVOID;
pub const WINAPI = std.os.windows.WINAPI;

const x_input = @import("zigwin32").ui.input.xbox_controller;
pub var XInputGetKeystroke: *const fn (u32, u32, ?*XINPUT_KEYSTROKE) callconv(std.os.windows.WINAPI) u32 = undefined;
pub const XINPUT_STATE = x_input.XINPUT_STATE;
pub const XINPUT_KEYSTROKE_KEYDOWN = @as(u32, 1);

pub const XINPUT_KEYSTROKE = extern struct {
    VirtualKey: XINPUT_VIRTUAL_KEY,
    Unicode: u16,
    Flags: u16,
    UserIndex: u8,
    HidCode: u8,
};

pub const XINPUT_VIRTUAL_KEY = enum(u16) {
    A = 22528,
    B = 22529,
    X = 22530,
    Y = 22531,
    RSHOULDER = 22532,
    LSHOULDER = 22533,
    LTRIGGER = 22534,
    RTRIGGER = 22535,
    DPAD_UP = 22544,
    DPAD_DOWN = 22545,
    DPAD_LEFT = 22546,
    DPAD_RIGHT = 22547,
    START = 22548,
    BACK = 22549,
    LTHUMB_PRESS = 22550,
    RTHUMB_PRESS = 22551,
    LTHUMB_UP = 22560,
    LTHUMB_DOWN = 22561,
    LTHUMB_RIGHT = 22562,
    LTHUMB_LEFT = 22563,
    LTHUMB_UPLEFT = 22564,
    LTHUMB_UPRIGHT = 22565,
    LTHUMB_DOWNRIGHT = 22566,
    LTHUMB_DOWNLEFT = 22567,
    RTHUMB_UP = 22576,
    RTHUMB_DOWN = 22577,
    RTHUMB_RIGHT = 22578,
    RTHUMB_LEFT = 22579,
    RTHUMB_UPLEFT = 22580,
    RTHUMB_UPRIGHT = 22581,
    RTHUMB_DOWNRIGHT = 22582,
    RTHUMB_DOWNLEFT = 22583,
    _,
};

const d3dx9 = @cImport({
    @cInclude("d3dx9.h");
});
pub const ID3DXSprite = d3dx9.ID3DXSprite;
pub var D3DXCreateSprite: *const @TypeOf(d3dx9.D3DXCreateSprite) = undefined;
pub const D3DXSPRITE_DONOTSAVESTATE = d3dx9.D3DXSPRITE_DONOTSAVESTATE;
pub const D3DXVECTOR3 = d3dx9.D3DXVECTOR3;

pub fn initialize() void {
    const ll = @import("zigwin32").system.library_loader;

    const xinput_dll = ll.GetModuleHandleA("xinput1_3.dll") orelse @panic("Failed to load xinput1_3.dll");
    defer _ = ll.FreeLibrary(xinput_dll);
    XInputGetKeystroke = @ptrCast(ll.GetProcAddress(xinput_dll, "XInputGetKeystroke") orelse @panic("Failed to load XInputGetKeystroke"));

    const d3dx9_dll = ll.GetModuleHandleA("d3dx9_43.dll") orelse @panic("Failed to load d3dx9_43.dll");
    defer _ = ll.FreeLibrary(d3dx9_dll);
    D3DXCreateSprite = @ptrCast(ll.GetProcAddress(d3dx9_dll, "D3DXCreateSprite") orelse @panic("Failed to load D3DXCreateSprite"));
}
