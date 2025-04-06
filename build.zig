const std = @import("std");

pub fn build(b: *std.Build) void {
    const target = b.standardTargetOptions(.{});
    const optimize = b.standardOptimizeOption(.{});

    const exe_mod = b.createModule(.{
        .root_source_file = b.path("src/main.zig"),
        .target = target,
        .optimize = optimize,
        .link_libc = true,
    });

    const exe = b.addExecutable(.{
        .name = "ledger",
        .root_module = exe_mod,
        .use_llvm = (optimize != .Debug),
    });

    const httpz = b.dependency("httpz", .{ .target = target, .optimize = optimize });
    exe_mod.addImport("httpz", httpz.module("httpz"));

    //
    // - SQLite3 -
    //
    switch (optimize) {
        .Debug => exe_mod.linkSystemLibrary("sqlite3", .{}),
        else => {
            exe_mod.addIncludePath(b.path("sqlite3"));
            exe_mod.addCSourceFile(.{
                .file = b.path("sqlite3/sqlite3.c"),
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

    const exe_unit_tests = b.addTest(.{
        .root_module = exe_mod,
    });

    const run_exe_unit_tests = b.addRunArtifact(exe_unit_tests);

    const test_step = b.step("test", "Run unit tests");
    test_step.dependOn(&run_exe_unit_tests.step);
}
