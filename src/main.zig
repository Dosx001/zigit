const std = @import("std");
const git = @cImport(@cInclude("git2.h"));

pub fn main() !void {
    _ = git.git_libgit2_init();
    var repo: ?*git.git_repository = undefined;
    if (0 < git.git_repository_open_ext(&repo, ".", 0, null)) return;
    try log(repo);
    try status(repo);
    try state(repo);
    try branch(repo);
    try stash(repo);
    return;
}

fn branch(repo: ?*git.git_repository) !void {
    var ref: ?*git.git_reference = undefined;
    _ = git.git_repository_head(&ref, repo);
    const name = git.git_reference_shorthand(ref);
    for ("HEAD", 0..) |c, i| {
        if (name[i] != c) break;
    } else {
        var walker: ?*git.git_revwalk = undefined;
        _ = git.git_revwalk_new(&walker, repo);
        _ = git.git_revwalk_push_ref(walker, "HEAD");
        var oid: git.git_oid = undefined;
        _ = git.git_revwalk_next(&oid, walker);
        var output: [8]u8 = undefined;
        _ = git.git_oid_tostr(&output, 8, &oid);
        std.debug.print("{s}\n", .{output});
    }
    std.debug.print("{s}\n", .{name});
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

fn state(repo: ?*git.git_repository) !void {
    const mode =
        switch (git.git_repository_state(repo)) {
        git.GIT_REPOSITORY_STATE_MERGE => "Merge",
        git.GIT_REPOSITORY_STATE_REVERT => "Revert",
        git.GIT_REPOSITORY_STATE_REVERT_SEQUENCE => "Revert",
        git.GIT_REPOSITORY_STATE_CHERRYPICK => "Cherrypick",
        git.GIT_REPOSITORY_STATE_CHERRYPICK_SEQUENCE => "Cherrypick",
        git.GIT_REPOSITORY_STATE_BISECT => "Bisect",
        git.GIT_REPOSITORY_STATE_REBASE => "Rebase",
        git.GIT_REPOSITORY_STATE_REBASE_INTERACTIVE => "Rebase",
        git.GIT_REPOSITORY_STATE_REBASE_MERGE => "Rebase/Merge",
        git.GIT_REPOSITORY_STATE_APPLY_MAILBOX => "Mailbox",
        git.GIT_REPOSITORY_STATE_APPLY_MAILBOX_OR_REBASE => "Mailbox or Rebase",
        else => return,
    };
    std.debug.print("State: {s}\n", .{mode});
}

fn status(repo: ?*git.git_repository) !void {
    var opts: git.git_status_options = undefined;
    _ = git.git_status_init_options(&opts, git.GIT_STATUS_OPTIONS_VERSION);
    opts.flags = git.GIT_STATUS_OPT_INCLUDE_UNTRACKED;
    _ = git.git_status_foreach_ext(repo, &opts, status_cb, null);
}

fn status_cb(path: [*c]const u8, status_flags: c_uint, payload: ?*anyopaque) callconv(.C) c_int {
    _ = payload;
    std.debug.print("{s}: {} ", .{ path, status_flags });
    return 0;
}
