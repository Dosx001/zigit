const std = @import("std");
const git = @cImport(@cInclude("git2.h"));

pub fn main() !void {
    _ = git.git_libgit2_init();
    var repo: ?*git.git_repository = undefined;
    if (0 < git.git_repository_open(&repo, ".")) return;
    try log(repo);
    try status(repo);
    try branch(repo);
    try stash(repo);
    return;
}

fn branch(repo: ?*git.git_repository) !void {
    var ref: ?*git.git_reference = undefined;
    _ = git.git_repository_head(&ref, repo);
    std.debug.print("{s}\n", .{git.git_reference_shorthand(ref)});
}

fn log(repo: ?*git.git_repository) !void {
    var walker: ?*git.git_revwalk = undefined;
    _ = git.git_revwalk_new(&walker, repo);
    _ = git.git_revwalk_push_ref(walker, "HEAD");
    var oid: git.git_oid = undefined;
    _ = git.git_revwalk_next(&oid, walker);
    var commit: ?*git.git_commit = undefined;
    _ = git.git_commit_lookup(&commit, repo, &oid);
    std.debug.print("{s}\n", .{git.git_commit_message(commit)});
}

fn stash(repo: ?*git.git_repository) !void {
    var count: u8 = 0;
    _ = git.git_stash_foreach(repo, stash_cb, &count);
    std.debug.print("Stashes: {}\n", .{count});
}

fn stash_cb(index: usize, message: [*c]const u8, stash_id: [*c]const git.git_oid, payload: ?*anyopaque) callconv(.C) c_int {
    _ = index;
    _ = stash_id;
    _ = message;
    const count: *u8 = @ptrCast(@alignCast(payload));
    count.* += 1;
    return 0;
}

fn status(repo: ?*git.git_repository) !void {
    _ = git.git_status_foreach(repo, status_cb, null);
}

fn status_cb(path: [*c]const u8, status_flags: c_uint, payload: ?*anyopaque) callconv(.C) c_int {
    _ = payload;
    std.debug.print("{s}\n", .{path});
    std.debug.print("{}\n", .{status_flags});
    return 0;
}
