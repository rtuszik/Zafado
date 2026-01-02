const std = @import("std");
const log = std.log.scoped(.printer);

pub const Commands = struct {
    pub const INIT = &[_]u8{ 0x1B, 0x40 };

    pub const BOLD_ON = &[_]u8{ 0x1B, 0x45, 1 };
    pub const BOLD_OFF = &[_]u8{ 0x1B, 0x45, 0 };
    pub const UNDERLINE_ON = &[_]u8{ 0x1B, 0x2D, 1 };
    pub const UNDERLINE_OFF = &[_]u8{ 0x1B, 0x2D, 0 };

    // Alignment
    pub const ALIGN_LEFT = &[_]u8{ 0x1B, 0x61, 0 };
    pub const ALIGN_CENTER = &[_]u8{ 0x1B, 0x61, 1 };
    pub const ALIGN_RIGHT = &[_]u8{ 0x1B, 0x61, 2 };

    // Size
    pub const SIZE_NORMAL = &[_]u8{ 0x1D, 0x21, 0x00 };
    pub const SIZE_DOUBLE = &[_]u8{ 0x1D, 0x21, 0x11 };
    pub const SIZE_TRIPLE = &[_]u8{ 0x1D, 0x21, 0x22 };

    // Paper control
    pub const PARTIAL_CUT = &[_]u8{ 0x1D, 0x56, 1 };
};

pub const TextStyle = struct {
    bold: bool = false,
    underline: bool = false,
    textAlign: enum { left, center, right } = .left,
    size: enum { normal, double, triple } = .double,
};

pub const Printer = struct {
    stream: std.net.Stream,

    pub fn init(ip: []const u8, port: u16) !Printer {
        log.info("Attempting Connection to {s}:{d}", .{ ip, port });

        const address = try std.net.Address.parseIp(ip, port);

        const stream = try std.net.tcpConnectToAddress(address);

        var buf: [128]u8 = undefined;
        var writer = stream.writer(&buf);
        _ = try writer.interface.writeAll(Commands.INIT);
        try writer.interface.flush();

        return Printer{ .stream = stream };
    }

    pub fn deinit(self: Printer) void {
        self.stream.close();
    }

    // utility functions

    pub fn feedLines(self: Printer, lines: u8) !void {
        const cmd = [_]u8{ 0x1B, 0x64, lines };
        var buf: [128]u8 = undefined;
        var writer = self.stream.writer(&buf);
        _ = try writer.interface.writeAll(&cmd);
        try writer.interface.flush();
    }

    pub fn cut(self: Printer) !void {
        try self.feedLines(5);

        var buf: [128]u8 = undefined;
        var writer = self.stream.writer(&buf);
        _ = try writer.interface.writeAll(Commands.PARTIAL_CUT);
        try writer.interface.flush();

        try self.feedLines(1);
    }

    // text

    pub fn printStyled(self: Printer, text: []const u8, style: TextStyle) !void {
        var buf: [1024]u8 = undefined;
        var writer = self.stream.writer(&buf);

        const align_cmd = switch (style.textAlign) {
            .left => Commands.ALIGN_LEFT,
            .center => Commands.ALIGN_CENTER,
            .right => Commands.ALIGN_RIGHT,
        };

        _ = try writer.interface.writeAll(align_cmd);

        const size_cmd = switch (style.size) {
            .normal => Commands.SIZE_NORMAL,
            .double => Commands.SIZE_DOUBLE,
            .triple => Commands.SIZE_TRIPLE,
        };

        _ = try writer.interface.writeAll(size_cmd);

        if (style.bold) {
            _ = try writer.interface.writeAll(Commands.BOLD_ON);
        }

        if (style.underline) {
            _ = try writer.interface.writeAll(Commands.UNDERLINE_ON);
        }

        _ = try writer.interface.writeAll(text);
        _ = try writer.interface.writeAll("\n");

        try writer.interface.flush();

        try self.resetStyle();
    }

    pub fn resetStyle(self: Printer) !void {
        var buf: [128]u8 = undefined;
        var writer = self.stream.writer(&buf);

        _ = try writer.interface.writeAll(Commands.ALIGN_LEFT);
        _ = try writer.interface.writeAll(Commands.SIZE_NORMAL);
        _ = try writer.interface.writeAll(Commands.BOLD_OFF);
        _ = try writer.interface.writeAll(Commands.UNDERLINE_OFF);

        try writer.interface.flush();
    }

    // presets
    pub fn printHeader(self: Printer, text: []const u8) !void {
        try self.printStyled(text, .{ .bold = true, .textAlign = .center });
        
        var buf: [128]u8 = undefined;
        var writer = self.stream.writer(&buf);
        _ = try writer.interface.writeAll("\n");
        try writer.interface.flush();
    }

    pub fn printTodo(self: Printer, text: []const u8, allocator: std.mem.Allocator) !void {
        try self.printHeader("Zafado");
        try self.feedLines(1);

        var buf: [256]u8 = undefined;
        var writer = self.stream.writer(&buf);

        _ = try writer.interface.writeAll("  [ ] ");
        try writer.interface.flush();
        try self.printStyled(text, .{ .bold = true });

        try self.feedLines(1);

        const timestamp = std.time.timestamp();

        const time_str = try std.fmt.allocPrint(allocator, "Printed @: {d}", .{timestamp});
        defer allocator.free(time_str);

        _ = try writer.interface.writeAll(time_str);
        _ = try writer.interface.writeAll("\n");
        try writer.interface.flush();

        try self.cut();
    }
};

test "BOLD_ON command has correct bytes" {
    try std.testing.expectEqualSlices(u8, &[_]u8{ 0x1B, 0x45, 1 }, Commands.BOLD_ON);
}

test "TextStyle defaults are correct" {
    const testing = std.testing;
    const style = TextStyle{};
    try testing.expect(style.bold == false);
    try testing.expect(style.underline == false);
    try testing.expectEqual(.left, style.textAlign);
    try testing.expectEqual(.normal, style.size);
}
