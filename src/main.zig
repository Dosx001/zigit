const std = @import("std");
const git = @cImport(@cInclude("git2.h"));

pub fn main() !void {
    _ = git.git_libgit2_init();
    var repo: ?*git.git_repository = undefined;
    if (0 < git.git_repository_open(&repo, ".")) return;
    var rp = Repository{ .repo = repo };
    try rp.log();
    try rp.status();
    return;
}

const Repository = struct {
    repo: ?*git.git_repository,
    pub fn log(self: Repository) !void {
        var walker: ?*git.git_revwalk = undefined;
        _ = git.git_revwalk_new(&walker, self.repo);
        _ = git.git_revwalk_push_ref(walker, "HEAD");
        var oid: git.git_oid = undefined;
        _ = git.git_revwalk_next(&oid, walker);
        var commit: ?*git.git_commit = undefined;
        _ = git.git_commit_lookup(&commit, self.repo, &oid);
        std.debug.print("{s}\n", .{git.git_commit_message(commit)});
    }
    pub fn status(self: Repository) !void {
        _ = git.git_status_foreach(self.repo, status_cb, null);
    }
    fn status_cb(path: [*c]const u8, status_flags: c_uint, payload: ?*anyopaque) callconv(.C) c_int {
        _ = payload;
        std.debug.print("{s}\n", .{path});
        std.debug.print("{}\n", .{status_flags});
        return 0;
    }
};
