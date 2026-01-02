const std = @import("std");
const Printer = @import("printer.zig").Printer;
const Queue = @import("queue.zig").Queue;
const Server = @import("server.zig").Server;
const Config = @import("config.zig");

const colors = struct {
    const red = "\x1b[91m";
    const yellow = "\x1b[93m";
    const green = "\x1b[92m";
    const cyan = "\x1b[96m";
    const gray = "\x1b[90m";
    const reset = "\x1b[0m";
};

pub fn main() !void {
    std.log.info("This is Zafado", .{});

    var gpa = std.heap.GeneralPurposeAllocator(.{}){};
    defer _ = gpa.deinit();
    const allocator = gpa.allocator();

    var config = try Config.load(allocator, "config.toml");
    defer config.deinit(allocator);

    std.log.debug("Initializing Printer", .{});
    var printer = try Printer.init(config.printer.network.ip, config.printer.network.port);
    defer printer.deinit();

    std.log.debug("Initializing Queue", .{});
    var queue = Queue.init(allocator, &printer);
    defer queue.deinit();

    std.log.debug("Initializing HTTP Server", .{});
    var server = try Server.init(allocator, &queue, config.server.port);
    defer server.deinit();

    std.log.info("HTTP Server ready on http://localhost:8080", .{});
    std.log.info("Press Ctrl + C to stop", .{});
    try server.run();
}

pub const std_options: std.Options = .{
    .log_level = if (@import("builtin").mode == .Debug) .debug else .info,
    .log_scope_levels = &[_]std.log.ScopeLevel{
        .{ .scope = .printer, .level = .debug },
        .{ .scope = .server, .level = .debug },
        .{ .scope = .queue, .level = .debug },
        .{ .scope = .config, .level = .debug },
    },
    .logFn = logConf,
};

pub fn logConf(
    comptime level: std.log.Level,
    comptime scope: @Type(.enum_literal),
    comptime format: []const u8,
    args: anytype,
) void {

    // direct towards correct output
    var buf: [4096]u8 = undefined;
    const stderr_file = std.fs.File.stderr();
    const stdout_file = std.fs.File.stdout();
    var writer = if (level == .err) stderr_file.writer(&buf) else stdout_file.writer(&buf);

    const level_color = switch (level) {
        .err => colors.red,
        .warn => colors.yellow,
        .info => colors.green,
        .debug => colors.cyan,
    };

    // friendly name for scope
    const scope_name = if (scope == .default) "main" else @tagName(scope);

    // Print: [scope] LEVEL: message
    writer.interface.print("{s}[{s}]{s} {s}{s}{s}: ", .{
        colors.gray,
        scope_name,
        colors.reset,
        level_color,
        @tagName(level),
        colors.reset,
    }) catch return;

    writer.interface.print(format ++ "\n", args) catch return;
    writer.interface.flush() catch return;
}
