const emu = @import("emulator.zig");
const view = @import("view.zig");

const PLAYER1_OFFSET = 0x100400;
const PLAYER2_OFFSET = 0x100500;
const STAGE_OFFSET = 0x100E00;
const MATCH_OFFSET = 0x107400;
const PROJECTILES_PTR_OFFSET = 0x100C88;
const IS_PAUSED_OFFSET = 0x1041D2;

const ObjectKind = union(enum) {
    Constant: enum { P1, P2, Stage },
    Projectile: usize,
};

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

pub fn getObject(kind: ObjectKind) ?Object {
    return switch (kind) {
        .Constant => |p| switch (p) {
            .P1 => Object.new(PLAYER1_OFFSET),
            .P2 => Object.new(PLAYER2_OFFSET),
            .Stage => Object.new(STAGE_OFFSET),
        },
        .Projectile => |idx| proj: {
            const addr = getProjectileAddr(idx) orelse return null;
            break :proj Object.new(addr);
        },
    };
}

fn getProjectileAddr(index: usize) ?u32 {
    const addr = emu.readMem(u32, PROJECTILES_PTR_OFFSET + index * 4);
    return if (addr == 0) null else addr;
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

pub const Object = struct {
    const PUSHBOX_BASE_ADDR = 0x358B0;
    const ID_OFFSET = 0x10;
    const POS_X_OFFSET = 0x20;
    const POS_Y_OFFSET = 0x28;
    const MOVE_STATUS_OFFSET = 0xC2;
    const NORMAL_ATTACK_STATUS_OFFSET = 0xC6;
    const SPECIAL_ATTACK_STATUS_OFFSET = 0xCA;
    const HITBOX_PTR_OFFSET = 0x7A;
    const INVULNERABILITY_OFFSET = 0xB3;
    const INSTRUCTION_PTR_OFFSET = 0x00;
    const PUSHABLE_OFFSET = 0xEE;

    const Instruction = enum(u16) {
        RTS = 0x4E75,
        JSR = 0x4EB9,
        _,
    };

    const MovingStatus = enum(u32) {
        Knockdown = 0x00000002,
        Crouching = 0x00000004,
        HopLanding = 0x00010000,
        Jumping = 0x00020000,
        BackwardHop = 0x00040000,
        ForwardHop = 0x00080000,
        VerticalHop = 0x00100000,
        BackwardJump = 0x00200000,
        ForwardJumpOrBackstep = 0x00400000,
        VerticalJump = 0x00800000,
        Dash = 0x01000000,
        Standing = 0x08000000,
        Crouch = 0x10000000,
        WalkBackward = 0x20000000,
        WalkForward = 0x40000000,
        Stand = 0x80000000,
        _,
    };

    const NormalMoveStatus = packed struct(u32) { raw: u32 };

    const SpecialMoveStatus = packed struct(u32) { raw: u32 };

    base_addr: u32,

    pub fn new(base_addr: u32) Object {
        return Object{ .base_addr = base_addr };
    }

    pub fn getId(self: *const Object) u16 {
        return emu.readMem(u16, self.base_addr + ID_OFFSET);
    }

    pub fn getX(self: *const Object) i16 {
        return emu.readMem(i16, self.base_addr + POS_X_OFFSET);
    }

    pub fn getY(self: *const Object) i16 {
        return emu.readMem(i16, self.base_addr + POS_Y_OFFSET);
    }

    pub fn getMoveStatus(self: *const Object) MovingStatus {
        return @enumFromInt(emu.readMem(u32, self.base_addr + MOVE_STATUS_OFFSET));
    }

    pub fn getNormalAttackStatus(self: *const Object) NormalMoveStatus {
        return @bitCast(emu.readMem(u32, self.base_addr + NORMAL_ATTACK_STATUS_OFFSET));
    }

    pub fn getSpecialAttackStatus(self: *const Object) SpecialMoveStatus {
        return @bitCast(emu.readMem(u32, self.base_addr + SPECIAL_ATTACK_STATUS_OFFSET));
    }

    pub fn isFacingRight(self: *const Object) bool {
        return emu.readMem(u8, self.base_addr + 0x71) & 1 == 1;
    }

    pub fn isTurning(self: *const Object) bool {
        // 0x6A is -80 when turning
        return emu.readMem(i8, self.base_addr + 0x6A) < 0;
    }

    pub fn isInvulnerable(self: *const Object) bool {
        if (emu.readMem(u8, self.base_addr + INVULNERABILITY_OFFSET) > 0) return true;

        var inst_offset: u32 = 0;
        while (true) : (inst_offset += 2) {
            const instruction = self.getInstruction(inst_offset);
            if (instruction == .JSR) {
                const jsr_addr = self.getInstructionParam(inst_offset);
                if (jsr_addr == 0x020684 or
                    (jsr_addr == 0x020696 and
                    emu.readMem(i8, self.base_addr + 0xFE) <= 0) or
                    jsr_addr == 0x0519EA) return false;
            } else if (instruction == .RTS) return true;
        }
    }

    pub fn getInstruction(self: *const Object, offset: usize) Instruction {
        const instruction_ptr: u32 = self.getInstructionPtr();
        return @enumFromInt(emu.readMem(u16, instruction_ptr + offset));
    }

    pub fn getInstructionParam(self: *const Object, offset: usize) u32 {
        const instruction_ptr: u32 = self.getInstructionPtr();
        return emu.readMem(u32, instruction_ptr + offset + 2);
    }

    pub fn getInstructionPtr(self: *const Object) u32 {
        return emu.readMem(u32, self.base_addr + INSTRUCTION_PTR_OFFSET);
    }

    pub fn getPushboxAddress(self: *const Object) u32 {
        const char_offset = self.getId() << 3;
        const pushbox_offset = self.getPushboxBlockOffset();
        return char_offset + pushbox_offset + PUSHBOX_BASE_ADDR;
    }

    pub fn getHitboxAddress(self: *const Object) u32 {
        return emu.readMem(u32, self.base_addr + HITBOX_PTR_OFFSET);
    }

    pub fn isPushable(self: *const Object) bool {
        return emu.readMem(u16, self.base_addr + PUSHABLE_OFFSET) == 0;
    }

    // it is in 0x0355C6 @TODO: remove all magic numbers
    fn getPushboxBlockOffset(self: *const Object) u32 {
        const move_status = self.getMoveStatus();
        if (move_status == .Knockdown) return 0x100;

        const normal_attack_status = self.getNormalAttackStatus();
        const special_attack_status = self.getSpecialAttackStatus();
        if (self.getY() > 0) {
            const is_doing_move =
                normal_attack_status.raw & 0xFFFFFFFF != 0 or
                special_attack_status.raw & 0xFFFFFFDE != 0;

            const cond1 = emu.readMem(u8, self.base_addr + 0xBB) << 0x04 == 0;
            const cond2 = special_attack_status.raw & 0xFFFFE01E != 0;

            return if (is_doing_move and cond1 and cond2) 0x300 else 0x200;
        } else {
            const m = move_status;
            return if (m == .Dash or
                m == .Knockdown or
                m == .Crouch or
                m == .Crouching or
                m == .ForwardJumpOrBackstep) 0x100 else 0x0;
        }
    }
};

pub const Box = struct {
    const Kind = enum {
        Push,
        Attack,
        Hurt,
        Guard,

        fn fromRaw(raw: u8) Kind {
            switch (raw) {
                0 => return .Push,
                1...15 => return .Hurt,
                16...17 => return .Guard,
                else => return .Attack,
            }
        }
    };

    top: i8,
    bottom: i8,
    right: i8,
    left: i8,
    kind: Kind,

    pub fn new(obj_id: u16, address: u32, index: usize) ?Box {
        const quantity = address >> 24 & 0xFF;

        if (index >= quantity and index != 0) return null;

        const addr = address + (index * 0x05);
        if (addr > 0x200000) {
            const bank = HITBOX_BANK[obj_id];
            return Box{
                .kind = Kind.fromRaw(emu.readBank(u8, bank, addr)),
                .top = emu.readBank(i8, bank, addr + 0x01),
                .bottom = emu.readBank(i8, bank, addr + 0x02),
                .right = emu.readBank(i8, bank, addr + 0x03),
                .left = emu.readBank(i8, bank, addr + 0x04),
            };
        } else {
            return Box{
                .kind = Kind.fromRaw(emu.readMem(u8, addr)),
                .top = emu.readMem(i8, addr + 0x01),
                .bottom = emu.readMem(i8, addr + 0x02),
                .right = emu.readMem(i8, addr + 0x03),
                .left = emu.readMem(i8, addr + 0x04),
            };
        }
    }

    const HITBOX_BANK = generateHitboxBankTable();

    fn generateHitboxBankTable() [14]usize {
        // Defined at 0x03332E
        const char_bank = [_]usize{
            0x25C8, // terry
            0x80A3, // rock
            0xA1D1, // donghwan
            0x0321, // jaehoon
            0x83D2, // hotaru
            0x874B, // gato
            0x038A, // jenny
            0x809B, // marco
            0x863A, // hokutomaru
            0x8242, // freeman
            0xA390, // griffon
            0x06B0, // kevin
            0x06AB, // grant
            0x85B2, // kain
        };

        var ret: [14]usize = undefined;
        for (char_bank, 0..) |b, i| ret[i] = (b >> 5) & 0x3FF;
        return ret;
    }
};
