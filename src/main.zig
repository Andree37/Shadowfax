const std = @import("std");

pub fn main() !void {
    // var gpa = std.heap.GeneralPurposeAllocator(.{}){};
    // const allocator = gpa.allocator();

    const address = try std.net.Address.parseIp4("127.0.0.1", 8080);
    var server = try std.net.Server.init(.{ .reuse_address = true });
    defer server.deinit();

    try server.listen(address);
    std.debug.print("Shadowfax Proxy running on {s}:{}\n", .{ address.ip4, address.port });

    while (true) {
        var conn = try server.accept();
        std.debug.print("New connection from {s}\n", .{conn.address});
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
