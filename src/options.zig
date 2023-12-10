const std = @import("std");
const view = @import("view.zig");
const game = @import("game.zig");
const input = @import("input.zig");
const emu = @import("emulator.zig");
const match_cheats = @import("match_cheats.zig");

const SELECTED_COLOR = 0xFFFF0000;
const UNSELECTED_COLOR = 0xFFFFFFFF;

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

const Option = struct {
    const Slowdown = enum { None, Half, Fifth, Tenth };
    const Power = enum { Normal, SPower, PPower };

    const Value = union(enum) {
        Slowdown: Slowdown,
        Power: Power,
        Bool: bool,
        Button: *?input.VirtualKey,

        fn toString(self: Value) []const u8 {
            switch (self) {
                .Slowdown => |v| {
                    return @tagName(v);
                },
                .Bool => |v| {
                    return if (v) "On" else "Off";
                },
                .Power => |v| {
                    return @tagName(v);
                },
                .Button => |v| {
                    return if (v.*) |k| switch (k) {
                        .Keyboard => |kb| @tagName(kb),
                        .Controller => |js| @tagName(js),
                    } else "None";
                },
            }
        }
    };

    label: []const u8,
    value: Value,
    action: *const fn (value: *Value, emu.Command) void,
};

var options = [_]Option{
    .{ .label = "Slowdown", .value = .{ .Slowdown = .None }, .action = &changeSlowdown },
    .{ .label = "P1 Power", .value = .{ .Power = .Normal }, .action = &changeP1Power },
    .{ .label = "P1 Top", .value = .{ .Bool = false }, .action = &changeP1Top },
    .{ .label = "P2 Health Recover", .value = .{ .Bool = true }, .action = &changeP2HealthRecover },
    .{ .label = "P2 Guard Recover", .value = .{ .Bool = true }, .action = &changeP2GuardRecover },
    .{ .label = "Save State Button", .value = .{ .Button = &match_cheats.save_state_button }, .action = &changeSaveStateBtn },
    .{ .label = "Load State Button", .value = .{ .Button = &match_cheats.load_state_button }, .action = &changeLoadStateBtn },
    .{ .label = "Command Record Button", .value = .{ .Button = &match_cheats.command_record_button }, .action = &changeCommandRecordBtn },
    .{ .label = "Command Replay Button", .value = .{ .Button = &match_cheats.command_replay_button }, .action = &changeCommandReplayBtn },
};
var selected_index: usize = 0;
var key_poll: ?KeyPoll = null;

pub fn run() void {
    view.drawRect(view.Rect.new(0, 0, view.SCREEN_WIDTH, view.SCREEN_HEIGHT, true, 0xAA000000), .{});
    view.drawText(view.Text.new("Settings", .{}, 0, 40, 0xFFFFFFFF), .{});

    if (key_poll) |*kp| {
        view.drawRect(view.Rect.new(0, view.SCREEN_HEIGHT / 2, 80, 10, true, 0xAA220055), .{});
        view.drawText(view.Text.new("PRESS SOME KEY", .{}, 0, view.SCREEN_HEIGHT / 2 + 4, 0xFFFFFFFF), .{});
        if (kp.poll()) key_poll = null;
        return;
    }

    if (command_pool.read()) |command| {
        switch (command.direction) {
            .Up => {
                selected_index = (selected_index + options.len - 1) % options.len;
            },
            .Down => {
                selected_index = (selected_index + 1) % options.len;
            },
            else => {
                options[selected_index].action(&options[selected_index].value, command);
            },
        }
    }

    for (options, 0..) |opt, i| {
        const col: u32 = if (i == selected_index) SELECTED_COLOR else UNSELECTED_COLOR;
        const y = 60 + @as(i32, @intCast(i)) * 10;
        view.drawText(view.Text.new("{s}", .{opt.label}, 120, y, col), .{ .anchor = .Left });
        view.drawText(view.Text.new("{s}", .{opt.value.toString()}, 120, y, col), .{ .anchor = .Right });
    }
}

const command_pool = struct {
    var previous_command: emu.Command = .{};

    fn read() ?emu.Command {
        const command = emu.getCommand(.P1);
        defer previous_command = command;
        return if (!std.meta.eql(command, previous_command)) command else null;
    }
};

fn changeSlowdown(val: *Option.Value, command: emu.Command) void {
    const Indexer = std.enums.EnumIndexer(Option.Slowdown);
    const count = Indexer.count;
    var idx = Indexer.indexOf(val.Slowdown);
    switch (command.direction) {
        .Left => {
            idx = (idx + count - 1) % count;
        },
        .Right => {
            idx = (idx + 1) % count;
        },
        else => {},
    }
    val.Slowdown = Indexer.keyForIndex(idx);

    match_cheats.slowdown = switch (val.Slowdown) {
        .None => 1,
        .Half => 2,
        .Fifth => 5,
        .Tenth => 10,
    };
}

fn changeP1Power(val: *Option.Value, command: emu.Command) void {
    const Indexer = std.enums.EnumIndexer(Option.Power);
    const count = Indexer.count;
    var idx = Indexer.indexOf(val.Power);
    switch (command.direction) {
        .Left => {
            idx = (idx + count - 1) % count;
        },
        .Right => {
            idx = (idx + 1) % count;
        },
        else => {},
    }
    val.Power = Indexer.keyForIndex(idx);
    match_cheats.p1_settings.power = switch (val.Power) {
        .Normal => null,
        .SPower => game.Player.S_POWER,
        .PPower => game.Player.P_POWER,
    };
}

fn changeP1Top(val: *Option.Value, command: emu.Command) void {
    if (command.direction != .Left and command.direction != .Right) return;
    val.Bool = !val.Bool;
    match_cheats.p1_settings.top = val.Bool;
}

fn changeP2HealthRecover(val: *Option.Value, command: emu.Command) void {
    if (command.direction != .Left and command.direction != .Right) return;
    val.Bool = !val.Bool;
    if (val.Bool) {
        match_cheats.p2_settings.health = game.Player.MAX_HEALTH;
    } else {
        match_cheats.p2_settings.health = null;
    }
}

fn changeP2GuardRecover(val: *Option.Value, command: emu.Command) void {
    if (command.direction != .Left and command.direction != .Right) return;
    val.Bool = !val.Bool;
    if (val.Bool) {
        match_cheats.p2_settings.guard = 0;
    } else {
        match_cheats.p2_settings.guard = null;
    }
}

fn changeSaveStateBtn(val: *Option.Value, command: emu.Command) void {
    if (!command.a) return;
    key_poll = KeyPoll{ .target = val.Button };
}

fn changeLoadStateBtn(val: *Option.Value, command: emu.Command) void {
    if (!command.a) return;
    key_poll = KeyPoll{ .target = val.Button };
}

fn changeCommandRecordBtn(val: *Option.Value, command: emu.Command) void {
    if (!command.a) return;
    key_poll = KeyPoll{ .target = val.Button };
}

fn changeCommandReplayBtn(val: *Option.Value, command: emu.Command) void {
    if (!command.a) return;
    key_poll = KeyPoll{ .target = val.Button };
}
