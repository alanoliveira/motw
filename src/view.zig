const std = @import("std");
const Renderer = @import("renderer.zig");

pub const SCREEN_WIDTH = 398;
pub const SCREEN_HEIGHT = 224;
const GLYPH_WIDTH = 4;

var string_buffer: [4096]u8 = undefined;
var strings_fba = std.heap.FixedBufferAllocator.init(&string_buffer);
var strings = strings_fba.allocator();

var drawable_buffer: [4096]u8 = undefined;
var fba = std.heap.FixedBufferAllocator.init(&drawable_buffer);
var allocator = fba.allocator();
const DrawableList = std.SinglyLinkedList(Drawable);
var drawables = DrawableList{};

const Drawable = struct {
    const Component = union(enum) {
        Text: Text,
        Line: Line,
        Rect: Rect,
    };
    component: Component,
    ttl: usize,
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
    var node = drawables.first;
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

        if (drawable.data.ttl > 0) {
            drawable.data.ttl -= 1;
        } else {
            drawables.remove(drawable);
            switch (drawable.data.component) {
                .Text => |d| strings.free(d.text),
                else => {},
            }
            allocator.destroy(drawable);
        }
    }
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
    var node = allocator.create(DrawableList.Node) catch return;
    var adj_text: Text = text;

    adj_text.text = strings.dupe(u8, text.text) catch return;
    const text_width = @as(i32, @intCast(adj_text.text.len)) * GLYPH_WIDTH;
    adj_text.x = opts.anchor.calcX(adj_text.x, text_width);

    node.data = .{
        .component = .{ .Text = adj_text },
        .ttl = opts.ttl,
    };
    drawables.prepend(node);
}

pub fn drawLine(line: Line, opts: DrawOptions) void {
    var adj_line: Line = line;
    adj_line.x1 = opts.anchor.calcX(adj_line.x1, 0);
    adj_line.x2 = opts.anchor.calcX(adj_line.x2, 0);

    var node = allocator.create(DrawableList.Node) catch return;
    node.data = .{
        .component = .{ .Line = adj_line },
        .ttl = opts.ttl,
    };
    drawables.prepend(node);
}

pub fn drawRect(rect: Rect, opts: DrawOptions) void {
    var adj_rect: Rect = rect;
    adj_rect.x = opts.anchor.calcX(adj_rect.x, adj_rect.w);

    var node = allocator.create(DrawableList.Node) catch return;
    node.data = .{
        .component = .{ .Rect = adj_rect },
        .ttl = opts.ttl,
    };
    drawables.prepend(node);
}
