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

    //
    // - libmicrohttpd -
    //
    switch (optimize) {
        .Debug => exe.linkSystemLibrary("microhttpd"),
        else => {
            exe.linkSystemLibrary("pthread");
            exe.linkSystemLibrary("gnutls");
            exe.addIncludePath(.{ .path = "microhttpd" });
            exe.addIncludePath(.{ .path = "microhttpd/include" });
            exe.addCSourceFiles(.{
                .root = .{ .path = "microhttpd" },
                .files = &[_][]const u8{
                    "basicauth.c",
                    "connection.c",
                    "connection_https.c",
                    "daemon.c",
                    "digestauth.c",
                    "gen_auth.c",
                    "internal.c",
                    "md5_ext.c",
                    "memorypool.c",
                    "mhd_compat.c",
                    "mhd_itc.c",
                    "mhd_mono_clock.c",
                    "mhd_panic.c",
                    "mhd_send.c",
                    "mhd_sockets.c",
                    "mhd_str.c",
                    "mhd_threads.c",
                    "postprocessor.c",
                    "reason_phrase.c",
                    "response.c",
                    "sha1.c",
                    "sha256_ext.c",
                    "sha512_256.c",
                    "sysfdsetsize.c",
                    "tsearch.c",
                },
                .flags = &[_][]const u8{
                    "-DHAVE_CONFIG_H",
                    "-D_GNU_SOURCE",
                    "-D_XOPEN_SOURCE=700",
                    "-fno-strict-aliasing",
                    "-fvisibility=hidden",
                    "-pthread",
                    "-g",
                },
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
