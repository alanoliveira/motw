const std = @import("std");
const emu = @import("emulator.zig");
const util = @import("util.zig");
const view = @import("view.zig");
const BUTTON_DISPLAY = std.ComptimeStringMap(struct { color: u32, label: []const u8 }, .{
    .{ "a", .{ .color = 0xFFFF0000, .label = "A" } },
    .{ "b", .{ .color = 0xFFFFFF00, .label = "B" } },
    .{ "c", .{ .color = 0xFF00FF00, .label = "C" } },
    .{ "d", .{ .color = 0xFF7777FF, .label = "D" } },
});

pub var display_p1_inputs: bool = true;
pub var display_p2_inputs: bool = true;
var p1_history: PlayerHistory = .{};
var p2_history: PlayerHistory = .{};

pub fn update() void {
    p1_history.insert(emu.getCommand(.P1));
    p2_history.insert(emu.getCommand(.P2));
}

pub fn draw() void {
    if (display_p1_inputs) {
        drawPlayerHistory(p1_history, .Left);
    }

    if (display_p2_inputs) {
        drawPlayerHistory(p2_history, .Right);
    }
}

fn drawPlayerHistory(history: PlayerHistory, anchor: view.DrawOptions.Anchor) void {
    var entries = history.iter();
    const opts = .{ .anchor = anchor };

    view.drawRect(view.Rect.new(0, 0, 39, view.SCREEN_HEIGHT, true, 0xCC000000), opts);

    var entry = entries.next();
    var y: i32 = 30;
    while (entry) |e| : (entry = entries.next()) {
        view.drawSymbol(view.Symbol.new(directionToSymbol(e.command.direction), 2, y, 0xFFFFFFFF), opts);

        if (anchor == .Left) {
            drawButtons(.{ "a", "b", "c", "d" }, e.command, y, opts);
        } else {
            drawButtons(.{ "d", "c", "b", "a" }, e.command, y, opts);
        }

        view.drawText(view.Text.new("{d}", .{@min(e.frames, 999)}, 26, y, 0xFFFFFFFF), opts);
        y += 10;
        if (y >= view.SCREEN_HEIGHT) break;
    }
}

fn drawButtons(comptime order: [4][]const u8, command: emu.Command, y: i32, opts: view.DrawOptions) void {
    var x: i32 = 8;
    inline for (order) |button| {
        if (@field(command, button)) {
            const display = BUTTON_DISPLAY.get(button).?;
            view.drawText(view.Text.new("{s}", .{display.label}, x, y, display.color), opts);
            x += view.GLYPH_WIDTH;
        }
    }
}

fn directionToSymbol(direction: emu.Command.Direction) view.Symbol.Kind {
    return switch (direction) {
        emu.Command.Direction.Neutral => view.Symbol.Kind.Neutral,
        emu.Command.Direction.Up => view.Symbol.Kind.Up,
        emu.Command.Direction.Down => view.Symbol.Kind.Down,
        emu.Command.Direction.Left => view.Symbol.Kind.Left,
        emu.Command.Direction.Right => view.Symbol.Kind.Right,
        emu.Command.Direction.UpLeft => view.Symbol.Kind.UpLeft,
        emu.Command.Direction.UpRight => view.Symbol.Kind.UpRight,
        emu.Command.Direction.DownLeft => view.Symbol.Kind.DownLeft,
        emu.Command.Direction.DownRight => view.Symbol.Kind.DownRight,
    };
}

const PlayerHistory = struct {
    const Queue = util.CircularQueue(Entry, 50);

    const Entry = struct {
        command: emu.Command,
        frames: usize,
    };

    queue: Queue = Queue.new(),
    current: Entry = .{ .command = emu.Command{}, .frames = 0 },

    fn insert(self: *PlayerHistory, command: emu.Command) void {
        if (std.meta.eql(self.current.command, command)) {
            self.current.frames += 1;
        } else {
            self.queue.enqueue(self.current);
            self.current = .{ .command = command, .frames = 1 };
        }
    }

    fn iter(self: *const PlayerHistory) EntryIterator {
        return .{ .history = self };
    }

    const EntryIterator = struct {
        history: *const PlayerHistory,
        index: usize = 0,

        pub fn next(self: *EntryIterator) ?Entry {
            defer self.index += 1;
            if (self.index == 0) return self.history.current;
            return self.history.queue.getFromEnd(self.index - 1);
        }
    };
};

pub const State = struct {
    p1_history: PlayerHistory,
    p2_history: PlayerHistory,

    pub fn save() State {
        return .{
            .p1_history = p1_history,
            .p2_history = p2_history,
        };
    }

    pub fn load(self: *const State) void {
        p1_history = self.p1_history;
        p2_history = self.p2_history;
    }
};
