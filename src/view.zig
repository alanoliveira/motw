const std = @import("std");
const Renderer = @import("renderer.zig");

pub const SCREEN_WIDTH = 398;
pub const SCREEN_HEIGHT = 224;
const GLYPH_WIDTH = 4;

const allocator = std.heap.c_allocator;
var drawables = DrawableBuffer{};

const DrawableBuffer = struct {
    const DrawableList = std.DoublyLinkedList(Drawable);

    buffer: [50]?DrawableList.Node = .{null} ** 50,
    list: DrawableList = .{},

    fn insert(self: *DrawableBuffer, drawable: Drawable) bool {
        for (0..self.buffer.len) |i| {
            if (self.buffer[i] != null) continue;
            self.buffer[i] = DrawableList.Node{ .data = drawable };
            self.list.append(&self.buffer[i].?);
            return true;
        }
        return false;
    }

    fn update(self: *DrawableBuffer) void {
        for (0..self.buffer.len) |i| {
            var node = &(self.buffer[i] orelse continue);
            if (node.data.ttl > 0) {
                node.data.ttl -= 1;
            } else {
                self.list.remove(node);
                switch (node.data.component) {
                    .Text => |t| allocator.free(t.text),
                    else => {},
                }
                self.buffer[i] = null;
            }
        }
    }
};

const Drawable = struct {
    const Component = union(enum) {
        Text: Text,
        Line: Line,
        Rect: Rect,
    };
    component: Component,
    ttl: usize = 0,
};

pub const Text = struct {
    text: []const u8,
    x: i32,
    y: i32,
    color: u32,

    pub fn new(comptime fmt: []const u8, args: anytype, x: i32, y: i32, color: u32) Text {
        const fmt_text = std.fmt.allocPrint(allocator, fmt, args) catch fmt_err: {
            std.debug.print("Failed to format string\n", .{});
            break :fmt_err "";
        };
        return Text{
            .text = fmt_text,
            .x = x,
            .y = y,
            .color = color,
        };
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
    x: i32,
    y: i32,
    w: i32,
    h: i32,
    fill: bool,
    color: u32,

    pub fn new(x: i32, y: i32, w: i32, h: i32, fill: bool, color: u32) Rect {
        return Rect{
            .x = x,
            .y = y,
            .w = w,
            .h = h,
            .fill = fill,
            .color = color,
        };
    }
};

pub fn render(renderer: *Renderer) void {
    var node = drawables.list.first;
    while (node) |drawable| : (node = drawable.next) {
        switch (drawable.data.component) {
            .Text => |d| renderer.drawText(d.text, d.x, d.y, d.color),
            .Line => |d| renderer.drawLine(d.x1, d.y1, d.x2, d.y2, d.color),
            .Rect => |d| if (d.fill) {
                renderer.drawRectFill(d.x, d.y, d.x + d.w, d.y + d.h, d.color);
            } else {
                renderer.drawRectOutline(d.x, d.y, d.x + d.w, d.y + d.h, d.color);
            },
        }
    }
}

pub fn update() void {
    drawables.update();
}

pub const DrawOptions = struct {
    pub const Anchor = enum {
        Left,
        Right,
        Center,

        fn calcX(self: Anchor, x: i32, width: i32) i32 {
            return switch (self) {
                .Right => (SCREEN_WIDTH) - x - width - 1,
                .Center => (SCREEN_WIDTH / 2) - @divTrunc(width, 2),
                else => x,
            };
        }
    };

    ttl: usize = 0,
    anchor: Anchor = Anchor.Center,
};

pub fn drawText(text: Text, opts: DrawOptions) void {
    var adj_text: Text = text;
    const text_width = @as(i32, @intCast(adj_text.text.len)) * GLYPH_WIDTH;
    adj_text.x = opts.anchor.calcX(adj_text.x, text_width);

    _ = drawables.insert(.{
        .component = .{ .Text = adj_text },
        .ttl = opts.ttl,
    });
}

pub fn drawLine(line: Line, opts: DrawOptions) void {
    var adj_line: Line = line;
    adj_line.x1 = opts.anchor.calcX(adj_line.x1, 0);
    adj_line.x2 = opts.anchor.calcX(adj_line.x2, 0);

    _ = drawables.insert(.{
        .component = .{ .Line = adj_line },
        .ttl = opts.ttl,
    });
}

pub fn drawRect(rect: Rect, opts: DrawOptions) void {
    var adj_rect: Rect = rect;
    adj_rect.x = opts.anchor.calcX(adj_rect.x, adj_rect.w);

    _ = drawables.insert(.{
        .component = .{ .Rect = adj_rect },
        .ttl = opts.ttl,
    });
}
