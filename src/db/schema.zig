const std = @import("std");

pub const groups =
    \\CREATE TABLE IF NOT EXISTS groups (
    \\id INTEGER PRIMARY KEY,
    \\name TEXT NOT NULL,
    \\description TEXT,
    \\created_at INTEGER NOT NULL
    \\)
;

pub fn members(allocator: std.mem.Allocator, group_id: u32) error{OutOfMemory}![:0]const u8 {
    return try std.fmt.allocPrintZ(allocator,
        \\CREATE TABLE members_{x} (
        \\id INTEGER PRIMARY KEY,
        \\name TEXT NOT NULL
        \\)
    , .{group_id});
}

pub fn trs(allocator: std.mem.Allocator, group_id: u32) error{OutOfMemory}![:0]const u8 {
    return try std.fmt.allocPrintZ(allocator,
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
