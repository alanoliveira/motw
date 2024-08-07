const Self = @This();
const std = @import("std");
const win = @import("win32.zig");
const Font8x8 = @import("font8x8.zig");

pub const SCREEN_WIDTH = 396;
pub const SCREEN_HEIGHT = 224;
pub const GLYPH_WIDTH = 8 / SCALE;
const SCALE = 2.0;

const D3D9Settings = struct {
    alphaBlendEnable: u32,
    destBlend: u32,
    srcBlend: u32,
    destBlendAlpha: u32,
    srcBlendAlpha: u32,
    magfilter: u32,
    minfilter: u32,
    mipfilter: u32,
    fvf: u32,
    pixelShader: ?*win.IDirect3DPixelShader9,
    texture: ?*win.IDirect3DBaseTexture9,

    fn extract(device: *const win.IDirect3DDevice9) !D3D9Settings {
        var cur: D3D9Settings = undefined;
        if (device.GetRenderState(.ALPHABLENDENABLE, &cur.alphaBlendEnable) != win.S_OK or
            device.GetRenderState(.DESTBLEND, &cur.destBlend) != win.S_OK or
            device.GetRenderState(.SRCBLEND, &cur.srcBlend) != win.S_OK or
            device.GetRenderState(.DESTBLENDALPHA, &cur.destBlendAlpha) != win.S_OK or
            device.GetRenderState(.SRCBLENDALPHA, &cur.srcBlendAlpha) != win.S_OK or
            device.GetSamplerState(0, .MAGFILTER, &cur.magfilter) != win.S_OK or
            device.GetSamplerState(0, .MINFILTER, &cur.minfilter) != win.S_OK or
            device.GetSamplerState(0, .MIPFILTER, &cur.mipfilter) != win.S_OK or
            device.GetFVF(&cur.fvf) != win.S_OK or
            device.GetPixelShader(&cur.pixelShader) != win.S_OK or
            device.GetTexture(0, &cur.texture) != win.S_OK) return error.ExtractSettingsError;

        return cur;
    }

    fn apply(self: *const D3D9Settings, device: *const win.IDirect3DDevice9) !void {
        if (device.SetRenderState(.ALPHABLENDENABLE, self.alphaBlendEnable) != win.S_OK or
            device.SetRenderState(.DESTBLEND, self.destBlend) != win.S_OK or
            device.SetRenderState(.SRCBLEND, self.srcBlend) != win.S_OK or
            device.SetRenderState(.DESTBLENDALPHA, self.destBlendAlpha) != win.S_OK or
            device.SetRenderState(.SRCBLENDALPHA, self.srcBlendAlpha) != win.S_OK or
            device.SetSamplerState(0, .MAGFILTER, self.magfilter) != win.S_OK or
            device.SetSamplerState(0, .MINFILTER, self.minfilter) != win.S_OK or
            device.SetSamplerState(0, .MIPFILTER, self.mipfilter) != win.S_OK or
            device.SetPixelShader(self.pixelShader) != win.S_OK or
            device.SetFVF(self.fvf) != win.S_OK or
            device.SetTexture(0, self.texture) != win.S_OK) return error.ApplySettingsError;
    }

    const CUSTOM_SETTINGS: D3D9Settings = D3D9Settings{
        .alphaBlendEnable = win.TRUE,
        .destBlend = @intFromEnum(win.D3DBLEND_INVSRCALPHA),
        .srcBlend = @intFromEnum(win.D3DBLEND_SRCALPHA),
        .destBlendAlpha = @intFromEnum(win.D3DBLEND_ONE),
        .srcBlendAlpha = @intFromEnum(win.D3DBLEND_ZERO),
        .magfilter = @intFromEnum(win.D3DTEXF_NONE),
        .minfilter = @intFromEnum(win.D3DTEXF_NONE),
        .mipfilter = @intFromEnum(win.D3DTEXF_NONE),
        .fvf = win.D3DFVF_XYZRHW | win.D3DFVF_DIFFUSE,
        .pixelShader = null,
        .texture = null,
    };
};

original_settings: D3D9Settings,
original_render_target: ?*win.IDirect3DSurface9,
device: *win.IDirect3DDevice9,
texture: ?*win.IDirect3DTexture9,
font8x8: ?Font8x8,

pub fn initialize(self: *Self, device: *win.IDirect3DDevice9) !void {
    if (self.device != device) {
        self.device = device;

        std.debug.print("Creating render target texture\n", .{});
        if (self.texture) |texture| _ = texture.IUnknown.Release();
        if (!win.SUCCEEDED(device.CreateTexture(
            @intFromFloat(SCREEN_WIDTH * SCALE),
            @intFromFloat(SCREEN_HEIGHT * SCALE),
            1,
            win.D3DUSAGE_RENDERTARGET,
            win.D3DFMT_A8R8G8B8,
            win.D3DPOOL_DEFAULT,
            &self.texture,
            null,
        ))) {
            std.debug.print("Error on create render target texture\n", .{});
            return error.TextureCreateError;
        }

        std.debug.print("Creating font8x8\n", .{});
        if (self.font8x8) |*font8x8| _ = font8x8.deinitialize();
        self.font8x8 = try Font8x8.initialize(device);
        std.debug.print("Font8x8 created\n", .{});
    }

    self.original_settings = try D3D9Settings.extract(self.device);
    try D3D9Settings.CUSTOM_SETTINGS.apply(self.device);

    if (!win.SUCCEEDED(device.GetRenderTarget(0, &self.original_render_target))) {
        std.debug.print("Error on get original render target\n", .{});
        return error.RenderTargetGetError;
    }

    var render_target: ?*win.IDirect3DSurface9 = null;
    if (!win.SUCCEEDED(self.texture.?.GetSurfaceLevel(0, &render_target))) {
        std.debug.print("Error on get render target surface\n", .{});
        return error.RenderTargetGetError;
    }

    if (!win.SUCCEEDED(self.device.SetRenderTarget(0, render_target))) {
        std.debug.print("Error on set render target\n", .{});
        return error.RenderTargetSetError;
    }
    errdefer _ = self.device.SetRenderTarget(0, self.original_render_target);

    if (!win.SUCCEEDED(self.device.SetTexture(0, null))) {
        std.debug.print("Error on set texture\n", .{});
        return error.TextureSetError;
    }
    _ = self.device.Clear(0, null, win.D3DCLEAR_TARGET, 0, 1.0, 0);
}

pub fn deinitialize(self: *Self) !void {
    if (!win.SUCCEEDED(self.device.SetRenderTarget(0, self.original_render_target))) {
        std.debug.print("Error on set original render target\n", .{});
        return error.RenderTargetSetError;
    }

    var viewPort: win.D3DVIEWPORT9 = undefined;
    if (!win.SUCCEEDED(self.device.GetViewport(&viewPort))) {
        std.debug.print("Error on get viewport\n", .{});
        return error.ViewPortGetError;
    }

    if (!win.SUCCEEDED(self.device.SetTexture(0, @ptrCast(self.texture)))) {
        std.debug.print("Error on set texture\n", .{});
        return error.TextureSetError;
    }

    if (!win.SUCCEEDED(self.device.SetFVF(win.D3DFVF_XYZRHW | win.D3DFVF_TEX1))) {
        std.debug.print("Error on set FVF\n", .{});
        return error.FVFSetError;
    }

    const width: f32 = @floatFromInt(viewPort.Width);
    const height: f32 = @floatFromInt(viewPort.Height);
    const vertices = [4]struct {
        x: f32,
        y: f32,
        z: f32,
        rhw: f32,
        u: f32,
        v: f32,
    }{
        .{ .x = 0.0, .y = 0.0, .z = 0.0, .rhw = 1.0, .u = 0.0, .v = 0.0 },
        .{ .x = width, .y = 0.0, .z = 0.0, .rhw = 1.0, .u = 1.0, .v = 0.0 },
        .{ .x = 0.0, .y = height, .z = 0.0, .rhw = 1.0, .u = 0.0, .v = 1.0 },
        .{ .x = width, .y = height, .z = 0.0, .rhw = 1.0, .u = 1.0, .v = 1.0 },
    };

    if (self.device.DrawPrimitiveUP(
        win.D3DPRIMITIVETYPE.TRIANGLESTRIP,
        2,
        &vertices,
        @sizeOf(@TypeOf(vertices[0])),
    ) != win.S_OK) {
        std.debug.print("Error on draw text target\n", .{});
    }

    try self.original_settings.apply(self.device);
}

pub fn drawLine(self: *const Self, x1: i32, y1: i32, x2: i32, y2: i32, color: u32) void {
    const screen_x1 = worldToScreen(x1);
    const screen_y1 = worldToScreen(y1);
    const screen_x2 = worldToScreen(x2);
    const screen_y2 = worldToScreen(y2);

    const rhw = 1.0;
    const z = 0.0;
    const vertices = [_]Vertex{
        Vertex{ .x = screen_x1, .y = screen_y1, .z = z, .rhw = rhw, .color = color },
        Vertex{ .x = screen_x2, .y = screen_y2, .z = z, .rhw = rhw, .color = color },
    };

    if (self.device.DrawPrimitiveUP(
        win.D3DPRIMITIVETYPE.LINELIST,
        1,
        &vertices,
        @sizeOf(Vertex),
    ) != win.S_OK) {
        std.debug.print("Error on draw line\n", .{});
    }
}

pub fn drawRectFill(self: *const Self, x1: i32, y1: i32, x2: i32, y2: i32, color: u32) void {
    const screen_x1 = worldToScreen(x1);
    const screen_y1 = worldToScreen(y1);
    const screen_x2 = worldToScreen(x2);
    const screen_y2 = worldToScreen(y2);

    const rhw = 1.0;
    const z = 0.0;
    const fill_vertices = [_]Vertex{
        Vertex{ .x = screen_x1, .y = screen_y1, .z = z, .rhw = rhw, .color = color },
        Vertex{ .x = screen_x1, .y = screen_y2, .z = z, .rhw = rhw, .color = color },
        Vertex{ .x = screen_x2, .y = screen_y1, .z = z, .rhw = rhw, .color = color },
        Vertex{ .x = screen_x2, .y = screen_y2, .z = z, .rhw = rhw, .color = color },
    };

    if (self.device.DrawPrimitiveUP(
        win.D3DPRIMITIVETYPE.TRIANGLESTRIP,
        2,
        &fill_vertices,
        @sizeOf(Vertex),
    ) != win.S_OK) {
        std.debug.print("Error on drawRectFill\n", .{});
    }
}

pub fn drawRectOutline(self: *const Self, x1: i32, y1: i32, x2: i32, y2: i32, color: u32) void {
    const screen_x1 = worldToScreen(x1);
    const screen_y1 = worldToScreen(y1);
    const screen_x2 = worldToScreen(x2);
    const screen_y2 = worldToScreen(y2);

    const rhw = 1.0;
    const z = 0.0;
    const outline_vertices = [_]Vertex{
        Vertex{ .x = screen_x1, .y = screen_y1, .z = z, .rhw = rhw, .color = color },
        Vertex{ .x = screen_x1, .y = screen_y2, .z = z, .rhw = rhw, .color = color },
        Vertex{ .x = screen_x2, .y = screen_y2, .z = z, .rhw = rhw, .color = color },
        Vertex{ .x = screen_x2, .y = screen_y1, .z = z, .rhw = rhw, .color = color },
        Vertex{ .x = screen_x1, .y = screen_y1, .z = z, .rhw = rhw, .color = color },
    };

    if (self.device.DrawPrimitiveUP(
        win.D3DPRIMITIVETYPE.LINESTRIP,
        4,
        &outline_vertices,
        @sizeOf(Vertex),
    ) != win.S_OK) {
        std.debug.print("Error on drawRectOl\n", .{});
    }
}

pub fn drawText(self: *const Self, text: []const u8, x: i32, y: i32, color: u32) void {
    const screen_x = worldToScreen(x);
    const screen_y = worldToScreen(y);

    if (self.font8x8) |*f| f.drawText(text, screen_x, screen_y, color);

    // font rendering is messing up the render state, so we need to restore it
    // @TODO: find a better way to do this
    D3D9Settings.CUSTOM_SETTINGS.apply(self.device) catch {};
}

pub fn drawTextFmt(self: *const Self, comptime fmt: []const u8, args: anytype, x: i32, y: i32, color: u32) void {
    var buffer: [1024]u8 = .{0} ** 1024;
    const text = std.fmt.bufPrint(@ptrCast(&buffer), fmt, args) catch {
        std.debug.print("Failed to format string\n", .{});
        return;
    };

    self.drawText(text, x, y, color);
}

fn worldToScreen(value: i32) f32 {
    return @as(f32, @floatFromInt(value)) * SCALE;
}

const Vertex = packed struct {
    x: f32,
    y: f32,
    z: f32,
    rhw: f32,
    color: u32,
};
