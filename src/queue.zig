const std = @import("std");
const Printer = @import("printer.zig").Printer;
const log = std.log.scoped(.queue);

pub const Todo = struct {
    text: []const u8,
};

pub const Queue = struct {
    items: std.ArrayList(Todo),
    printer: *Printer,
    allocator: std.mem.Allocator,

    pub fn init(allocator: std.mem.Allocator, printer: *Printer) Queue {
        log.debug("Initializing Queue", .{});
        return Queue{
            .items = .{},
            .printer = printer,
            .allocator = allocator,
        };
    }

    pub fn deinit(self: *Queue) void {
        log.debug("Deinitialized Queue", .{});
        self.items.deinit(self.allocator);
    }

    pub fn add(self: *Queue, text: []const u8) !void {
        self.printer.printTodo(text, self.allocator) catch |err| {
            log.warn("Print failed: {}, queueing todo: {s}", .{ err, text });

            const todo = Todo{ .text = text };
            try self.items.append(self.allocator, todo);
            return;
        };
        log.info("Successfully printed: {s}", .{text});
    }

    pub fn count(self: Queue) usize {
        return self.items.items.len;
    }

    pub fn retryPending(self: *Queue) !void {
        var i: usize = 0;
        while (i < self.items.items.len) {
            const todo = self.items.items[i];

            self.printer.printHeader(todo.text) catch |err| {
                log.warn("Retry failed for: {s}, error: {}", .{ todo.text, err });
                i += 1;
                continue;
            };

            log.info("Successfully printed queued item: {s}", .{todo.text});
            _ = self.items.orderedRemove(self.allocator, i);
        }
    }
};

test "Queue Init and Destroy" {
    const testing = std.testing;
    const allocator = testing.allocator;

    var printer = Printer{
        .stream = undefined,
    };

    var queue = Queue.init(allocator, &printer);
    defer queue.deinit();

    try testing.expectEqual(@as(usize, 0), queue.items.items.len);
}

test "Queue Operations" {
    const testing = std.testing;
    const allocator = testing.allocator;
    var printer = Printer{ .stream = undefined };
    var queue = Queue.init(allocator, &printer);
    defer queue.deinit();

    try testing.expectEqual(@as(usize, 0), queue.count());

    const todo = Todo{ .text = "Test todo" };
    try queue.items.append(todo);
    try testing.expectEqual(@as(usize, 1), queue.count());
}
