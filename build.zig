const std = @import("std");

pub fn build(b: *std.Build) void {
    const target = b.standardTargetOptions(.{});
    const optimize = b.standardOptimizeOption(.{});

    const ledger_module = b.createModule(.{
        .root_source_file = b.path("src/main.zig"),
        .target = target,
        .optimize = optimize,
        .link_libc = true,
    });

    const ledger = b.addExecutable(.{
        .name = "ledger",
        .root_module = ledger_module,
        .use_llvm = optimize != .Debug,
    });

    //
    // - http.zig -
    //
    const httpz = b.dependency("httpz", .{ .target = target, .optimize = optimize });
    ledger_module.addImport("httpz", httpz.module("httpz"));

    //
    // - SQLite3 -
    //
    switch (optimize) {
        .Debug => ledger_module.linkSystemLibrary("sqlite3", .{}),
        else => {
            ledger_module.addIncludePath(b.path("sqlite3"));
            ledger_module.addCSourceFile(.{
                .file = b.path("sqlite3/sqlite3.c"),
                .flags = &.{},
            });
        },
    }

    b.installArtifact(ledger);

    const run_ledger = b.addRunArtifact(ledger);
    run_ledger.step.dependOn(b.getInstallStep());

    if (b.args) |args| {
        run_ledger.addArgs(args);
    }

    const run_ledger_step = b.step("run", "Run the app");
    run_ledger_step.dependOn(&run_ledger.step);

    //
    // - Tests -
    //
    const tests = b.addTest(.{
        .root_module = ledger_module,
    });

    const run_tests = b.addRunArtifact(tests);

    const run_tests_step = b.step("test", "Run unit tests");
    run_tests_step.dependOn(&run_tests.step);
}
