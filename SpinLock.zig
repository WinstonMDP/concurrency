const std = @import("std");
const atomic = std.atomic;
const assert = std.debug.assert;

locked: atomic.Value(bool) = atomic.Value(bool).init(false),

pub fn lock(self: *@This()) void {
    while (!self.tryLock()) {}
}

pub fn tryLock(self: *@This()) bool {
    return self.locked.cmpxchgWeak(
        false,
        true,
        .seq_cst,
        .seq_cst,
    ) == null;
}

pub fn unlock(self: *@This()) void {
    assert(self.locked.load(.seq_cst));
    assert(!self.tryLock());

    self.locked.store(false, .seq_cst);
}

const testing = std.testing;
const expect = testing.expect;
const expectEqual = testing.expectEqual;

test {
    var spin_lock = @This(){};

    try expect(spin_lock.tryLock());
    try expect(!spin_lock.tryLock());
    spin_lock.unlock();

    spin_lock.lock();
    try expect(!spin_lock.tryLock());
    spin_lock.unlock();

    try expect(spin_lock.tryLock());
}

const SpinLock = @This();
const Thread = std.Thread;

test {
    const ntimes = 100_000;
    const TestCtx = struct {
        spin_lock: SpinLock = SpinLock{},
        val: usize = 0,

        fn func(self: *@This()) void {
            for (0..ntimes) |_| {
                self.spin_lock.lock();
                self.val += 1;
                self.spin_lock.unlock();
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
