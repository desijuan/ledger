const std = @import("std");
const httpz = @import("httpz");

const DB = @import("../db/db.zig");
const GroupInfo = DB.GroupInfo;
const Member = DB.Member;
const Tr = DB.Tr;

db: *const DB,
index: []const u8,
stylesheet: []const u8,
js_app: []const u8,

const Self = @This();

pub fn uncaughtError(self: *const Self, req: *httpz.Request, res: *httpz.Response, err: anyerror) void {
    return switch (err) {
        error.SyntaxError,
        error.InvalidCharacter,
        error.Overflow,
        error.MissingField,
        error.UnknownField,
        error.InvalidGroupId,
        error.InvalidMemberId,
        error.InvalidTrId,
        => notFound(self, req, res),

        else => {
            res.status = 500;
            res.content_type = .TEXT;
            res.body = "Internal Server Error";
            std.log.err("httpz: unhandled exception for request: {s}\nError: {s}", .{ req.url.raw, @errorName(err) });
        },
    };
}

pub fn notFound(_: *const Self, _: *httpz.Request, res: *httpz.Response) void {
    res.status = 404;
    res.content_type = .TEXT;
    res.body = "Not Found";
}

pub fn static(
    comptime content_type: httpz.ContentType,
    comptime field_name: []const u8,
) fn (*const Self, *httpz.Request, *httpz.Response) error{}!void {
    return struct {
        fn handler(self: *const Self, _: *httpz.Request, res: *httpz.Response) error{}!void {
            res.status = 200;
            res.content_type = content_type;
            res.body = @field(self, field_name);
        }
    }.handler;
}

const NewGroupReqInfo = struct {
    name: []const u8,
    description: []const u8,
    members: []const []const u8,
};

const NewGroupRes = struct {
    success: bool,
    group_id: []const u8,
};

pub fn newGroup(self: *const Self, req: *httpz.Request, res: *httpz.Response) !void {
    const req_body: []const u8 = req.body() orelse return error.NoReqBody;

    const parsedNewGroupReqInfo = try std.json.parseFromSlice(
        NewGroupReqInfo,
        res.arena,
        req_body,
        .{},
    );
    defer parsedNewGroupReqInfo.deinit();

    const g: NewGroupReqInfo = parsedNewGroupReqInfo.value;

    const group_id: u32 = try self.db.newGroup(res.arena, g.name, g.description, g.members);

    const group_id_hex: []const u8 = try std.fmt.allocPrint(res.arena, "{x}", .{group_id});
    defer res.arena.free(group_id_hex);

    res.status = 200;
    try res.json(NewGroupRes{
        .success = true,
        .group_id = group_id_hex,
    }, .{});
}

const GroupBoard = struct {
    group_id: []const u8,
    name: []const u8,
    description: []const u8,
    created_at: []const u8,
    members: []const Member,
    trs: []const Tr,
};

const GroupOverviewRes = struct {
    success: bool,
    group_board: GroupBoard,
};

pub fn groupOverview(self: *const Self, req: *httpz.Request, res: *httpz.Response) !void {
    const group_id_hex: []const u8 = req.param("group_id") orelse return error.NoGroupId;
    const group_id: u32 = try std.fmt.parseInt(u32, group_id_hex, 16);

    const groupInfo: *const GroupInfo = try self.db.getGroupInfo(res.arena, group_id) orelse
        return notFound(self, req, res);
    defer {
        res.arena.free(groupInfo.name);
        res.arena.free(groupInfo.description);
        res.arena.destroy(groupInfo);
    }

    const members: []const Member = try self.db.getMembers(res.arena, group_id);
    defer {
        for (members) |m| res.arena.free(m.name);
        res.arena.free(members);
    }

    const trs: []const Tr = try self.db.getTrs(res.arena, group_id);
    defer {
        for (trs) |t| res.arena.free(t.description);
        res.arena.free(trs);
    }

    res.status = 200;
    try res.json(GroupOverviewRes{
        .success = true,
        .group_board = GroupBoard{
            .group_id = group_id_hex,
            .name = groupInfo.name,
            .description = groupInfo.description,
            .created_at = groupInfo.created_at,
            .members = members,
            .trs = trs,
        },
    }, .{});
}

const NewExpenseReqInfo = struct {
    from_id: i64,
    to_id: i64,
    amount: i64,
    description: []const u8,
};

const NewExpenseRes = struct {
    success: bool,
    tr: *const Tr,
};

pub fn newExpense(self: *const Self, req: *httpz.Request, res: *httpz.Response) !void {
    const group_id_hex: []const u8 = req.param("group_id") orelse return error.NoGroupId;
    const group_id: u32 = try std.fmt.parseInt(u32, group_id_hex, 16);

    const req_body: []const u8 = req.body() orelse return error.NoReqBody;

    const parsedNewTrReqInfo = try std.json.parseFromSlice(
        NewExpenseReqInfo,
        res.arena,
        req_body,
        .{},
    );
    defer parsedNewTrReqInfo.deinit();

    const t: NewExpenseReqInfo = parsedNewTrReqInfo.value;

    const tr: *const Tr = try self.db.newTr(
        res.arena,
        group_id,
        t.from_id,
        t.to_id,
        t.amount,
        t.description,
    );
    defer {
        res.arena.free(tr.description);
        res.arena.free(tr.timestamp);
        res.arena.destroy(tr);
    }

    res.status = 200;
    try res.json(NewExpenseRes{
        .success = true,
        .tr = tr,
    }, .{});
}
