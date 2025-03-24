pub fn ThreadPool(nthreads: comptime_int) type {
    return struct {
        mutex: Mutex = Mutex{},
        condition: Condition = Condition{},
        threads: [nthreads]Thread = undefined,
        tasks: ArrayList(*const fn () void),
        stopped: atomic.Value(bool) = atomic.Value(bool).init(false),

        pub fn init(allocator: anytype) !@This() {
            return @This(){
                .tasks = ArrayList(*const fn () void).init(allocator),
            };
        }

        pub fn start(self: *@This()) !void {
            for (&self.threads) |*thread|
                thread.* = try Thread.spawn(.{}, work, .{self});
        }

        fn work(self: *@This()) void {
            while (!self.stopped.load(.seq_cst)) {
                self.mutex.lock();
                if (self.tasks.items.len == 0) self.condition.wait(&self.mutex);
                if (self.tasks.items.len != 0) self.tasks.pop()();
                self.mutex.unlock();
            }
        }

        pub fn submit(self: *@This(), task: *const fn () void) !void {
            {
                self.mutex.lock();
                defer self.mutex.unlock();
                try self.tasks.append(task);
            }
            self.condition.signal();
        }

        pub fn stop(self: *@This()) void {
            self.stopped.store(true, .seq_cst);
            self.condition.broadcast();
            for (self.threads) |thread| thread.join();
            self.tasks.deinit();
        }
    };
}

test {
    const TestCtx = struct {
        fn func() void {
            std.time.sleep(500_000_000);
        }
    };

    var thread_pool = try ThreadPool(12).init(test_allocator);
    try thread_pool.start();
    try thread_pool.submit(TestCtx.func);
    try thread_pool.submit(TestCtx.func);
    try thread_pool.submit(TestCtx.func);
    thread_pool.stop();
}

const std = @import("std");
const Thread = std.Thread;
const atomic = std.atomic;
const ArrayList = std.ArrayList;
const Mutex = @import("Mutex.zig");
const Condition = @import("Condition.zig");
const test_allocator = std.testing.allocator;
