const emu = @import("emulator.zig");

const PLAYER1_OFFSET = 0x100400;
const PLAYER2_OFFSET = 0x100500;

pub const p1 = Player.new(PLAYER1_OFFSET);
pub const p2 = Player.new(PLAYER2_OFFSET);

pub const Player = struct {
    pub const MAX_HEALTH = 120;
    pub const P_POWER = 128;
    pub const S_POWER = 64;
    pub const MAX_GUARD = 54;
    const HEALTH_OFFSET = 0x8E;
    const POWER_OFFSET = 0xBE;
    const GUARD_OFFSET = 0xA8E4;

    base_addr: u32,

    pub fn new(base_addr: u32) Player {
        return Player{ .base_addr = base_addr };
    }

    pub fn getHealth(self: *const Player) u8 {
        return emu.readMem(u8, self.base_addr + HEALTH_OFFSET);
    }

    pub fn getPower(self: *const Player) u8 {
        return emu.readMem(u8, self.base_addr + POWER_OFFSET);
    }

    pub fn getGuard(self: *const Player) u8 {
        return emu.readMem(u8, self.base_addr + GUARD_OFFSET);
    }
};
