const std = @import("std");
const httpz = @import("httpz");
const utils = @import("utils.zig");
const DB = @import("db/db.zig");
const Handler = @import("server/Handler.zig");
const Logger = @import("server/Logger.zig");

const ADDRESS = "0.0.0.0";
const PORT = 5882;

pub const std_options = std.Options{
    .log_level = .info,
};

var server_instance: ?*httpz.Server(*const Handler) = null;

fn shutdown(_: c_int) callconv(.C) void {
    if (server_instance) |server| {
        std.log.info("Server shutting down", .{});
        server_instance = null;
        server.stop();
    }
}

pub fn main() !void {
    if (comptime @import("builtin").os.tag == .windows) {
        @compileError("Using Windows, shame on you!");
    }

    var gpa_inst = std.heap.GeneralPurposeAllocator(.{ .safety = true }){};
    defer std.log.debug("gpa: {}", .{gpa_inst.deinit()});

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

    const js_app: []const u8 = try utils.readFile(gpa, "frontend/public/app.js");
    defer gpa.free(js_app);

    const handler = Handler{
        .db = &db,
        .index = index,
        .stylesheet = stylesheet,
        .js_app = js_app,
    };

    var server = try httpz.Server(*const Handler).init(gpa, .{ .port = PORT, .address = ADDRESS }, &handler);
    defer server.deinit();

    const cors = try server.middleware(httpz.middleware.Cors, .{
        .origin = "*",
        .headers = "content-type",
        .methods = "GET,POST",
        .max_age = "300",
    });

    const logger = try server.middleware(Logger, .{});

    var router = try server.router(.{ .middlewares = &.{ logger, cors } });

    var public_router = router.group("/public", .{});
    public_router.get("/styles.css", Handler.static(.CSS, "stylesheet"), .{});
    public_router.get("/app.js", Handler.static(.JS, "js_app"), .{});

    var app_router = router.group("/app", .{});
    app_router.get("/*", Handler.static(.HTML, "index"), .{});

    router.post("/new-group", Handler.newGroup, .{});

    var group_router = router.group("/group", .{});
    group_router.get("/:group_id", Handler.groupOverview, .{});
    group_router.post("/:group_id/new-expense", Handler.newExpense, .{});

    std.posix.sigaction(std.posix.SIG.INT, &.{
        .handler = .{ .handler = shutdown },
        .mask = std.posix.empty_sigset,
        .flags = 0,
    }, null);
    std.posix.sigaction(std.posix.SIG.TERM, &.{
        .handler = .{ .handler = shutdown },
        .mask = std.posix.empty_sigset,
        .flags = 0,
    }, null);

    std.log.info("Server listening on {?s}:{?d}", .{ server.config.address, server.config.port });
    server_instance = &server;
    try server.listen();
}
