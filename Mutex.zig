const std = @import("std");
const atomic = std.atomic;
const Thread = std.Thread;
const Futex = Thread.Futex;
const assert = std.debug.assert;

const unlocked: u32 = 0;
const locked: u32 = 1;
const contended: u32 = 2;

state: std.atomic.Value(u32) = std.atomic.Value(u32).init(unlocked),

pub fn lock(self: *@This()) void {
    if (!self.tryLock()) {
        if (self.state.load(.seq_cst) == contended)
            Futex.wait(&self.state, contended);

        while (self.state.swap(contended, .seq_cst) != unlocked)
            Futex.wait(&self.state, contended);
    }
}

pub fn tryLock(self: *@This()) bool {
    return self.state.cmpxchgWeak(unlocked, locked, .seq_cst, .seq_cst) == null;
}

pub fn unlock(self: *@This()) void {
    const state = self.state.swap(unlocked, .seq_cst);
    assert(state != unlocked);

    if (state == contended) Futex.wake(&self.state, 1);
}

const testing = std.testing;
const expect = testing.expect;
const expectEqual = testing.expectEqual;

test {
    var mutex = @This(){};

    try expect(mutex.tryLock());
    try expect(!mutex.tryLock());
    mutex.unlock();

    mutex.lock();
    try expect(!mutex.tryLock());
    mutex.unlock();

    try expect(mutex.tryLock());
}

const Mutex = @This();

test {
    const ntimes = 1_000_000;
    const TestCtx = struct {
        mutex: Mutex = Mutex{},
        val: usize = 0,

        fn func(self: *@This()) void {
            for (0..ntimes) |i| {
                if (i % 2 == 0)
                    self.mutex.lock()
                else while (!self.mutex.tryLock()) {}
                self.val += 1;
                self.mutex.unlock();
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
