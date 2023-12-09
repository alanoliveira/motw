const Self = @This();
const std = @import("std");
const win = @import("win32.zig");

const font8x8 = @cImport({
    @cInclude("font8x8.h");
});

texture: ?*win.IDirect3DTexture9,
sprite: ?*win.ID3DXSprite,

pub fn initialize(device: *win.IDirect3DDevice9) !Self {
    var texture: ?*win.IDirect3DTexture9 = null;
    if (device.IDirect3DDevice9_CreateTexture(
        8,
        8 * (128 + SYMBOLS_BMP.len),
        1,
        win.D3DUSAGE_DYNAMIC,
        win.D3DFORMAT.A8R8G8B8,
        win.D3DPOOL.DEFAULT,
        &texture,
        null,
    ) != win.S_OK) return error.CreateTextureError;
    errdefer _ = texture.?.IUnknown_Release();

    var surface: ?*win.IDirect3DSurface9 = null;
    if (texture.?.vtable.GetSurfaceLevel(texture.?, 0, &surface) != win.S_OK) {
        return error.GetSurfaceLevelError;
    }

    var lock_rect: win.D3DLOCKED_RECT = undefined;
    if (surface.?.vtable.LockRect(surface.?, &lock_rect, null, win.D3DLOCK_DISCARD) != win.S_OK) {
        return error.LockRectError;
    }

    const bmp_data: [*]u32 = @alignCast(@ptrCast(lock_rect.pBits));
    for (0..(font8x8.font8x8_basic.len + SYMBOLS_BMP.len)) |i| {
        const glyph = if (i < font8x8.font8x8_basic.len)
            font8x8.font8x8_basic[i]
        else
            SYMBOLS_BMP[i - font8x8.font8x8_basic.len];
        for (glyph, 0..) |glyph_row, y| {
            for (0..8) |x| {
                const bit = std.math.shr(u8, glyph_row, x) & 1;
                bmp_data[(i * 8 + y) * 32 + x] = if (bit != 0) 0xFFFFFFFF else 0;
            }
        }
    }

    if (surface.?.vtable.UnlockRect(surface.?) != win.S_OK) {
        return error.UnlockRectError;
    }

    var sprite: ?*win.ID3DXSprite = null;
    if (win.D3DXCreateSprite(@ptrCast(device), &sprite) != win.S_OK) {
        return error.CreateSpriteError;
    }

    return Self{
        .texture = texture,
        .sprite = sprite,
    };
}

pub fn drawText(self: *const Self, text: []const u8, x: f32, y: f32, color: u32) void {
    const sprite = self.sprite.?;

    var device: *win.IDirect3DDevice9 = undefined;
    if (sprite.lpVtbl.*.GetDevice.?(sprite, @ptrCast(&device)) != win.S_OK) {
        std.debug.print("Error on sprite.GetDevice\n", .{});
        return;
    }

    var magfilter: u32 = 0;
    var minfilter: u32 = 0;
    var mipfilter: u32 = 0;
    _ = device.IDirect3DDevice9_GetSamplerState(0, .MAGFILTER, @ptrCast(&magfilter));
    _ = device.IDirect3DDevice9_GetSamplerState(0, .MINFILTER, @ptrCast(&minfilter));
    _ = device.IDirect3DDevice9_GetSamplerState(0, .MIPFILTER, @ptrCast(&mipfilter));

    if (sprite.lpVtbl.*.Begin.?(sprite, win.D3DXSPRITE_DONOTSAVESTATE) != win.S_OK) {
        std.debug.print("Error on sprite.Begin\n", .{});
    }

    // do not smooth the pixels
    _ = device.IDirect3DDevice9_SetSamplerState(0, .MAGFILTER, @intFromEnum(win.D3DTEXF_NONE));
    _ = device.IDirect3DDevice9_SetSamplerState(0, .MINFILTER, @intFromEnum(win.D3DTEXF_NONE));
    _ = device.IDirect3DDevice9_SetSamplerState(0, .MIPFILTER, @intFromEnum(win.D3DTEXF_NONE));

    var pos_x = x;
    var pos_y = y;
    for (text) |c| {
        if (c == '\n') {
            pos_x = x;
            pos_y += 8;
            continue;
        }

        const offset_y: i32 = 8 * @as(i32, c);

        const rect = win.RECT{ .left = 0, .top = offset_y, .right = 8, .bottom = offset_y + 8 };
        if (sprite.lpVtbl.*.Draw.?(
            sprite,
            @ptrCast(self.texture.?),
            @ptrCast(&rect),
            null,
            &win.D3DXVECTOR3{ .x = pos_x, .y = pos_y, .z = 0 },
            color,
        ) != win.S_OK) {
            std.debug.print("Error on sprite.Draw\n", .{});
        }
        pos_x += 8;
    }

    if (sprite.lpVtbl.*.End.?(sprite) != win.S_OK) {
        std.debug.print("Error on sprite.End\n", .{});
    }

    _ = device.IDirect3DDevice9_SetSamplerState(0, .MAGFILTER, magfilter);
    _ = device.IDirect3DDevice9_SetSamplerState(0, .MINFILTER, minfilter);
    _ = device.IDirect3DDevice9_SetSamplerState(0, .MIPFILTER, mipfilter);
}

pub fn deinitialize(self: *Self) void {
    if (self.sprite) |s| _ = s.lpVtbl.*.Release.?(s);
    if (self.texture) |t| _ = t.IUnknown_Release();
}

const SYMBOLS_BMP = [_][8]u8{
    .{ // Neutral
        0b00000000,
        0b00100000,
        0b00100000,
        0b11111000,
        0b00100000,
        0b00100000,
        0b00000000,
        0b00000000,
    },
    .{ // Up
        0b00010000,
        0b00111000,
        0b01010100,
        0b10010010,
        0b00010000,
        0b00010000,
        0b00010000,
        0b00000000,
    },
    .{ // Down
        0b00010000,
        0b00010000,
        0b00010000,
        0b10010010,
        0b01010100,
        0b00111000,
        0b00010000,
        0b00000000,
    },
    .{ // Right
        0b00010000,
        0b00001000,
        0b00000100,
        0b11111110,
        0b00000100,
        0b00001000,
        0b00010000,
        0b00000000,
    },
    .{ // Left
        0b00010000,
        0b00100000,
        0b01000000,
        0b11111110,
        0b01000000,
        0b00100000,
        0b00010000,
        0b00000000,
    },
    .{ // Up-Right
        0b01111100,
        0b00001100,
        0b00010100,
        0b00100100,
        0b01000100,
        0b10000000,
        0b00000000,
        0b00000000,
    },
    .{ // Up-Left
        0b11111000,
        0b11000000,
        0b10100000,
        0b10010000,
        0b10001000,
        0b00000100,
        0b00000000,
        0b00000000,
    },
    .{ // Down-Right
        0b10000000,
        0b01000100,
        0b00100100,
        0b00010100,
        0b00001100,
        0b01111100,
        0b00000000,
        0b00000000,
    },
    .{ // Down-Left
        0b00000100,
        0b10001000,
        0b10010000,
        0b10100000,
        0b11000000,
        0b11111000,
        0b00000000,
        0b00000000,
    },
};
