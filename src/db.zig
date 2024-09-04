const c = @cImport(@cInclude("sqlite3.h"));

pub const sqlite3 = c.sqlite3;

const std = @import("std");

file_name: [*c]const u8,
db_p: *?*c.sqlite3,
random: *const std.Random,

const Self = @This();

const groups_schema =
    \\CREATE TABLE IF NOT EXISTS groups (
    \\id INTEGER PRIMARY KEY,
    \\name TEXT NOT NULL,
    \\description TEXT,
    \\created_at INTEGER NOT NULL
    \\)
;

fn members_schema(alloc: std.mem.Allocator, group_id: u32) ![:0]const u8 {
    return try std.fmt.allocPrintZ(alloc,
        \\CREATE TABLE members_{x} (
        \\id INTEGER PRIMARY KEY,
        \\name TEXT NOT NULL
        \\)
    , .{group_id});
}

fn trs_schema(alloc: std.mem.Allocator, group_id: u32) ![:0]const u8 {
    return try std.fmt.allocPrintZ(alloc,
        \\CREATE TABLE trs_{x} (
        \\id INTEGER PRIMARY KEY,
        \\from_id INTEGER NOT NULL,
        \\to_id INTEGER NOT NULL,
        \\amount INTEGER NOT NULL,
        \\description TEXT,
        \\timestamp INTEGER NOT NULL
        \\)
    , .{group_id});
}

pub const GroupInfo = struct {
    group_id: u32,
    name: []const u8,
    description: []const u8,
    created_at: []const u8,
};

pub const Member = struct {
    member_id: i64,
    name: []const u8,
};

pub const Tr = struct {
    tr_id: i64,
    from_id: i64,
    to_id: i64,
    amount: i64,
    description: []const u8,
    timestamp: []const u8,
};

fn prepareStmt(self: *const Self, stmt_p: *?*c.sqlite3_stmt, sql_str: []const u8) !void {
    if (c.sqlite3_prepare_v2(
        self.db_p.*,
        @as([*c]const u8, @ptrCast(sql_str)),
        @as(c_int, @intCast(sql_str.len)),
        stmt_p,
        null,
    ) != c.SQLITE_OK) {
        std.log.err("{s}", .{c.sqlite3_errmsg(self.db_p.*)});
        return error.DBError;
    }
}

fn stepStmtOnce(self: *const Self, stmt: ?*c.sqlite3_stmt) !void {
    if (c.sqlite3_step(stmt) != c.SQLITE_DONE) {
        std.log.err("{s}", .{c.sqlite3_errmsg(self.db_p.*)});
        return error.DBError;
    }
}

fn bindText(
    self: *const Self,
    stmt: ?*c.sqlite3_stmt,
    index: comptime_int,
    text: []const u8,
    placeholder: []const u8,
) !void {
    if (c.sqlite3_bind_text(
        stmt,
        index,
        @as([*c]const u8, @ptrCast(text)),
        @as(c_int, @intCast(text.len)),
        c.SQLITE_STATIC,
    ) != c.SQLITE_OK) {
        std.log.err(
            "Error binding parameter: {s} -> {s}\n{s}",
            .{ text, placeholder, c.sqlite3_errmsg(self.db_p.*) },
        );
        return error.DBError;
    }
}

pub fn open(self: *const Self) !void {
    const sqlite3_version = c.sqlite3_libversion();
    std.log.info("SQLite v{s}", .{sqlite3_version});

    if (c.sqlite3_open_v2(
        self.file_name,
        self.db_p,
        c.SQLITE_OPEN_READWRITE | c.SQLITE_OPEN_CREATE,
        null,
    ) != c.SQLITE_OK) {
        std.log.err(
            "Error opening the database: {s}\n{s}",
            .{ self.file_name, c.sqlite3_errmsg(self.db_p.*) },
        );
        _ = c.sqlite3_close(self.db_p.*);
        return error.DBError;
    }

    std.log.debug("Successfully opened the database: {s}", .{self.file_name});
}

pub fn close(self: *const Self) !void {
    if (c.sqlite3_close(self.db_p.*) != c.SQLITE_OK) {
        std.log.err(
            "Error closing the database: {s}\n{s}",
            .{ self.file_name, c.sqlite3_errmsg(self.db_p.*) },
        );
        return error.DBError;
    }

    std.log.debug("Successfully closed the database: {s}", .{self.file_name});
}

pub fn initGroupsTable(self: *const Self) !void {
    var stmt: ?*c.sqlite3_stmt = undefined;

    try self.prepareStmt(&stmt, groups_schema);
    defer {
        _ = c.sqlite3_finalize(stmt);
    }

    try self.stepStmtOnce(stmt);

    std.log.debug("Initialized groups table", .{});
}

inline fn isIdValid(self: *const Self, alloc: std.mem.Allocator, table: []const u8, id: i64) !bool {
    var stmt: ?*c.sqlite3_stmt = undefined;

    const sql_str = try std.fmt.allocPrintZ(
        alloc,
        "SELECT id FROM {s} WHERE id = {d}",
        .{ table, id },
    );
    defer alloc.free(sql_str);

    try self.prepareStmt(&stmt, sql_str);
    defer {
        _ = c.sqlite3_finalize(stmt);
    }

    const rc = c.sqlite3_step(stmt);

    return switch (rc) {
        c.SQLITE_DONE => false,
        c.SQLITE_ROW => true,
        else => blk: {
            std.log.err(
                "Error stepping sql statement\n{s}\n{s}",
                .{ sql_str, c.sqlite3_errmsg(self.db_p.*) },
            );
            break :blk error.DBError;
        },
    };
}

pub fn isGroupIdValid(self: *const Self, alloc: std.mem.Allocator, group_id: u32) !bool {
    return isIdValid(self, alloc, "groups", group_id);
}

pub fn isMemberIdValid(
    self: *const Self,
    alloc: std.mem.Allocator,
    group_id: u32,
    member_id: i64,
) !bool {
    const members_table = try std.fmt.allocPrint(alloc, "members_{x}", .{group_id});
    defer alloc.free(members_table);

    return isIdValid(self, alloc, members_table, member_id);
}

pub fn isTrIdValid(
    self: *const Self,
    alloc: std.mem.Allocator,
    group_id: u32,
    tr_id: i64,
) !bool {
    const trs_table = try std.fmt.allocPrint(alloc, "trs_{x}", .{group_id});
    defer alloc.free(trs_table);

    return isIdValid(self, alloc, trs_table, tr_id);
}

pub fn getGroupInfo(
    self: *const Self,
    alloc: std.mem.Allocator,
    group_id: u32,
) !?*const GroupInfo {
    var stmt: ?*c.sqlite3_stmt = undefined;

    const sql_str = try std.fmt.allocPrintZ(
        alloc,
        "SELECT name, description, datetime(created_at, 'unixepoch') FROM groups WHERE id = {d}",
        .{group_id},
    );
    defer alloc.free(sql_str);

    try self.prepareStmt(&stmt, sql_str);
    defer {
        _ = c.sqlite3_finalize(stmt);
    }

    const rc = c.sqlite3_step(stmt);

    return switch (rc) {
        c.SQLITE_DONE => null,
        c.SQLITE_ROW => blk: {
            const groupInfo = try alloc.create(GroupInfo);
            errdefer alloc.destroy(groupInfo);

            groupInfo.group_id = group_id;

            const name = try std.fmt.allocPrint(
                alloc,
                "{s}",
                .{c.sqlite3_column_text(stmt, 0)},
            );
            errdefer alloc.free(name);
            groupInfo.name = name;

            const description = try std.fmt.allocPrint(
                alloc,
                "{s}",
                .{c.sqlite3_column_text(stmt, 1)},
            );
            errdefer alloc.free(description);
            groupInfo.description = description;

            const created_at = try std.fmt.allocPrint(
                alloc,
                "{s}",
                .{c.sqlite3_column_text(stmt, 2)},
            );
            errdefer alloc.free(created_at);
            groupInfo.created_at = created_at;

            break :blk groupInfo;
        },
        else => blk: {
            std.log.err(
                "Error stepping sql statement\n{s}\n{s}",
                .{ sql_str, c.sqlite3_errmsg(self.db_p.*) },
            );
            break :blk error.DBError;
        },
    };
}

pub fn getMemberInfo(
    self: *const Self,
    alloc: std.mem.Alloc,
    group_id: u32,
    member_id: i64,
) !?Member {
    var stmt: ?*c.sqlite3_stmt = undefined;

    const sql_str = try std.fmt.allocPrintZ(
        alloc,
        "SELECT name FROM members_{x} WHERE id = {d}",
        .{ group_id, member_id },
    );
    defer alloc.free(sql_str);

    try self.prepareStmt(&stmt, sql_str);
    defer {
        _ = c.sqlite3_finalize(stmt);
    }

    const rc = c.sqlite3_step(stmt);

    return switch (rc) {
        c.SQLITE_DONE => null,
        c.SQLITE_ROW => blk: {
            const member = try alloc.create(Member);
            errdefer alloc.destroy(member);

            member.member_id = member_id;

            const name = try std.fmt.allocPrint(
                alloc.*,
                "{s}",
                .{c.sqlite3_column_text(stmt, 0)},
            );
            errdefer alloc.free(name);
            member.name = name;

            break :blk member;
        },
        else => blk: {
            std.log.err(
                "Error stepping sql statement\n{s}\n{s}",
                .{ sql_str, c.sqlite3_errmsg(self.db_p.*) },
            );
            break :blk error.DBError;
        },
    };
}

pub fn getMembers(self: *const Self, alloc: std.mem.Allocator, group_id: u32) ![]const Member {
    var stmt: ?*c.sqlite3_stmt = undefined;

    const sql_str = try std.fmt.allocPrintZ(
        alloc,
        "SELECT id, name FROM members_{x}",
        .{group_id},
    );
    defer alloc.free(sql_str);

    try self.prepareStmt(&stmt, sql_str);
    defer {
        _ = c.sqlite3_finalize(stmt);
    }

    var rc = c.sqlite3_step(stmt);

    const data_count: usize = @intCast(c.sqlite3_data_count(stmt));

    var array_list = try std.ArrayList(Member).initCapacity(alloc, data_count);
    errdefer array_list.deinit();

    while (rc == c.SQLITE_ROW) : (rc = c.sqlite3_step(stmt)) {
        const member_id: i64 = c.sqlite3_column_int64(stmt, 0);

        const name = try std.fmt.allocPrint(
            alloc,
            "{s}",
            .{c.sqlite3_column_text(stmt, 1)},
        );
        errdefer alloc.free(name);

        try array_list.append(Member{
            .member_id = member_id,
            .name = name,
        });
    } else if (rc != c.SQLITE_DONE) {
        std.log.err(
            "Error stepping sql statement\n{s}\n{s}",
            .{ sql_str, c.sqlite3_errmsg(self.db_p.*) },
        );
        return error.DBError;
    }

    return array_list.toOwnedSlice();
}

pub fn getTrs(self: *const Self, alloc: std.mem.Allocator, group_id: u32) ![]const Tr {
    var stmt: ?*c.sqlite3_stmt = undefined;

    const sql_str = try std.fmt.allocPrintZ(
        alloc,
        "SELECT id, from_id, to_id, amount, description, datetime(timestamp, 'unixepoch') FROM trs_{x}",
        .{group_id},
    );
    defer alloc.free(sql_str);

    try self.prepareStmt(&stmt, sql_str);
    defer {
        _ = c.sqlite3_finalize(stmt);
    }

    var rc = c.sqlite3_step(stmt);

    const data_count: usize = @intCast(c.sqlite3_data_count(stmt));

    var array_list = try std.ArrayList(Tr).initCapacity(alloc, data_count);
    errdefer array_list.deinit();

    while (rc == c.SQLITE_ROW) : (rc = c.sqlite3_step(stmt)) {
        const tr_id: i64 = c.sqlite3_column_int64(stmt, 0);
        const from_id: i64 = c.sqlite3_column_int64(stmt, 1);
        const to_id: i64 = c.sqlite3_column_int64(stmt, 2);
        const amount: i64 = c.sqlite3_column_int64(stmt, 3);

        const description = try std.fmt.allocPrint(
            alloc,
            "{s}",
            .{c.sqlite3_column_text(stmt, 4)},
        );
        errdefer alloc.free(description);

        const timestamp = try std.fmt.allocPrint(
            alloc,
            "{s}",
            .{c.sqlite3_column_text(stmt, 5)},
        );
        errdefer alloc.free(timestamp);

        try array_list.append(Tr{
            .tr_id = tr_id,
            .from_id = from_id,
            .to_id = to_id,
            .amount = amount,
            .description = description,
            .timestamp = timestamp,
        });
    } else if (rc != c.SQLITE_DONE) {
        std.log.err(
            "Error stepping sql statement\n{s}\n{s}",
            .{ sql_str, c.sqlite3_errmsg(self.db_p.*) },
        );
        return error.DBError;
    }

    return array_list.toOwnedSlice();
}

pub fn newGroup(
    self: *const Self,
    alloc: std.mem.Allocator,
    name: []const u8,
    description: []const u8,
    members: []const []const u8,
) !u32 {
    var random_int = self.random.int(u32);
    const group_id: u32 = while (try self.isGroupIdValid(alloc, random_int)) {
        random_int = self.random.int(u32);
    } else random_int;

    try self.addGroup(alloc, group_id, name, description);
    try self.createMembersTable(alloc, group_id);
    _ = try self.addGroupMember(alloc, group_id);
    for (members) |member_name| {
        _ = try self.addMember(alloc, group_id, member_name);
    }
    try self.createTrsTable(alloc, group_id);

    return group_id;
}

pub fn newTr(
    self: *const Self,
    alloc: std.mem.Allocator,
    group_id: u32,
    from_id: i64,
    to_id: i64,
    amount: i64,
    description: []const u8,
) !i64 {
    if (!try self.isGroupIdValid(alloc, group_id)) return error.InvalidGroupId;
    if (!try self.isMemberIdValid(alloc, group_id, from_id)) return error.InvalidMemberId;
    if (!try self.isMemberIdValid(alloc, group_id, to_id)) return error.InvalidMemberId;

    return self.addTr(alloc, group_id, from_id, to_id, amount, description);
}

fn addGroup(
    self: *const Self,
    alloc: std.mem.Allocator,
    group_id: u32,
    name: []const u8,
    description: []const u8,
) !void {
    var stmt: ?*c.sqlite3_stmt = undefined;

    const sql_str = try std.fmt.allocPrintZ(
        alloc,
        "INSERT INTO groups (id, name, description, created_at) VALUES ({d}, :name, :description, unixepoch())",
        .{group_id},
    );
    defer alloc.free(sql_str);

    try self.prepareStmt(&stmt, sql_str);
    defer {
        _ = c.sqlite3_finalize(stmt);
    }

    try self.bindText(stmt, 1, name, ":name");
    try self.bindText(stmt, 2, description, ":description");

    try self.stepStmtOnce(stmt);

    std.log.debug(
        "New Group [id: {x} ({0d}), name: {s}, description: {s}]",
        .{ group_id, name, description },
    );
}

fn createMembersTable(self: *const Self, alloc: std.mem.Allocator, group_id: u32) !void {
    var stmt: ?*c.sqlite3_stmt = undefined;

    const sql_str = try members_schema(alloc, group_id);
    defer alloc.free(sql_str);

    try self.prepareStmt(&stmt, sql_str);
    defer {
        _ = c.sqlite3_finalize(stmt);
    }

    try self.stepStmtOnce(stmt);

    std.log.debug("Initialized members table for group {x}", .{group_id});
}

fn addGroupMember(self: *const Self, alloc: std.mem.Allocator, group_id: u32) !i64 {
    var stmt: ?*c.sqlite3_stmt = undefined;

    const GROUP_MEMBER_NAME = "_group_";

    const sql_str = try std.fmt.allocPrintZ(
        alloc,
        "INSERT INTO members_{x} (id, name) VALUES (0, '{s}')",
        .{ group_id, GROUP_MEMBER_NAME },
    );
    defer alloc.free(sql_str);

    try self.prepareStmt(&stmt, sql_str);
    defer {
        _ = c.sqlite3_finalize(stmt);
    }

    try self.stepStmtOnce(stmt);

    const member_id: i64 = @intCast(c.sqlite3_last_insert_rowid(self.db_p.*));

    std.log.debug("New Member [id: {d}, name: {s}]", .{ member_id, GROUP_MEMBER_NAME });

    return member_id;
}

fn addMember(self: *const Self, alloc: std.mem.Allocator, group_id: u32, name: []const u8) !i64 {
    var stmt: ?*c.sqlite3_stmt = undefined;

    const sql_str = try std.fmt.allocPrintZ(
        alloc,
        "INSERT INTO members_{x} (name) VALUES (:name)",
        .{group_id},
    );
    defer alloc.free(sql_str);

    try self.prepareStmt(&stmt, sql_str);
    defer {
        _ = c.sqlite3_finalize(stmt);
    }

    try self.bindText(stmt, 1, name, ":name");

    try self.stepStmtOnce(stmt);

    const member_id: i64 = @intCast(c.sqlite3_last_insert_rowid(self.db_p.*));

    std.log.debug("New Member [id: {d}, name: {s}]", .{ member_id, name });

    return member_id;
}

fn createTrsTable(self: *const Self, alloc: std.mem.Allocator, group_id: u32) !void {
    var stmt: ?*c.sqlite3_stmt = undefined;

    const sql_str = try trs_schema(alloc, group_id);
    defer alloc.free(sql_str);

    try self.prepareStmt(&stmt, sql_str);
    defer {
        _ = c.sqlite3_finalize(stmt);
    }

    try self.stepStmtOnce(stmt);

    std.log.debug("Initialized transactions table for group {x}", .{group_id});
}

fn addTr(
    self: *const Self,
    alloc: std.mem.Allocator,
    group_id: u32,
    from_id: i64,
    to_id: i64,
    amount: i64,
    description: []const u8,
) !i64 {
    var stmt: ?*c.sqlite3_stmt = undefined;

    const sql_str = try std.fmt.allocPrintZ(
        alloc,
        \\INSERT INTO trs_{x}
        \\(from_id, to_id, amount, description, timestamp)
        \\VALUES ({d}, {d}, {d}, :description, unixepoch())
    ,
        .{ group_id, from_id, to_id, amount },
    );
    defer alloc.free(sql_str);

    try self.prepareStmt(&stmt, sql_str);
    defer {
        _ = c.sqlite3_finalize(stmt);
    }

    try self.bindText(stmt, 1, description, ":description");

    try self.stepStmtOnce(stmt);

    const tr_id: i64 = @intCast(c.sqlite3_last_insert_rowid(self.db_p.*));

    std.log.debug(
        "New Transaction [group_id: {x} ({0d}), tr_id: {d}, from_id: {d}, to_id: {d}, amount: {d}, description: {s}]",
        .{ group_id, tr_id, from_id, to_id, amount, description },
    );

    return tr_id;
}
