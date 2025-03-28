next_free_ticket: atomic.Value(u64) = atomic.Value(u64).init(0),
owner_ticket: atomic.Value(u64) = atomic.Value(u64).init(0),

pub fn lock(self: *@This()) void {
    const ticket = self.next_free_ticket.fetchAdd(1, .seq_cst);
    while (self.owner_ticket.load(.seq_cst) != ticket) {}
}

pub fn tryLock(self: *@This()) bool {
    const current_owner_ticket = self.owner_ticket.load(.seq_cst);
    assert(current_owner_ticket <= self.next_free_ticket.load(.seq_cst));

    return self.next_free_ticket.cmpxchgWeak(
        current_owner_ticket,
        current_owner_ticket + 1,
        .seq_cst,
        .seq_cst,
    ) == null;
}

pub fn unlock(self: *@This()) void {
    assert(!self.tryLock());
    _ = self.owner_ticket.fetchAdd(1, .seq_cst);
}

test {
    var ticket_lock = @This(){};

    try expect(ticket_lock.tryLock());
    try expect(!ticket_lock.tryLock());
    ticket_lock.unlock();

    ticket_lock.lock();
    try expect(!ticket_lock.tryLock());
    ticket_lock.unlock();

    try expect(ticket_lock.tryLock());
}

test {
    const ntimes = 100_000;
    const TestCtx = struct {
        ticket_lock: TicketLock = TicketLock{},
        val: usize = 0,

        fn func(self: *@This()) void {
            for (0..ntimes) |i| {
                if (i % 2 == 0)
                    self.ticket_lock.lock()
                else while (!self.ticket_lock.tryLock()) {}
                self.val += 1;
                self.ticket_lock.unlock();
            }
        }
    };
    var test_ctx = TestCtx{};

    var threads: [12]Thread = undefined;
    inline for (&threads) |*thread|
        thread.* = try Thread.spawn(.{}, TestCtx.func, .{&test_ctx});
    inline for (&threads) |*thread| thread.join();

    try expectEqual(test_ctx.val, threads.len * ntimes);
}

const TicketLock = @This();
const std = @import("std");
const atomic = std.atomic;
const assert = std.debug.assert;
const Thread = std.Thread;
const testing = std.testing;
const expect = testing.expect;
const expectEqual = testing.expectEqual;
