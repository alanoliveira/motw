const Self = @This();
const std = @import("std");
const game = @import("game.zig");
const util = @import("util.zig");
const view = @import("view.zig");
const settings = @import("settings.zig");

pub fn run() void {
    if (!settings.display_hud_info) return;
    Self.new(&game.p1, .P1).draw();
    Self.new(&game.p2, .P2).draw();
}

player: *const game.Player,
side: util.Side,

fn new(player: *const game.Player, side: util.Side) Self {
    return .{
        .player = player,
        .side = side,
    };
}

fn draw(self: *const Self) void {
    self.drawHealth();
    self.drawPower();
    self.drawGuard();
}

fn drawHealth(self: *const Self) void {
    view.drawText(
        view.Text.new("{d:0>3}", .{self.player.getHealth()}, 160, 18, 0xFF0000AA),
        .{ .anchor = self.getAnchor() },
    );
}

fn drawPower(self: *const Self) void {
    view.drawText(
        view.Text.new("{d:0>3}", .{self.player.getPower()}, 88, 210, 0xFF0000AA),
        .{ .anchor = self.getAnchor() },
    );
}

fn drawGuard(self: *const Self) void {
    self.drawGuardGauge();
}

const GUARD_GAUGE_WIDTH = 65;
fn drawGuardGauge(self: *const Self) void {
    const guard = self.player.getGuard();
    const guard_percent: f32 = @as(f32, @floatFromInt(guard)) / game.Player.MAX_GUARD;
    const cur_gauge_width: i32 = @intFromFloat(65.0 * guard_percent);

    const options = .{ .anchor = self.getAnchor() };
    view.drawRect(view.Rect.new(62, 216, GUARD_GAUGE_WIDTH, 5, false, 0xFFFFFFFF), options);
    view.drawRect(view.Rect.new(62, 216, cur_gauge_width, 5, true, 0xFFBBBBFF), options);
    view.drawText(view.Text.new("{d:0>2}", .{guard}, 88, 217, 0xFF0000AA), options);
}

fn getAnchor(self: *const Self) view.DrawOptions.Anchor {
    return switch (self.side) {
        .P1 => .Left,
        .P2 => .Right,
    };
}
