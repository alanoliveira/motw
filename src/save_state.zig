const emu = @import("emulator.zig");
const view = @import("view.zig");
const settings = @import("settings.zig");
const command_recorder = @import("command_recorder.zig");
const command_history = @import("command_history.zig");

pub const MAX_SLOTS = 10;

const State = struct {
    emulator_state: emu.State,
    command_recorder_state: command_recorder.State,
    command_history_state: command_history.State,
};

var states: [MAX_SLOTS]?State = .{null} ** MAX_SLOTS;

pub fn save() void {
    const slot = settings.save_state_slot;
    if (slot >= states.len) return;

    states[slot] = State{
        .emulator_state = emu.State.save(),
        .command_recorder_state = command_recorder.State.save(),
        .command_history_state = command_history.State.save(),
    };
    view.drawText(view.Text.new("STATE {d} SAVED", .{slot}, 0, 50, 0xFF0000AA), .{ .ttl = 60 });
}

pub fn load() void {
    const slot = settings.save_state_slot;
    if (slot >= states.len) return;

    if (states[slot]) |state| {
        state.emulator_state.load();
        state.command_recorder_state.load();
        state.command_history_state.load();
        view.drawText(view.Text.new("STATE {d} LOADED", .{slot}, 0, 50, 0xFF0000AA), .{ .ttl = 60 });
    }
}
