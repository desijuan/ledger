const std = @import("std");

pub const Error = struct {
    status_code: u16,
    msg: []const u8,
};

pub const Route = union(enum) {
    ERROR: Error,
    NOT_FOUND: void,
    HOME_PAGE: void,
    NEW_GROUP: void,
    GROUP_OVERVIEW: u32,
    NEW_EXPENSE: u32,
};

pub fn route(httpUrl: HttpUrl, httpMethod: HttpMethod, httpVersion: HttpVersion) Route {
    if (httpVersion != .HTTP11) {
        return .NOT_FOUND;
    }

    return switch (httpUrl) {
        .UNKNOWN => .NOT_FOUND,

        .HOME => switch (httpMethod) {
            .GET => .HOME_PAGE,
            else => .NOT_FOUND,
        },

        .NEW_GROUP => switch (httpMethod) {
            .POST => .NEW_GROUP,
            else => .NOT_FOUND,
        },

        .GROUP_OVERVIEW => |group_id| switch (httpMethod) {
            .GET => .{ .GROUP_OVERVIEW = group_id },
            else => .NOT_FOUND,
        },

        .NEW_EXPENSE => |group_id| switch (httpMethod) {
            .POST => .{ .NEW_EXPENSE = group_id },
            else => .NOT_FOUND,
        },
    };
}

pub const HttpUrl = union(enum) {
    UNKNOWN: void,
    HOME: void,
    NEW_GROUP: void,
    GROUP_OVERVIEW: u32,
    NEW_EXPENSE: u32,

    pub fn parse(url_str: []const u8) HttpUrl {
        var iter = std.mem.tokenizeScalar(u8, url_str, '/');
        const str0 = iter.next() orelse return .HOME;

        if (std.mem.eql(u8, "new-group", str0))
            return .NEW_GROUP;

        if (std.mem.eql(u8, "group", str0)) {
            const str1 = iter.next() orelse return .UNKNOWN;
            const group_id = std.fmt.parseInt(u32, str1, 16) catch return .UNKNOWN;

            const str2 = iter.next() orelse return .{ .GROUP_OVERVIEW = group_id };

            if (iter.next()) |_| return .UNKNOWN;

            return if (std.mem.eql(u8, "new-expense", str2))
                .{ .NEW_EXPENSE = group_id }
            else
                .UNKNOWN;
        } else return .UNKNOWN;
    }
};

pub const HttpMethod = enum {
    UNKNOWN,
    GET,
    POST,

    pub fn parse(method_str: []const u8) HttpMethod {
        return if (std.mem.eql(u8, "GET", method_str))
            .GET
        else if (std.mem.eql(u8, "POST", method_str))
            .POST
        else
            .UNKNOWN;
    }
};

pub const HttpVersion = enum {
    UNKNOWN,
    HTTP11,

    pub fn parse(url_str: []const u8) HttpVersion {
        return if (std.mem.eql(u8, "HTTP/1.1", url_str))
            .HTTP11
        else
            .UNKNOWN;
    }
};
