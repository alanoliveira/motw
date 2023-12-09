const input = @import("input.zig");

pub var slowdown_divider: u32 = 1;
pub var save_state_slot: u32 = 0;
pub var command_record_slot: u32 = 0;
pub var display_hud_info: bool = true;
pub var display_p1_inputs: bool = true;
pub var display_p2_inputs: bool = true;
pub var display_hitboxes: bool = true;

pub var save_state_button: ?input.VirtualKey = null;
pub var load_state_button: ?input.VirtualKey = null;
pub var command_record_button: ?input.VirtualKey = null;
pub var command_playback_button: ?input.VirtualKey = null;

pub const PlayerSettings = struct {
    health: ?u8 = null,
    power: ?u8 = null,
    guard: ?u8 = null,
    top: ?bool = null,
};
pub var p1_settings: PlayerSettings = .{};
pub var p2_settings: PlayerSettings = .{};
