const std = @import("std");
const httpz = @import("httpz");

const Logger = @This();

pub const Config = struct {};

pub fn init(_: Config) error{}!Logger {
    return Logger{};
}

pub fn execute(_: *const Logger, req: *httpz.Request, res: *httpz.Response, executor: anytype) !void {
    defer std.log.info("{d} {s} {} {s}", .{ res.status, @tagName(req.method), req.address, req.url.path });
    return executor.next();
}
