const std = @import("std");
const net = std.net;
const mem = std.mem;
const Queue = @import("queue.zig").Queue;
const log = std.log.scoped(.server);

pub const Server = struct {
    allocator: mem.Allocator,
    queue: *Queue,
    server: net.Server,

    pub fn init(allocator: mem.Allocator, queue: *Queue, port: u16) !Server {
        // create listen addr
        // TODO make configurable
        // resolveIP supports ipv6, rest doesn't yet.
        const address = try net.Address.resolveIp("0.0.0.0", port);

        // create server, bind to  addr
        const server = try address.listen(.{});

        log.info("Server listening on port {}", .{port});

        return Server{
            .allocator = allocator,
            .queue = queue,
            .server = server,
        };
    }

    pub fn deinit(self: *Server) void {
        self.server.deinit();
    }

    pub fn run(self: *Server) !void {
        log.info("Server started, waiting for conenctions.", .{});

        while (true) {
            const connection = try self.server.accept();

            log.info("Got conection from {f}", .{connection.address});

            self.handleConnection(connection) catch |err| {
                log.err("Failed to handle connection: {}", .{err});
            };
        }
    }

    pub fn handleConnection(self: *Server, connection: net.Server.Connection) !void {
        defer connection.stream.close();

        var read_buf: [4096]u8 = undefined;
        var buffer: [1024]u8 = undefined;

        // Use buffered reader
        var reader = connection.stream.reader(&read_buf);
        const bytes_read = try reader.interface().readSliceShort(&buffer);

        if (bytes_read == 0) {
            log.debug("Empty request received", .{});
            return;
        }

        const request = buffer[0..bytes_read];

        log.debug("Raw request:\n{s}", .{request});

        try self.parseAndHandle(connection, request);
    }

    pub fn parseAndHandle(self: *Server, connection: net.Server.Connection, request: []const u8) !void {
        // Prepare buffered writer
        var write_buf: [4096]u8 = undefined;
        var writer = connection.stream.writer(&write_buf);

        // check for http header separator
        const header_end = mem.indexOf(u8, request, "\r\n\r\n");

        //if separator exists, header is everything before, else no body exists.
        const headers = if (header_end) |end| request[0..end] else request;

        //if body exists, its 4 bytes after separator (bc. sep is 4 bytes itself)
        const body = if (header_end) |end|
            if (end + 4 < request.len) request[end + 4 ..] else ""
        else
            "";

        const first_line_end = mem.indexOf(u8, headers, "\r\n") orelse headers.len;
        const first_line = headers[0..first_line_end];

        // splitting first line into parts to extract methid, path and protocol.
        // e.g. "POST", "/todo", "HTTP/1.1"
        var parts = mem.tokenizeScalar(u8, first_line, ' ');

        // return error if method or parts don't exist
        const request_method = parts.next() orelse return error.InvalidRequest;
        const path = parts.next() orelse return error.InvalidRequest;

        const protocol = parts.next();
        log.info("Request: {s} {s} {?s}", .{ request_method, path, protocol });

        // using mem.eql to compare string contents byte by byte. (request_method == "POST" would compare addresses in memory and not text)
        if (mem.eql(u8, request_method, "POST") and mem.eql(u8, path, "/todo")) {
            if (body.len == 0) {
                const response = "HTTP/1.1 201 Created\r\nContent-Length: 14\r\n\r\nTodo printed!\n";
                _ = try writer.interface.writeAll(response);
                try writer.interface.flush();
                return;
            }
            try self.queue.add(body);

            const response = "HTTP/1.1 201 Created\r\nContent-Length: 14\r\n\r\nTodo printed! \n";
            _ = try writer.interface.writeAll(response);
            try writer.interface.flush();
        } else if (mem.eql(u8, request_method, "GET") and mem.eql(u8, path, "/status")) {
            const count = self.queue.count();

            const response_body = try std.fmt.allocPrint(self.allocator, "Queue has {} items\n", .{count});
            defer self.allocator.free(response_body);

            const response = try std.fmt.allocPrint(self.allocator, "HTTP/1.1 200 OK\r\nContent-Length: {}\r\n\r\n{s}", .{ response_body.len, response_body });

            defer self.allocator.free(response);

            _ = try writer.interface.writeAll(response);
            try writer.interface.flush();
        } else {
            const response = "HTTP/1.1 404 Not Found\r\nContent-Length: 9\r\n\r\nNotFound";
            _ = try writer.interface.writeAll(response);
            try writer.interface.flush();
        }
    }
};
