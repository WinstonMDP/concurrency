futex_queue: atomic.Value(u32) = atomic.Value(u32).init(0),

pub fn wait(self: *@This(), mutex: *Mutex) void {
    assert(!mutex.tryLock());

    const old = self.futex_queue.raw;
    mutex.unlock();
    Futex.wait(&self.futex_queue, old);
    mutex.lock();
}

pub fn signal(self: *@This()) void {
    _ = self.futex_queue.fetchAdd(1, .seq_cst);
    Futex.wake(&self.futex_queue, 1);
}

pub fn broadcast(self: *@This()) void {
    _ = self.futex_queue.fetchAdd(1, .seq_cst);
    Futex.wake(&self.futex_queue, std.math.maxInt(u32));
}

test {
    const TestCtx = struct {
        mutex: Mutex = Mutex{},
        condition: Condition = Condition{},
        flag: bool = false,

        fn consumer(self: *@This()) void {
            self.mutex.lock();
            while (!self.flag) {
                self.condition.wait(&self.mutex);
            }
            self.mutex.unlock();
        }

        fn producer(self: *@This()) void {
            self.mutex.lock();
            self.flag = true;
            self.mutex.unlock();
            self.condition.signal();
            self.mutex.lock();
            assert(self.flag);
            self.mutex.unlock();
        }
    };
    var test_ctx = TestCtx{};

    const thread = try std.Thread.spawn(.{}, TestCtx.producer, .{&test_ctx});
    test_ctx.consumer();
    thread.join();
}

test {
    const ntimes = 100_000;
    var threads: [12]Thread = undefined;
    var buf: [ntimes * threads.len]u8 = undefined;
    var fba = std.heap.FixedBufferAllocator.init(&buf);
    const allocator = fba.allocator();
    const TestCtx = struct {
        array_list: ArrayList(bool),
        mutex: Mutex = Mutex{},
        condition: Condition = Condition{},

        fn func(self: *@This()) void {
            for (0..ntimes) |i| {
                if (i % 2 == 0) {
                    self.mutex.lock();
                    self.array_list.append(true) catch unreachable;
                    self.mutex.unlock();
                    self.condition.signal();
                } else {
                    self.mutex.lock();
                    defer self.mutex.unlock();

                    while (self.array_list.items.len == 0)
                        self.condition.wait(&self.mutex);

                    _ = self.array_list.pop();
                }
            }
        }
    };
    var test_ctx = TestCtx{ .array_list = try ArrayList(bool).initCapacity(allocator, buf.len) };

    inline for (&threads) |*thread|
        thread.* = try Thread.spawn(.{}, TestCtx.func, .{&test_ctx});
    inline for (&threads) |*thread| thread.join();
}

const Condition = @This();
const std = @import("std");
const assert = std.debug.assert;
const atomic = std.atomic;
const Thread = std.Thread;
const Futex = Thread.Futex;
const expectEqual = std.testing.expectEqual;
const ArrayList = std.ArrayList;
const Mutex = @import("Mutex.zig");
