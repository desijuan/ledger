const c = @cImport({
    @cInclude("sys/types.h");
    @cInclude("sys/select.h");
    @cInclude("sys/socket.h");
    @cInclude("microhttpd.h");
});

pub const MHD_Daemon = c.MHD_Daemon;

const std = @import("std");
const DB = @import("db.zig");
const Router = @import("router.zig");

const HttpUrl = Router.HttpUrl;
const HttpMethod = Router.HttpMethod;
const HttpVersion = Router.HttpVersion;
const Route = Router.Route;

const MAX_UPLOAD_DATA_SIZE = 0x1000;

const Cls = struct {
    alloc: *const std.mem.Allocator,
    db: *const DB,
};

port: u16,
daemon_p: *?*c.MHD_Daemon,
cls: *const Cls,

const Self = @This();

pub fn start(self: *const Self) !void {
    const mhd_version = c.MHD_get_version();
    std.log.info("MHD v{s}", .{mhd_version});

    const global_cls: *anyopaque = @constCast(self.cls);

    self.daemon_p.* = c.MHD_start_daemon(
        c.MHD_USE_INTERNAL_POLLING_THREAD | c.MHD_USE_ERROR_LOG,
        self.port,
        null,
        null,
        &accessHandlerCallback,
        global_cls,
        c.MHD_OPTION_NOTIFY_COMPLETED,
        &requestCompletedCallback,
        global_cls,
        c.MHD_OPTION_END,
    ) orelse return error.StartMHDDaemon;
    std.log.info("Server listening on port {d}", .{self.port});
}

pub fn stop(self: *const Self) void {
    c.MHD_stop_daemon(self.daemon_p.*);
    self.daemon_p.* = null;
}

const ReqCls = struct {
    httpUrl: HttpUrl,
    httpMethod: HttpMethod,
    httpVersion: HttpVersion,
    route: Route,
    data: ?[]const u8,

    fn new(
        allocator: *const std.mem.Allocator,
        httpUrl: HttpUrl,
        httpMethod: HttpMethod,
        httpVersion: HttpVersion,
    ) !*const ReqCls {
        const route = Router.route(httpUrl, httpMethod, httpVersion);

        const reqCls = try allocator.create(ReqCls);

        reqCls.httpUrl = httpUrl;
        reqCls.httpMethod = httpMethod;
        reqCls.httpVersion = httpVersion;
        reqCls.route = route;
        reqCls.data = null;

        return reqCls;
    }
};

fn accessHandlerCallback(
    global_cls: ?*anyopaque,
    conn: ?*c.MHD_Connection,
    url: [*c]const u8,
    method: [*c]const u8,
    version: [*c]const u8,
    upload_data: [*c]const u8,
    upload_data_size: [*c]usize,
    req_cls: [*c]?*anyopaque,
) callconv(.C) c.MHD_Result {
    const cls: *const Cls = @alignCast(@ptrCast(global_cls));

    if (req_cls.* == null) {
        std.log.info("{s} {s} {s}", .{ method, url, version });

        const u_len = std.mem.len(url);
        const httpUrl = HttpUrl.parse(url[0..u_len]);

        const m_len = std.mem.len(method);
        const httpMethod = HttpMethod.parse(method[0..m_len]);

        const v_len = std.mem.len(version);
        const httpVersion = HttpVersion.parse(version[0..v_len]);

        const reqCls = ReqCls.new(cls.alloc, httpUrl, httpMethod, httpVersion) catch
            return sendTxtStatic(conn, 500, "Error\n");

        req_cls.* = @as(*anyopaque, @constCast(reqCls));
        return c.MHD_YES;
    }

    const reqCls: *ReqCls = @alignCast(@ptrCast(req_cls.*));

    if (upload_data_size.* > 0) {
        if (upload_data_size.* > MAX_UPLOAD_DATA_SIZE) {
            reqCls.route = .{ .ERROR = .{
                .status_code = 400,
                .msg = "UploadDataTooBig",
            } };
            upload_data_size.* = 0;
            return c.MHD_YES;
        }

        switch (reqCls.httpMethod) {
            .POST => {
                reqCls.data = cls.alloc.dupe(
                    u8,
                    upload_data[0..upload_data_size.*],
                ) catch |err| blk: {
                    reqCls.route = .{ .ERROR = .{
                        .status_code = 500,
                        .msg = @errorName(err),
                    } };
                    break :blk null;
                };
            },
            else => {},
        }

        upload_data_size.* = 0;
        return c.MHD_YES;
    }

    return switch (reqCls.route) {
        .ERROR => |err| handleError(cls, conn, err),
        .NOT_FOUND => handleNotFound(conn),
        .HOME_PAGE => handleHomePage(conn),
        .NEW_GROUP => handleNewGroup(cls, conn, reqCls),
        .GROUP_OVERVIEW => |group_id| handleGroupOverview(cls, conn, group_id),
        .NEW_EXPENSE => |group_id| handleNewExpense(cls, conn, group_id, reqCls),
    };
}

fn requestCompletedCallback(
    global_cls: ?*anyopaque,
    _: ?*c.MHD_Connection,
    req_cls: [*c]?*anyopaque,
    _: c.MHD_RequestTerminationCode,
) callconv(.C) void {
    const cls: *const Cls = @alignCast(@ptrCast(global_cls));
    const reqCls: *const ReqCls = @alignCast(@ptrCast(req_cls.*));

    if (reqCls.data) |data| cls.alloc.free(data);
    cls.alloc.destroy(reqCls);
    req_cls.* = null;
}

fn sendTxtStatic(
    conn: ?*c.MHD_Connection,
    status_code: u32,
    bytes: []const u8,
) c.MHD_Result {
    const response = c.MHD_create_response_from_buffer_static(
        bytes.len,
        @as(*const anyopaque, @ptrCast(bytes.ptr)),
    ) orelse return c.MHD_NO;
    defer c.MHD_destroy_response(response);

    if (c.MHD_add_response_header(
        response,
        "Content-Type",
        "text/plain",
    ) != c.MHD_YES) return c.MHD_NO;

    return c.MHD_queue_response(conn, status_code, response);
}

fn sendJson(
    cls: *const Cls,
    conn: ?*c.MHD_Connection,
    status_code: u32,
    json_data: anytype,
) c.MHD_Result {
    const json = std.json.stringifyAlloc(
        cls.alloc.*,
        json_data,
        .{ .whitespace = .minified },
    ) catch return c.MHD_NO;
    defer cls.alloc.free(json);

    const response = c.MHD_create_response_from_buffer_copy(
        json.len,
        @as(*const anyopaque, @ptrCast(json.ptr)),
    ) orelse return c.MHD_NO;
    defer c.MHD_destroy_response(response);

    if (c.MHD_add_response_header(
        response,
        "Content-Type",
        "application/json",
    ) != c.MHD_YES) return c.MHD_NO;

    return c.MHD_queue_response(conn, status_code, response);
}

const ErrorJson = struct {
    @"error": []const u8,
};

fn handleError(
    cls: *const Cls,
    conn: ?*c.MHD_Connection,
    err: Router.Error,
) c.MHD_Result {
    std.log.err("{s}", .{err.msg});
    return sendJson(cls, conn, err.status_code, ErrorJson{ .@"error" = err.msg });
}

fn handleNotFound(
    conn: ?*c.MHD_Connection,
) c.MHD_Result {
    return sendTxtStatic(conn, 404, "Not Found\n");
}

fn handleHomePage(
    conn: ?*c.MHD_Connection,
) c.MHD_Result {
    return sendTxtStatic(conn, 200, "Hello my friend!\n");
}

const NewGroupReqInfo = struct {
    name: []const u8,
    description: []const u8,
    members: []const []const u8,
};

fn handleNewGroup(
    cls: *const Cls,
    conn: ?*c.MHD_Connection,
    reqCls: *ReqCls,
) c.MHD_Result {
    const data = reqCls.data orelse
        return sendJson(cls, conn, 500, ErrorJson{ .@"error" = "Error" });
    defer {
        cls.alloc.free(data);
        reqCls.data = null;
    }

    const parsedNewGroupReqInfo = std.json.parseFromSlice(
        NewGroupReqInfo,
        cls.alloc.*,
        data,
        .{},
    ) catch |err| return sendJson(cls, conn, 500, ErrorJson{ .@"error" = @errorName(err) });
    defer parsedNewGroupReqInfo.deinit();

    const grp = parsedNewGroupReqInfo.value;

    const group_id = cls.db.newGroup(grp.name, grp.description, grp.members) catch |err|
        return sendJson(cls, conn, 500, ErrorJson{ .@"error" = @errorName(err) });

    return sendJson(cls, conn, 200, .{
        .success = true,
        .group_id = group_id,
    });
}

const GroupBoard = struct {
    group_id: u32,
    name: []const u8,
    description: ?[]const u8,
    members: []const DB.Member,
    trs: []const DB.Tr,
};

fn handleGroupOverview(
    cls: *const Cls,
    conn: ?*c.MHD_Connection,
    group_id: u32,
) c.MHD_Result {
    const optionalGroupInfo = cls.db.getGroupInfo(group_id) catch |err|
        return sendJson(cls, conn, 500, ErrorJson{ .@"error" = @errorName(err) });

    const groupInfo: *const DB.GroupInfo = optionalGroupInfo orelse
        return sendJson(cls, conn, 200, .{
        .success = false,
        .msg = "GroupNotFound",
    });
    defer {
        cls.alloc.free(groupInfo.name);
        cls.alloc.free(groupInfo.description);
        cls.alloc.destroy(groupInfo);
    }

    const members = cls.db.getMembers(group_id) catch |err|
        return sendJson(cls, conn, 500, ErrorJson{ .@"error" = @errorName(err) });
    defer {
        for (members) |m| cls.alloc.free(m.name);
        cls.alloc.free(members);
    }

    const trs = cls.db.getTrs(group_id) catch |err|
        return sendJson(cls, conn, 500, ErrorJson{ .@"error" = @errorName(err) });
    defer {
        for (trs) |t| cls.alloc.free(t.description);
        cls.alloc.free(trs);
    }

    return sendJson(cls, conn, 200, .{
        .success = true,
        .group_board = .{
            .group_id = group_id,
            .name = groupInfo.name,
            .description = groupInfo.description,
            .members = members,
            .trs = trs,
        },
    });
}

const NewTrReqInfo = struct {
    from_id: i64,
    to_id: i64,
    amount: i64,
    description: []const u8,
};

fn handleNewExpense(
    cls: *const Cls,
    conn: ?*c.MHD_Connection,
    group_id: u32,
    reqCls: *ReqCls,
) c.MHD_Result {
    const data = reqCls.data orelse
        return sendJson(cls, conn, 500, ErrorJson{ .@"error" = "Error" });
    defer {
        cls.alloc.free(data);
        reqCls.data = null;
    }

    const parsedNewTrReqInfo = std.json.parseFromSlice(
        NewTrReqInfo,
        cls.alloc.*,
        data,
        .{},
    ) catch |err| return sendJson(cls, conn, 500, ErrorJson{ .@"error" = @errorName(err) });
    defer parsedNewTrReqInfo.deinit();

    const tr = parsedNewTrReqInfo.value;

    const tr_id = cls.db.newTr(
        group_id,
        tr.from_id,
        tr.to_id,
        tr.amount,
        tr.description,
    ) catch |err| return sendJson(cls, conn, 500, ErrorJson{ .@"error" = @errorName(err) });

    return sendJson(cls, conn, 200, .{
        .success = true,
        .tr_id = tr_id,
    });
}
