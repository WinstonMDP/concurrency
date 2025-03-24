fn Mutexed(T: type) type {
    return struct {
        val: T,
        mutex: Mutex = Mutex{},

        fn init(val: T) @This() {
            return @This(){ .val = val };
        }

        fn acquire(self: *@This()) *T {
            self.mutex.lock();
            return &self.val;
        }
    };
}

test {
    var mutexed = Mutexed(u8).init(9);
    const val = mutexed.acquire();
    try std.testing.expectEqual(9, val.*);
    defer mutexed.mutex.unlock();
}

const std = @import("std");
const Mutex = std.Thread.Mutex;
