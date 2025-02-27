const std = @import("std");

pub fn main() !void {
    var gpa = std.heap.GeneralPurposeAllocator(.{}){};
    const allocator = gpa.allocator();

    const host = [4]u8{ 127, 0, 0, 1 };
    const port = 3490;
    const address = std.net.Address.initIp4(host, port);
    const socket = try std.posix.socket(address.any.family, std.posix.SOCK.STREAM, std.posix.IPPROTO.TCP);
    const stream = std.net.Stream{ .handle = socket };
    const server = try allocator.create(std.net.Server);
    server.* = .{ .listen_address = address, .stream = stream };
    defer server.deinit();

    std.debug.print("Shadowfax Proxy running on {?}\n", .{address.in});

    while (true) {
        const conn = try server.accept();
        std.debug.print("New connection from {?}\n", .{conn.address});
        handleRequest(conn) catch |err| {
            std.debug.print("Request error: {}\n", .{err});
        };
        conn.stream.close();
    }
}

fn handleRequest(conn: std.net.Server.Connection) !void {
    var buf: [1024]u8 = undefined;
    const bytes_read = try conn.stream.read(&buf);
    const request = buf[0..bytes_read];

    if (std.mem.startsWith(u8, request, "GET ")) {
        try conn.stream.writeAll("HTTP/1.1 200 OK\r\nContent-Length: 13\r\n\r\nHello, Shadowfax!");
    } else {
        try conn.stream.writeAll("HTTP/1.1 400 Bad Request\r\n\r\n");
    }
}
