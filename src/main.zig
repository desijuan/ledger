const std = @import("std");
const httpz = @import("httpz");
const DB = @import("db.zig");
const Handler = @import("handler.zig");

const Ctx = Handler.Ctx;

const PORT = 5882;

pub const std_options = std.Options{
    .log_level = .info,
};

pub fn main() !void {
    var gpa = std.heap.GeneralPurposeAllocator(.{}){};
    defer std.log.info("gpa: {}", .{gpa.deinit()});

    const allocator = gpa.allocator();

    const seed: u64 = @intCast(std.time.milliTimestamp());
    var prng = std.rand.DefaultPrng.init(seed);
    const random = prng.random();

    var db_p: ?*DB.sqlite3 = null;
    const db = DB{
        .file_name = "db.sqlite",
        .db_p = &db_p,
        .random = &random,
    };
    try db.open();
    defer db.close() catch |err| {
        std.log.err("{}", .{err});
    };

    try db.initGroupsTable();

    const ctx = Ctx{
        .db = &db,
    };

    var server = try httpz.ServerCtx(*const Ctx, *const Ctx)
        .init(allocator, .{
        .port = PORT,
        .cors = .{
            .origin = "*",
            .headers = "content-type",
            .methods = "GET,POST",
            .max_age = "300",
        },
    }, &ctx);

    server.errorHandler(Handler.errorHandler);
    server.notFound(Handler.notFound);

    var router = server.router();

    router.get("/", Handler.homePage);
    router.post("/new-group", Handler.newGroup);

    var group_router = router.group("/group", .{});
    group_router.get("/:group_id", Handler.groupOverview);
    group_router.post("/:group_id/new-expense", Handler.newExpense);

    std.log.info("Server listening on port {d}", .{PORT});
    try server.listen();
}
