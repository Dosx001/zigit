const std = @import("std");
const git = @cImport(@cInclude("git2.h"));

pub fn main() !void {
    _ = git.git_libgit2_init();
    var repo: ?*git.git_repository = undefined;
    const err = git.git_repository_open(&repo, ".");
    if (err < 0) return;
    var walker: ?*git.git_revwalk = undefined;
    _ = git.git_revwalk_new(&walker, repo);
    _ = git.git_revwalk_push_ref(walker, "HEAD");
    var oid: git.git_oid = undefined;
    _ = git.git_revwalk_next(&oid, walker);
    var commit: ?*git.git_commit = undefined;
    _ = git.git_commit_lookup(&commit, repo, &oid);
    std.debug.print("{s}\n", .{git.git_commit_message(commit)});
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
