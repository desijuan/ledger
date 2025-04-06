const std = @import("std");
const httpz = @import("httpz");
const utils = @import("utils.zig");
const DB = @import("db/db.zig");
const Handler = @import("server/Handler.zig");

const PORT = 5882;

pub const std_options = std.Options{
    .log_level = .info,
};

pub fn main() !void {
    var gpa_inst = std.heap.GeneralPurposeAllocator(.{ .safety = true }){};
    defer std.log.info("gpa: {}", .{gpa_inst.deinit()});

    const gpa = gpa_inst.allocator();

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

    const index: []const u8 = try utils.readFile(gpa, "frontend/public/index.html");
    defer gpa.free(index);

    const stylesheet: []const u8 = try utils.readFile(gpa, "frontend/public/styles.css");
    defer gpa.free(stylesheet);

    const js_src: []const u8 = try utils.readFile(gpa, "frontend/public/app.js");
    defer gpa.free(js_src);

    const handler = Handler{
        .db = &db,
        .index = index,
        .stylesheet = stylesheet,
        .js_src = js_src,
    };

    var server = try httpz.Server(*const Handler).init(gpa, .{ .port = PORT }, &handler);
    defer server.deinit();

    const cors = try server.middleware(httpz.middleware.Cors, .{
        .origin = "*",
        .headers = "content-type",
        .methods = "GET,POST",
        .max_age = "300",
    });

    var router = try server.router(.{ .middlewares = &.{cors} });

    var public_router = router.group("/public", .{});
    public_router.get("/styles.css", Handler.cssStyles, .{});
    public_router.get("/app.js", Handler.appJs, .{});

    var app_router = router.group("/app", .{});
    app_router.get("/*", Handler.homePage, .{});

    router.post("/new-group", Handler.newGroup, .{});

    var group_router = router.group("/group", .{});
    group_router.get("/:group_id", Handler.groupOverview, .{});
    group_router.post("/:group_id/new-expense", Handler.newExpense, .{});

    std.log.info("Server listening on port {d}", .{PORT});
    try server.listen();
    defer server.stop();
}
