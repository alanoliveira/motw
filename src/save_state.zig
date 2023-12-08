const emu = @import("emulator.zig");
const view = @import("view.zig");
const command_recorder = @import("command_recorder.zig");

pub const MAX_SLOTS = 10;

const State = struct {
    emulator_state: emu.State,
    command_recorder_state: command_recorder.State,
};

var states: [MAX_SLOTS]?State = .{null} ** MAX_SLOTS;

pub fn save(slot: usize) void {
    if (slot >= states.len) return;

    states[slot] = State{
        .emulator_state = emu.State.save(),
        .command_recorder_state = command_recorder.State.save(),
    };
    view.drawText(view.Text.newFmt("STATE {d} SAVED", .{slot}, 0, 50, 0xFF0000AA), .{ .ttl = 60 });
}

pub fn load(slot: usize) void {
    if (slot >= states.len) return;

    if (states[slot]) |state| {
        state.emulator_state.load();
        state.command_recorder_state.load();
        view.drawText(view.Text.newFmt("STATE {d} LOADED", .{slot}, 0, 50, 0xFF0000AA), .{ .ttl = 60 });
    }
}
