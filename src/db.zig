const c = @cImport({
    @cInclude("sqlite3.h");
});

pub const sqlite3 = c.sqlite3;

const std = @import("std");

file_name: [*c]const u8,
db_p: *?*c.sqlite3,
alloc: *const std.mem.Allocator,
random: *const std.Random,

const Self = @This();

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

    std.log.info("Successfully opened the database: {s}", .{self.file_name});
}

pub fn close(self: *const Self) !void {
    if (c.sqlite3_close(self.db_p.*) != c.SQLITE_OK) {
        std.log.err(
            "Error closing the database: {s}\n{s}",
            .{ self.file_name, c.sqlite3_errmsg(self.db_p.*) },
        );
        return error.DBError;
    }

    std.log.info("Successfully closed the database: {s}", .{self.file_name});
}

pub fn initGroupsTable(self: *const Self) !void {
    var stmt: ?*c.sqlite3_stmt = undefined;

    const sql_str =
        \\CREATE TABLE IF NOT EXISTS groups(
        \\name TEXT NOT NULL,
        \\description TEXT
        \\)
    ;

    if (c.sqlite3_prepare_v2(
        self.db_p.*,
        sql_str,
        sql_str.len,
        &stmt,
        null,
    ) != c.SQLITE_OK) {
        std.log.err(
            "Error creating groups table\n{s}",
            .{c.sqlite3_errmsg(self.db_p.*)},
        );
        return error.DBError;
    }
    defer {
        _ = c.sqlite3_finalize(stmt);
    }

    if (c.sqlite3_step(stmt) != c.SQLITE_DONE) {
        std.log.err(
            "Error creating groups table\n{s}",
            .{c.sqlite3_errmsg(self.db_p.*)},
        );
        return error.DBError;
    }

    std.log.info("Initialized groups table", .{});
}

pub fn isGroupIdValid(self: *const Self, group_id: u32) !bool {
    var stmt: ?*c.sqlite3_stmt = undefined;

    const sql_str = try std.fmt.allocPrintZ(
        self.alloc.*,
        "SELECT rowid FROM groups WHERE rowid == {d}",
        .{group_id},
    );
    defer self.alloc.free(sql_str);

    if (c.sqlite3_prepare_v2(
        self.db_p.*,
        sql_str,
        @as(c_int, @intCast(sql_str.len)),
        &stmt,
        null,
    ) != c.SQLITE_OK) {
        std.log.err(
            "Error preparing sql statement\n{s}\n{s}",
            .{ sql_str, c.sqlite3_errmsg(self.db_p.*) },
        );
        return error.DBError;
    }
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

pub fn isMemberIdValid(self: *const Self, group_id: u32, member_id: i64) !bool {
    var stmt: ?*c.sqlite3_stmt = undefined;

    const sql_str = try std.fmt.allocPrintZ(
        self.alloc.*,
        "SELECT rowid FROM members_{x} WHERE rowid == {d}",
        .{ group_id, member_id },
    );
    defer self.alloc.free(sql_str);

    if (c.sqlite3_prepare_v2(
        self.db_p.*,
        sql_str,
        @as(c_int, @intCast(sql_str.len)),
        &stmt,
        null,
    ) != c.SQLITE_OK) {
        std.log.err(
            "Error preparing sql statement\n{s}\n{s}",
            .{ sql_str, c.sqlite3_errmsg(self.db_p.*) },
        );
        return error.DBError;
    }
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

pub fn isTrIdValid(self: *const Self, group_id: u32, tr_id: i64) !bool {
    var stmt: ?*c.sqlite3_stmt = undefined;

    const sql_str = try std.fmt.allocPrintZ(
        self.alloc.*,
        "SELECT rowid FROM tr_{x} WHERE rowid == {d}",
        .{ group_id, tr_id },
    );
    defer self.alloc.free(sql_str);

    if (c.sqlite3_prepare_v2(
        self.db_p.*,
        sql_str,
        @as(c_int, @intCast(sql_str.len)),
        &stmt,
        null,
    ) != c.SQLITE_OK) {
        std.log.err(
            "Error preparing sql statement\n{s}\n{s}",
            .{ sql_str, c.sqlite3_errmsg(self.db_p.*) },
        );
        return error.DBError;
    }
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

pub const GroupInfo = struct {
    group_id: u32,
    name: []const u8,
    description: []const u8,
};

pub fn getGroupInfo(self: *const Self, group_id: u32) !?*const GroupInfo {
    var stmt: ?*c.sqlite3_stmt = undefined;

    const sql_str = try std.fmt.allocPrintZ(
        self.alloc.*,
        "SELECT name, description FROM groups WHERE rowid == {d}",
        .{group_id},
    );
    defer self.alloc.free(sql_str);

    if (c.sqlite3_prepare_v2(
        self.db_p.*,
        sql_str,
        @as(c_int, @intCast(sql_str.len)),
        &stmt,
        null,
    ) != c.SQLITE_OK) {
        std.log.err(
            "Error preparing sql statement\n{s}\n{s}",
            .{ sql_str, c.sqlite3_errmsg(self.db_p.*) },
        );
        return error.DBError;
    }
    defer {
        _ = c.sqlite3_finalize(stmt);
    }

    const rc = c.sqlite3_step(stmt);

    return switch (rc) {
        c.SQLITE_DONE => null,
        c.SQLITE_ROW => blk: {
            const groupInfo = try self.alloc.create(GroupInfo);
            errdefer self.alloc.destroy(groupInfo);

            groupInfo.group_id = group_id;

            const name = try std.fmt.allocPrint(
                self.alloc.*,
                "{s}",
                .{c.sqlite3_column_text(stmt, 0)},
            );
            errdefer self.alloc.free(name);

            groupInfo.name = name;

            groupInfo.description = try std.fmt.allocPrint(
                self.alloc.*,
                "{s}",
                .{c.sqlite3_column_text(stmt, 1)},
            );

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

pub const Member = struct {
    member_id: i64,
    name: []const u8,
};

pub fn getMemberInfo(self: *const Self, group_id: u32, member_id: i64) !?Member {
    var stmt: ?*c.sqlite3_stmt = undefined;

    const sql_str = try std.fmt.allocPrintZ(
        self.alloc.*,
        "SELECT name FROM members_{x} WHERE rowid == {d}",
        .{ group_id, member_id },
    );
    defer self.alloc.free(sql_str);

    if (c.sqlite3_prepare_v2(
        self.db_p.*,
        sql_str,
        @as(c_int, @intCast(sql_str.len)),
        &stmt,
        null,
    ) != c.SQLITE_OK) {
        std.log.err(
            "Error preparing sql statement\n{s}\n{s}",
            .{ sql_str, c.sqlite3_errmsg(self.db_p.*) },
        );
        return error.DBError;
    }
    defer {
        _ = c.sqlite3_finalize(stmt);
    }

    const rc = c.sqlite3_step(stmt);

    return switch (rc) {
        c.SQLITE_DONE => null,
        c.SQLITE_ROW => blk: {
            const member = try self.alloc.create(Member);
            errdefer self.alloc.destroy(member);

            member.member_id = member_id;

            member.name = try std.fmt.allocPrint(
                self.alloc.*,
                "{s}",
                .{c.sqlite3_column_text(stmt, 0)},
            );

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

pub fn getMembers(self: *const Self, group_id: u32) ![]const Member {
    var stmt: ?*c.sqlite3_stmt = undefined;

    const sql_str = try std.fmt.allocPrintZ(
        self.alloc.*,
        "SELECT rowid, name FROM members_{x}",
        .{group_id},
    );
    defer self.alloc.free(sql_str);

    if (c.sqlite3_prepare_v2(
        self.db_p.*,
        sql_str,
        @as(c_int, @intCast(sql_str.len)),
        &stmt,
        null,
    ) != c.SQLITE_OK) {
        std.log.err(
            "Error preparing sql statement\n{s}\n{s}",
            .{ sql_str, c.sqlite3_errmsg(self.db_p.*) },
        );
        return error.DBError;
    }
    defer {
        _ = c.sqlite3_finalize(stmt);
    }

    var rc = c.sqlite3_step(stmt);

    const data_count: usize = @intCast(c.sqlite3_data_count(stmt));

    var array_list = try std.ArrayList(Member).initCapacity(self.alloc.*, data_count);
    errdefer array_list.deinit();

    while (rc == c.SQLITE_ROW) : (rc = c.sqlite3_step(stmt)) {
        const member_id: i64 = c.sqlite3_column_int64(stmt, 0);

        const name = try std.fmt.allocPrint(
            self.alloc.*,
            "{s}",
            .{c.sqlite3_column_text(stmt, 1)},
        );
        errdefer self.alloc.free(name);

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

pub const Tr = struct {
    tr_id: i64,
    from_id: i64,
    to_id: i64,
    amount: i64,
    description: []const u8,
};

pub fn getTrs(self: *const Self, group_id: u32) ![]const Tr {
    var stmt: ?*c.sqlite3_stmt = undefined;

    const sql_str = try std.fmt.allocPrintZ(
        self.alloc.*,
        "SELECT rowid, t_from, t_to, t_amount, t_description FROM trs_{x}",
        .{group_id},
    );
    defer self.alloc.free(sql_str);

    if (c.sqlite3_prepare_v2(
        self.db_p.*,
        sql_str,
        @as(c_int, @intCast(sql_str.len)),
        &stmt,
        null,
    ) != c.SQLITE_OK) {
        std.log.err(
            "Error preparing sql statement\n{s}\n{s}",
            .{ sql_str, c.sqlite3_errmsg(self.db_p.*) },
        );
        return error.DBError;
    }
    defer {
        _ = c.sqlite3_finalize(stmt);
    }

    var rc = c.sqlite3_step(stmt);

    const data_count: usize = @intCast(c.sqlite3_data_count(stmt));

    var array_list = try std.ArrayList(Tr).initCapacity(self.alloc.*, data_count);
    errdefer array_list.deinit();

    while (rc == c.SQLITE_ROW) : (rc = c.sqlite3_step(stmt)) {
        const rowid: i64 = c.sqlite3_column_int64(stmt, 0);
        const t_from: i64 = c.sqlite3_column_int64(stmt, 1);
        const t_to: i64 = c.sqlite3_column_int64(stmt, 2);
        const t_amount: i64 = c.sqlite3_column_int64(stmt, 3);

        const t_description = try std.fmt.allocPrint(
            self.alloc.*,
            "{s}",
            .{c.sqlite3_column_text(stmt, 4)},
        );
        errdefer self.alloc.free(t_description);

        try array_list.append(Tr{
            .tr_id = @intCast(rowid),
            .from_id = t_from,
            .to_id = t_to,
            .amount = t_amount,
            .description = t_description,
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
    name: []const u8,
    description: []const u8,
    members: []const []const u8,
) !u32 {
    var random_int = self.random.int(u32);
    const group_id: u32 = while (try self.isGroupIdValid(random_int)) {
        random_int = self.random.int(u32);
    } else random_int;

    try self.addGroup(group_id, name, description);
    try self.createMembersTable(group_id);
    for (members) |member_name| {
        _ = try self.addMember(group_id, member_name);
    }
    try self.createTrsTable(group_id);

    return group_id;
}

pub fn newTr(
    self: *const Self,
    group_id: u32,
    from_id: i64,
    to_id: i64,
    amount: i64,
    description: []const u8,
) !i64 {
    if (!try self.isGroupIdValid(group_id)) return error.InvalidGroupId;
    if (!try self.isMemberIdValid(group_id, from_id)) return error.InvalidMemberId;
    if (!try self.isMemberIdValid(group_id, to_id)) return error.InvalidMemberId;

    return self.addTr(group_id, from_id, to_id, amount, description);
}

fn addGroup(
    self: *const Self,
    group_id: u32,
    name: []const u8,
    description: []const u8,
) !void {
    var stmt: ?*c.sqlite3_stmt = undefined;

    const sql_str = try std.fmt.allocPrintZ(
        self.alloc.*,
        "INSERT INTO groups (rowid, name, description) VALUES ({d}, :name, :description)",
        .{group_id},
    );
    defer self.alloc.free(sql_str);

    if (c.sqlite3_prepare_v2(
        self.db_p.*,
        @as([*c]const u8, @ptrCast(sql_str)),
        @as(c_int, @intCast(sql_str.len)),
        &stmt,
        null,
    ) != c.SQLITE_OK) {
        std.log.err(
            "Error preparing sql statement\n{s}\n{s}",
            .{ sql_str, c.sqlite3_errmsg(self.db_p.*) },
        );
        return error.DBError;
    }
    defer {
        _ = c.sqlite3_finalize(stmt);
    }

    if (c.sqlite3_bind_text(
        stmt,
        1,
        @as([*c]const u8, @ptrCast(name)),
        @as(c_int, @intCast(name.len)),
        c.SQLITE_STATIC,
    ) != c.SQLITE_OK) {
        std.log.err("Error binding parameter: {s} -> {s}", .{ name, ":name" });
        return error.DBError;
    }

    if (c.sqlite3_bind_text(
        stmt,
        2,
        @as([*c]const u8, @ptrCast(description)),
        @as(c_int, @intCast(description.len)),
        c.SQLITE_STATIC,
    ) != c.SQLITE_OK) {
        std.log.err("Error binding parameter: {s} -> {s}", .{ description, ":description" });
        return error.DBError;
    }

    if (c.sqlite3_step(stmt) != c.SQLITE_DONE) {
        std.log.err(
            "Error stepping sql statement\n{s}\n{s}",
            .{ sql_str, c.sqlite3_errmsg(self.db_p.*) },
        );
        return error.DBError;
    }

    std.log.info(
        "New Group [id: {x} ({0d}), name: {s}, description: {s}]",
        .{ group_id, name, description },
    );
}

fn createMembersTable(self: *const Self, group_id: u32) !void {
    var stmt: ?*c.sqlite3_stmt = undefined;

    const sql_str_template =
        \\CREATE TABLE members_{x}(
        \\name TEXT NOT NULL
        \\);
    ;

    const sql_str = try std.fmt.allocPrintZ(self.alloc.*, sql_str_template, .{group_id});
    defer self.alloc.free(sql_str);

    if (c.sqlite3_prepare_v2(
        self.db_p.*,
        @as([*c]const u8, @ptrCast(sql_str)),
        @as(c_int, @intCast(sql_str.len)),
        &stmt,
        null,
    ) != c.SQLITE_OK) {
        std.log.err(
            "Error creating members table for group {x}\n{s}",
            .{ group_id, c.sqlite3_errmsg(self.db_p.*) },
        );
        return error.DBError;
    }
    defer {
        _ = c.sqlite3_finalize(stmt);
    }

    if (c.sqlite3_step(stmt) != c.SQLITE_DONE) {
        std.log.err(
            "Error creating members table for group {x}\n{s}",
            .{ group_id, c.sqlite3_errmsg(self.db_p.*) },
        );
        return error.DBError;
    }

    std.log.info("Initialized members table for group {x}", .{group_id});
}

fn addMember(self: *const Self, group_id: u32, name: []const u8) !i64 {
    var stmt: ?*c.sqlite3_stmt = undefined;

    const sql_str = try std.fmt.allocPrintZ(
        self.alloc.*,
        "INSERT INTO members_{x} (name) VALUES (:name)",
        .{group_id},
    );
    defer self.alloc.free(sql_str);

    if (c.sqlite3_prepare_v2(
        self.db_p.*,
        @as([*c]const u8, @ptrCast(sql_str)),
        @as(c_int, @intCast(sql_str.len)),
        &stmt,
        null,
    ) != c.SQLITE_OK) {
        std.log.err(
            "Error preparing sql statement\n{s}\n{s}",
            .{ sql_str, c.sqlite3_errmsg(self.db_p.*) },
        );
        return error.DBError;
    }
    defer {
        _ = c.sqlite3_finalize(stmt);
    }

    if (c.sqlite3_bind_text(
        stmt,
        1,
        @as([*c]const u8, @ptrCast(name)),
        @as(c_int, @intCast(name.len)),
        c.SQLITE_STATIC,
    ) != c.SQLITE_OK) {
        std.log.err("Error binding parameter: {s} -> {s}", .{ name, ":name" });
        return error.DBError;
    }

    if (c.sqlite3_step(stmt) != c.SQLITE_DONE) {
        std.log.err(
            "Error stepping sql statement\n{s}\n{s}",
            .{ sql_str, c.sqlite3_errmsg(self.db_p.*) },
        );
        return error.DBError;
    }

    const member_id: i64 = @intCast(c.sqlite3_last_insert_rowid(self.db_p.*));

    std.log.info("New Member [id: {d}, name: {s}]", .{ member_id, name });

    return member_id;
}

fn createTrsTable(self: *const Self, group_id: u32) !void {
    var stmt: ?*c.sqlite3_stmt = undefined;

    const sql_str_template =
        \\CREATE TABLE trs_{x}(
        \\t_from INTEGER NOT NULL,
        \\t_to INTEGER NOT NULL,
        \\t_amount INTEGER NOT NULL,
        \\t_description TEXT
        \\);
    ;

    const sql_str = try std.fmt.allocPrintZ(self.alloc.*, sql_str_template, .{group_id});
    defer self.alloc.free(sql_str);

    if (c.sqlite3_prepare_v2(
        self.db_p.*,
        @as([*c]const u8, @ptrCast(sql_str)),
        @as(c_int, @intCast(sql_str.len)),
        &stmt,
        null,
    ) != c.SQLITE_OK) {
        std.log.err(
            "Error creating transactions table for group {x}\n{s}",
            .{ group_id, c.sqlite3_errmsg(self.db_p.*) },
        );
        return error.DBError;
    }
    defer {
        _ = c.sqlite3_finalize(stmt);
    }

    if (c.sqlite3_step(stmt) != c.SQLITE_DONE) {
        std.log.err(
            "Error creating transactions table for group {x}\n{s}",
            .{ group_id, c.sqlite3_errmsg(self.db_p.*) },
        );
        return error.DBError;
    }

    std.log.info("Initialized transactions table for group {x}", .{group_id});
}

fn addTr(
    self: *const Self,
    group_id: u32,
    from_id: i64,
    to_id: i64,
    amount: i64,
    description: []const u8,
) !i64 {
    var stmt: ?*c.sqlite3_stmt = undefined;

    const sql_str = try std.fmt.allocPrintZ(
        self.alloc.*,
        "INSERT INTO trs_{x} (t_from, t_to, t_amount, t_description) VALUES ({d}, {d}, {d}, :t_description)",
        .{ group_id, from_id, to_id, amount },
    );
    defer self.alloc.free(sql_str);

    if (c.sqlite3_prepare_v2(
        self.db_p.*,
        sql_str,
        @as(c_int, @intCast(sql_str.len)),
        &stmt,
        null,
    ) != c.SQLITE_OK) {
        std.log.err(
            "Error preparing sql statement\n{s}\n{s}",
            .{ sql_str, c.sqlite3_errmsg(self.db_p.*) },
        );
        return error.DBError;
    }
    defer {
        _ = c.sqlite3_finalize(stmt);
    }

    if (c.sqlite3_bind_text(
        stmt,
        1,
        @as([*c]const u8, @ptrCast(description)),
        @as(c_int, @intCast(description.len)),
        c.SQLITE_STATIC,
    ) != c.SQLITE_OK) {
        std.log.err("Error binding parameter: {s} -> {s}", .{ description, ":t_description" });
        return error.DBError;
    }

    if (c.sqlite3_step(stmt) != c.SQLITE_DONE) {
        std.log.err(
            "Error stepping sql statement\n{s}\n{s}",
            .{ sql_str, c.sqlite3_errmsg(self.db_p.*) },
        );
        return error.DBError;
    }

    const tr_id: i64 = @intCast(c.sqlite3_last_insert_rowid(self.db_p.*));

    std.log.info(
        "New Transaction [group_id: {x} ({0d}), tr_id: {d}, from_id: {d}, to_id: {d}, description: {s}]",
        .{ group_id, tr_id, from_id, to_id, description },
    );

    return tr_id;
}
