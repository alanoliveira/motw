const emu = @import("emulator.zig");

pub const MAX_SLOTS = 10;

const State = struct {
    emulator_state: emu.State,
};

var states: [MAX_SLOTS]?State = .{null} ** MAX_SLOTS;

pub fn save(slot: usize) void {
    if (slot >= states.len) return;

    states[slot] = State{
        .emulator_state = emu.State.save(),
    };
}

pub fn load(slot: usize) void {
    if (slot >= states.len) return;

    if (states[slot]) |state| {
        state.emulator_state.load();
    }
}
