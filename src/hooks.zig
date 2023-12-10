const std = @import("std");
const win = @import("win32.zig");
const emu = @import("emulator.zig");
const game = @import("game.zig");
const view = @import("view.zig");
const input = @import("input.zig");
const match_cheats = @import("match_cheats.zig");
const command_recorder = @import("command_recorder.zig");
const command_history = @import("command_history.zig");
const hitbox_viewer = @import("hitbox_viewer.zig");
const options = @import("options.zig");
const hud_info = @import("hud_info.zig");
const Renderer = @import("renderer.zig");

pub var originalRunOpcode: emu.RunOpcodeT = undefined;
pub var originalRunFrame: emu.RunFrameT = undefined;
pub var originalGameTick: emu.GameTickT = undefined;
pub var originalWriteInput: emu.WriteInputT = undefined;
pub var originalEndScene: std.meta.FieldType(win.IDirect3DDevice9.VTable, .EndScene) = undefined;
var renderer: Renderer = undefined;

pub fn runOpcode() callconv(.C) void {
    if (!emu.isEmulationRunning()) return originalRunOpcode();

    game.changeBehaviour(.{ .skip_round_count = true });
    return originalRunOpcode();
}

pub fn runFrame() callconv(.C) u32 {
    if (emu.isOnlineMode()) @import("root").shutdown();
    if (!emu.isEmulationRunning()) return originalRunFrame();

    input.poll();
    view.update();
    if (game.isPaused()) {
        options.run();
    } else {
        match_cheats.run();
        hud_info.run();
        command_history.draw();
        hitbox_viewer.run();
    }
    return originalRunFrame();
}

pub fn gameTick() callconv(.C) void {
    if (!emu.isEmulationRunning() or game.isPaused()) originalGameTick();

    if (match_cheats.gameTick()) originalGameTick();
}

pub fn writeInput(ipt: u32) callconv(.C) void {
    if (!emu.isEmulationRunning()) return;

    originalWriteInput(ipt);
    command_recorder.process();
    command_history.update();
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
