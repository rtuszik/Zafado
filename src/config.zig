const std = @import("std");
const log = std.log.scoped(.config);

pub const Config = struct {
    printer: PrinterConfig,
    server: ServerConfig,

    pub const PrinterConfig = struct {
        ip: []const u8,
        port: u16,
    };

    pub const ServerConfig = struct {
        port: u16,
    };
    pub fn deinit(self: *Config, allocator: std.mem.Allocator) void {
        allocator.free(self.printer.ip);
    }
};

pub fn load(allocator: std.mem.Allocator, path: []const u8) !Config {
    const file = try std.fs.cwd().openFile(path, .{});
    defer file.close();

    const file_size = try file.getEndPos();
    const contents = try allocator.alloc(u8, file_size);
    defer allocator.free(contents);
    _ = try file.read(contents);

    var config = Config{
        .printer = .{
            .ip = try allocator.dupe(u8, "192.168.1.1"),
            .port = 9100,
        },
        .server = .{
            .port = 8080,
        },
    };

    var lines = std.mem.tokenizeScalar(u8, contents, '\n');

    while (lines.next()) |line| {
        if (line.len == 0 or line[0] == '#') continue;

        const eq_index = std.mem.indexOf(u8, line, "=") orelse continue;
        const key = std.mem.trim(u8, line[0..eq_index], " \t");
        const value = std.mem.trim(u8, line[eq_index + 1 ..], " \t");

        if (std.mem.eql(u8, key, "printer.ip")) {
            config.printer.ip = try allocator.dupe(u8, value);
        } else if (std.mem.eql(u8, key, "printer.port")) {
            config.printer.port = try std.fmt.parseInt(u16, value, 10);
        } else if (std.mem.eql(u8, key, "server.port")) {
            config.server.port = try std.fmt.parseInt(u16, value, 10);
        }

        log.info("Config Loaded: printer={s}:{}, server port = {}", .{ config.printer.ip, config.printer.port, config.server.port });
    }

    return config;
}
