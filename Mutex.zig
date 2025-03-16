const std = @import("std");
const atomic = std.atomic;
const Thread = std.Thread;
const Futex = Thread.Futex;
const assert = std.debug.assert;

locked: atomic.Value(u32) = atomic.Value(u32).init(0),

pub fn lock(self: *@This()) void {
    while (!self.tryLock()) {
        Futex.wait(&self.locked, 1);
    }
}

pub fn tryLock(self: *@This()) bool {
    return self.locked.swap(1, .seq_cst) == 0;
}

pub fn unlock(self: *@This()) void {
    assert(self.locked.load(.seq_cst) == 1);
    assert(!self.tryLock());

    self.locked.store(0, .seq_cst);
    Futex.wake(&self.locked, 1);
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
