const std = @import("std");
const httpz = @import("httpz");
const DB = @import("db/db.zig");
const Handler = @import("server/Handler.zig");

const PORT = 5882;

pub const std_options = std.Options{
    .log_level = .debug,
};

pub fn main() !void {
    var gpa = std.heap.GeneralPurposeAllocator(.{ .safety = true }){};
    defer std.log.info("gpa: {}", .{gpa.deinit()});

    const allocator = gpa.allocator();

    const seed: u64 = @intCast(std.time.milliTimestamp());
    var prng = std.Random.DefaultPrng.init(seed);

    var db_p: ?*DB.sqlite3 = null;
    const db = DB{
        .file_name = "db.sqlite",
        .db_p = &db_p,
        .random = prng.random(),
    };
    try db.open();
    defer db.close() catch |err| {
        std.log.err("{}", .{err});
    };

    try db.initGroupsTable();

    const handler = Handler{ .db = &db };

    var server = try httpz.Server(*const Handler).init(allocator, .{ .port = PORT }, &handler);
    defer server.deinit();

    const cors = try server.middleware(httpz.middleware.Cors, .{
        .origin = "*",
        .headers = "content-type",
        .methods = "GET,POST",
        .max_age = "300",
    });

    var router = try server.router(.{ .middlewares = &.{cors} });

    router.get("/", Handler.homePage, .{});
    router.get("/styles.css", Handler.cssStyles, .{});
    router.get("/app.js", Handler.appJs, .{});

    router.post("/new-group", Handler.newGroup, .{});

    var group_router = router.group("/group", .{});
    group_router.get("/:group_id", Handler.groupOverview, .{});
    group_router.post("/:group_id/new-expense", Handler.newExpense, .{});

    std.log.info("Server listening on port {d}", .{PORT});
    try server.listen();
}
