const std = @import("std");
const Mutex = @import("Mutex.zig");
const Condition = @import("Condition.zig");

mutex: Mutex = Mutex{},
condition: Condition = Condition{},
nthreads: usize,
narrived: usize = 0,
go: bool = false,

pub fn arriveAndWait(self: *@This()) void {
    self.mutex.lock();
    defer self.mutex.unlock();

    self.narrived += 1;
    if (self.narrived == self.nthreads) {
        self.go = true;
        self.condition.broadcast();
    }
    while (!self.go) self.condition.wait(&self.mutex);
    self.narrived -= 1;
    if (self.narrived == 0) self.go = false;
}

const Barrier = @This();
const Thread = std.Thread;

test {
    var threads: [12]Thread = undefined;
    const TestCtx = struct {
        barrier: Barrier,

        fn func(self: *@This()) void {
            self.barrier.arriveAndWait();
        }
    };
    var test_ctx = TestCtx{ .barrier = Barrier{ .nthreads = threads.len } };

    inline for (&threads) |*thread|
        thread.* = try Thread.spawn(.{}, TestCtx.func, .{&test_ctx});
    inline for (&threads) |*thread| thread.join();
}
