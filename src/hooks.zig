const std = @import("std");
const win = @import("win32.zig");
const emu = @import("emulator.zig");
const game = @import("game.zig");
const view = @import("view.zig");
const input = @import("input.zig");
const settings = @import("settings.zig");
const save_state = @import("save_state.zig");
const command_recorder = @import("command_recorder.zig");
const command_history = @import("command_history.zig");
const menu = @import("menu.zig");
const hud_info = @import("hud_info.zig");
const Renderer = @import("renderer.zig");

pub var originalRunOpcode: emu.RunOpcodeT = undefined;
pub var originalRunFrame: emu.RunFrameT = undefined;
pub var originalGameTick: emu.GameTickT = undefined;
pub var originalWriteInput: emu.WriteInputT = undefined;
pub var originalEndScene: std.meta.FieldType(win.IDirect3DDevice9.VTable, .EndScene) = undefined;
var renderer: Renderer = undefined;

pub fn runOpcode() callconv(.C) void {
    return originalRunOpcode();
}

pub fn runFrame() callconv(.C) u32 {
    if (emu.isOnlineMode()) @import("root").shutdown();
    if (!emu.isEmulationRunning()) return originalRunFrame();

    input.poll();
    view.update();
    if (game.isPaused()) {
        menu.run();
    } else {
        checkInputs();
        hud_info.run();
        command_history.run();
    }
    return originalRunFrame();
}

pub fn gameTick() callconv(.C) void {
    if (!emu.isEmulationRunning()) return;

    const frame = emu.getFrameCount();
    if (game.isPaused() or
        (settings.slowdown_divider > 0 and frame % settings.slowdown_divider == 0))
        originalGameTick();
}

pub fn writeInput(ipt: u32) callconv(.C) void {
    if (!emu.isEmulationRunning()) return;

    originalWriteInput(ipt);
    command_recorder.process();
}

// remind: directx EndScene is called a few times per frame
pub fn endScene(device: *win.IDirect3DDevice9) callconv(win.WINAPI) win.HRESULT {
    if (!emu.isEmulationRunning() or game.match.getStatus() != .Active) {
        return originalEndScene(device);
    }

    renderer.initialize(device) catch return originalEndScene(device);

    view.render(&renderer);

    renderer.deinitialize() catch {};
    return originalEndScene(device);
}

fn checkInputs() void {
    if (input.isPressed(.{ .Keyboard = .F7 })) {
        defer @import("root").shutdown();
    }
    if (settings.save_state_button) |btn| if (input.isPressed(btn)) {
        save_state.save();
    };
    if (settings.load_state_button) |btn| if (input.isPressed(btn)) {
        save_state.load();
    };
    if (settings.command_record_button) |btn| if (input.isPressed(btn)) {
        command_recorder.record();
    };
    if (settings.command_playback_button) |btn| if (input.isPressed(btn)) {
        command_recorder.playback();
    };
}
