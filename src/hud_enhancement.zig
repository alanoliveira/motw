const Self = @This();
const std = @import("std");
const game = @import("game.zig");
const util = @import("util.zig");
const Renderer = @import("renderer.zig");

pub fn render(renderer: *Renderer) void {
    Self.new(&game.p1, .P1, renderer).draw();
    Self.new(&game.p2, .P2, renderer).draw();
}

player: *const game.Player,
side: util.Side,
renderer: *Renderer,

fn new(player: *const game.Player, side: util.Side, renderer: *Renderer) Self {
    return .{
        .player = player,
        .side = side,
        .renderer = renderer,
    };
}

fn draw(self: *const Self) void {
    self.drawHealth();
    self.drawPower();
    self.drawGuard();
}

fn drawHealth(self: *const Self) void {
    self.drawTextFmt("{d:0>3}", .{self.player.getHealth()}, 160, 18);
}

fn drawPower(self: *const Self) void {
    self.drawTextFmt("{d:0>3}", .{self.player.getPower()}, 88, 210);
}

fn drawGuard(self: *const Self) void {
    self.drawGuardGauge();
}

const GUARD_GAUGE_WIDTH = 65;
fn drawGuardGauge(self: *const Self) void {
    const guard = self.player.getGuard();
    const guard_percent: f32 = @as(f32, @floatFromInt(guard)) / game.Player.MAX_GUARD;
    const cur_gauge_width: i32 = @intFromFloat(65.0 * guard_percent);

    switch (self.side) {
        .P1 => self.drawRect(62, 216, GUARD_GAUGE_WIDTH, 5, 0xFFFFFFFF, false),
        .P2 => self.drawRect(Renderer.SCREEN_WIDTH - 63, 216, -GUARD_GAUGE_WIDTH, 5, 0xFFFFFFFF, false),
    }

    switch (self.side) {
        .P1 => self.drawRect(62, 216, cur_gauge_width, 5, 0xFFBBBBFF, true),
        .P2 => self.drawRect(Renderer.SCREEN_WIDTH - 63, 216, -cur_gauge_width, 5, 0xFFBBBBFF, true),
    }

    self.drawTextFmt("{d:0>2}", .{guard}, 88, 217);
}

fn drawRect(self: *const Self, x: i32, y: i32, w: i32, h: i32, color: u32, fill: bool) void {
    if (fill)
        self.renderer.drawRectFill(x, y, x + w, y + h, color)
    else
        self.renderer.drawRectOutline(x, y, x + w, y + h, color);
}

fn drawTextFmt(self: *const Self, comptime fmt: []const u8, args: anytype, x: i32, y: i32) void {
    var buffer: [32]u8 = .{0} ** 32;
    const text = std.fmt.bufPrint(@ptrCast(&buffer), fmt, args) catch return;

    const side_x = switch (self.side) {
        .P1 => x,
        .P2 => Renderer.SCREEN_WIDTH - x - (@as(i32, @intCast(text.len)) * @as(i32, @intFromFloat(Renderer.GLYPH_SIZE))),
    };

    self.renderer.drawText(text, side_x, y, 0xFF0000AA);
}
