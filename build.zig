const std = @import("std");

pub fn build(b: *std.Build) void {
    const exe = b.addExecutable(.{
        .name = "zigit",
        .root_source_file = .{ .path = "src/main.zig" },
        .optimize = .ReleaseFast,
    });
    exe.linkSystemLibrary("c");
    exe.linkSystemLibrary("git2");
    b.installArtifact(exe);
    exe.optimize = .Debug;
    const run_exe = b.addRunArtifact(exe);
    const run_step = b.step("run", "Run the application");
    run_step.dependOn(&run_exe.step);
}
