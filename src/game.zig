const emu = @import("emulator.zig");

const PLAYER1_OFFSET = 0x100400;
const PLAYER2_OFFSET = 0x100500;
const MATCH_OFFSET = 0x107400;
const IS_PAUSED_OFFSET = 0x1041D2;

pub const p1 = Player.new(PLAYER1_OFFSET);
pub const p2 = Player.new(PLAYER2_OFFSET);
pub const match = Match.new(MATCH_OFFSET);

const BehaviourOption = struct {
    skip_round_count: bool,
};

pub fn changeBehaviour(opts: BehaviourOption) void {
    const pc = emu.getCpuRegister(.PC);
    switch (pc) {
        0x02705E => if (opts.skip_round_count) emu.setCpuRegister(.PC, 0x027062), // skip player win increment
        0x00F4A6 => if (opts.skip_round_count) emu.setCpuRegister(.PC, 0x00F4AA), // skip round increment
        else => {},
    }
}

pub fn isPaused() bool {
    return emu.readMem(u8, IS_PAUSED_OFFSET) == 0xFF;
}

pub const Match = struct {
    pub const MAX_TIME = 0x99;
    const TIMER_OFFSET = 0x90;
    const MATCH_STATUS_OFFSET = 0x8A;

    const MatchStatus = enum(u8) {
        Active = 0x44,
        _,
    };

    base_addr: u32,

    pub fn new(base_addr: u32) Match {
        return Match{ .base_addr = base_addr };
    }

    pub fn getStatus(self: *const Match) MatchStatus {
        return @enumFromInt(emu.readMem(u8, self.base_addr + MATCH_STATUS_OFFSET));
    }

    pub fn setTimer(self: *const Match, val: u8) void {
        const timer = if (val > MAX_TIME) MAX_TIME else val;
        emu.writeMem(u8, self.base_addr + TIMER_OFFSET, timer);
    }

    pub fn getTimer(self: *const Match) u16 {
        return emu.readMem(u16, self.base_addr + TIMER_OFFSET);
    }
};

pub const Player = struct {
    pub const Status = packed struct(u16) {
        raw: u16 = 0,

        // not sure about these status values
        // @TODO: check if these are correct

        pub fn isBlocking(self: *const Status) bool {
            return (self.raw & 0x0160) == 0x0160;
        }

        pub fn isHitStun(self: *const Status) bool {
            return self.raw >= 0x0170 and self.raw <= 0x01FF;
        }

        pub fn isAttacking(self: *const Status) bool {
            return self.raw >= 0x0020 and self.raw <= 0x00FF;
        }

        pub fn isNeutral(self: *const Status) bool {
            return self.raw <= 0x19;
        }
    };

    pub const MAX_HEALTH = 120;
    pub const P_POWER = 128;
    pub const S_POWER = 64;
    pub const MAX_GUARD = 54;

    const STATUS_OFFSET = 0x60;
    const HEALTH_OFFSET = 0x8E;
    const POWER_OFFSET = 0xBE;
    const GUARD_OFFSET = 0xA8E4;
    const TOP_OFFSET = 0xA8AC;

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

    pub fn getStatus(self: *const Player) Status {
        const raw_status = emu.readMem(u16, self.base_addr + STATUS_OFFSET);
        return Status{ .raw = raw_status };
    }

    pub fn setHealth(self: *Player, health: u8) void {
        emu.writeMem(u8, self.base_addr + HEALTH_OFFSET, health);
    }

    pub fn setPower(self: *Player, power: u8) void {
        emu.writeMem(u8, self.base_addr + POWER_OFFSET, power);
    }

    pub fn setGuard(self: *Player, guard: u8) void {
        emu.writeMem(u8, self.base_addr + GUARD_OFFSET, guard);
    }

    pub fn setTop(self: *Player, on: bool) void {
        const val: u8 = if (on) 3 else 2; // 7 also activates top
        emu.writeMem(u8, self.base_addr + TOP_OFFSET, val);
    }
};
