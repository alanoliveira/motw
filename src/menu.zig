const std = @import("std");
const emu = @import("emulator.zig");
const game = @import("game.zig");
const view = @import("view.zig");
const input = @import("input.zig");
const settings = @import("settings.zig");

const Option = struct {
    name: []const u8,
    change: *const fn (command: emu.Command) void,
    getValueLabel: *const fn () []const u8,
};

const SELECTED_COLOR = 0xFFFF0000;
const UNSELECTED_COLOR = 0xFFFFFFFF;
const OPTIONS = [_]Option{
    .{ .name = Slowdown.LABEL, .change = Slowdown.change, .getValueLabel = Slowdown.getValueLabel },
    .{ .name = SaveStateSlot.LABEL, .change = SaveStateSlot.change, .getValueLabel = SaveStateSlot.getValueLabel },
    .{ .name = CommandRecordSlot.LABEL, .change = CommandRecordSlot.change, .getValueLabel = CommandRecordSlot.getValueLabel },
    .{ .name = DisplayHudInfo.LABEL, .change = DisplayHudInfo.change, .getValueLabel = DisplayHudInfo.getValueLabel },
    .{ .name = DisplayP1Inputs.LABEL, .change = DisplayP1Inputs.change, .getValueLabel = DisplayP1Inputs.getValueLabel },
    .{ .name = DisplayP2Inputs.LABEL, .change = DisplayP2Inputs.change, .getValueLabel = DisplayP2Inputs.getValueLabel },
    .{ .name = SaveStateButton.LABEL, .change = SaveStateButton.change, .getValueLabel = SaveStateButton.getValueLabel },
    .{ .name = LoadStateButton.LABEL, .change = LoadStateButton.change, .getValueLabel = LoadStateButton.getValueLabel },
    .{ .name = CommandRecordButton.LABEL, .change = CommandRecordButton.change, .getValueLabel = CommandRecordButton.getValueLabel },
    .{ .name = CommandPlaybackButton.LABEL, .change = CommandPlaybackButton.change, .getValueLabel = CommandPlaybackButton.getValueLabel },
};

const KeyPoll = struct {
    target: *?input.VirtualKey,

    fn poll(self: *KeyPoll) bool {
        const pressed = input.getPressed();
        if (pressed) |key| {
            self.target.* = if (std.meta.eql(pressed, self.target.*)) null else key;
            return true;
        }
        return false;
    }
};

var selected_index: usize = 0;
var key_poll: ?KeyPoll = null;
var str_buf: [10]u8 = undefined;

pub fn run() void {
    view.drawRect(view.Rect.new(0, 0, view.SCREEN_WIDTH, view.SCREEN_HEIGHT, true, 0xAA000000), .{});
    view.drawText(view.Text.new("Settings", .{}, 0, 10, 0xFFFFFFFF), .{});

    if (key_poll) |*kp| {
        view.drawRect(view.Rect.new(0, view.SCREEN_HEIGHT / 2, 80, 10, true, 0xAA220055), .{});
        view.drawText(view.Text.new("PRESS SOME KEY", .{}, 0, view.SCREEN_HEIGHT / 2 + 4, 0xFFFFFFFF), .{});
        if (kp.poll()) key_poll = null;
        return;
    }

    if (CommandPoll.read()) |cmd| {
        switch (cmd.direction) {
            .Up => {
                if (selected_index > 0) {
                    selected_index -= 1;
                }
            },
            .Down => {
                if (selected_index < OPTIONS.len - 1) {
                    selected_index += 1;
                }
            },
            else => {
                OPTIONS[selected_index].change(cmd);
            },
        }
    }

    for (OPTIONS, 0..) |option, index| {
        const color: u32 = if (index == selected_index) SELECTED_COLOR else UNSELECTED_COLOR;
        const y: i32 = 30 + @as(i32, @intCast(index * 10));
        view.drawText(view.Text.new("{s}", .{option.name}, 120, y, color), .{ .anchor = .Left });
        view.drawText(view.Text.new("{s}", .{option.getValueLabel()}, 120, y, color), .{ .anchor = .Right });
    }
}

const CommandPoll = struct {
    var previous_command: emu.Command = .{};

    fn read() ?emu.Command {
        const command = emu.getCommand(.P1);
        defer previous_command = command;
        return if (!std.meta.eql(command, previous_command)) command else null;
    }
};

const Slowdown = struct {
    const LABEL = "Slowdown";

    fn change(command: emu.Command) void {
        if (command.direction == .Left) {
            settings.slowdown_divider -= 1;
        } else if (command.direction == .Right) {
            settings.slowdown_divider += 1;
        }
    }

    fn getValueLabel() []const u8 {
        return switch (settings.slowdown_divider) {
            1 => "Off",
            2 => "1/2",
            else => "Unknown",
        };
    }
};

const SaveStateSlot = struct {
    const LABEL = "Save State";

    fn change(command: emu.Command) void {
        if (command.direction == .Left) {
            settings.save_state_slot -= 1;
        } else if (command.direction == .Right) {
            settings.save_state_slot += 1;
        }
    }

    fn getValueLabel() []const u8 {
        return std.fmt.bufPrint(&str_buf, "Slot {d}", .{settings.save_state_slot}) catch "Error";
    }
};

const CommandRecordSlot = struct {
    const LABEL = "Command Record";

    fn change(command: emu.Command) void {
        if (command.direction == .Left) {
            settings.command_record_slot -= 1;
        } else if (command.direction == .Right) {
            settings.command_record_slot += 1;
        }
    }

    fn getValueLabel() []const u8 {
        return std.fmt.bufPrint(&str_buf, "Slot {d}", .{settings.command_record_slot}) catch "Error";
    }
};

const DisplayHudInfo = struct {
    const LABEL = "Display HUD Info";

    fn change(command: emu.Command) void {
        if (command.direction == .Left or command.direction == .Right) {
            settings.display_hud_info = !settings.display_hud_info;
        }
    }

    fn getValueLabel() []const u8 {
        return if (settings.display_hud_info) "On" else "Off";
    }
};

const DisplayP1Inputs = struct {
    const LABEL = "Display P1 Inputs";

    fn change(command: emu.Command) void {
        if (command.direction == .Left or command.direction == .Right) {
            settings.display_p1_inputs = !settings.display_p1_inputs;
        }
    }

    fn getValueLabel() []const u8 {
        return if (settings.display_p1_inputs) "On" else "Off";
    }
};

const DisplayP2Inputs = struct {
    const LABEL = "Display P2 Inputs";

    fn change(command: emu.Command) void {
        if (command.direction == .Left or command.direction == .Right) {
            settings.display_p2_inputs = !settings.display_p2_inputs;
        }
    }

    fn getValueLabel() []const u8 {
        return if (settings.display_p2_inputs) "On" else "Off";
    }
};

const SaveStateButton = struct {
    const LABEL = "Save State Button";

    fn change(command: emu.Command) void {
        if (command.c) key_poll = KeyPoll{ .target = &settings.save_state_button };
    }

    fn getValueLabel() []const u8 {
        return if (settings.save_state_button) |vk| vkToString(vk) else "None";
    }
};

const LoadStateButton = struct {
    const LABEL = "Load State Button";

    fn change(command: emu.Command) void {
        if (command.c) key_poll = KeyPoll{ .target = &settings.load_state_button };
    }

    fn getValueLabel() []const u8 {
        return if (settings.load_state_button) |vk| vkToString(vk) else "None";
    }
};

const CommandRecordButton = struct {
    const LABEL = "Command Record Button";

    fn change(command: emu.Command) void {
        if (command.c) key_poll = KeyPoll{ .target = &settings.command_record_button };
    }

    fn getValueLabel() []const u8 {
        return if (settings.command_record_button) |vk| vkToString(vk) else "None";
    }
};

const CommandPlaybackButton = struct {
    const LABEL = "Command Playback Button";

    fn change(command: emu.Command) void {
        if (command.c) key_poll = KeyPoll{ .target = &settings.command_playback_button };
    }

    fn getValueLabel() []const u8 {
        return if (settings.command_playback_button) |vk| vkToString(vk) else "None";
    }
};

fn vkToString(vk: input.VirtualKey) []const u8 {
    var kind: []const u8 = undefined;
    var key: []const u8 = undefined;
    switch (vk) {
        .Keyboard => |kb| {
            kind = "Keyboard";
            key = @tagName(kb);
        },
        .Controller => |js| {
            kind = "Joystick";
            key = @tagName(js);
        },
    }

    return std.fmt.bufPrint(&str_buf, "{s}-{s}", .{ kind, key }) catch "Error";
}
