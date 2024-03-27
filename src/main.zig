const std = @import("std");
const DB = @import("db.zig");
const MHD = @import("mhd.zig");

pub const std_options = std.Options{
    .log_level = .info,
};

pub fn main() !void {
    var gpa = std.heap.GeneralPurposeAllocator(.{}){};
    defer {
        const check = gpa.deinit();
        std.log.debug("gpa: {}", .{check});
    }

    const alloc = gpa.allocator();

    const seed: u64 = @intCast(std.time.milliTimestamp());
    var prng = std.rand.DefaultPrng.init(seed);
    const random = prng.random();

    var db_p: ?*DB.sqlite3 = null;
    const db = DB{
        .file_name = "db.sqlite",
        .db_p = &db_p,
        .alloc = &alloc,
        .random = &random,
    };
    try db.open();
    defer db.close() catch |err| {
        std.log.err("{}", .{err});
    };

    try db.initGroupsTable();

    var daemon_p: ?*MHD.MHD_Daemon = null;
    const mhd = MHD{
        .port = 3000,
        .daemon_p = &daemon_p,
        .cls = &.{
            .alloc = &alloc,
            .db = &db,
        },
    };

    try mhd.start();
    defer mhd.stop();

    var buf: [10]u8 = undefined;
    _ = try std.io.getStdIn().reader().readUntilDelimiterOrEof(buf[0..], '\n');
}
