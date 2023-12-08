const std = @import("std");
const Renderer = @import("renderer.zig");

pub const SCREEN_WIDTH = 398;
pub const SCREEN_HEIGHT = 224;
const GLYPH_WIDTH = 4;

const DrawableList = std.ArrayList(Drawable);
var buffer: [4096]u8 = undefined;
var fba = std.heap.FixedBufferAllocator.init(&buffer);
var allocator = fba.allocator();
var drawables: DrawableList = undefined;

const Drawable = union(enum) {
    Text: *Text,
    Line: *Line,
    Rect: *Rect,
};

pub const Anchor = enum {
    Left,
    Right,
    Center,

    fn calcX(self: Anchor, x: i32, width: i32) i32 {
        return switch (self) {
            .Right => (SCREEN_WIDTH) - x - width - 1,
            .Center => (SCREEN_WIDTH / 2) - @divTrunc(width, 2) - 1,
            else => x,
        };
    }
};

pub const Text = struct {
    text: []const u8,
    x: i32,
    y: i32,
    color: u32,

    pub fn new(text: []const u8, x: i32, y: i32, color: u32) Text {
        return Text{
            .text = text,
            .x = x,
            .y = y,
            .color = color,
        };
    }

    pub fn newFmt(comptime fmt: []const u8, args: anytype, x: i32, y: i32, color: u32) Text {
        var txt_buffer: [1024]u8 = .{0} ** 1024;
        const text = std.fmt.bufPrint(@ptrCast(&txt_buffer), fmt, args) catch fmt_err: {
            std.debug.print("Failed to format string\n", .{});
            break :fmt_err "";
        };
        return Text.new(text, x, y, color);
    }
};

pub const Line = struct {
    x1: i32,
    y1: i32,
    x2: i32,
    y2: i32,
    color: u32,

    pub fn new(x1: i32, y1: i32, x2: i32, y2: i32, color: u32) Line {
        return Line{
            .x1 = x1,
            .y1 = y1,
            .x2 = x2,
            .y2 = y2,
            .color = color,
        };
    }
};

pub const Rect = struct {
    x1: i32,
    y1: i32,
    x2: i32,
    y2: i32,
    fill: bool,
    color: u32,

    pub fn new(x1: i32, y1: i32, x2: i32, y2: i32, fill: bool, color: u32) Rect {
        return Rect{
            .x1 = x1,
            .y1 = y1,
            .x2 = x2,
            .y2 = y2,
            .fill = fill,
            .color = color,
        };
    }

    pub fn newWH(x: i32, y: i32, w: i32, h: i32, fill: bool, color: u32) Rect {
        return Rect{
            .x1 = x,
            .y1 = y,
            .x2 = x + w,
            .y2 = y + h,
            .fill = fill,
            .color = color,
        };
    }
};

pub fn clean() void {
    fba.reset();
    drawables = DrawableList.init(allocator);
}

pub fn render(renderer: *Renderer) void {
    for (drawables.items) |drawable| {
        switch (drawable) {
            .Text => |d| renderer.drawText(d.text, d.x, d.y, d.color),
            .Line => |d| renderer.drawLine(d.x1, d.y1, d.x2, d.y2, d.color),
            .Rect => |d| if (d.fill) {
                renderer.drawRectFill(d.x1, d.y1, d.x2, d.y2, d.color);
            } else {
                renderer.drawRectOutline(d.x1, d.y1, d.x2, d.y2, d.color);
            },
        }
    }
}

pub fn drawText(text: Text, anchor: Anchor) void {
    var text_mem: *Text = allocator.create(Text) catch return;
    text_mem.* = text;
    text_mem.text = allocator.dupe(u8, text.text) catch return;
    text_mem.x = anchor.calcX(text_mem.x, @as(i32, @intCast(text_mem.text.len)) * GLYPH_WIDTH);
    drawables.append(Drawable{ .Text = text_mem }) catch return;
}

pub fn drawLine(line: Line, anchor: Anchor) void {
    var line_mem: *Line = allocator.dupe(Line, line) catch return;
    line_mem.x1 = anchor.calcX(line_mem.x1, 0);
    line_mem.x2 = anchor.calcX(line_mem.x2, 0);

    drawables.append(Drawable{
        .Line = line_mem,
    }) catch return;
}

pub fn drawRect(rect: Rect, anchor: Anchor) void {
    var rect_mem: *Rect = allocator.create(Rect) catch return;
    rect_mem.* = rect;
    rect_mem.x1 = anchor.calcX(rect_mem.x1, 0);
    rect_mem.x2 = anchor.calcX(rect_mem.x2, 0);

    drawables.append(Drawable{
        .Rect = rect_mem,
    }) catch return;
}
