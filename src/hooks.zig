const std = @import("std");
const win = @import("win32.zig");
const emu = @import("emulator.zig");
const input = @import("input.zig");
const settings = @import("settings.zig");
const save_state = @import("save_state.zig");
const command_recorder = @import("command_recorder.zig");

pub var originalRunOpcode: emu.RunOpcodeT = undefined;
pub var originalRunFrame: emu.RunFrameT = undefined;
pub var originalGameTick: emu.GameTickT = undefined;
pub var originalWriteInput: emu.WriteInputT = undefined;

pub fn runOpcode() callconv(.C) void {
    return originalRunOpcode();
}

pub fn runFrame() callconv(.C) u32 {
    checkInputs();
    return originalRunFrame();
}

pub fn gameTick() callconv(.C) void {
    const frame = emu.getFrameCount();
    if (frame % settings.slowdown_divider == 0)
        originalGameTick();
}

pub fn writeInput(ipt: u32) callconv(.C) void {
    originalWriteInput(ipt);
    command_recorder.process();
}

fn checkInputs() void {
    input.poll();

    if (input.isPressed(.{ .Keyboard = .F7 })) {
        defer @import("root").shutdown();
    }
    if (input.isPressed(.{ .Keyboard = .F3 })) {
        save_state.save(settings.save_state_slot);
    }
    if (input.isPressed(.{ .Keyboard = .F4 })) {
        save_state.load(settings.save_state_slot);
    }
    if (input.isPressed(.{ .Keyboard = .F9 })) {
        command_recorder.record();
    }
    if (input.isPressed(.{ .Keyboard = .F10 })) {
        command_recorder.playback();
    }
}
