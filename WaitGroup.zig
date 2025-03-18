const std = @import("std");
const Mutex = @import("Mutex.zig");
const Condition = @import("Condition.zig");
const atomic = std.atomic;

mutex: Mutex = Mutex{},
condition: Condition = Condition{},
count: atomic.Value(usize) = atomic.Value(usize).init(0),

pub fn add(self: *@This(), count: usize) void {
    _ = self.count.fetchAdd(count, .seq_cst);
}

pub fn done(self: *@This()) void {
    _ = self.count.fetchSub(1, .seq_cst);
    if (self.count.load(.seq_cst) == 0) self.condition.broadcast();
}

pub fn wait(self: *@This()) void {
    self.mutex.lock();
    while (self.count.raw != 0) self.condition.wait(&self.mutex);
    self.mutex.unlock();
}

test {
    var wait_group = @This(){};
    wait_group.add(2);
    wait_group.done();
    wait_group.done();
    wait_group.wait();
}
