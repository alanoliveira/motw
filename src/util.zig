pub const Side = enum { P1, P2 };

pub fn CircularQueue(comptime T: type, comptime capacity: usize) type {
    return struct {
        const Self = @This();

        start: usize = 0,
        end: usize = 0,
        cursize: usize = 0,
        buffer: [capacity]T = undefined,

        pub fn new() Self {
            return Self{};
        }

        pub fn enqueue(self: *Self, item: T) void {
            self.cursize = @min(self.cursize + 1, capacity);
            self.end = (self.end + 1) % self.cursize;
            self.buffer[self.end] = item;
            if (self.end == self.start) self.start = (self.start + 1) % self.cursize;
        }

        pub fn size(self: *const Self) usize {
            return self.cursize;
        }

        pub fn getFromEnd(self: *const Self, nth: usize) ?T {
            if (nth >= self.cursize) return null;
            const real_idx = (self.end + self.cursize - nth) % self.cursize;
            return self.buffer[real_idx];
        }

        pub fn getFromStart(self: *const Self, nth: usize) ?T {
            if (nth >= self.cursize) return null;
            const real_idx = (self.start + nth) % self.cursize;
            return self.buffer[real_idx];
        }
    };
}

test "CircularQueue" {
    const t = @import("std").testing;
    var q = CircularQueue(usize, 5).new();

    try t.expectEqual(@as(usize, 0), q.size());
    try t.expect(null == q.getFromStart(0));
    try t.expect(null == q.getFromEnd(0));

    q.enqueue(1);
    q.enqueue(2);
    q.enqueue(3);
    try t.expectEqual(@as(usize, 3), q.size());
    try t.expectEqual(@as(usize, 1), q.getFromStart(0).?);
    try t.expectEqual(@as(usize, 2), q.getFromStart(1).?);
    try t.expectEqual(@as(usize, 3), q.getFromStart(2).?);
    try t.expectEqual(@as(usize, 3), q.getFromEnd(0).?);
    try t.expectEqual(@as(usize, 2), q.getFromEnd(1).?);
    try t.expectEqual(@as(usize, 1), q.getFromEnd(2).?);

    q.enqueue(4);
    q.enqueue(5);
    q.enqueue(6);
    try t.expectEqual(@as(usize, 5), q.size());
    try t.expectEqual(@as(usize, 2), q.getFromStart(0).?);
    try t.expectEqual(@as(usize, 3), q.getFromStart(1).?);
    try t.expectEqual(@as(usize, 4), q.getFromStart(2).?);
    try t.expectEqual(@as(usize, 6), q.getFromEnd(0).?);
    try t.expectEqual(@as(usize, 5), q.getFromEnd(1).?);
    try t.expectEqual(@as(usize, 4), q.getFromEnd(2).?);
}
