const std = @import("std");
const git = @cImport(@cInclude("git2.h"));

pub fn main() !void {
    _ = git.git_libgit2_init();
    var repo: ?*git.git_repository = undefined;
    const err = git.git_repository_open(&repo, ".");
    if (err < 0) return;
    _ = git.git_status_foreach(repo, status_cb, null);
    _ = git.git_libgit2_shutdown();
    return;
}

fn status_cb(path: [*c]const u8, status_flags: c_uint, payload: ?*anyopaque) callconv(.C) c_int {
    _ = payload;
    std.debug.print("{s}\n", .{path});
    std.debug.print("{}\n", .{status_flags});
    return 0;
}
