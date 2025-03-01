const std = @import("std");

pub const Socket = struct {
    _address: std.net.Address,
    _stream: std.net.Stream,

    pub fn init() !Socket {
        const host = [4]u8{ 127, 0, 0, 1 };
        const port: u16 = 3000;
        const addr = std.net.Address.initIp4(host, port);
        const socket = try std.posix.socket(
            addr.any.family,
            std.posix.SOCK.STREAM,
            std.posix.IPPROTO.TCP,
        );
        const stream = std.net.Stream{ .handle = socket };
        return Socket{ ._address = addr, ._stream = stream };
    }
};
