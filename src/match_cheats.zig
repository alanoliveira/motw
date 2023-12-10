const std = @import("std");
const emu = @import("emulator.zig");
const game = @import("game.zig");
const input = @import("input.zig");
const save_state = @import("save_state.zig");
const command_recorder = @import("command_recorder.zig");

pub const PlayerSettings = struct {
    health: ?u8 = game.Player.MAX_HEALTH,
    power: ?u8 = game.Player.P_POWER,
    guard: ?u8 = null,
    top: ?bool = null,

    fn apply(self: PlayerSettings, player: *game.Player) void {
        if (self.health) |val| player.setHealth(val);
        if (self.power) |val| player.setPower(val);
        if (self.guard) |val| player.setGuard(val);
        if (self.top) |val| player.setTop(val);
    }
};

pub var p1_settings: PlayerSettings = .{};
pub var p2_settings: PlayerSettings = .{};
pub var save_state_button: ?input.VirtualKey = null;
pub var load_state_button: ?input.VirtualKey = null;
pub var command_record_button: ?input.VirtualKey = null;
pub var command_replay_button: ?input.VirtualKey = null;
pub var slowdown: u32 = 1;

pub fn run() void {
    var p1 = game.p1;
    var p2 = game.p2;
    var match = game.match;

    match.setTimer(game.Match.MAX_TIME);

    if (p1.getStatus().isNeutral() and p2.getStatus().isNeutral()) {
        p1_settings.apply(&p1);
        p2_settings.apply(&p2);
    }

    checkInputs();
}

pub fn gameTick() bool {
    const frame = emu.getFrameCount();
    return slowdown > 0 and frame % slowdown == 0;
}

fn checkInputs() void {
    if (save_state_button) |btn| if (input.isPressed(btn)) {
        save_state.save();
    };

    if (load_state_button) |btn| if (input.isPressed(btn)) {
        save_state.load();
    };

    if (command_record_button) |btn| if (input.isPressed(btn)) {
        command_recorder.record();
    };

    if (command_replay_button) |btn| if (input.isPressed(btn)) {
        command_recorder.replay();
    };
}
