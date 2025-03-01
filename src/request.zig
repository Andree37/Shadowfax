const std = @import("std");

pub fn read_request(conn: std.net.Server.Connection, buffer: []u8) !void {
    const reader = conn.stream.reader();
    _ = try reader.read(buffer);
}
