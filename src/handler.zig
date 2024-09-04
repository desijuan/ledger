const std = @import("std");
const httpz = @import("httpz");
const DB = @import("db.zig");

pub const Ctx = struct {
    db: *const DB,
};

pub fn errorHandler(ctx: *const Ctx, req: *httpz.Request, res: *httpz.Response, err: anyerror) void {
    return switch (err) {
        error.SyntaxError,
        error.InvalidCharacter,
        error.Overflow,
        error.MissingField,
        error.UnknownField,
        error.InvalidGroupId,
        error.InvalidMemberId,
        error.InvalidTrId,
        => notFound(ctx, req, res) catch {},

        else => {
            res.status = 500;
            res.content_type = .TEXT;
            res.body = "Internal Server Error";
            std.log.err("httpz: unhandled exception for request: {s}\nError: {s}", .{ req.url.raw, @errorName(err) });
        },
    };
}

pub fn notFound(_: *const Ctx, _: *httpz.Request, res: *httpz.Response) !void {
    res.status = 404;
    res.content_type = .TEXT;
    res.body = "Not Found";
}

pub fn homePage(_: *const Ctx, _: *httpz.Request, res: *httpz.Response) !void {
    res.status = 200;
    res.content_type = .TEXT;
    res.body = "Hello my friend!";
}

const NewGroupReqInfo = struct {
    name: []const u8,
    description: []const u8,
    members: []const []const u8,
};

pub fn newGroup(ctx: *const Ctx, req: *httpz.Request, res: *httpz.Response) !void {
    const req_body = req.body() orelse return error.NoReqBody;

    const parsedNewGroupReqInfo = try std.json.parseFromSlice(
        NewGroupReqInfo,
        res.arena,
        req_body,
        .{},
    );
    defer parsedNewGroupReqInfo.deinit();

    const group = parsedNewGroupReqInfo.value;

    const group_id = try ctx.db.newGroup(res.arena, group.name, group.description, group.members);

    res.status = 200;
    try res.json(.{
        .sucess = true,
        .group_id = group_id,
    }, .{});
}

const GroupBoard = struct {
    group_id: u32,
    name: []const u8,
    description: []const u8,
    created_at: []const u8,
    members: []const DB.Member,
    trs: []const DB.Tr,
};

pub fn groupOverview(ctx: *const Ctx, req: *httpz.Request, res: *httpz.Response) !void {
    const group_id_hex = req.param("group_id") orelse return error.NoGroupId;
    const group_id: u32 = try std.fmt.parseInt(u32, group_id_hex, 16);

    const groupInfo: *const DB.GroupInfo = try ctx.db.getGroupInfo(res.arena, group_id) orelse return {
        res.status = 200;
        try res.json(.{
            .success = false,
            .msg = "Group Not Found",
        }, .{});
    };
    defer {
        res.arena.free(groupInfo.name);
        res.arena.free(groupInfo.description);
        res.arena.destroy(groupInfo);
    }

    const members = try ctx.db.getMembers(res.arena, group_id);
    defer {
        for (members) |m| res.arena.free(m.name);
        res.arena.free(members);
    }

    const trs = try ctx.db.getTrs(res.arena, group_id);
    defer {
        for (trs) |t| res.arena.free(t.description);
        res.arena.free(trs);
    }

    res.status = 200;
    try res.json(.{
        .success = true,
        .group_board = GroupBoard{
            .group_id = group_id,
            .name = groupInfo.name,
            .description = groupInfo.description,
            .created_at = groupInfo.created_at,
            .members = members,
            .trs = trs,
        },
    }, .{});
}

const NewTrReqInfo = struct {
    from_id: i64,
    to_id: i64,
    amount: i64,
    description: []const u8,
};

pub fn newExpense(ctx: *const Ctx, req: *httpz.Request, res: *httpz.Response) !void {
    const group_id_hex = req.param("group_id") orelse return error.NoGroupId;
    const group_id: u32 = try std.fmt.parseInt(u32, group_id_hex, 16);

    const req_body = req.body() orelse return error.NoReqBody;

    const parsedNewTrReqInfo = try std.json.parseFromSlice(
        NewTrReqInfo,
        res.arena,
        req_body,
        .{},
    );
    defer parsedNewTrReqInfo.deinit();

    const tr = parsedNewTrReqInfo.value;

    const tr_id = try ctx.db.newTr(
        res.arena,
        group_id,
        tr.from_id,
        tr.to_id,
        tr.amount,
        tr.description,
    );

    res.status = 200;
    try res.json(.{
        .success = true,
        .tr_id = tr_id,
    }, .{});
}
