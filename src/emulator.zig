const std = @import("std");

// IMPORTANT:
// The emulator was written for x86 architecture, that uses little endian 32-bit, but
// the game was written for M68K architecture, that uses big endian 16-bit.
// Because of that, the game address 0x1000 was stored in <rom_offset> + 0x1001, and the
// game address 0x1001 was stored in <rom_offset> + 0x1000.
// It needs to be taken into account when reading/writing to memory.

pub const RunOpcodeT: type = *fn () callconv(.C) void;
pub const RunFrameT: type = *fn () callconv(.C) u32;
pub const GameTickT: type = *fn () callconv(.C) void;

pub const CpuRegister = enum(u32) {
    D0 = 0,
    D1,
    D2,
    D3,
    D4,
    D5,
    D6,
    D7,
    A0,
    A1,
    A2,
    A3,
    A4,
    A5,
    A6,
    SP,
    PC,
    IR = 50,
};

const RUN_OPCODE_FN_OFFSET = 0x5BAE0;
const RUN_FRAME_FN_OFFSET = 0xBC90;
const GAME_TICK_FN_OFFSET = 0x4700;
const CPU_REGS_OFFSET = 0xEE6820;
const DYN_BANK_MAP_OFFSET = 0xEE6994;
const STT_BANK_MAP_OFFSET = 0x139D38;
const BANK_SIZE = 0x10_0000;
const IS_EMULATION_RUNNING_OFFSET = 0x11BAF4;
const FRAME_COUNTER_OFFSET = 0x1E4770;
const USER_RAM_OFFSET = 0x2B6000;
const PAL_OFFSET = 0x241000;
const VRAM_OFFSET = 0x286000;

// Probably I'm missing something.
// @TODO: replace it by the emulator save state when I find the address.
pub const State = struct {
    user_ram: [0x10000]u8,
    cpu: [0x300]u8,
    vram: [0x10000]u8,
    pallette: [0x10000]u8,

    pub fn save() State {
        var state: State = undefined;
        @memcpy(&state.user_ram, base_ptr + USER_RAM_OFFSET);
        @memcpy(&state.vram, base_ptr + VRAM_OFFSET);
        @memcpy(&state.cpu, base_ptr + CPU_REGS_OFFSET);
        @memcpy(&state.pallette, base_ptr + PAL_OFFSET);
        return state;
    }

    pub fn load(self: *const State) void {
        @memcpy(base_ptr + USER_RAM_OFFSET, &self.user_ram);
        @memcpy(base_ptr + VRAM_OFFSET, &self.vram);
        @memcpy(base_ptr + CPU_REGS_OFFSET, &self.cpu);
        @memcpy(base_ptr + PAL_OFFSET, &self.pallette);
    }
};

var base_ptr: [*]u8 = undefined;

pub fn initialize(ptr: [*]u8) void {
    base_ptr = ptr;
}

pub fn getRunOpcodePtr() RunOpcodeT {
    return @ptrCast(base_ptr + RUN_OPCODE_FN_OFFSET);
}

pub fn getRunFramePtr() RunFrameT {
    return @ptrCast(base_ptr + RUN_FRAME_FN_OFFSET);
}

pub fn getGameTickPtr() RunFrameT {
    return @ptrCast(base_ptr + GAME_TICK_FN_OFFSET);
}

/// Returns true if the emulation is running (the game is not paused or in main menu).
pub fn isEmulationRunning() bool {
    return std.mem.readInt(u8, @ptrCast(base_ptr + IS_EMULATION_RUNNING_OFFSET), .little) != 1;
}

pub fn getFrameCount() u32 {
    return std.mem.readInt(u32, @ptrCast(base_ptr + FRAME_COUNTER_OFFSET), .little);
}

pub fn getCpuRegister(reg: CpuRegister) u32 {
    return getRegPtr(reg).*;
}

pub fn setCpuRegister(reg: CpuRegister, val: u32) void {
    getRegPtr(reg).* = val;
}

pub fn printRegisters() void {
    std.debug.print(
        \\D0: 0x{X:0>8}    A0: 0x{X:0>8}    SP: 0x{X:0>8}
        \\D1: 0x{X:0>8}    A1: 0x{X:0>8}    PC: 0x{X:0>8}
        \\D2: 0x{X:0>8}    A2: 0x{X:0>8}    IR: 0x{X:0>4}
        \\D3: 0x{X:0>8}    A3: 0x{X:0>8}
        \\D4: 0x{X:0>8}    A4: 0x{X:0>8}
        \\D5: 0x{X:0>8}    A5: 0x{X:0>8}
        \\D6: 0x{X:0>8}    A6: 0x{X:0>8}
        \\D7: 0x{X:0>8}
        \\
    , .{
        getCpuRegister(CpuRegister.D0),
        getCpuRegister(CpuRegister.A0),
        getCpuRegister(CpuRegister.SP),
        getCpuRegister(CpuRegister.D1),
        getCpuRegister(CpuRegister.A1),
        getCpuRegister(CpuRegister.PC),
        getCpuRegister(CpuRegister.D2),
        getCpuRegister(CpuRegister.A2),
        getCpuRegister(CpuRegister.IR),
        getCpuRegister(CpuRegister.D3),
        getCpuRegister(CpuRegister.A3),
        getCpuRegister(CpuRegister.D4),
        getCpuRegister(CpuRegister.A4),
        getCpuRegister(CpuRegister.D5),
        getCpuRegister(CpuRegister.A5),
        getCpuRegister(CpuRegister.D6),
        getCpuRegister(CpuRegister.A6),
        getCpuRegister(CpuRegister.D7),
    });
}

pub fn readMem(comptime T: type, addr: u32) T {
    const mapped_bank_ptr = getMappedBankPtr(addr);
    return readM64KInt(T, @ptrCast(mapped_bank_ptr + (addr & 0x7FFF)));
}

pub fn readMemInto(comptime T: type, addr: u32, buffer: []T) void {
    for (buffer, 0..) |*b, i| b.* = readMem(T, addr + i);
}

pub fn writeMem(comptime T: type, addr: u32, value: T) void {
    const mapped_bank_ptr = getMappedBankPtr(addr);
    writeM64KInt(T, @ptrCast(mapped_bank_ptr + (addr & 0x7FFF)), value);
}

pub fn readBank(comptime T: type, bank: u32, addr: u32) T {
    return readM64KInt(T, @ptrCast(getStaticBankPtr(bank) + (addr & 0xFFFFF)));
}

fn getRomPtr() [*]u8 {
    const mem_ptr_var: *[*]u8 = @alignCast(@ptrCast(base_ptr + DYN_BANK_MAP_OFFSET));
    return mem_ptr_var.*;
}

fn getMappedBankPtr(addr: u32) [*]u8 {
    const mapped_bank_offset = ((addr & 0xFFFFFF) >> 15) * 4;
    return @ptrFromInt(std.mem.readInt(
        u32,
        @ptrCast(base_ptr + DYN_BANK_MAP_OFFSET + mapped_bank_offset),
        .little,
    ));
}

fn getStaticBankPtr(bank: u32) [*]u8 {
    const stt_bank_map: [*]u32 = @alignCast(@ptrCast(base_ptr + STT_BANK_MAP_OFFSET));
    const bank_offset: u32 = stt_bank_map[bank];
    return @ptrCast(getRomPtr() + bank_offset);
}

fn getRegPtr(reg: CpuRegister) *u32 {
    const cpu_regs_ptr: [*]u32 = @alignCast(@ptrCast(base_ptr + CPU_REGS_OFFSET));
    const offset = @intFromEnum(reg);
    return @ptrCast(cpu_regs_ptr + offset);
}

inline fn readM64KInt(comptime T: type, buffer: *const [@divExact(@typeInfo(T).Int.bits, 8)]u8) T {
    const ptr: [*]const u8 = @ptrCast(buffer);

    var value: T = 0;
    const val_bytes = std.mem.asBytes(&value);
    for (val_bytes, 0..) |*b, i| b.* = getM64KBytePtr(ptr + i).*;

    return @byteSwap(value);
}

inline fn writeM64KInt(comptime T: type, buffer: *[@divExact(@typeInfo(T).Int.bits, 8)]u8, value: T) void {
    const ptr: [*]u8 = @ptrCast(buffer);

    const swapped_value = @byteSwap(value);
    const val_bytes = std.mem.asBytes(&swapped_value);
    for (val_bytes, 0..) |*b, i| getM64KBytePtr(ptr + i).* = b.*;

    return;
}

inline fn getM64KBytePtr(buffer: [*]const u8) *u8 {
    return @ptrFromInt(@intFromPtr(buffer) ^ 1);
}

test "readM64KInt" {
    const t = @import("std").testing;
    const data = [_]u8{ 0xA1, 0xB2, 0xC3, 0xD4, 0xE5, 0xF6 };
    const ptr: [*]const u8 = @ptrCast(&data);

    try t.expectEqual(@as(u8, 0xB2), readM64KInt(u8, @ptrCast(ptr)));
    try t.expectEqual(@as(u8, 0xA1), readM64KInt(u8, @ptrCast(ptr + 1)));
    try t.expectEqual(@as(u16, 0xB2A1), readM64KInt(u16, @ptrCast(ptr)));
    try t.expectEqual(@as(u16, 0xA1D4), readM64KInt(u16, @ptrCast(ptr + 1)));
    try t.expectEqual(@as(u32, 0xB2A1D4C3), readM64KInt(u32, @ptrCast(ptr)));
    try t.expectEqual(@as(u32, 0xA1D4C3F6), readM64KInt(u32, @ptrCast(ptr + 1)));
}

test "writeM64KInt" {
    const t = @import("std").testing;
    var data: [6]u8 = undefined;
    const ptr: [*]u8 = @ptrCast(&data);

    data = [_]u8{ 0xA1, 0xB2, 0xC3, 0xD4, 0xE5, 0xF6 };
    writeM64KInt(u8, @ptrCast(ptr), 0xFF);
    try t.expectEqual([_]u8{ 0xA1, 0xFF, 0xC3, 0xD4, 0xE5, 0xF6 }, data);

    data = [_]u8{ 0xA1, 0xB2, 0xC3, 0xD4, 0xE5, 0xF6 };
    writeM64KInt(u8, @ptrCast(ptr + 1), 0xFF);
    try t.expectEqual([_]u8{ 0xFF, 0xB2, 0xC3, 0xD4, 0xE5, 0xF6 }, data);

    data = [_]u8{ 0xA1, 0xB2, 0xC3, 0xD4, 0xE5, 0xF6 };
    writeM64KInt(u16, @ptrCast(ptr), 0xFFFF);
    try t.expectEqual([_]u8{ 0xFF, 0xFF, 0xC3, 0xD4, 0xE5, 0xF6 }, data);

    data = [_]u8{ 0xA1, 0xB2, 0xC3, 0xD4, 0xE5, 0xF6 };
    writeM64KInt(u16, @ptrCast(ptr + 1), 0xFFFF);
    try t.expectEqual([_]u8{ 0xFF, 0xB2, 0xC3, 0xFF, 0xE5, 0xF6 }, data);

    data = [_]u8{ 0xA1, 0xB2, 0xC3, 0xD4, 0xE5, 0xF6 };
    writeM64KInt(u32, @ptrCast(ptr), 0xFFFFFFFF);
    try t.expectEqual([_]u8{ 0xFF, 0xFF, 0xFF, 0xFF, 0xE5, 0xF6 }, data);

    data = [_]u8{ 0xA1, 0xB2, 0xC3, 0xD4, 0xE5, 0xF6 };
    writeM64KInt(u32, @ptrCast(ptr + 1), 0xFFFFFFFF);
    try t.expectEqual([_]u8{ 0xFF, 0xB2, 0xFF, 0xFF, 0xE5, 0xFF }, data);
}
