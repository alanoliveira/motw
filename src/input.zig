const std = @import("std");
const win = @import("win32.zig");

pub const VirtualKey = union(enum) {
    Controller: win.XINPUT_VIRTUAL_KEY,
    Keyboard: win.VIRTUAL_KEY,
};

var keyboard_state: [256]bool = .{false} ** 256;
var joystick_state: win.XINPUT_KEYSTROKE = std.mem.zeroes(win.XINPUT_KEYSTROKE);

pub fn poll() void {
    inline for (@typeInfo(win.VIRTUAL_KEY).Enum.fields) |field| {
        const stt: u16 = @bitCast(win.GetAsyncKeyState(field.value));
        keyboard_state[field.value] = (stt & 0x8001 == 0x8001);
    }
    _ = win.XInputGetKeystroke(0, 0, &joystick_state);
}

pub fn isPressed(virtual_key: VirtualKey) bool {
    switch (virtual_key) {
        .Controller => |k| return joystick_state.Flags & win.XINPUT_KEYSTROKE_KEYDOWN != 0 and joystick_state.VirtualKey == k,
        .Keyboard => |k| return keyboard_state[@intFromEnum(k)],
    }
    return false;
}

pub fn getPressed() ?VirtualKey {
    if (joystick_state.Flags & win.XINPUT_KEYSTROKE_KEYDOWN != 0 and @intFromEnum(joystick_state.VirtualKey) != 0) {
        return .{ .Controller = joystick_state.VirtualKey };
    }

    for (0..256) |i| if (keyboard_state[i]) {
        return .{ .Keyboard = @enumFromInt(i) };
    };

    return null;
}
