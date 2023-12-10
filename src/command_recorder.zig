const std = @import("std");
const emu = @import("emulator.zig");
const view = @import("view.zig");
const Command = emu.Command;

const Status = enum {
    Stopped,
    Prepare,
    Recording,
    Replay,
};

const Slot = struct {
    const MAX_LENGTH = 0x1000;

    commands: [MAX_LENGTH]Command = undefined,
    size: usize = 0,

    fn push(self: *Slot, command: Command) bool {
        if (self.size >= MAX_LENGTH) return false;
        self.commands[self.size] = command;
        self.size += 1;
        return true;
    }

    fn pop(self: *Slot) ?Command {
        if (self.size == 0) return null;
        self.size -= 1;
        return self.commands[self.size];
    }

    fn reverse(self: *Slot) void {
        std.mem.reverse(Command, self.commands[0..self.size]);
    }
};

const MAX_SLOTS = 10;

var status: Status = .Stopped;
var buffer: Slot = .{ .size = 0 };
var slots: [MAX_SLOTS]Slot = undefined;
var selected_slot: usize = 0;

pub fn process() void {
    switch (status) {
        .Prepare => {
            swapCommands();
            view.drawText(view.Text.new("PREPARE", .{}, 0, 50, 0xFFFF0000), .{});
        },
        .Recording => {
            swapCommands();
            if (!buffer.push(emu.getCommand(.P2))) {
                stopRecording();
                return;
            }
            view.drawText(view.Text.new("REC {d}", .{buffer.size}, 0, 50, 0xFFFF0000), .{});
        },
        .Replay => {
            const recorded = buffer.pop() orelse {
                stopReplay();
                return;
            };
            emu.setCommand(.P2, recorded);
            view.drawText(view.Text.new("PLAY {d}", .{buffer.size}, 0, 50, 0xFF00FF00), .{});
        },
        else => {},
    }
}

pub fn record() void {
    switch (status) {
        .Stopped => prepareRecording(),
        .Prepare => startRecording(),
        .Recording => stopRecording(),
        else => cancel(),
    }
}

pub fn replay() void {
    switch (status) {
        .Stopped => startReplay(),
        .Replay => stopReplay(),
        else => cancel(),
    }
}

pub fn selectSlot(slot: usize) void {
    if (slot >= MAX_SLOTS) return;
    selected_slot = slot;
}

fn prepareRecording() void {
    status = .Prepare;
}

fn startRecording() void {
    buffer.size = 0;
    status = .Recording;
}

fn stopRecording() void {
    buffer.reverse();
    slots[selected_slot] = buffer;
    status = .Stopped;
}

fn startReplay() void {
    buffer.size = 0;
    buffer = slots[selected_slot];
    status = .Replay;
}

fn stopReplay() void {
    status = .Stopped;
}

fn cancel() void {
    status = .Stopped;
}

fn swapCommands() void {
    const temp = emu.getCommand(.P1);
    emu.setCommand(.P1, emu.getCommand(.P2));
    emu.setCommand(.P2, temp);
}

pub const State = struct {
    status: Status,
    slot: Slot,

    pub fn save() State {
        return .{
            .status = status,
            .slot = buffer,
        };
    }

    pub fn load(self: *const State) void {
        status = self.status;
        buffer = self.slot;
    }
};
