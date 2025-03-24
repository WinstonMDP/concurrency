mutex: Mutex = Mutex{},
condition: Condition = Condition{},
npermits: usize,
max_permits: if (mode == .Debug) usize else void,

pub fn init(npermits: usize) @This() {
    return @This(){
        .npermits = npermits,
        .max_permits = if (mode == .Debug) npermits else void{},
    };
}

pub fn acquire(self: *@This()) void {
    self.mutex.lock();
    while (self.npermits == 0) self.condition.wait(&self.mutex);
    self.npermits -= 1;
    self.mutex.unlock();
}

pub fn release(self: *@This()) void {
    self.mutex.lock();
    self.npermits += 1;
    if (mode == .Debug) assert(self.npermits <= self.max_permits);
    self.mutex.unlock();
}

test {
    var semaphore = @This().init(3);
    semaphore.acquire();
    semaphore.release();
    try if (mode == .Debug)
        expectEqual(semaphore.max_permits, 3)
    else
        expectEqual(semaphore.max_permits, void{});
}

const std = @import("std");
const assert = std.debug.assert;
const expectEqual = std.testing.expectEqual;
const builtin = @import("builtin");
const mode = builtin.mode;
const Condition = @import("Condition.zig");
const Mutex = @import("Mutex.zig");
