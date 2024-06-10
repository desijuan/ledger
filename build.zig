const std = @import("std");

pub fn build(b: *std.Build) void {
    const target = b.standardTargetOptions(.{});
    const optimize = b.standardOptimizeOption(.{});

    const exe = b.addExecutable(.{
        .name = "ledger",
        .root_source_file = .{ .path = "src/main.zig" },
        .target = target,
        .optimize = optimize,
    });

    const httpz = b.dependency("httpz", .{ .target = target, .optimize = optimize });
    exe.root_module.addImport("httpz", httpz.module("httpz"));

    exe.linkLibC();

    //
    // - SQLite3 -
    //
    switch (optimize) {
        .Debug => exe.linkSystemLibrary("sqlite3"),
        else => {
            exe.addIncludePath(.{ .path = "sqlite3" });
            exe.addCSourceFile(.{
                .file = .{ .path = "sqlite3/sqlite3.c" },
                .flags = &.{},
            });
        },
    }

    b.installArtifact(exe);

    const run_cmd = b.addRunArtifact(exe);
    run_cmd.step.dependOn(b.getInstallStep());

    if (b.args) |args| {
        run_cmd.addArgs(args);
    }

    const run_step = b.step("run", "Run the app");
    run_step.dependOn(&run_cmd.step);
}
