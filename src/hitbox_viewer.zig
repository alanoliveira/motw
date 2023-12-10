const std = @import("std");
const emu = @import("emulator.zig");
const game = @import("game.zig");
const view = @import("view.zig");

const HALF_GAME_SCREEN = 160;
const GROUND_OFFSET = 24;
const BOX_SCALE = 4;
const AXIS_SIZE = 10;
const AXIS_COLOR = 0xFF000000;
const BOX_COLORS = [_]struct { fill: u32, outline: u32 }{
    .{ .fill = 0xAA00FF00, .outline = 0xFF00FF00 },
    .{ .fill = 0xAAFF0000, .outline = 0xFFFF0000 },
    .{ .fill = 0xAA0000FF, .outline = 0xFF0000FF },
    .{ .fill = 0xAAFFFFFF, .outline = 0xFFFFFFFF },
};

pub var enabled = true;
var screen_x: i32 = 0;
var screen_y: i32 = 0;

pub fn run() void {
    if (!enabled) return;

    const stage = game.getObject(.{ .Constant = .Stage }).?;
    screen_x = stage.getX();
    screen_y = stage.getY();

    const p1 = game.getObject(.{ .Constant = .P1 }).?;
    const p2 = game.getObject(.{ .Constant = .P2 }).?;
    drawObject(p1);
    drawObject(p2);

    var proj_index: usize = 0;
    while (true) {
        const proj = game.getObject(.{ .Projectile = proj_index }) orelse break;
        if (proj.getInstruction(0) != .RTS) drawObject(proj);
        proj_index += 1;
    }
}

pub fn drawObject(object: game.Object) void {
    drawBoxes(object);
    drawAxis(object);
}

fn drawAxis(object: game.Object) void {
    const x = posXtoScreenX(object.getX());
    const y = posYtoScreenY(object.getY());

    view.drawLine(view.Line.new(x - AXIS_SIZE, y, x + AXIS_SIZE, y, AXIS_COLOR), .{});
    view.drawLine(view.Line.new(x, y - AXIS_SIZE, x, y + AXIS_SIZE, AXIS_COLOR), .{});
}

fn drawBoxes(object: game.Object) void {
    const x = posXtoScreenX(object.getX());
    const y = posYtoScreenY(object.getY());
    const id = object.getId();

    const flip = (object.isFacingRight() or object.isTurning()) and
        !(object.isFacingRight() and object.isTurning());
    const invul = object.isInvulnerable();

    if (object.isPushable()) {
        drawBox(id, object.getPushboxAddress(), x, y, invul, flip);
    }
    drawBox(id, object.getHitboxAddress(), x, y, invul, flip);
}

fn drawBox(id: u16, addr: u32, x: i32, y: i32, invul: bool, flip: bool) void {
    var box_idx: usize = 0;
    while (true) {
        const box = game.Box.new(id, addr, box_idx) orelse break;
        box_idx += 1;

        if (box.kind == .Hurt and invul) continue;

        const flip_num: i32 = if (flip) -1 else 1;
        const left: i32 = box.left;
        const top: i32 = box.top;
        const right: i32 = box.right;
        const bottom: i32 = box.bottom;

        const width = right - left;
        const height = bottom - top;
        const offset_y = box.bottom * BOX_SCALE;
        const offset_x = (left + right) * (BOX_SCALE / 2) * flip_num;
        const col = BOX_COLORS[@intFromEnum(box.kind)];
        view.drawRect(view.Rect.new(x + offset_x, y - offset_y, width * BOX_SCALE, height * BOX_SCALE, true, col.fill), .{});
        view.drawRect(view.Rect.new(x + offset_x, y - offset_y, width * BOX_SCALE, height * BOX_SCALE, false, col.outline), .{});
    }
}

fn posXtoScreenX(pos_x: i16) i32 {
    return (pos_x - screen_x) - HALF_GAME_SCREEN;
}

fn posYtoScreenY(pos_y: i16) i32 {
    return screen_y + view.SCREEN_HEIGHT - GROUND_OFFSET - pos_y;
}
